import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/core/logging/app_log.dart';
import 'package:app_flutter/core/network/order_api.dart';
import 'package:app_flutter/data/models/order.dart';
import 'package:app_flutter/data/repositories/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late List<String> lines;
  setUp(() {
    lines = [];
    AppLog.enabled = true;
    AppLog.sink = lines.add;
  });
  tearDown(() {
    AppLog.sink = null;
    AppLog.enabled = false;
  });

  test('formato: prefijo, nivel, clave=valor y comillas con espacios', () {
    AppLog.w('catalog', 'catalog.refresh.fallback', {
      'cached': 30,
      'offline': true,
      'reason': 'Sin conexión',
      'skipped': null,
    });
    expect(lines, [
      '[qr_pedidos/catalog] W catalog.refresh.fallback cached=30 '
          'offline=true reason="Sin conexión"',
    ]);
    expect(AppLog.shortId('eb470beb-1234-4000-8000-000000000000'), 'eb470beb');
  });

  test('desactivado no emite nada', () {
    AppLog.enabled = false;
    AppLog.i('db', 'db.open');
    expect(lines, isEmpty);
  });

  test('el doble toque emite queue.batch.joined', () async {
    final dir = await Directory.systemTemp.createTemp('qr_pedidos_log');
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${dir.path}/t.db',
    );
    final gate = Completer<void>();
    final repository = OrderRepository(
      database: database,
      api: OrderApi(
        client: MockClient((_) async {
          await gate.future;
          return http.Response(jsonEncode({'id': 51}), 201);
        }),
      ),
    );
    await repository.createOrder(const [
      OrderLine(productId: 1, quantity: 2, title: 'A', unitPrice: 1.5),
    ]);

    final first = repository.sendPending();
    final second = repository.sendPending();
    gate.complete();
    await Future.wait([first, second]);
    await database.close();
    await dir.delete(recursive: true);

    expect(lines.where((l) => l.contains('queue.batch.start')), hasLength(1));
    expect(
      lines.where((l) => l.contains('queue.batch.joined batch=1')),
      hasLength(1),
    );
  });
}
