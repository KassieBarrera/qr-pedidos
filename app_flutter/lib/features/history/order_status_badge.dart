import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/order.dart';

/// Sello de estado: icono + texto + color. Nunca depende solo del color.
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

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.statusStyle(status, Theme.of(context).brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.fg, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == OrderStatus.sending)
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: style.fg),
            )
          else
            Icon(iconFor(status), size: 18, color: style.fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(
                color: style.fg,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
