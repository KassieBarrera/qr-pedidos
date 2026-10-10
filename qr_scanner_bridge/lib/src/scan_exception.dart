import 'scan_error_code.dart';

/// Error tipado de un escaneo (incluida la cancelación: [ScanErrorCode.cancelled]).
class ScanException implements Exception {
  const ScanException(this.code, [this.message]);

  final ScanErrorCode code;
  final String? message;

  @override
  String toString() =>
      'ScanException(${code.wire}${message == null ? '' : ': $message'})';
}
