import 'package:flutter/material.dart';

enum FeedbackKind { success, info, error }

/// SnackBar flotante con icono y colores del tema; sustituye al texto plano.
void showAppSnack(
  BuildContext context,
  String text, {
  FeedbackKind kind = FeedbackKind.success,
  IconData? icon,
}) =>
    showAppSnackOn(ScaffoldMessenger.of(context), text, kind: kind, icon: icon);

/// Igual que [showAppSnack] pero sobre un messenger concreto (cada pestaña
/// tiene el suyo para que el aviso quede sobre su propio FAB/pie).
void showAppSnackOn(
  ScaffoldMessengerState messenger,
  String text, {
  FeedbackKind kind = FeedbackKind.success,
  IconData? icon,
}) {
  final isError = kind == FeedbackKind.error;
  final iconData =
      icon ??
      switch (kind) {
        FeedbackKind.success => Icons.check_circle,
        FeedbackKind.info => Icons.info,
        FeedbackKind.error => Icons.error,
      };
  final iconColor = switch (kind) {
    FeedbackKind.success => const Color(0xFFA5D6A7),
    FeedbackKind.info => const Color(0xFFFFD58A),
    FeedbackKind.error => Colors.white,
  };

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // Rojo de error con texto blanco (5.6:1); el resto, tinta (14:1).
        backgroundColor: isError ? const Color(0xFFC62828) : null,
        duration: Duration(seconds: isError ? 6 : 4),
        content: Row(
          children: [
            Icon(iconData, color: iconColor),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
}

/// Estado a pantalla completa: carga, vacío o error, con acción opcional.
class StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isError
                    ? scheme.errorContainer
                    : scheme.secondaryContainer,
              ),
              child: Icon(
                icon,
                size: 48,
                color: isError
                    ? scheme.onErrorContainer
                    : scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Indicador de carga con texto que explica qué ocurre.
class LoadingMessage extends StatelessWidget {
  final String text;
  const LoadingMessage({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
