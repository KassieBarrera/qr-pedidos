import 'dart:async';
import 'dart:math';

import '../../core/database/app_database.dart';
import '../../core/logging/app_log.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/network/order_api.dart';
import '../models/order.dart';

class SendSummary {
  final int confirmed;
  final int failed;
  final int unknown;

  /// true si ya había un lote en curso y esta llamada no inició otro.
  final bool alreadyRunning;

  const SendSummary({
    this.confirmed = 0,
    this.failed = 0,
    this.unknown = 0,
    this.alreadyRunning = false,
  });

  int get total => confirmed + failed + unknown;
}

class OrderRepository {
  final AppDatabase database;
  final OrderApi api;
  final DateTime Function() _now;
  final Random _random;

  Future<SendSummary>? _runningBatch;
  int _batchCounter = 0;
  int _currentBatch = 0;
  final Set<String> _sendingIds = {};
  final _changes = StreamController<void>.broadcast();

  /// Emite cada vez que cambia el estado de algún pedido.
  Stream<void> get changes => _changes.stream;

  OrderRepository({
    required this.database,
    required this.api,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  bool get isSending => _runningBatch != null || _sendingIds.isNotEmpty;

  Future<List<Order>> getOrders() => database.getOrders();

  /// Crea un pedido `pending` con un ID local estable.
  Future<Order> createOrder(List<OrderLine> lines) async {
    if (lines.isEmpty) {
      throw ArgumentError('El pedido debe tener al menos una línea');
    }
    final now = _now();
    final order = Order(
      id: _generateId(),
      status: OrderStatus.pending,
      createdAt: now,
      updatedAt: now,
      lines: List.unmodifiable(lines),
    );
    await database.insertOrder(order);
    AppLog.i('orders', 'orders.create', {
      'order': AppLog.shortId(order.id),
      'lines': order.lines.length,
      'units': order.totalItems,
      'total': order.estimatedTotal.toStringAsFixed(2),
    });
    _changes.add(null);
    return order;
  }

  /// Debe llamarse al iniciar la app.
  Future<int> recoverInterruptedSends() =>
      database.recoverInterruptedSends(_now());

  Future<void> dispose() => _changes.close();

  /// Envía los pedidos `pending` y `error`. Los `confirmed` se excluyen y los
  /// `unknown` no se incluyen en el lote: requieren decisión manual.
  ///
  /// Si ya hay un lote en curso, devuelve ese mismo lote sin iniciar otro.
  Future<SendSummary> sendPending() {
    final running = _runningBatch;
    if (running != null) {
      AppLog.i('queue', 'queue.batch.joined', {'batch': _currentBatch});
      return running.then(
        (s) => SendSummary(
          confirmed: s.confirmed,
          failed: s.failed,
          unknown: s.unknown,
          alreadyRunning: true,
        ),
      );
    }

    final batch = _sendBatch(++_batchCounter);
    _runningBatch = batch;
    return batch.whenComplete(() => _runningBatch = null);
  }

  /// Reintento manual de un solo pedido. Para `unknown`, la UI debe advertir
  /// antes que el servidor pudo haberlo recibido ya.
  Future<OrderStatus?> retry(String orderId) async {
    final current = (await database.getOrder(orderId))?.status;
    if (current == OrderStatus.unknown) {
      AppLog.w('queue', 'queue.retry', {
        'order': AppLog.shortId(orderId),
        'from': 'unknown',
      });
    }
    return _sendOne(
      orderId,
      from: const [OrderStatus.pending, OrderStatus.error, OrderStatus.unknown],
    );
  }

  Future<SendSummary> _sendBatch(int batchId) async {
    _currentBatch = batchId;
    final watch = Stopwatch()..start();
    final candidates = await database.getOrders(
      statuses: const [OrderStatus.pending, OrderStatus.error],
    );
    AppLog.i('queue', 'queue.batch.start', {
      'batch': batchId,
      'candidates': candidates.length,
    });

    var confirmed = 0, failed = 0, unknown = 0;
    // Del más antiguo al más reciente.
    for (final order in candidates.reversed) {
      final result = await _sendOne(
        order.id,
        from: const [OrderStatus.pending, OrderStatus.error],
      );
      switch (result) {
        case OrderStatus.confirmed:
          confirmed++;
        case OrderStatus.error:
          failed++;
        case OrderStatus.unknown:
          unknown++;
        default:
          break;
      }
    }
    AppLog.i('queue', 'queue.batch.end', {
      'batch': batchId,
      'confirmed': confirmed,
      'failed': failed,
      'unknown': unknown,
      'ms': watch.elapsedMilliseconds,
    });
    return SendSummary(confirmed: confirmed, failed: failed, unknown: unknown);
  }

  /// Devuelve el estado final, o null si el pedido no se pudo tomar (ya
  /// estaba enviándose, confirmado o no existe).
  Future<OrderStatus?> _sendOne(
    String orderId, {
    required List<OrderStatus> from,
  }) async {
    final short = AppLog.shortId(orderId);
    if (!_sendingIds.add(orderId)) {
      AppLog.w('queue', 'queue.order.skip', {
        'order': short,
        'reason': 'alreadySending',
      });
      return null;
    }
    try {
      final claimed = await database.claimForSending(
        orderId,
        from: from,
        now: _now(),
      );
      if (!claimed) {
        AppLog.w('queue', 'queue.order.skip', {
          'order': short,
          'reason': 'notClaimable',
        });
        return null;
      }
      _changes.add(null);

      final order = await database.getOrder(orderId);
      if (order == null) return null;
      AppLog.i('queue', 'queue.order.send', {
        'order': short,
        'attempt': order.attempts,
        'lines': order.lines.length,
        'units': order.totalItems,
      });

      try {
        final remoteRef = await api.submit(order);
        await database.finishSending(
          orderId,
          status: OrderStatus.confirmed,
          now: _now(),
          remoteRef: remoteRef,
        );
        AppLog.i('queue', 'queue.order.result', {
          'order': short,
          'status': 'confirmed',
          'ref': remoteRef,
        });
        return OrderStatus.confirmed;
      } on ApiException catch (e) {
        final status = e.outcomeUnknown
            ? OrderStatus.unknown
            : OrderStatus.error;
        await database.finishSending(
          orderId,
          status: status,
          now: _now(),
          lastError: e.message,
        );
        AppLog.w('queue', 'queue.order.result', {
          'order': short,
          'status': status.code,
          'reason': e.message,
          'httpStatus': e.statusCode,
        });
        return status;
      } catch (e) {
        // Error inesperado: no sabemos si la solicitud salió.
        await database.finishSending(
          orderId,
          status: OrderStatus.unknown,
          now: _now(),
          lastError: 'Error inesperado: $e',
        );
        AppLog.e('queue', 'queue.order.result', {
          'order': short,
          'status': 'unknown',
          'reason': 'unexpected',
        }, e);
        return OrderStatus.unknown;
      }
    } finally {
      _sendingIds.remove(orderId);
      _changes.add(null);
    }
  }

  /// UUID v4 sin dependencias externas.
  String _generateId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
