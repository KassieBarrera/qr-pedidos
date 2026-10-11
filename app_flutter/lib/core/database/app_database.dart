import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../logging/app_log.dart';

class AppDatabase {
  /// [factory] y [path] permiten usar una base en memoria en las pruebas.
  final DatabaseFactory? factory;
  final String? path;

  AppDatabase({this.factory, this.path});

  Future<Database>? _opening;

  /// La apertura se comparte: llamadas concurrentes no abren la base dos veces.
  /// Si falla, se descarta para que el siguiente acceso lo reintente.
  Future<Database> get database => _opening ??= _openOnce();

  Future<Database> _openOnce() async {
    try {
      return await _initializeDatabase();
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    await (await opening)?.close();
  }

  Future<Database> _initializeDatabase() async {
    final factory = this.factory ?? databaseFactory;
    final path =
        this.path ?? join(await factory.getDatabasesPath(), 'qr_pedidos.db');

    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createProducts(db);
          await _createOrders(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          AppLog.i('db', 'db.migrate', {'from': oldVersion, 'to': newVersion});
          if (oldVersion < 2) await _createOrders(db);
        },
      ),
    );
    AppLog.i('db', 'db.open', {'version': 2, 'path': basename(path)});
    return db;
  }

  static Future<void> _createProducts(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        price REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createOrders(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        remote_ref TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE order_lines (
        order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        title TEXT NOT NULL,
        unit_price REAL NOT NULL,
        PRIMARY KEY (order_id, product_id)
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Productos

  Future<void> saveProducts(List<Product> products) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final product in products) {
        await txn.insert(
          'products',
          _productToRow(product),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'title ASC');
    return rows.map(_productFromRow).toList();
  }

  Future<Product?> getProduct(int id) async {
    final db = await database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _productFromRow(rows.first);
  }

  static Map<String, Object?> _productToRow(Product product) => {
    'id': product.id,
    'title': product.title,
    'price': product.price,
    'updated_at': product.updatedAt.toIso8601String(),
  };

  static Product _productFromRow(Map<String, Object?> row) => Product(
    id: row['id'] as int,
    title: row['title'] as String,
    price: (row['price'] as num).toDouble(),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  // ---------------------------------------------------------------------------
  // Pedidos

  /// Inserta el pedido y sus líneas en una sola transacción para no dejar
  /// pedidos con líneas incompletas.
  Future<void> insertOrder(Order order) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert('orders', {
        'id': order.id,
        'status': order.status.code,
        'created_at': order.createdAt.toIso8601String(),
        'updated_at': order.updatedAt.toIso8601String(),
        'attempts': order.attempts,
        'last_error': order.lastError,
        'remote_ref': order.remoteRef,
      });

      for (final line in order.lines) {
        await txn.insert('order_lines', {
          'order_id': order.id,
          'product_id': line.productId,
          'quantity': line.quantity,
          'title': line.title,
          'unit_price': line.unitPrice,
        });
      }
    });
    AppLog.d('db', 'db.order.insert', {
      'order': AppLog.shortId(order.id),
      'lines': order.lines.length,
    });
  }

  Future<List<Order>> getOrders({List<OrderStatus>? statuses}) async {
    final db = await database;

    final where = statuses == null
        ? null
        : 'status IN (${List.filled(statuses.length, '?').join(', ')})';

    final orderRows = await db.query(
      'orders',
      where: where,
      whereArgs: statuses?.map((s) => s.code).toList(),
      orderBy: 'created_at DESC',
    );
    if (orderRows.isEmpty) return [];

    final lineRows = await db.query('order_lines', orderBy: 'rowid ASC');
    final linesByOrder = <String, List<OrderLine>>{};
    for (final row in lineRows) {
      linesByOrder
          .putIfAbsent(row['order_id'] as String, () => [])
          .add(
            OrderLine(
              productId: row['product_id'] as int,
              quantity: row['quantity'] as int,
              title: row['title'] as String,
              unitPrice: (row['unit_price'] as num).toDouble(),
            ),
          );
    }

    return orderRows.map((row) {
      final id = row['id'] as String;
      return Order(
        id: id,
        status: OrderStatus.fromCode(row['status'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        attempts: row['attempts'] as int,
        lastError: row['last_error'] as String?,
        remoteRef: row['remote_ref'] as String?,
        lines: linesByOrder[id] ?? const [],
      );
    }).toList();
  }

  Future<Order?> getOrder(String id) async {
    final orders = await getOrders();
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Pasa el pedido a `sending` solo si su estado actual está en [from].
  /// Es la barrera contra envíos concurrentes del mismo pedido: si otro
  /// intento ya lo tomó, devuelve false.
  Future<bool> claimForSending(
    String id, {
    required List<OrderStatus> from,
    required DateTime now,
  }) async {
    final db = await database;
    final changed = await db.rawUpdate(
      'UPDATE orders SET status = ?, attempts = attempts + 1, updated_at = ? '
      'WHERE id = ? AND status IN (${List.filled(from.length, '?').join(', ')})',
      [
        OrderStatus.sending.code,
        now.toIso8601String(),
        id,
        ...from.map((s) => s.code),
      ],
    );
    AppLog.d('db', 'db.order.claim', {
      'order': AppLog.shortId(id),
      'from': from.map((s) => s.code).join(','),
      'ok': changed == 1,
    });
    return changed == 1;
  }

  /// Cierra un intento en `sending` con su resultado.
  Future<void> finishSending(
    String id, {
    required OrderStatus status,
    required DateTime now,
    String? lastError,
    String? remoteRef,
  }) async {
    final db = await database;
    await db.update(
      'orders',
      {
        'status': status.code,
        'updated_at': now.toIso8601String(),
        'last_error': lastError,
        'remote_ref': ?remoteRef,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, OrderStatus.sending.code],
    );
    AppLog.d('db', 'db.order.finish', {
      'order': AppLog.shortId(id),
      'status': status.code,
    });
  }

  /// Al iniciar la app, cualquier pedido que quedó en `sending` (la app se
  /// cerró durante el envío) pasa a `unknown` para decidirlo manualmente.
  Future<int> recoverInterruptedSends(DateTime now) async {
    final db = await database;
    final count = await db.update(
      'orders',
      {
        'status': OrderStatus.unknown.code,
        'updated_at': now.toIso8601String(),
        'last_error': 'La app se cerró durante el envío. No sabemos si llegó al servidor.',
      },
      where: 'status = ?',
      whereArgs: [OrderStatus.sending.code],
    );
    if (count > 0) {
      AppLog.w('db', 'db.recover.interrupted', {'count': count});
    } else {
      AppLog.d('db', 'db.recover.interrupted', {'count': 0});
    }
    return count;
  }
}
