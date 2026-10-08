import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'core/database/app_database.dart';
import 'core/network/product_api.dart';
import 'data/repositories/product_repository.dart';
import 'features/catalog/catalog_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final client = http.Client();
  final database = AppDatabase();

  final repository = ProductRepository(
    api: ProductApi(client: client),
    database: database,
  );

  runApp(QrPedidosApp(repository: repository));
}

class QrPedidosApp extends StatelessWidget {
  final ProductRepository repository;

  const QrPedidosApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Pedidos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: CatalogScreen(repository: repository),
    );
  }
}
