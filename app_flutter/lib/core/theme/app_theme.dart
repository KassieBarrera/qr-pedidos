import 'package:flutter/material.dart';

import '../../data/models/order.dart';

/// Tema "Mostrador": tinta azul profundo, ámbar para la acción de escaneo y
/// papel cálido de fondo. Solo usa la fuente del sistema (funciona offline).
class AppColors {
  AppColors._();

  static const ink = Color(0xFF1F2A44);
  static const amber = Color(0xFFF2A33A);
  static const paper = Color(0xFFFAF7F2);
  static const card = Color(0xFFFFFDF9);

  // Modo oscuro
  static const inkDark = Color(0xFFB4C2EA);
  static const paperDark = Color(0xFF141824);
  static const cardDark = Color(0xFF1E2434);
}

/// Colores de estado: texto/icono (`fg`) y fondo suave (`bg`) del sello.
class StatusStyle {
  final Color fg;
  final Color bg;
  const StatusStyle(this.fg, this.bg);
}

class AppTheme {
  AppTheme._();

  static const tabular = [FontFeature.tabularFigures()];

  /// Estilo numérico con cifras tabulares para que precios y totales alineen.
  static TextStyle money(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(fontFeatures: tabular);

  static StatusStyle statusStyle(OrderStatus status, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (status) {
      OrderStatus.pending =>
        dark
            ? const StatusStyle(Color(0xFFFFC857), Color(0xFF3A2E10))
            : const StatusStyle(Color(0xFF7A5400), Color(0xFFFBEBC8)),
      OrderStatus.sending =>
        dark
            ? const StatusStyle(Color(0xFF8FB8FF), Color(0xFF16294A))
            : const StatusStyle(Color(0xFF1456B8), Color(0xFFDCE8FB)),
      OrderStatus.confirmed =>
        dark
            ? const StatusStyle(Color(0xFF7FD48A), Color(0xFF14301A))
            : const StatusStyle(Color(0xFF2E7D32), Color(0xFFEAF6EB)),
      OrderStatus.error =>
        dark
            ? const StatusStyle(Color(0xFFFF8F8F), Color(0xFF3E1717))
            : const StatusStyle(Color(0xFFC62828), Color(0xFFFDEAEA)),
      OrderStatus.unknown =>
        dark
            ? const StatusStyle(Color(0xFFFFA866), Color(0xFF3B2412))
            : const StatusStyle(Color(0xFF8D4B00), Color(0xFFFFE3CC)),
    };
  }

  static ThemeData light() => _build(
    ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDDE3F3),
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      secondaryContainer: const Color(0xFFFBE3BC),
      onSecondaryContainer: const Color(0xFF3B2600),
      tertiary: const Color(0xFF7A5400),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFBEBC8),
      onTertiaryContainer: const Color(0xFF3B2600),
      error: const Color(0xFFC62828),
      onError: Colors.white,
      errorContainer: const Color(0xFFFADADA),
      onErrorContainer: const Color(0xFF5C0F0F),
      surface: AppColors.paper,
      onSurface: const Color(0xFF1B1B1F),
      onSurfaceVariant: const Color(0xFF52505A),
      surfaceContainerLowest: AppColors.card,
      surfaceContainerLow: AppColors.card,
      surfaceContainer: const Color(0xFFF3EEE5),
      surfaceContainerHigh: const Color(0xFFEFE9DE),
      surfaceContainerHighest: const Color(0xFFE9E2D5),
      outline: const Color(0xFF857F76),
      outlineVariant: const Color(0xFFD9D1C3),
    ),
  );

  static ThemeData dark() => _build(
    ColorScheme.dark(
      primary: AppColors.inkDark,
      onPrimary: const Color(0xFF14203F),
      primaryContainer: const Color(0xFF2B3960),
      onPrimaryContainer: const Color(0xFFDDE3F7),
      secondary: AppColors.amber,
      onSecondary: const Color(0xFF241800),
      secondaryContainer: const Color(0xFF5A3E0B),
      onSecondaryContainer: const Color(0xFFFFE2B4),
      tertiary: const Color(0xFFFFC857),
      onTertiary: const Color(0xFF3B2600),
      tertiaryContainer: const Color(0xFF3A2E10),
      onTertiaryContainer: const Color(0xFFFFE2B4),
      error: const Color(0xFFFF8F8F),
      onError: const Color(0xFF4A0A0A),
      errorContainer: const Color(0xFF3E1717),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: AppColors.paperDark,
      onSurface: const Color(0xFFE8E6EE),
      onSurfaceVariant: const Color(0xFFB9B7C3),
      surfaceContainerLowest: const Color(0xFF0F121B),
      surfaceContainerLow: AppColors.cardDark,
      surfaceContainer: const Color(0xFF1B2030),
      surfaceContainerHigh: const Color(0xFF252B3D),
      surfaceContainerHighest: const Color(0xFF2F364A),
      outline: const Color(0xFF8E8C9A),
      outlineVariant: const Color(0xFF3A4156),
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final t = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final textTheme = t.copyWith(
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: tabular,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: tabular,
      ),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.35),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.35),
      bodySmall: t.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.3,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: scheme.primary,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondary,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? scheme.onSecondary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelMedium?.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        elevation: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.primary == AppColors.ink
            ? AppColors.ink
            : const Color(0xFF2F364A),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: scheme.tertiaryContainer,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onTertiaryContainer,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
