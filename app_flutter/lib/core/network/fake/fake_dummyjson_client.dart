import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'fake_scenario.dart';

/// Cliente HTTP falso que imita a DummyJSON (`https://dummyjson.com`).
///
/// Se inyecta en lugar de `http.Client()`, de modo que `ProductApi` y
/// `OrderApi` ejecutan exactamente el mismo código de parsing, validación y
/// clasificación de errores que en modo real.
class FakeDummyJsonClient extends http.BaseClient {
  static const productsAsset = 'assets/fixtures/products.json';
  static const cartAsset = 'assets/fixtures/cart_add_response.json';

  final FakeScenario scenario;
  final Future<String> Function(String asset) _loadAsset;

  FakeDummyJsonClient({
    required this.scenario,
    Future<String> Function(String asset)? loadAsset,
  }) : _loadAsset = loadAsset ?? rootBundle.loadString;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final method = request.method;

    if (method == 'GET' && path == '/products') {
      return _catalog(
        request,
        () async => (200, await _loadAsset(productsAsset)),
      );
    }
    final single = RegExp(r'^/products/(.+)$').firstMatch(path);
    if (method == 'GET' && single != null) {
      return _catalog(request, () => _singleProduct(single.group(1)!));
    }
    if (method == 'POST' && path == '/carts/add') {
      return _cart(request);
    }
    return _json(request, 404, jsonEncode({'message': 'Not found: $path'}));
  }

  Future<http.StreamedResponse> _catalog(
    http.BaseRequest request,
    Future<(int, String)> Function() okResponse,
  ) async {
    await Future<void>.delayed(scenario.latency);
    switch (scenario.catalogFailure) {
      case CatalogFailure.offline:
        throw const SocketException('Failed host lookup: dummyjson.com');
      case CatalogFailure.http500:
        return _json(request, 500, '{"message":"Internal Server Error"}');
      case CatalogFailure.invalidJson:
        return _json(request, 200, '<html>not json</html>');
      case CatalogFailure.none:
        break;
    }
    final (status, body) = await okResponse();
    return _json(request, status, body);
  }

  /// 200 con el producto del fixture; cualquier otro ID (p. ej. 999999) → 404.
  Future<(int, String)> _singleProduct(String rawId) async {
    final data = jsonDecode(await _loadAsset(productsAsset)) as Map;
    final id = int.tryParse(rawId);
    for (final item in data['products'] as List) {
      if ((item as Map)['id'] == id) return (200, jsonEncode(item));
    }
    return (404, jsonEncode({'message': "Product with id '$rawId' not found"}));
  }

  Future<http.StreamedResponse> _cart(http.BaseRequest request) async {
    // Consume el cuerpo como lo haría una conexión real.
    await request.finalize().drain<void>();
    final failure = scenario.cartFailure;

    if (failure == CartFailure.timeout) {
      // Nunca responde: el timeout de guardedRequest actúa de verdad.
      return Completer<http.StreamedResponse>().future;
    }

    await Future<void>.delayed(scenario.latency);
    switch (failure) {
      case CartFailure.offline:
        throw const SocketException('Failed host lookup: dummyjson.com');
      case CartFailure.dropAfterSend:
        throw http.ClientException('Connection reset by peer', request.url);
      case CartFailure.http500:
        return _json(request, 500, '{"message":"Internal Server Error"}');
      case CartFailure.http400:
        return _json(request, 400, '{"message":"Bad Request"}');
      case CartFailure.invalidJson:
        return _json(request, 200, '<html>not json</html>');
      case CartFailure.timeout:
      case CartFailure.none:
        return _json(request, 201, await _loadAsset(cartAsset));
    }
  }

  http.StreamedResponse _json(http.BaseRequest request, int code, String body) {
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream.value(bytes),
      code,
      contentLength: bytes.length,
      request: request,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
