import 'package:flutter/material.dart';
import 'package:qr_scanner_bridge/qr_scanner_bridge.dart';

import '../../core/format.dart';
import '../../core/logging/app_log.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/quantity_stepper.dart';
import '../../core/widgets/app_feedback.dart';
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
  String query = '';
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    searchController.clear();
    setState(() => query = '');
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
    if (isScanning) {
      AppLog.w('scanner', 'scanner.rejected', {
        'reason': 'scanInProgress',
        'source': 'ui',
      });
      return;
    }
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
    showAppSnack(
      context,
      text,
      kind: isError ? FeedbackKind.error : FeedbackKind.success,
      icon: icon,
    );
  }

  List<Product> get _filtered {
    final q = query.trim().toLowerCase().replaceFirst('#', '');
    if (q.isEmpty) return products;
    return products
        .where((p) => p.title.toLowerCase().contains(q) || p.id.toString() == q)
        .toList();
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
        tooltip: 'Escanear un código QR de producto',
        icon: isScanning
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              )
            : const Icon(Icons.qr_code_scanner),
        label: const Text('Escanear QR'),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading && products.isEmpty) {
      return const LoadingMessage(text: 'Cargando catálogo…');
    }

    if (loadError != null) {
      return StateMessage(
        icon: Icons.error_outline,
        isError: true,
        title: loadError!,
        body:
            'Puedes intentarlo de nuevo; tus pedidos guardados no se pierden.',
        actionLabel: 'Reintentar',
        onAction: loadProducts,
      );
    }

    if (products.isEmpty) {
      return StateMessage(
        icon: Icons.cloud_off,
        title: 'Todavía no hay catálogo guardado',
        body:
            'Conéctate a internet y actualiza para descargarlo. '
            'Después podrás usarlo sin conexión.',
        actionLabel: 'Descargar catálogo',
        onAction: loadProducts,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final visible = _filtered;

    return Column(
      children: [
        if (refreshError != null)
          Material(
            color: isOffline ? scheme.tertiaryContainer : scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Icon(
                    isOffline ? Icons.cloud_off : Icons.sync_problem,
                    color: isOffline
                        ? scheme.onTertiaryContainer
                        : scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isOffline
                          ? 'Sin conexión: mostrando el catálogo guardado.\n$refreshError'
                          : 'No se pudo actualizar el catálogo; mostrando el '
                                'guardado.\n$refreshError',
                      style: TextStyle(
                        color: isOffline
                            ? scheme.onTertiaryContainer
                            : scheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: loadProducts,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: searchController,
            onChanged: (v) => setState(() => query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o #id',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(Icons.close),
                      onPressed: _clearSearch,
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? StateMessage(
                  icon: Icons.search_off,
                  title: 'Sin resultados',
                  body: 'Ningún producto coincide con "$query".',
                  actionLabel: 'Borrar búsqueda',
                  onAction: _clearSearch,
                )
              : RefreshIndicator(
                  onRefresh: loadProducts,
                  child: ListenableBuilder(
                    listenable: widget.cart,
                    builder: (context, _) => ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final product = visible[index];
                        final inCart = widget.cart.quantityOf(product.id);
                        return _ProductTile(
                          product: product,
                          inCart: inCart,
                          onTap: () => _addToCart(product),
                          onQuantityChanged: (quantity) =>
                              widget.cart.setQuantity(product.id, quantity),
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

class _ProductTile extends StatelessWidget {
  final Product product;
  final int inCart;
  final VoidCallback onTap;
  final ValueChanged<int> onQuantityChanged;

  const _ProductTile({
    required this.product,
    required this.inCart,
    required this.onTap,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      minVerticalPadding: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
      leading: Container(
        constraints: const BoxConstraints(minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '#${product.id}',
          textAlign: TextAlign.center,
          style: AppTheme.money(
            theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
      title: Text(
        product.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        formatMoney(product.price),
        style: AppTheme.money(theme.textTheme.bodyMedium),
      ),
      // Sin unidades: botón de agregar. Con unidades: el mismo contador − n +
      // del pedido, para quitar o sumar sin cambiar de pestaña.
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: inCart > 0
            ? QuantityStepper(
                key: const ValueKey('stepper'),
                quantity: inCart,
                itemName: product.title,
                onChanged: onQuantityChanged,
              )
            : IconButton(
                key: const ValueKey('add'),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                tooltip: 'Agregar ${product.title} al pedido',
                icon: Icon(Icons.add_circle_outline, color: scheme.primary),
                onPressed: onTap,
              ),
      ),
    );
  }
}
