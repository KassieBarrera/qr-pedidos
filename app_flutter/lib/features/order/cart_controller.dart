import 'package:flutter/foundation.dart';

import '../../data/models/order.dart';
import '../../data/models/product.dart';

/// Pedido en construcción. Vive en memoria: no se exige que sobreviva al
/// cierre de la app hasta que se guarda como pedido.
class CartController extends ChangeNotifier {
  final List<OrderLine> _lines = [];

  List<OrderLine> get lines => List.unmodifiable(_lines);

  bool get isEmpty => _lines.isEmpty;

  int get totalItems => _lines.fold(0, (sum, line) => sum + line.quantity);

  /// Total estimado: precio × cantidad, sin impuestos ni descuentos.
  double get estimatedTotal =>
      _lines.fold(0.0, (sum, line) => sum + line.subtotal);

  int quantityOf(int productId) {
    final index = _indexOf(productId);
    return index < 0 ? 0 : _lines[index].quantity;
  }

  /// Escanear de nuevo el mismo producto en otra sesión suma una unidad.
  void addProduct(Product product) {
    final index = _indexOf(product.id);
    if (index >= 0) {
      setQuantity(product.id, _lines[index].quantity + 1);
      return;
    }
    _lines.add(
      OrderLine(
        productId: product.id,
        quantity: 1,
        title: product.title,
        unitPrice: product.price,
      ),
    );
    notifyListeners();
  }

  /// Una cantidad menor que 1 quita la línea.
  void setQuantity(int productId, int quantity) {
    final index = _indexOf(productId);
    if (index < 0) return;

    if (quantity < 1) {
      _lines.removeAt(index);
    } else {
      final line = _lines[index];
      _lines[index] = OrderLine(
        productId: line.productId,
        quantity: quantity,
        title: line.title,
        unitPrice: line.unitPrice,
      );
    }
    notifyListeners();
  }

  void removeProduct(int productId) => setQuantity(productId, 0);

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  int _indexOf(int productId) =>
      _lines.indexWhere((line) => line.productId == productId);
}
