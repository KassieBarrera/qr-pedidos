import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';

class OrdersController extends ChangeNotifier {
  final OrderRepository repository;
  late final StreamSubscription<void> _subscription;

  OrdersController({required this.repository}) {
    _subscription = repository.changes.listen((_) => load());
  }

  List<Order> _orders = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _loadError;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get loadError => _loadError;

  int get sendableCount => _orders
      .where(
        (o) => o.status == OrderStatus.pending || o.status == OrderStatus.error,
      )
      .length;

  int get attentionCount =>
      _orders.where((o) => o.status != OrderStatus.confirmed).length;

  /// Recupera envíos interrumpidos y carga el historial.
  Future<void> initialize() async {
    await repository.recoverInterruptedSends();
    await load();
  }

  Future<void> load() async {
    try {
      _orders = await repository.getOrders();
      _loadError = null;
    } catch (e) {
      _loadError = 'No pudimos leer los pedidos guardados.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Order> create(List<OrderLine> lines) => repository.createOrder(lines);

  /// Un segundo toque mientras hay un lote activo no inicia otro: el
  /// repositorio devuelve el lote en curso.
  Future<SendSummary> sendPending() async {
    _isSending = true;
    notifyListeners();
    try {
      return await repository.sendPending();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<OrderStatus?> retry(String orderId) => repository.retry(orderId);

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
