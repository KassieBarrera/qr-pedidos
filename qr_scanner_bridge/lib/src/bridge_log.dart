import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Logger mínimo interno del puente (el paquete no depende de la app).
/// Mismo formato que la app: `[qr_pedidos/scanner] <L> evento k=v`.
/// Apagado en release y bajo `flutter test`.
class BridgeLog {
  BridgeLog._();

  static bool enabled = !kReleaseMode && !_isFlutterTest();

  static bool _isFlutterTest() {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static void i(String event, [Map<String, Object?>? fields]) =>
      _log(800, 'I', event, fields);

  static void w(String event, [Map<String, Object?>? fields]) =>
      _log(900, 'W', event, fields);

  static void _log(
    int level,
    String letter,
    String event,
    Map<String, Object?>? fields,
  ) {
    if (!enabled) return;
    final buffer = StringBuffer('[qr_pedidos/scanner] $letter $event');
    fields?.forEach((key, value) {
      if (value != null) buffer.write(' $key=$value');
    });
    final line = buffer.toString();
    debugPrint(line);
    developer.log(line, name: 'qr_pedidos.scanner', level: level);
  }
}
