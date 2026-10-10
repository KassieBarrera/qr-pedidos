import 'package:flutter/foundation.dart';

enum CatalogFailure {
  none('Sin fallo'),
  offline('Sin conexión'),
  http500('HTTP 500'),
  invalidJson('JSON inválido');

  final String label;
  const CatalogFailure(this.label);
}

enum CartFailure {
  none('Sin fallo (pedido confirmado)'),
  offline('Sin conexión (no se envió)'),
  http500('HTTP 500'),
  http400('HTTP 400 (pedido rechazado)'),
  invalidJson('JSON inválido'),
  timeout('Timeout (resultado desconocido)'),
  dropAfterSend('Conexión cortada tras enviar (resultado desconocido)');

  final String label;
  const CartFailure(this.label);
}

/// Escenario de prueba mutable, solo en memoria (no persiste entre sesiones).
class FakeScenario extends ChangeNotifier {
  CatalogFailure _catalogFailure = CatalogFailure.none;
  CartFailure _cartFailure = CartFailure.none;
  Duration _latency = const Duration(milliseconds: 800);

  CatalogFailure get catalogFailure => _catalogFailure;
  CartFailure get cartFailure => _cartFailure;
  Duration get latency => _latency;

  /// "Sin conexión" global: catálogo y envío de pedidos fallan sin red.
  bool get offline =>
      _catalogFailure == CatalogFailure.offline &&
      _cartFailure == CartFailure.offline;

  set catalogFailure(CatalogFailure value) {
    _catalogFailure = value;
    notifyListeners();
  }

  set cartFailure(CartFailure value) {
    _cartFailure = value;
    notifyListeners();
  }

  set latency(Duration value) {
    _latency = value;
    notifyListeners();
  }

  set offline(bool value) {
    _catalogFailure = value ? CatalogFailure.offline : CatalogFailure.none;
    _cartFailure = value ? CartFailure.offline : CartFailure.none;
    notifyListeners();
  }
}
