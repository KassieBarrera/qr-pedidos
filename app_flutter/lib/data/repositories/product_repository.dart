import '../../core/database/app_database.dart';
import '../../core/network/product_api.dart';
import '../models/product.dart';

class ProductRepository {
  final ProductApi api;
  final AppDatabase database;

  ProductRepository({required this.api, required this.database});

  Future<List<Product>> getProducts() async {
    final cachedProducts = await database.getProducts();

    List<Product> remoteProducts;

    try {
      remoteProducts = await api.fetchProducts();
    } catch (_) {
      return cachedProducts;
    }

    await database.saveProducts(remoteProducts);

    return await database.getProducts();
  }
}
