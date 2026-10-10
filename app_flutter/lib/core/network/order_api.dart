import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/order.dart';
import 'api_exceptions.dart';
import 'product_api.dart';

class OrderApi {
  /// Usuario ficticio fijo exigido por el ejercicio.
  static const demoUserId = 1;

  final http.Client client;

  OrderApi({required this.client});

  /// Envía el pedido a `POST /carts/add` y devuelve la referencia simulada.
  ///
  /// Lanza [ApiException]; `outcomeUnknown` indica si el servidor pudo
  /// haberlo recibido.
  Future<String> submit(Order order) async {
    final body = jsonEncode({
      'userId': demoUserId,
      'products': [
        for (final line in order.lines)
          {'id': line.productId, 'quantity': line.quantity},
      ],
    });

    final response = await guardedRequest(
      () => client.post(
        Uri.parse('${ProductApi.baseUrl}/carts/add'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'El servidor rechazó el pedido (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final Object? data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('El servidor respondió con JSON inválido.');
    }

    final remoteId = data is Map<String, dynamic> ? data['id'] : null;
    if (remoteId is! num) {
      throw const ApiException(
        'La respuesta del servidor no incluye la referencia del pedido.',
      );
    }
    return remoteId.toInt().toString();
  }
}
