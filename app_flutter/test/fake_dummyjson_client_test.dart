import 'dart:io';

import 'package:app_flutter/core/network/api_exceptions.dart';
import 'package:app_flutter/core/network/fake/fake_dummyjson_client.dart';
import 'package:app_flutter/core/network/fake/fake_scenario.dart';
import 'package:app_flutter/core/network/order_api.dart';
import 'package:app_flutter/core/network/product_api.dart';
import 'package:app_flutter/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// El modo simulado debe ejercitar los clientes REST reales sin cambios.
void main() {
  late FakeScenario scenario;
  late ProductApi productApi;
  late OrderApi orderApi;

  final order = Order(
    id: 'local-1',
    status: OrderStatus.pending,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    lines: const [
      OrderLine(productId: 1, quantity: 2, title: 'Mascara', unitPrice: 9.99),
    ],
  );

  setUp(() {
    scenario = FakeScenario()..latency = Duration.zero;
    final client = FakeDummyJsonClient(
      scenario: scenario,
      loadAsset: (asset) => File(asset).readAsString(),
    );
    productApi = ProductApi(client: client);
    orderApi = OrderApi(client: client);
  });

  test('sirve el catálogo de fixtures con los IDs 1, 2 y 3', () async {
    final products = await productApi.fetchProducts();
    expect(products.map((p) => p.id), containsAll([1, 2, 3]));
  });

  test('product:999999 es el doble de producto inexistente (404)', () async {
    expect(await productApi.fetchProduct(2), isNotNull);
    expect(await productApi.fetchProduct(999999), isNull);
  });

  test('sin fallo, el pedido devuelve la referencia simulada', () async {
    expect(await orderApi.submit(order), '51');
  });

  test('catálogo sin conexión es un fallo de conectividad', () async {
    scenario.catalogFailure = CatalogFailure.offline;
    await expectLater(
      productApi.fetchProducts(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isConnectivity,
          'isConnectivity',
          isTrue,
        ),
      ),
    );
  });

  test('catálogo con HTTP 500 no se confunde con falta de conexión', () async {
    scenario.catalogFailure = CatalogFailure.http500;
    await expectLater(
      productApi.fetchProducts(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isConnectivity, 'isConnectivity', isFalse)
            .having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });

  test('conexión cortada tras enviar deja el resultado desconocido', () async {
    scenario.cartFailure = CartFailure.dropAfterSend;
    await expectLater(
      orderApi.submit(order),
      throwsA(
        isA<ApiException>().having(
          (e) => e.outcomeUnknown,
          'outcomeUnknown',
          isTrue,
        ),
      ),
    );
  });

  test('pedido con HTTP 400 es un error conocido', () async {
    scenario.cartFailure = CartFailure.http400;
    await expectLater(
      orderApi.submit(order),
      throwsA(
        isA<ApiException>()
            .having((e) => e.outcomeUnknown, 'outcomeUnknown', isFalse)
            .having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
  });
}
