import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

const quietModules = 4;

/// Matriz QR con versión fija 2 y corrección M, para que todos tengan el
/// mismo tamaño y el resultado sea determinista.
QrImage matrix(String text) {
  final code = QrCode(2, QrErrorCorrectLevel.M)..addData(text);
  return QrImage(code);
}

/// QR en blanco y negro con zona silenciosa de 4 módulos.
img.Image renderQr(String text, int scale) {
  final m = matrix(text);
  final side = (m.moduleCount + 2 * quietModules) * scale;
  final out = img.Image(width: side, height: side, numChannels: 3);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  final black = img.ColorRgb8(0, 0, 0);
  for (var r = 0; r < m.moduleCount; r++) {
    for (var c = 0; c < m.moduleCount; c++) {
      if (m.isDark(r, c)) {
        final x = (c + quietModules) * scale;
        final y = (r + quietModules) * scale;
        img.fillRect(out,
            x1: x, y1: y, x2: x + scale - 1, y2: y + scale - 1, color: black);
      }
    }
  }
  return out;
}

int textWidth(String s, img.BitmapFont font) {
  var w = 0;
  for (final u in s.codeUnits) {
    w += font.characters[u]?.xAdvance ?? 0;
  }
  return w;
}

/// Dibuja [s] centrado horizontalmente dentro de [x0, x0 + width).
void drawCentered(img.Image dst, String s, img.BitmapFont font, int x0,
    int width, int y, img.Color color) {
  final x = x0 + (width - textWidth(s, font)) ~/ 2;
  img.drawString(dst, s, font: font, x: x < x0 ? x0 : x, y: y, color: color);
}
