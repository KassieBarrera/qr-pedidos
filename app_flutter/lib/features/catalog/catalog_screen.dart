import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

class CatalogScreen extends StatefulWidget {
  final ProductRepository repository;

  const CatalogScreen({super.key, required this.repository});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Product> products = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await widget.repository.getProducts();

      if (!mounted) return;

      setState(() {
        products = result;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'No pudimos cargar el catálogo.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Pedidos'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadProducts,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar catálogo',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage!),
            ElevatedButton(
              onPressed: loadProducts,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (products.isEmpty) {
      return const Center(child: Text('No hay productos disponibles todavía.'));
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];

        return ListTile(
          title: Text(product.title),
          subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
          leading: const Icon(Icons.inventory_2_outlined),
        );
      },
    );
  }
}
