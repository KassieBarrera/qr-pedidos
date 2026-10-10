/// Códigos de error estables del escáner (ver docs/CONTRATO_SCANNER.md).
enum ScanErrorCode {
  permissionDenied('permissionDenied'),
  cameraUnavailable('cameraUnavailable'),
  invalidQr('invalidQr'),
  cancelled('cancelled'),
  scanInProgress('scanInProgress'),

  /// Cualquier código no reconocido, plugin ausente o respuesta malformada.
  unknown('unknown');

  const ScanErrorCode(this.wire);

  /// Código tal como viaja por el MethodChannel.
  final String wire;

  /// Convierte un código wire; lo desconocido (o nulo) pasa a [unknown].
  static ScanErrorCode fromWire(String? wire) {
    for (final code in values) {
      if (code.wire == wire) return code;
    }
    return unknown;
  }
}
