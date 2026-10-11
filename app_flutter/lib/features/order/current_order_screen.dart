import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/quantity_stepper.dart';
import '../../core/widgets/app_feedback.dart';
import '../history/orders_controller.dart';
import '../../data/models/order.dart';
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

    try {
      await widget.orders.create(widget.cart.lines);
      widget.cart.clear();
      // El aviso de éxito lo muestra HomeShell sobre el Historial.
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          'No se pudo guardar el pedido: $e',
          kind: FeedbackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.cart,
      builder: (context, _) {
        final cart = widget.cart;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Pedido actual')),
          body: cart.isEmpty
              ? const StateMessage(
                  icon: Icons.shopping_basket_outlined,
                  title: 'El pedido está vacío',
                  body: 'Escanea un QR o toca un producto del catálogo para agregarlo.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    // El ticket se ajusta a su contenido; la lista hace scroll
                    // si hay muchas líneas.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            const _TicketHeader(),
                            for (final line in cart.lines) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: DottedDivider(),
                              ),
                              _LineRow(
                                line: line,
                                onChanged: (q) =>
                                    cart.setQuantity(line.productId, q),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          // En bottomNavigationBar el SnackBar queda siempre por encima.
          bottomNavigationBar: cart.isEmpty
              ? null
              : Material(
                  color: scheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                'Total estimado · ${cart.totalItems} '
                                '${cart.totalItems == 1 ? 'unidad' : 'unidades'}',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatMoney(cart.estimatedTotal),
                              style: AppTheme.money(
                                theme.textTheme.headlineSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Precio × cantidad, sin impuestos ni envío.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: isSaving ? null : _save,
                          icon: isSaving
                              ? SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onSurface,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            isSaving ? 'Guardando…' : 'Guardar pedido',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(Icons.receipt_long, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ticket del pedido',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final OrderLine line;
  final ValueChanged<int> onChanged;

  const _LineRow({required this.line, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(line.title, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  formatMoney(line.subtotal),
                  textAlign: TextAlign.end,
                  style: AppTheme.money(theme.textTheme.titleMedium),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatMoney(line.unitPrice)} × ${line.quantity}',
                  style: AppTheme.money(theme.textTheme.bodySmall),
                ),
              ),
              QuantityStepper(
                quantity: line.quantity,
                itemName: line.title,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Separador punteado de ticket.
class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DotsPainter(Theme.of(context).colorScheme.outline),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color color;
  _DotsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 2, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}
