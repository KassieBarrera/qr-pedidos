import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/core/network/order_api.dart';
import 'package:app_flutter/data/models/order.dart';
import 'package:app_flutter/data/repositories/order_repository.dart';
import 'package:app_flutter/features/history/orders_controller.dart';
import 'package:app_flutter/features/history/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const lines = [
  OrderLine(productId: 1, quantity: 2, title: 'Mascara', unitPrice: 9.99),
];

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase database;
  late OrderRepository repository;
  late OrdersController controller;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handler;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('qr_pedidos_orders_ui');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDir.path}/test.db',
    );
    requests = [];
    handler = (_) async => http.Response(jsonEncode({'id': 77}), 201);
    repository = OrderRepository(
      database: database,
      api: OrderApi(
        client: MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
      ),
    );
    controller = OrdersController(repository: repository);
  });

  tearDown(() async {
    controller.dispose();
    await repository.dispose();
    await database.close();
    await tempDir.delete(recursive: true);
  });

  /// La base ffi hace I/O real: se avanza el reloj real hasta que se cumpla
  /// la condición, sin esperas fijas.
  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue, reason: 'la condición no se cumplió a tiempo');
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(
      MaterialApp(home: OrdersScreen(controller: controller)),
    );
    await tester.pump();
  }

  testWidgets('historial vacío muestra un mensaje explicativo', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Aún no hay pedidos guardados'), findsOneWidget);
    expect(find.textContaining('sin conexión'), findsOneWidget);
    expect(find.textContaining('Enviar pendientes'), findsNothing);
  });

  testWidgets(
    'doble toque en Enviar pendientes produce un solo POST y estado con texto',
    (tester) async {
      final gate = Completer<void>();
      handler = (_) async {
        await gate.future;
        return http.Response(jsonEncode({'id': 77}), 201);
      };
      await tester.runAsync(() => repository.createOrder(lines));
      await pumpScreen(tester);

      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Enviar pendientes (1)'), findsOneWidget);

      await tester.tap(find.text('Enviar pendientes (1)'));
      await pumpUntil(tester, () => requests.length == 1);
      // Segundo toque mientras la respuesta sigue retenida.
      await tester.tap(find.byType(FloatingActionButton), warnIfMissed: false);
      await tester.pump();

      gate.complete();
      await pumpUntil(
        tester,
        () => find.text('Confirmado simulado').evaluate().isNotEmpty,
      );

      expect(requests, hasLength(1));
      expect(find.text('Confirmado simulado'), findsOneWidget);
      expect(find.textContaining('Referencia simulada: #77'), findsOneWidget);
    },
  );

  testWidgets('pedido desconocido: aviso, diálogo y Cancelar no envía nada', (
    tester,
  ) async {
    handler = (_) async => throw TimeoutException('lento');
    await tester.runAsync(() async {
      await repository.createOrder(lines);
      await repository.sendPending();
    });
    requests.clear();
    await pumpScreen(tester);

    expect(find.text('Resultado desconocido'), findsOneWidget);
    expect(
      find.textContaining('No se incluye en "Enviar pendientes"'),
      findsOneWidget,
    );
    // Sin pendientes ni errores, el botón de envío se oculta.
    expect(find.textContaining('Enviar pendientes ('), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Reintentar este pedido?'), findsOneWidget);
    expect(find.textContaining('podría recibirlo dos veces'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Reintentar este pedido?'), findsNothing);
    expect(requests, isEmpty);
    expect(find.text('Resultado desconocido'), findsOneWidget);
  });
}
