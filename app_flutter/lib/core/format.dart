/// Formato monetario con redondeo a 2 decimales (half-up de `toStringAsFixed`).
/// Los cálculos se hacen con el valor completo; solo se redondea al mostrar.
String formatMoney(double value) => '\$${value.toStringAsFixed(2)}';

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
