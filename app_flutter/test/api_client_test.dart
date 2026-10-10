import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/core/network/api_exceptions.dart';
import 'package:app_flutter/core/network/order_api.dart';
import 'package:app_flutter/core/network/product_api.dart';
import 'package:app_flutter/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final order = Order(
  id: 'abc',
  status: OrderStatus.pending,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  lines: const [
    OrderLine(productId: 1, quantity: 2, title: 'Mascara', unitPrice: 9.99),
    OrderLine(productId: 5, quantity: 1, title: 'Otro', unitPrice: 1),
  ],
);

Future<ApiException> expectApiException(Future<void> Function() action) async {
  try {
    await action();
  } on ApiException catch (e) {
    return e;
  }
  fail('Se esperaba ApiException');
}

void main() {
  group('ProductApi', () {
    test('fetchProducts usa GET /products?limit=30', () async {
      late http.Request captured;
      final api = ProductApi(
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'products': []}), 200);
        }),
      );

      final products = await api.fetchProducts();

      expect(products, isEmpty);
      expect(captured.method, 'GET');
      expect(
        captured.url.toString(),
        'https://dummyjson.com/products?limit=30',
      );
    });

    test('fetchProduct(5) usa GET /products/5', () async {
      late http.Request captured;
      final api = ProductApi(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'id': 5, 'title': 'Cinco', 'price': 5}),
            200,
          );
        }),
      );

      final product = await api.fetchProduct(5);

      expect(product?.id, 5);
      expect(captured.method, 'GET');
      expect(captured.url.toString(), 'https://dummyjson.com/products/5');
    });
  });

  group('OrderApi.submit', () {
    test(
      'envía POST /carts/add con el cuerpo esperado y devuelve el id',
      () async {
        late http.Request captured;
        final api = OrderApi(
          client: MockClient((request) async {
            captured = request;
            return http.Response(jsonEncode({'id': 51, 'total': 1}), 201);
          }),
        );

        final ref = await api.submit(order);

        expect(ref, '51');
        expect(captured.method, 'POST');
        expect(captured.url.toString(), 'https://dummyjson.com/carts/add');
        expect(
          captured.headers['Content-Type'],
          startsWith('application/json'),
        );
        expect(
          captured.body,
          '{"userId":1,"products":'
          '[{"id":1,"quantity":2},{"id":5,"quantity":1}]}',
        );
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect((body['products'] as List).first, isNot(contains('productId')));
      },
    );

    for (final status in [404, 400, 503]) {
      test('HTTP $status lanza ApiException conocida con statusCode', () async {
        final api = OrderApi(
          client: MockClient((_) async => http.Response('x', status)),
        );

        final error = await expectApiException(() => api.submit(order));

        expect(error.outcomeUnknown, isFalse);
        expect(error.statusCode, status);
      });
    }

    test('respuesta 200 sin id lanza ApiException', () async {
      final api = OrderApi(
        client: MockClient((_) async => http.Response('{"total":3}', 200)),
      );

      final error = await expectApiException(() => api.submit(order));

      expect(error.outcomeUnknown, isFalse);
    });
  });

  group('guardedRequest', () {
    Future<http.Response> failWith(Object error) =>
        guardedRequest(() async => throw error);

    test('TimeoutException deja el resultado desconocido', () async {
      final error = await expectApiException(
        () => failWith(TimeoutException('lento')),
      );
      expect(error.outcomeUnknown, isTrue);
    });

    test('SocketException "Failed host lookup" no llegó al servidor', () async {
      final error = await expectApiException(
        () => failWith(const SocketException('Failed host lookup: x')),
      );
      expect(error.outcomeUnknown, isFalse);
    });

    test('SocketException "Connection refused" no llegó al servidor', () async {
      final error = await expectApiException(
        () => failWith(const SocketException('Connection refused')),
      );
      expect(error.outcomeUnknown, isFalse);
    });

    test('ClientException "Connection reset by peer" es desconocido', () async {
      final error = await expectApiException(
        () => failWith(http.ClientException('Connection reset by peer')),
      );
      expect(error.outcomeUnknown, isTrue);
    });
  });
}
