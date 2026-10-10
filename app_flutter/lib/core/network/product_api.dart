import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/product.dart';
import 'api_exceptions.dart';

class ProductApi {
  static const baseUrl = 'https://dummyjson.com';

  final http.Client client;

  ProductApi({required this.client});

  Future<List<Product>> fetchProducts() async {
    final response = await guardedRequest(
      () => client.get(Uri.parse('$baseUrl/products?limit=30')),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Error al obtener productos: HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = _decode(response.body);
    if (data is! Map<String, dynamic> || data['products'] is! List) {
      throw const ApiException('Respuesta de productos con formato inesperado');
    }

    return (data['products'] as List).map((item) {
      return Product.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }

  /// Devuelve null si el producto no existe (HTTP 404).
  Future<Product?> fetchProduct(int id) async {
    final response = await guardedRequest(
      () => client.get(Uri.parse('$baseUrl/products/$id')),
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException(
        'Error al obtener el producto $id: HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = _decode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Respuesta de producto con formato inesperado');
    }
    return Product.fromJson(data);
  }

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const ApiException('La respuesta no es JSON válido');
    }
  }
}
