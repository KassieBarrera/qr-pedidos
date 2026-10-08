
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/data/models/product.dart';

void main() {
  test('Product debe convertir correctamente un JSON', () {
    final json = {
      'id': 1,
      'title': 'Producto de prueba',
      'price': 9.99,
    };

    final product = Product.fromJson(json);

    expect(product.id, 1);
    expect(product.title, 'Producto de prueba');
    expect(product.price, 9.99);
    expect(product.updatedAt, isA<DateTime>());
  });
}
