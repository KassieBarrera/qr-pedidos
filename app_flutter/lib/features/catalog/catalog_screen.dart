import 'package:flutter/material.dart';
import 'package:qr_scanner_bridge/qr_scanner_bridge.dart';

import '../../core/format.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../order/cart_controller.dart';

class CatalogScreen extends StatefulWidget {
  final ProductRepository repository;
  final CartController cart;
  final QrScannerBridge scannerBridge;

  const CatalogScreen({
    super.key,
    required this.repository,
    required this.cart,
    required this.scannerBridge,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Product> products = [];
  bool isLoading = true;
  String? refreshError;
  bool isOffline = false;
  String? loadError;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await widget.repository.getProducts();
      if (!mounted) return;
      setState(() {
        products = result.products;
        refreshError = result.refreshError;
        isOffline = result.isOffline;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadError = 'No pudimos leer el catálogo guardado.';
        isLoading = false;
      });
    }
  }

  void _addToCart(Product product) {
    widget.cart.addProduct(product);
    _showMessage(
      '${product.title} agregado · ${widget.cart.quantityOf(product.id)} en el pedido',
    );
  }

  Future<void> scanProduct() async {
    if (isScanning) return;
    setState(() => isScanning = true);

    try {
      final scan = await widget.scannerBridge.scanProduct();
      if (!mounted) return;
      final productId = scan.productId;

      final lookup = await widget.repository.findById(productId);
      if (!mounted) return;

      switch (lookup) {
        case ProductFound(:final product):
          _addToCart(product);
        case ProductNotFound():
          _showMessage('Producto $productId no encontrado.', isError: true);
        case ProductUnavailableOffline():
          _showMessage(
            'El producto $productId no está guardado y no hay conexión. '
            'No está disponible offline.',
            isError: true,
          );
        case ProductLookupFailed(:final message):
          _showMessage(
            'No se pudo consultar el producto $productId: $message',
            isError: true,
          );
      }
    } on ScanException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case ScanErrorCode.cancelled:
          _showMessage('Escaneo cancelado.', icon: Icons.info_outline);
        case ScanErrorCode.permissionDenied:
          _showMessage(
            'Se necesita permiso de cámara para escanear. Puedes volver a '
            'intentarlo y aceptarlo; si el sistema ya no lo solicita, '
            'habilítalo en Ajustes > Aplicaciones > QR Pedidos > Permisos.',
            isError: true,
          );
        case ScanErrorCode.cameraUnavailable:
          _showMessage(
            'No se pudo usar la cámara. Verifica que el dispositivo tenga '
            'cámara y que no la esté usando otra app.',
            isError: true,
          );
        case ScanErrorCode.invalidQr:
          _showMessage(
            'El código no es un QR de producto válido (product:<id>).',
            isError: true,
          );
        case ScanErrorCode.scanInProgress:
          _showMessage('Ya hay un escaneo en curso.', isError: true);
        case ScanErrorCode.unknown:
          _showMessage(
            'No se pudo escanear por un error inesperado. Inténtalo de nuevo.',
            isError: true,
          );
      }
    } finally {
      if (mounted) setState(() => isScanning = false);
    }
  }

  void _showMessage(String text, {bool isError = false, IconData? icon}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ??
                  (isError ? Icons.error_outline : Icons.check_circle_outline),
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadProducts,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar catálogo',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isScanning ? null : scanProduct,
        icon: isScanning
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_scanner),
        label: const Text('Escanear QR'),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (loadError != null) {
      return _Message(
        icon: Icons.error_outline,
        title: loadError!,
        actionLabel: 'Reintentar',
        onAction: loadProducts,
      );
    }

    if (products.isEmpty) {
      return _Message(
        icon: Icons.cloud_off,
        title: 'Todavía no hay catálogo guardado',
        body:
            'Conéctate a internet y actualiza para descargarlo. '
            'Después podrás usarlo sin conexión.',
        actionLabel: 'Descargar catálogo',
        onAction: loadProducts,
      );
    }

    return Column(
      children: [
        if (refreshError != null)
          MaterialBanner(
            leading: Icon(isOffline ? Icons.cloud_off : Icons.sync_problem),
            content: Text(
              isOffline
                  ? 'Sin conexión: mostrando el catálogo guardado.\n$refreshError'
                  : 'No se pudo actualizar el catálogo; mostrando el '
                        'guardado.\n$refreshError',
            ),
            actions: [
              TextButton(
                onPressed: loadProducts,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: loadProducts,
            child: ListenableBuilder(
              listenable: widget.cart,
              builder: (context, _) => ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final inCart = widget.cart.quantityOf(product.id);

                  return ListTile(
                    leading: CircleAvatar(child: Text('${product.id}')),
                    title: Text(product.title),
                    subtitle: Text(formatMoney(product.price)),
                    trailing: inCart > 0
                        ? Badge(
                            label: Text('$inCart'),
                            child: const Icon(Icons.shopping_basket),
                          )
                        : const Icon(Icons.add_circle_outline),
                    onTap: () => _addToCart(product),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.title,
    this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
