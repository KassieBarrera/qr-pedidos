import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Contador − n + con áreas táctiles de 48dp. Con cantidad 1, el botón de
/// restar se convierte en "quitar" (papelera en rojo).
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final String itemName;
  final ValueChanged<int> onChanged;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.itemName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final removing = quantity == 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          tooltip: removing
              ? 'Quitar $itemName del pedido'
              : 'Restar uno a $itemName',
          icon: Icon(
            removing ? Icons.delete_outline : Icons.remove,
            color: removing ? scheme.error : scheme.primary,
          ),
          onPressed: () => onChanged(quantity - 1),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              '$quantity',
              key: ValueKey(quantity),
              textAlign: TextAlign.center,
              semanticsLabel: '$quantity unidades',
              style: AppTheme.money(theme.textTheme.titleMedium),
            ),
          ),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          tooltip: 'Sumar uno a $itemName',
          icon: Icon(Icons.add, color: scheme.primary),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}
