import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/product.dart';

class ProductApi {
  final http.Client client;

  ProductApi({required this.client});

  Future<List<Product>> fetchProducts() async {
    final uri = Uri.parse('https://dummyjson.com/products?limit=30');
    final response = await client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al obtener productos: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic> || data['products'] is! List) {
      throw const FormatException(
        'Error al obtener productos: formato de respuesta inesperado',
      );
    }
    final products = data['products'] as List;

    return products.map((item) {
      return Product.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }
}
