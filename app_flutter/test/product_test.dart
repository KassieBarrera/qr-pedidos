import 'package:app_flutter/data/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Product debe convertir correctamente un JSON', () {
    final json = {'id': 1, 'title': 'Producto de prueba', 'price': 9.99};

    final product = Product.fromJson(json);

    expect(product.id, 1);
    expect(product.title, 'Producto de prueba');
    expect(product.price, 9.99);
    expect(product.updatedAt, isA<DateTime>());
  });

  test('Product acepta un precio entero y lo convierte a double', () {
    final product = Product.fromJson({'id': 2, 'title': 'Entero', 'price': 10});

    expect(product.price, 10.0);
    expect(product.price, isA<double>());
  });
}
