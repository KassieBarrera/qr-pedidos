import '../../core/database/app_database.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/network/product_api.dart';
import '../../core/logging/app_log.dart';
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
    AppLog.i('catalog', 'catalog.refresh.start');
    try {
      final remote = await api.fetchProducts();
      await database.saveProducts(remote);
      final saved = await database.getProducts();
      AppLog.i('catalog', 'catalog.refresh.ok', {'count': saved.length});
      return CatalogResult(saved);
    } on ApiException catch (e) {
      final cached = await database.getProducts();
      if (cached.isEmpty) {
        AppLog.w('catalog', 'catalog.empty', {
          'offline': e.isConnectivity,
          'reason': e.message,
        });
      } else {
        AppLog.w('catalog', 'catalog.refresh.fallback', {
          'cached': cached.length,
          'offline': e.isConnectivity,
          'reason': e.message,
        });
      }
      return CatalogResult(
        cached,
        refreshError: e.message,
        isOffline: e.isConnectivity,
      );
    }
  }

  /// Busca primero en la base local y, si no está, en `GET /products/{id}`.
  Future<ProductLookup> findById(int id) async {
    final local = await database.getProduct(id);
    if (local != null) {
      AppLog.d('lookup', 'lookup.local.hit', {'id': id});
      return ProductFound(local);
    }

    try {
      final remote = await api.fetchProduct(id);
      if (remote == null) {
        AppLog.w('lookup', 'lookup.notFound', {'id': id});
        return const ProductNotFound();
      }
      await database.saveProducts([remote]);
      AppLog.i('lookup', 'lookup.remote.found', {'id': id});
      return ProductFound(remote);
    } on ApiException catch (e) {
      if (e.isConnectivity) {
        AppLog.w('lookup', 'lookup.offline', {'id': id});
        return const ProductUnavailableOffline();
      }
      AppLog.w('lookup', 'lookup.failed', {'id': id, 'reason': e.message});
      return ProductLookupFailed(e.message);
    }
  }
}
