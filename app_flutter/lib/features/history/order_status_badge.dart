import 'package:flutter/material.dart';

import '../../data/models/order.dart';

/// Estado con icono + texto: no depende solo del color.
class OrderStatusBadge extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusBadge({super.key, required this.status});

  static IconData iconFor(OrderStatus status) => switch (status) {
    OrderStatus.pending => Icons.schedule,
    OrderStatus.sending => Icons.sync,
    OrderStatus.confirmed => Icons.check_circle,
    OrderStatus.error => Icons.error,
    OrderStatus.unknown => Icons.help,
  };

  static Color colorFor(OrderStatus status, ColorScheme scheme) =>
      switch (status) {
        OrderStatus.pending => scheme.tertiary,
        OrderStatus.sending => scheme.primary,
        OrderStatus.confirmed => const Color(0xFF2E7D32),
        OrderStatus.error => scheme.error,
        OrderStatus.unknown => const Color(0xFFB26A00),
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status, Theme.of(context).colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == OrderStatus.sending)
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(iconFor(status), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
