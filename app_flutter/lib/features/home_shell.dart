import 'package:flutter/material.dart';
import 'package:qr_scanner_bridge/qr_scanner_bridge.dart';

import '../core/config/app_config.dart';
import '../core/network/fake/fake_scenario.dart';
import '../data/repositories/product_repository.dart';
import 'catalog/catalog_screen.dart';
import 'fake_mode_banner.dart';
import 'history/orders_controller.dart';
import 'history/orders_screen.dart';
import 'order/cart_controller.dart';
import 'order/current_order_screen.dart';

class HomeShell extends StatefulWidget {
  final ProductRepository productRepository;
  final OrdersController orders;
  final CartController cart;
  final QrScannerBridge scannerBridge;

  /// Solo se usa con `API_MODE=fake`.
  final FakeScenario? fakeScenario;

  const HomeShell({
    super.key,
    required this.productRepository,
    required this.orders,
    required this.cart,
    required this.scannerBridge,
    this.fakeScenario,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          CatalogScreen(
            repository: widget.productRepository,
            cart: widget.cart,
            scannerBridge: widget.scannerBridge,
          ),
          CurrentOrderScreen(
            cart: widget.cart,
            orders: widget.orders,
            onSaved: () => setState(() => index = 2),
          ),
          OrdersScreen(controller: widget.orders),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (AppConfig.useFakeApi && widget.fakeScenario != null)
            FakeModeBanner(scenario: widget.fakeScenario!),
          _buildNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.cart, widget.orders]),
      builder: (context, _) => NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: widget.cart.totalItems > 0,
              label: Text('${widget.cart.totalItems}'),
              child: const Icon(Icons.shopping_basket_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_basket),
            label: 'Pedido',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: widget.orders.attentionCount > 0,
              label: Text('${widget.orders.attentionCount}'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}
