import 'package:flutter/services.dart';

import 'bridge_log.dart';
import 'scan_error_code.dart';
import 'scan_exception.dart';
import 'scan_result.dart';

/// Puente hacia el SDK nativo de lectura QR (MethodChannel `com.qrpedidos/qr_scanner`).
class QrScannerBridge {
  QrScannerBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.qrpedidos/qr_scanner';

  final MethodChannel _channel;
  bool _scanInFlight = false;

  /// Abre el escáner nativo y devuelve el id del producto leído.
  ///
  /// Lanza [ScanException] con un [ScanErrorCode] ante cualquier fallo, incluida
  /// la cancelación. Una segunda llamada mientras hay otra en vuelo lanza
  /// [ScanErrorCode.scanInProgress] sin llegar al canal.
  Future<ScanResult> scanProduct() async {
    if (_scanInFlight) {
      BridgeLog.w('scanner.rejected', {'reason': 'scanInProgress'});
      throw const ScanException(
        ScanErrorCode.scanInProgress,
        'Ya hay un escaneo en curso.',
      );
    }
    _scanInFlight = true;
    BridgeLog.i('scanner.call');
    try {
      final response = await _channel.invokeMethod<Object?>('scanProduct');
      final productId = response is Map ? response['productId'] : null;
      if (productId is int && productId > 0) {
        BridgeLog.i('scanner.result', {'productId': productId});
        return ScanResult(productId);
      }
      BridgeLog.w('scanner.error', {
        'code': 'unknown',
        'reason': 'badResponse',
      });
      throw const ScanException(
        ScanErrorCode.unknown,
        'Respuesta inválida del escáner nativo.',
      );
    } on PlatformException catch (e) {
      final code = ScanErrorCode.fromWire(e.code);
      BridgeLog.w('scanner.error', {'code': code.wire});
      throw ScanException(code, e.message);
    } on MissingPluginException {
      BridgeLog.w('scanner.error', {'code': 'unknown', 'reason': 'noPlugin'});
      throw const ScanException(
        ScanErrorCode.unknown,
        'El plugin nativo del escáner no está disponible.',
      );
    } finally {
      _scanInFlight = false;
    }
  }

  /// Cancela el escaneo activo. `true` si había una sesión que cancelar.
  /// El `scanProduct` pendiente termina con [ScanErrorCode.cancelled].
  Future<bool> cancelScan() async {
    try {
      return await _channel.invokeMethod<bool>('cancelScan') ?? false;
    } on PlatformException catch (e) {
      throw ScanException(ScanErrorCode.fromWire(e.code), e.message);
    } on MissingPluginException {
      throw const ScanException(
        ScanErrorCode.unknown,
        'El plugin nativo del escáner no está disponible.',
      );
    }
  }
}
