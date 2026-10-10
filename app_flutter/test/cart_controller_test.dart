import 'package:app_flutter/data/models/product.dart';
import 'package:app_flutter/features/order/cart_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mascara = Product(
    id: 1,
    title: 'Mascara',
    price: 9.99,
    updatedAt: DateTime(2026),
  );
  final eyeshadow = Product(
    id: 2,
    title: 'Eyeshadow',
    price: 19.99,
    updatedAt: DateTime(2026),
  );

  test('escanear el mismo producto suma cantidad', () {
    final cart = CartController()
      ..addProduct(mascara)
      ..addProduct(mascara)
      ..addProduct(eyeshadow);

    expect(cart.lines, hasLength(2));
    expect(cart.quantityOf(1), 2);
    expect(cart.totalItems, 3);
    expect(cart.estimatedTotal, closeTo(39.97, 0.001));
  });

  test('bajar a cero quita la línea', () {
    final cart = CartController()..addProduct(mascara);

    cart.setQuantity(1, 0);

    expect(cart.isEmpty, isTrue);
  });
}
