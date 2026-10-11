import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Fallo de red clasificado según si la solicitud pudo llegar al servidor.
class ApiException implements Exception {
  final String message;

  /// true si la solicitud pudo haber llegado al servidor y no sabemos su
  /// resultado (timeout o conexión cortada durante el intercambio).
  final bool outcomeUnknown;

  /// Código HTTP cuando hubo respuesta.
  final int? statusCode;

  /// true si el fallo fue de conectividad (sin red, timeout, conexión
  /// cortada). false si el servidor respondió con error o con datos inválidos.
  final bool isConnectivity;

  const ApiException(
    this.message, {
    this.outcomeUnknown = false,
    this.statusCode,
    this.isConnectivity = false,
  });

  @override
  String toString() => message;
}

const requestTimeout = Duration(seconds: 10);

/// Ejecuta [request] con timeout y traduce los errores de transporte.
///
/// Los errores de resolución DNS o conexión rechazada ocurren antes de enviar
/// el cuerpo, así que sabemos que el servidor no recibió nada. Cualquier otro
/// corte (timeout, socket cerrado a mitad) deja el resultado desconocido.
Future<http.Response> guardedRequest(
  Future<http.Response> Function() request,
) async {
  try {
    return await request().timeout(requestTimeout);
  } on TimeoutException {
    throw const ApiException(
      'El servidor no respondió a tiempo.',
      outcomeUnknown: true,
      isConnectivity: true,
    );
  } on SocketException catch (e) {
    throw _fromTransport(e.toString());
  } on http.ClientException catch (e) {
    throw _fromTransport(e.message);
  }
}

/// true si el detalle indica que la solicitud no salió del dispositivo.
bool isNotSentError(String detail) {
  final lower = detail.toLowerCase();
  return lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('no address associated');
}

ApiException _fromTransport(String detail) {
  return isNotSentError(detail)
      ? const ApiException(
          'Sin conexión. La solicitud no se envió.',
          isConnectivity: true,
        )
      : const ApiException(
          'Se perdió la conexión durante el envío.',
          outcomeUnknown: true,
          isConnectivity: true,
        );
}
