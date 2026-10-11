import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Logs de diagnóstico de consola. Formato: `[qr_pedidos/<area>] <L> evento k=v`.
/// Ver docs/LOGS.md. No cambian el comportamiento de la app.
class AppLog {
  AppLog._();

  /// Apagado en release y, por defecto, bajo `flutter test`.
  static bool enabled = !kReleaseMode && !_isFlutterTest();

  /// Receptor alternativo (pruebas). Si es null se escribe en consola.
  @visibleForTesting
  static void Function(String line)? sink;

  static bool _isFlutterTest() {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static void d(String area, String event, [Map<String, Object?>? fields]) =>
      _log(500, 'D', area, event, fields);

  static void i(String area, String event, [Map<String, Object?>? fields]) =>
      _log(800, 'I', area, event, fields);

  static void w(
    String area,
    String event, [
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stack,
  ]) => _log(900, 'W', area, event, fields, error, stack);

  static void e(
    String area,
    String event, [
    Map<String, Object?>? fields,
    Object? error,
    StackTrace? stack,
  ]) => _log(1000, 'E', area, event, fields, error, stack);

  /// Acorta un id de pedido a 8 caracteres.
  static String shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  /// `clave=valor` con comillas si el valor tiene espacios o está vacío.
  @visibleForTesting
  static String format(
    String area,
    String level,
    String event, [
    Map<String, Object?>? fields,
  ]) {
    final buffer = StringBuffer('[qr_pedidos/$area] $level $event');
    fields?.forEach((key, value) {
      if (value == null) return;
      final text = value.toString();
      final needsQuotes = text.isEmpty || text.contains(RegExp(r'[\s"]'));
      buffer.write(
        ' $key=${needsQuotes ? '"${text.replaceAll('"', "'")}"' : text}',
      );
    });
    return buffer.toString();
  }

  static void _log(
    int level,
    String letter,
    String area,
    String event,
    Map<String, Object?>? fields, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (!enabled) return;
    final fieldsWithError = error == null
        ? fields
        : {...?fields, 'error': error.runtimeType};
    final line = format(area, letter, event, fieldsWithError);
    final custom = sink;
    if (custom != null) {
      custom(line);
      return;
    }
    debugPrint(line);
    developer.log(
      line,
      name: 'qr_pedidos.$area',
      level: level,
      error: error,
      stackTrace: stack,
    );
  }
}
