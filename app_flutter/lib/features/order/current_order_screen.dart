import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../history/orders_controller.dart';
import 'cart_controller.dart';

class CurrentOrderScreen extends StatefulWidget {
  final CartController cart;
  final OrdersController orders;

  /// Se llama después de guardar para llevar al usuario al historial.
  final VoidCallback onSaved;

  const CurrentOrderScreen({
    super.key,
    required this.cart,
    required this.orders,
    required this.onSaved,
  });

  @override
  State<CurrentOrderScreen> createState() => _CurrentOrderScreenState();
}

class _CurrentOrderScreenState extends State<CurrentOrderScreen> {
  bool isSaving = false;

  Future<void> _save() async {
    if (isSaving || widget.cart.isEmpty) return;
    setState(() => isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await widget.orders.create(widget.cart.lines);
      widget.cart.clear();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Pedido guardado como Pendiente. Envíalo desde Historial.',
          ),
        ),
      );
      widget.onSaved();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el pedido: $e'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedido actual')),
      body: ListenableBuilder(
        listenable: widget.cart,
        builder: (context, _) {
          final cart = widget.cart;

          if (cart.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_basket_outlined, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'El pedido está vacío',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Escanea un QR o toca un producto del catálogo para agregarlo.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = cart.lines[index];
                    return ListTile(
                      title: Text(line.title),
                      subtitle: Text(
                        '${formatMoney(line.unitPrice)} × ${line.quantity} = '
                        '${formatMoney(line.subtotal)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: line.quantity == 1
                                ? 'Quitar ${line.title}'
                                : 'Restar uno',
                            icon: Icon(
                              line.quantity == 1
                                  ? Icons.delete_outline
                                  : Icons.remove_circle_outline,
                            ),
                            onPressed: () => cart.setQuantity(
                              line.productId,
                              line.quantity - 1,
                            ),
                          ),
                          Text(
                            '${line.quantity}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            tooltip: 'Sumar uno',
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => cart.setQuantity(
                              line.productId,
                              line.quantity + 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Total estimado · ${cart.totalItems} unidades'),
                          const Spacer(),
                          Text(
                            formatMoney(cart.estimatedTotal),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const Text(
                        'Precio × cantidad, sin impuestos ni envío.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: isSaving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar pedido'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
