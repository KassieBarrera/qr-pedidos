import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/models/order.dart';
import 'order_status_badge.dart';
import 'orders_controller.dart';

class OrdersScreen extends StatelessWidget {
  final OrdersController controller;

  const OrdersScreen({super.key, required this.controller});

  Future<void> _sendPending(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final summary = await controller.sendPending();
    if (summary.alreadyRunning) return;

    final text = summary.total == 0
        ? 'No hay pedidos pendientes para enviar.'
        : 'Envío terminado: ${summary.confirmed} confirmados, '
              '${summary.failed} con error, ${summary.unknown} desconocidos.';
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Resultado: ${result.label}')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Historial')),
        body: _buildBody(context),
        floatingActionButton: controller.orders.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: controller.isSending || controller.sendableCount == 0
                    ? null
                    : () => _sendPending(context),
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
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.loadError != null) {
      return Center(child: Text(controller.loadError!));
    }

    if (controller.orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 56),
              SizedBox(height: 16),
              Text(
                'Aún no hay pedidos guardados',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Arma un pedido y guárdalo. Puedes hacerlo sin conexión y '
                'enviarlo después.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: controller.orders.length,
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
    final canRetry =
        order.status == OrderStatus.error ||
        order.status == OrderStatus.unknown;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                OrderStatusBadge(status: order.status),
                const Spacer(),
                Text(
                  formatMoney(order.estimatedTotal),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pedido ${order.id.substring(0, 8)} · ${formatDateTime(order.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final line in order.lines)
              Text('${line.quantity} × ${line.title}'),
            if (order.attempts > 0 || order.remoteRef != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (order.attempts > 0) 'Intentos: ${order.attempts}',
                  if (order.remoteRef != null)
                    'Referencia simulada: #${order.remoteRef}',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (order.lastError != null &&
                order.status != OrderStatus.confirmed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  order.lastError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (order.status == OrderStatus.unknown)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'No se incluye en "Enviar pendientes". Decide si reintentarlo.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (canRetry)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onRetry(order),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
