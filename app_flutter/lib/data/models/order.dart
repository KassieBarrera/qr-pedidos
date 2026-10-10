enum OrderStatus {
  /// Guardado y disponible para enviar.
  pending('pending', 'Pendiente'),

  /// Intento activo; no se permite otro envío del mismo pedido.
  sending('sending', 'Enviando'),

  /// HTTP 2xx con JSON válido. Se excluye de próximos envíos.
  confirmed('confirmed', 'Confirmado simulado'),

  /// Fallo conocido (HTTP 4xx/5xx, JSON inválido o sin conexión antes de
  /// enviar). Se puede reintentar.
  error('error', 'Error'),

  /// El intento pudo llegar al servidor pero no se conoce la respuesta
  /// (timeout, conexión cortada o cierre de la app durante el envío).
  /// Solo se reintenta de forma manual e individual.
  unknown('unknown', 'Resultado desconocido');

  final String code;
  final String label;

  const OrderStatus(this.code, this.label);

  static OrderStatus fromCode(String code) {
    return OrderStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => throw FormatException('Estado desconocido: $code'),
    );
  }
}

class OrderLine {
  final int productId;
  final int quantity;
  final String title;
  final double unitPrice;

  const OrderLine({
    required this.productId,
    required this.quantity,
    required this.title,
    required this.unitPrice,
  }) : assert(quantity > 0);

  double get subtotal => unitPrice * quantity;
}

class Order {
  /// ID local estable generado al crear el pedido. No cambia al reintentar.
  final String id;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderLine> lines;
  final int attempts;
  final String? lastError;

  /// Referencia devuelta por DummyJSON. Es solo de demostración.
  final String? remoteRef;

  const Order({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lines,
    this.attempts = 0,
    this.lastError,
    this.remoteRef,
  });

  int get totalItems => lines.fold(0, (sum, line) => sum + line.quantity);

  /// Total estimado: suma de precio × cantidad, sin impuestos ni descuentos.
  /// Se redondea a 2 decimales solo al mostrarlo.
  double get estimatedTotal =>
      lines.fold(0.0, (sum, line) => sum + line.subtotal);
}
