/// Definición única de los QR de prueba (sección 4 del enunciado).
class QrCase {
  const QrCase(this.file, this.text, this.category, this.expected);

  /// Nombre del PNG (estable).
  final String file;

  /// Texto plano exacto codificado en el QR (sin salto de línea final).
  final String text;

  /// `valid`, `invalid` o `notfound`.
  final String category;

  /// Resultado esperado según el enunciado / la app.
  final String expected;

  String get label => switch (category) {
        'valid' => 'VALIDO',
        'invalid' => 'INVALIDO',
        _ => 'NO EXISTE',
      };
}

const qrCases = <QrCase>[
  QrCase('valid_product_1.png', 'product:1', 'valid',
      'ID 1 valido; producto de prueba'),
  QrCase('valid_product_2.png', 'product:2', 'valid',
      'ID 2 valido; producto de prueba'),
  QrCase('valid_product_3.png', 'product:3', 'valid',
      'ID 3 valido; producto de prueba'),
  QrCase('invalid_product_0.png', 'product:0', 'invalid', 'Formato invalido'),
  QrCase('invalid_product_minus1.png', 'product:-1', 'invalid',
      'Formato invalido'),
  QrCase('invalid_product_01_leading_zero.png', 'product:01', 'invalid',
      'Formato invalido'),
  QrCase('invalid_PRODUCT_1_uppercase.png', 'PRODUCT:1', 'invalid',
      'Formato invalido'),
  QrCase('invalid_product_abc.png', 'product:abc', 'invalid',
      'Formato invalido'),
  QrCase('invalid_hola.png', 'hola', 'invalid', 'Formato invalido'),
  QrCase('notfound_product_999999.png', 'product:999999', 'notfound',
      'Formato valido; producto no encontrado'),
];
