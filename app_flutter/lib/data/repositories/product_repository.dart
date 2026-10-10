import '../../core/database/app_database.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/network/product_api.dart';
import '../models/product.dart';

class CatalogResult {
  final List<Product> products;

  /// Mensaje si la descarga falló y se muestran los datos guardados.
  final String? refreshError;

  /// true si el refresco falló por falta de conectividad (no por un error
  /// del servidor).
  final bool isOffline;

  const CatalogResult(
    this.products, {
    this.refreshError,
    this.isOffline = false,
  });

  bool get isFromCache => refreshError != null;
}

sealed class ProductLookup {
  const ProductLookup();
}

class ProductFound extends ProductLookup {
  final Product product;
  const ProductFound(this.product);
}

/// El servidor confirmó que el ID no existe.
class ProductNotFound extends ProductLookup {
  const ProductNotFound();
}

/// No está guardado localmente y no hay conexión para consultar la API.
class ProductUnavailableOffline extends ProductLookup {
  const ProductUnavailableOffline();
}

/// No está guardado localmente y la API respondió con error o datos
/// inválidos. Distinto de offline: hay red, pero el servidor falló.
class ProductLookupFailed extends ProductLookup {
  final String message;
  const ProductLookupFailed(this.message);
}

class ProductRepository {
  final ProductApi api;
  final AppDatabase database;

  ProductRepository({required this.api, required this.database});

  /// Refresca desde REST y devuelve la base local. Si la descarga falla,
  /// conserva la última copia válida.
  Future<CatalogResult> getProducts() async {
    try {
      final remote = await api.fetchProducts();
      await database.saveProducts(remote);
      return CatalogResult(await database.getProducts());
    } on ApiException catch (e) {
      return CatalogResult(
        await database.getProducts(),
        refreshError: e.message,
        isOffline: e.isConnectivity,
      );
    }
  }

  /// Busca primero en la base local y, si no está, en `GET /products/{id}`.
  Future<ProductLookup> findById(int id) async {
    final local = await database.getProduct(id);
    if (local != null) return ProductFound(local);

    try {
      final remote = await api.fetchProduct(id);
      if (remote == null) return const ProductNotFound();
      await database.saveProducts([remote]);
      return ProductFound(remote);
    } on ApiException catch (e) {
      return e.isConnectivity
          ? const ProductUnavailableOffline()
          : ProductLookupFailed(e.message);
    }
  }
}
