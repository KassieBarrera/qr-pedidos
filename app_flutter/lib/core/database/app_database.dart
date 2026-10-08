import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/product.dart';

class AppDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'qr_pedidos.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            price REAL NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> saveProducts(List<Product> products) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final product in products) {
        await txn.insert('products', {
          'id': product.id,
          'title': product.title,
          'price': product.price,
          'updated_at': product.updatedAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'title ASC');

    return rows.map((row) {
      return Product(
        id: row['id'] as int,
        title: row['title'] as String,
        price: (row['price'] as num).toDouble(),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
    }).toList();
  }
}
