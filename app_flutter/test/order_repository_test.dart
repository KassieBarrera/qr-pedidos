import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/core/network/order_api.dart';
import 'package:app_flutter/data/models/order.dart';
import 'package:app_flutter/data/repositories/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const lines = [
  OrderLine(productId: 1, quantity: 2, title: 'Mascara', unitPrice: 9.99),
  OrderLine(productId: 2, quantity: 1, title: 'Eyeshadow', unitPrice: 19.99),
];

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase database;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handler;

  OrderRepository buildRepository([AppDatabase? db]) {
    return OrderRepository(
      database: db ?? database,
      api: OrderApi(
        client: MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
      ),
    );
  }

  http.Response ok() =>
      http.Response(jsonEncode({'id': 51, 'total': 39.97}), 201);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qr_pedidos_test');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/test.db',
    );
    requests = [];
    handler = (_) async => ok();
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test('el pedido y sus líneas sobreviven al cierre de la base', () async {
    final created = await buildRepository().createOrder(lines);
    await database.close();

    final reopened = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/test.db',
    );
    final orders = await buildRepository(reopened).getOrders();
    await reopened.close();

    expect(orders, hasLength(1));
    expect(orders.single.id, created.id);
    expect(orders.single.status, OrderStatus.pending);
    expect(orders.single.lines.map((l) => l.quantity), [2, 1]);
    expect(orders.single.estimatedTotal, closeTo(39.97, 0.001));
  });

  test('envío satisfactorio queda confirmado y no se reenvía', () async {
    final repository = buildRepository();
    await repository.createOrder(lines);

    final first = await repository.sendPending();
    final second = await repository.sendPending();

    expect(first.confirmed, 1);
    expect(second.total, 0);
    expect(requests, hasLength(1));

    final body = jsonDecode(requests.single.body);
    expect(body, {
      'userId': 1,
      'products': [
        {'id': 1, 'quantity': 2},
        {'id': 2, 'quantity': 1},
      ],
    });
    expect(
      requests.single.headers['Content-Type'],
      startsWith('application/json'),
    );

    final order = (await repository.getOrders()).single;
    expect(order.status, OrderStatus.confirmed);
    expect(order.remoteRef, '51');
  });

  test('doble toque no inicia dos lotes ni dos POST', () async {
    final gate = Completer<void>();
    handler = (_) async {
      await gate.future;
      return ok();
    };
    final repository = buildRepository();
    await repository.createOrder(lines);

    final first = repository.sendPending();
    final second = repository.sendPending();
    gate.complete();

    final results = await Future.wait([first, second]);
    expect(requests, hasLength(1));
    expect(results[1].alreadyRunning, isTrue);
  });

  test('HTTP 500 deja error y el reintento conserva el mismo ID', () async {
    handler = (_) async => http.Response('fallo', 500);
    final repository = buildRepository();
    final created = await repository.createOrder(lines);

    final failed = await repository.sendPending();
    expect(failed.failed, 1);
    var order = (await repository.getOrders()).single;
    expect(order.status, OrderStatus.error);
    expect(order.lastError, contains('500'));

    handler = (_) async => ok();
    final retried = await repository.sendPending();
    expect(retried.confirmed, 1);

    final orders = await repository.getOrders();
    expect(orders, hasLength(1));
    order = orders.single;
    expect(order.id, created.id);
    expect(order.attempts, 2);
    expect(order.status, OrderStatus.confirmed);
  });

  test('JSON inválido con HTTP 200 deja error', () async {
    handler = (_) async => http.Response('<html>', 200);
    final repository = buildRepository();
    await repository.createOrder(lines);

    await repository.sendPending();
    expect((await repository.getOrders()).single.status, OrderStatus.error);
  });

  test('sin conexión antes de enviar deja error reintentable', () async {
    handler = (_) async =>
        throw const SocketException('Failed host lookup: dummyjson.com');
    final repository = buildRepository();
    await repository.createOrder(lines);

    final summary = await repository.sendPending();
    expect(summary.failed, 1);
    expect((await repository.getOrders()).single.status, OrderStatus.error);
  });

  test('timeout deja resultado desconocido y no entra al lote', () async {
    handler = (_) async => throw TimeoutException('lento');
    final repository = buildRepository();
    final created = await repository.createOrder(lines);

    final summary = await repository.sendPending();
    expect(summary.unknown, 1);
    expect((await repository.getOrders()).single.status, OrderStatus.unknown);

    handler = (_) async => ok();
    final again = await repository.sendPending();
    expect(again.total, 0);
    expect(requests, hasLength(1));

    final result = await repository.retry(created.id);
    expect(result, OrderStatus.confirmed);
    expect(requests, hasLength(2));
  });

  test(
    'un pedido que quedó en Enviando se recupera como desconocido',
    () async {
      final repository = buildRepository();
      final created = await repository.createOrder(lines);
      await database.claimForSending(
        created.id,
        from: const [OrderStatus.pending],
        now: DateTime.now(),
      );

      final recovered = await repository.recoverInterruptedSends();
      final order = (await repository.getOrders()).single;

      expect(recovered, 1);
      expect(order.status, OrderStatus.unknown);
      expect(order.lastError, isNotNull);
    },
  );
}
