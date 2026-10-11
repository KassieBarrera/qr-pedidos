import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../order/current_order_screen.dart' show DottedDivider;
import '../../data/models/order.dart';
import 'order_status_badge.dart';
import 'orders_controller.dart';

class OrdersScreen extends StatelessWidget {
  final OrdersController controller;

  const OrdersScreen({super.key, required this.controller});

  Future<void> _sendPending(BuildContext context) async {
    final summary = await controller.sendPending();
    if (summary.alreadyRunning || !context.mounted) return;

    if (summary.total == 0) {
      showAppSnack(
        context,
        'No hay pedidos pendientes para enviar.',
        kind: FeedbackKind.info,
      );
      return;
    }
    showAppSnack(
      context,
      'Envío terminado: ${summary.confirmed} confirmados, '
      '${summary.failed} con error, ${summary.unknown} desconocidos.',
      kind: summary.failed + summary.unknown > 0
          ? FeedbackKind.info
          : FeedbackKind.success,
      icon: summary.failed + summary.unknown > 0
          ? Icons.warning_amber
          : Icons.cloud_done,
    );
  }

  Future<void> _retry(BuildContext context, Order order) async {
    if (order.status == OrderStatus.unknown) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.help_outline),
          title: const Text('¿Reintentar este pedido?'),
          content: const Text(
            'No sabemos si el intento anterior llegó al servidor. '
            'Si lo reenvías, el servidor podría recibirlo dos veces.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reintentar de todos modos'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final result = await controller.retry(order.id);
    if (!context.mounted || result == null) return;
    showAppSnack(
      context,
      'Resultado: ${result.label}',
      kind: result == OrderStatus.confirmed
          ? FeedbackKind.success
          : FeedbackKind.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final canSend = !controller.isSending && controller.sendableCount > 0;
        return Scaffold(
          appBar: AppBar(title: const Text('Historial')),
          body: _buildBody(context),
          // Sin pedidos pendientes o con error no hay nada que enviar: el botón
          // se oculta. Mientras hay un lote en curso se mantiene como "Enviando…".
          floatingActionButton: !canSend && !controller.isSending
              ? null
              : FloatingActionButton.extended(
                  onPressed: canSend ? () => _sendPending(context) : null,
                  icon: controller.isSending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    controller.isSending
                        ? 'Enviando…'
                        : 'Enviar pendientes (${controller.sendableCount})',
                  ),
                ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.isLoading) {
      return const LoadingMessage(text: 'Cargando pedidos…');
    }

    if (controller.loadError != null) {
      return StateMessage(
        icon: Icons.error_outline,
        isError: true,
        title: controller.loadError!,
        body: 'Tus pedidos siguen guardados en el dispositivo.',
        actionLabel: 'Reintentar',
        onAction: controller.load,
      );
    }

    if (controller.orders.isEmpty) {
      return const StateMessage(
        icon: Icons.receipt_long_outlined,
        title: 'Aún no hay pedidos guardados',
        body:
            'Arma un pedido y guárdalo. Puedes hacerlo sin conexión y '
            'enviarlo después.',
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        // Un talón por pedido.
        itemCount: controller.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _OrderCard(
          order: controller.orders[index],
          onRetry: (order) => _retry(context, order),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final void Function(Order) onRetry;

  const _OrderCard({required this.order, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppTheme.statusStyle(order.status, theme.brightness);
    final canRetry =
        order.status == OrderStatus.error ||
        order.status == OrderStatus.unknown;
    final meta = [
      if (order.attempts > 0) 'Intentos: ${order.attempts}',
      if (order.remoteRef != null) 'Referencia simulada: #${order.remoteRef}',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lomo del talón con el color del estado (refuerza, no sustituye).
            Container(width: 6, color: status.fg),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OrderStatusBadge(status: order.status),
                        Text(
                          'Pedido #${order.id.substring(0, 8)}',
                          style: AppTheme.money(theme.textTheme.titleSmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDateTime(order.createdAt),
                      style: AppTheme.money(theme.textTheme.bodySmall),
                    ),
                    const SizedBox(height: 12),
                    const DottedDivider(),
                    const SizedBox(height: 8),
                    for (final line in order.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${line.quantity} × ${line.title}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              formatMoney(line.subtotal),
                              style: AppTheme.money(theme.textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    const DottedDivider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total estimado',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          formatMoney(order.estimatedTotal),
                          style: AppTheme.money(theme.textTheme.titleLarge),
                        ),
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        meta.join(' · '),
                        style: AppTheme.money(theme.textTheme.bodySmall),
                      ),
                    ],
                    if (order.lastError != null &&
                        order.status != OrderStatus.confirmed &&
                        order.status != OrderStatus.unknown)
                      _Note(
                        icon: Icons.error_outline,
                        text: order.lastError!,
                        background: scheme.errorContainer,
                        foreground: scheme.onErrorContainer,
                      ),
                    if (order.status == OrderStatus.unknown)
                      _Note(
                        icon: Icons.help_outline,
                        // Una sola caja: motivo + incertidumbre, sin tono de error.
                        text:
                            '${order.lastError ?? 'No recibimos respuesta.'} '
                            'No sabemos si el pedido llegó.\n'
                            'No se incluye en "Enviar pendientes". Decide si reintentarlo.',
                        background: status.bg,
                        foreground: status.fg,
                      ),
                    if (canRetry)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => onRetry(order),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  const _Note({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
