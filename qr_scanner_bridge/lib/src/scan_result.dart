/// Resultado exitoso de un escaneo: id del producto leído en el QR.
class ScanResult {
  const ScanResult(this.productId);

  final int productId;

  @override
  bool operator ==(Object other) =>
      other is ScanResult && other.productId == productId;

  @override
  int get hashCode => productId.hashCode;

  @override
  String toString() => 'ScanResult(productId: $productId)';
}
