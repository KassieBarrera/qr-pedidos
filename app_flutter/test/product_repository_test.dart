import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/core/network/order_api.dart';
import 'package:app_flutter/core/network/product_api.dart';
import 'package:app_flutter/data/models/order.dart';
import 'package:app_flutter/data/models/product.dart';
import 'package:app_flutter/data/repositories/order_repository.dart';
import 'package:app_flutter/data/repositories/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

http.Response catalogJson() => http.Response(
  jsonEncode({
    'products': [
      {'id': 1, 'title': 'Mascara', 'price': 9.99},
      {'id': 2, 'title': 'Eyeshadow', 'price': 19},
    ],
  }),
  200,
);

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase database;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handler;

  ProductRepository buildRepository() {
    return ProductRepository(
      database: database,
      api: ProductApi(
        client: MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
      ),
    );
  }

  final offline = SocketException('Failed host lookup: dummyjson.com');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qr_pedidos_products');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/test.db',
    );
    requests = [];
    handler = (_) async => catalogJson();
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> seedCache() async {
    await database.saveProducts([
      Product(id: 1, title: 'Mascara', price: 9.99, updatedAt: DateTime(2026)),
      Product(
        id: 2,
        title: 'Eyeshadow',
        price: 19.99,
        updatedAt: DateTime(2026),
      ),
    ]);
  }

  group('getProducts', () {
    test(
      'primera carga con red guarda en la BD y devuelve productos',
      () async {
        final result = await buildRepository().getProducts();

        expect(result.refreshError, isNull);
        expect(result.isFromCache, isFalse);
        expect(result.products.map((p) => p.title), ['Eyeshadow', 'Mascara']);
        expect(await database.getProducts(), hasLength(2));
        expect(requests, hasLength(1));
      },
    );

    test('con caché previa y red caída devuelve la copia guardada', () async {
      await seedCache();
      handler = (_) async => throw offline;

      final result = await buildRepository().getProducts();

      expect(result.products, hasLength(2));
      expect(result.refreshError, isNotNull);
      expect(result.isFromCache, isTrue);
      expect(result.isOffline, isTrue);
    });

    test('HTTP 500 en el refresco conserva la última copia válida', () async {
      await seedCache();
      handler = (_) async => http.Response('fallo', 500);

      final result = await buildRepository().getProducts();

      expect(result.isFromCache, isTrue);
      expect(result.isOffline, isFalse);
      expect(result.products, hasLength(2));
      expect(await database.getProducts(), hasLength(2));
    });

    test('JSON inválido en el refresco conserva la última copia', () async {
      await seedCache();
      handler = (_) async => http.Response('<html>', 200);

      final result = await buildRepository().getProducts();

      expect(result.isFromCache, isTrue);
      expect(result.products, hasLength(2));
      expect(await database.getProducts(), hasLength(2));
    });

    test('refrescar el catálogo no borra los pedidos guardados', () async {
      final orders = OrderRepository(
        database: database,
        api: OrderApi(
          client: MockClient((_) async => http.Response('{}', 500)),
        ),
      );
      final created = await orders.createOrder(const [
        OrderLine(productId: 1, quantity: 2, title: 'Mascara', unitPrice: 9.99),
      ]);

      await buildRepository().getProducts();
      handler = (_) async => throw offline;
      await buildRepository().getProducts();

      final saved = await orders.getOrders();
      expect(saved, hasLength(1));
      expect(saved.single.id, created.id);
      expect(saved.single.lines.single.quantity, 2);
    });

    test('sin caché y sin red devuelve lista vacía con error', () async {
      handler = (_) async => throw offline;

      final result = await buildRepository().getProducts();

      expect(result.products, isEmpty);
      expect(result.refreshError, isNotNull);
    });
  });

  group('findById', () {
    test('producto guardado localmente no toca la red', () async {
      await seedCache();

      final lookup = await buildRepository().findById(1);

      expect(lookup, isA<ProductFound>());
      expect((lookup as ProductFound).product.title, 'Mascara');
      expect(requests, isEmpty);
    });

    test('no local y API 200 devuelve el producto y lo guarda', () async {
      handler = (_) async => http.Response(
        jsonEncode({'id': 7, 'title': 'Lipstick', 'price': 12.5}),
        200,
      );

      final lookup = await buildRepository().findById(7);

      expect(lookup, isA<ProductFound>());
      expect(requests.single.url.path, '/products/7');
      expect((await database.getProduct(7))?.title, 'Lipstick');
    });

    test(
      'product:999999 con doble que responde 404 es ProductNotFound',
      () async {
        handler = (_) async => http.Response('{"message":"not found"}', 404);

        final lookup = await buildRepository().findById(999999);

        expect(lookup, isA<ProductNotFound>());
        expect(requests.single.url.path, '/products/999999');
        expect(await database.getProduct(999999), isNull);
      },
    );

    test('no local y sin red devuelve ProductUnavailableOffline', () async {
      handler = (_) async => throw offline;

      final lookup = await buildRepository().findById(7);

      expect(lookup, isA<ProductUnavailableOffline>());
    });

    test(
      'no local y HTTP 500 devuelve ProductLookupFailed, no offline',
      () async {
        handler = (_) async => http.Response('fallo', 500);

        final lookup = await buildRepository().findById(7);

        expect(lookup, isA<ProductLookupFailed>());
      },
    );
  });
}
