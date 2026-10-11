// Genera los PNG de los QR de prueba, la hoja imprimible y manifest.json.
// Uso: dart run bin/generate.dart [--out <dir>]   (por defecto ../../qr)
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:qr_generator/qr_codes.dart';
import 'package:qr_generator/render.dart';

void main(List<String> args) {
  var outDir = '../../qr';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      outDir = args[++i];
    } else if (args[i] == '-h' || args[i] == '--help') {
      stdout.writeln('Uso: dart run bin/generate.dart [--out <dir>]');
      return;
    } else {
      stderr.writeln('Argumento desconocido: ${args[i]}');
      exit(64);
    }
  }
  Directory(outDir).createSync(recursive: true);

  final black = img.ColorRgb8(0, 0, 0);
  final white = img.ColorRgb8(255, 255, 255);

  // PNG individuales: QR (escala 20 => 780 px) + texto debajo.
  for (final c in qrCases) {
    final qr = renderQr(c.text, 20);
    const textH = 110;
    final out = img.Image(
        width: qr.width, height: qr.height + textH, numChannels: 3);
    img.fill(out, color: white);
    img.compositeImage(out, qr);
    drawCentered(out, c.text, img.arial48, 0, out.width, qr.height, black);
    _save(out, '$outDir/${c.file}');
  }

  // Hoja imprimible: 5 columnas x 2 filas.
  const cols = 5, rows = 2, cell = 380, margin = 30, header = 110;
  const cellH = 480;
  final sheet = img.Image(
      width: cols * cell + 2 * margin,
      height: header + rows * cellH + margin,
      numChannels: 3);
  img.fill(sheet, color: white);
  drawCentered(sheet, 'QR de prueba - Pedidos por QR', img.arial48, 0,
      sheet.width, 30, black);
  for (var i = 0; i < qrCases.length; i++) {
    final c = qrCases[i];
    final x0 = margin + (i % cols) * cell;
    final y0 = header + (i ~/ cols) * cellH;
    final qr = renderQr(c.text, 9); // 33 modulos * 9 = 297 px
    img.compositeImage(sheet, qr, dstX: x0 + (cell - qr.width) ~/ 2, dstY: y0);
    final ty = y0 + qr.height;
    drawCentered(sheet, c.text, img.arial24, x0, cell, ty, black);
    final color = switch (c.category) {
      'valid' => img.ColorRgb8(0, 120, 40),
      'invalid' => img.ColorRgb8(190, 0, 0),
      _ => img.ColorRgb8(200, 110, 0),
    };
    drawCentered(sheet, c.label, img.arial24, x0, cell, ty + 34, color);
    img.drawRect(sheet,
        x1: x0 + 4, y1: y0 - 4, x2: x0 + cell - 6, y2: y0 + cellH - 24,
        color: img.ColorRgb8(200, 200, 200));
  }
  _save(sheet, '$outDir/hoja_qr.png');

  // Manifest (JSON determinista).
  final manifest = {
    'format': r'^product:([1-9][0-9]*)$',
    'codes': [
      for (final c in qrCases)
        {
          'file': c.file,
          'text': c.text,
          'category': c.category,
          'expected': c.expected,
        }
    ],
  };
  File('$outDir/manifest.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n');

  stdout.writeln('Generados ${qrCases.length} QR + hoja_qr.png + manifest.json '
      'en $outDir');
}

void _save(img.Image im, String path) =>
    File(path).writeAsBytesSync(img.encodePng(im));
