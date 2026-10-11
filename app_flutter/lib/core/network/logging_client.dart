import 'dart:async';

import 'package:http/http.dart' as http;

import '../logging/app_log.dart';
import 'api_exceptions.dart';

/// Decorador que registra cada solicitud HTTP sin tocar los clientes REST.
/// No registra cuerpos; del POST solo cuenta líneas y unidades.
class LoggingClient extends http.BaseClient {
  final http.Client _inner;

  LoggingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;
    final base = <String, Object?>{
      'method': request.method,
      'path': url.hasQuery ? '${url.path}?${url.query}' : url.path,
    };
    AppLog.d('http', 'http.request', base);
    final watch = Stopwatch()..start();
    try {
      // Mismo plazo que guardedRequest: así el timeout se ve aquí con su
      // método y ruta (guardedRequest recibe el mismo TimeoutException).
      final response = await _inner.send(request).timeout(requestTimeout);
      final fields = {
        ...base,
        'status': response.statusCode,
        'ms': watch.elapsedMilliseconds,
      };
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLog.i('http', 'http.response', fields);
      } else {
        AppLog.w('http', 'http.response', fields);
      }
      return response;
    } catch (e) {
      final kind = e is TimeoutException
          ? 'timeout'
          : isNotSentError(e.toString())
          ? 'noConnection'
          : 'connectionLost';
      AppLog.w('http', 'http.failure', {
        ...base,
        'kind': kind,
        'outcomeUnknown': kind != 'noConnection',
        'ms': watch.elapsedMilliseconds,
      });
      rethrow;
    }
  }
}
