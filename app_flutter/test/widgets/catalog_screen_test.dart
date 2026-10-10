import 'dart:convert';

import 'package:app_flutter/core/database/app_database.dart';
import 'package:app_flutter/core/network/product_api.dart';
import 'package:app_flutter/data/models/product.dart';
import 'package:app_flutter/data/repositories/product_repository.dart';
import 'package:app_flutter/features/catalog/catalog_screen.dart';
import 'package:app_flutter/features/order/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_scanner_bridge/qr_scanner_bridge.dart';

/// Doble en memoria de la base: evita I/O real de sqflite en widget tests.
class InMemoryDatabase extends AppDatabase {
  final Map<int, Product> products = {};

  @override
  Future<void> saveProducts(List<Product> list) async {
    for (final p in list) {
      products[p.id] = p;
    }
  }

  @override
  Future<List<Product>> getProducts() async =>
      products.values.toList()..sort((a, b) => a.title.compareTo(b.title));

  @override
  Future<Product?> getProduct(int id) async => products[id];

  @override
  Future<void> close() async {}
}

const channel = MethodChannel('test');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDatabase database;
  late CartController cart;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handler;
  late Future<Object?> Function() scanHandler;

  final catalog = http.Response(
    jsonEncode({
      'products': [
        {'id': 1, 'title': 'Mascara', 'price': 9.99},
        {'id': 2, 'title': 'Eyeshadow', 'price': 19.99},
      ],
    }),
    200,
  );

  Product product(int id, String title) =>
      Product(id: id, title: title, price: 9.99, updatedAt: DateTime(2026));

  Future<void> pumpCatalog(WidgetTester tester) async {
    final repository = ProductRepository(
      database: database,
      api: ProductApi(
        client: MockClient((request) {
          requests.add(request);
          return handler(request);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogScreen(
          repository: repository,
          cart: cart,
          scannerBridge: QrScannerBridge(channel: channel),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    database = InMemoryDatabase();
    cart = CartController();
    requests = [];
    handler = (_) async => catalog;
    scanHandler = () async => {'productId': 1};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) => scanHandler());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('sin datos y sin conexión muestra el estado vacío explicativo', (
    tester,
  ) async {
    handler = (_) async => throw http.ClientException('Failed host lookup');

    await pumpCatalog(tester);

    expect(find.text('Todavía no hay catálogo guardado'), findsOneWidget);
    expect(find.text('Descargar catálogo'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('con caché y sin red muestra la lista y el banner sin conexión', (
    tester,
  ) async {
    await database.saveProducts([
      product(1, 'Mascara'),
      product(2, 'Eyeshadow'),
    ]);
    handler = (_) async => throw http.ClientException('Failed host lookup');

    await pumpCatalog(tester);

    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('Mascara'), findsOneWidget);
    expect(
      find.textContaining('Sin conexión: mostrando el catálogo guardado'),
      findsOneWidget,
    );
  });

  group('escaneo', () {
    testWidgets('producto existente se agrega al carrito con SnackBar', (
      tester,
    ) async {
      await pumpCatalog(tester);

      await scan(tester);

      expect(cart.quantityOf(1), 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Mascara agregado'), findsOneWidget);
    });

    testWidgets('re-escanear el mismo producto suma cantidad (decisión)', (
      tester,
    ) async {
      await pumpCatalog(tester);

      await scan(tester);
      await scan(tester);

      expect(cart.quantityOf(1), 2);
      expect(cart.lines, hasLength(1));
    });

    testWidgets(
      'cancelar muestra "Escaneo cancelado." y no cambia el carrito',
      (tester) async {
        await pumpCatalog(tester);
        scanHandler = () async => throw PlatformException(code: 'cancelled');

        await scan(tester);

        expect(find.text('Escaneo cancelado.'), findsOneWidget);
        expect(cart.isEmpty, isTrue);
      },
    );

    testWidgets('QR inválido muestra su mensaje y no cambia el carrito', (
      tester,
    ) async {
      await pumpCatalog(tester);
      scanHandler = () async => throw PlatformException(code: 'invalidQr');

      await scan(tester);

      expect(
        find.textContaining('no es un QR de producto válido'),
        findsOneWidget,
      );
      expect(cart.isEmpty, isTrue);
    });

    testWidgets('permiso denegado muestra su mensaje y no cambia el carrito', (
      tester,
    ) async {
      await pumpCatalog(tester);
      scanHandler = () async =>
          throw PlatformException(code: 'permissionDenied');

      await scan(tester);

      expect(find.textContaining('permiso de cámara'), findsOneWidget);
      expect(cart.isEmpty, isTrue);
    });

    testWidgets(
      'product:999999 con API 404 muestra "no encontrado" sin línea',
      (tester) async {
        await pumpCatalog(tester);
        scanHandler = () async => {'productId': 999999};
        handler = (request) async => request.url.path == '/products/999999'
            ? http.Response('{"message":"not found"}', 404)
            : catalog;

        await scan(tester);

        expect(find.textContaining('999999 no encontrado'), findsOneWidget);
        expect(cart.isEmpty, isTrue);
      },
    );
  });
}
