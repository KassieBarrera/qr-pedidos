import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_scanner_bridge/qr_scanner_bridge.dart';

import 'core/config/app_config.dart';
import 'core/database/app_database.dart';
import 'core/network/fake/fake_dummyjson_client.dart';
import 'core/network/fake/fake_scenario.dart';
import 'core/logging/app_log.dart';
import 'core/network/logging_client.dart';
import 'core/network/order_api.dart';
import 'core/network/product_api.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'features/history/orders_controller.dart';
import 'features/home_shell.dart';
import 'features/order/cart_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final fakeScenario = AppConfig.useFakeApi ? FakeScenario() : null;
  final http.Client client = LoggingClient(
    fakeScenario != null
        ? FakeDummyJsonClient(scenario: fakeScenario)
        : http.Client(),
  );
  AppLog.i('app', 'app.start', {
    'apiMode': fakeScenario != null ? 'fake' : 'real',
  });
  if (fakeScenario != null) {
    AppLog.i('fake', 'fake.mode.active');
    fakeScenario.addListener(
      () => AppLog.i('fake', 'fake.scenario', {
        'catalog': fakeScenario.catalogFailure.name,
        'cart': fakeScenario.cartFailure.name,
        'latencyMs': fakeScenario.latency.inMilliseconds,
      }),
    );
  }
  final database = AppDatabase();

  final productRepository = ProductRepository(
    api: ProductApi(client: client),
    database: database,
  );
  final orders = OrdersController(
    repository: OrderRepository(
      database: database,
      api: OrderApi(client: client),
    ),
  )..initialize();

  runApp(
    QrPedidosApp(
      productRepository: productRepository,
      orders: orders,
      cart: CartController(),
      scannerBridge: QrScannerBridge(),
      fakeScenario: fakeScenario,
    ),
  );
}

class QrPedidosApp extends StatelessWidget {
  final ProductRepository productRepository;
  final OrdersController orders;
  final CartController cart;
  final QrScannerBridge scannerBridge;
  final FakeScenario? fakeScenario;

  const QrPedidosApp({
    super.key,
    required this.productRepository,
    required this.orders,
    required this.cart,
    required this.scannerBridge,
    this.fakeScenario,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Pedidos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeShell(
        productRepository: productRepository,
        orders: orders,
        cart: cart,
        scannerBridge: scannerBridge,
        fakeScenario: fakeScenario,
      ),
    );
  }
}
