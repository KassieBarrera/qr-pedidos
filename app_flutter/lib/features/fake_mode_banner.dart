import 'package:flutter/material.dart';

import '../core/network/fake/fake_scenario.dart';

/// Franja persistente que identifica el modo simulado y abre el selector de
/// escenarios de prueba.
class FakeModeBanner extends StatelessWidget {
  final FakeScenario scenario;

  const FakeModeBanner({super.key, required this.scenario});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ScenarioSheet(scenario: scenario),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 18,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListenableBuilder(
                    listenable: scenario,
                    builder: (context, _) {
                      final active =
                          scenario.catalogFailure != CatalogFailure.none ||
                          scenario.cartFailure != CartFailure.none;
                      return Text(
                        active
                            ? 'Modo simulado · datos de prueba locales · fallo activo'
                            : 'Modo simulado · datos de prueba locales',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: scheme.onTertiaryContainer),
                      );
                    },
                  ),
                ),
                Icon(Icons.tune, size: 18, color: scheme.onTertiaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScenarioSheet extends StatelessWidget {
  final FakeScenario scenario;

  const ScenarioSheet({super.key, required this.scenario});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ListenableBuilder(
          listenable: scenario,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Escenario de prueba',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Solo en memoria: se restablece al cerrar la app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sin conexión'),
                subtitle: const Text('Catálogo y envío fallan sin red'),
                value: scenario.offline,
                onChanged: (value) => scenario.offline = value,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<CatalogFailure>(
                key: ValueKey('catalog-${scenario.catalogFailure}'),
                initialValue: scenario.catalogFailure,
                decoration: const InputDecoration(
                  labelText: 'Fallo en el catálogo',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final f in CatalogFailure.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) {
                  if (v != null) scenario.catalogFailure = v;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CartFailure>(
                key: ValueKey('cart-${scenario.cartFailure}'),
                initialValue: scenario.cartFailure,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Fallo al enviar el pedido',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final f in CartFailure.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) {
                  if (v != null) scenario.cartFailure = v;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
