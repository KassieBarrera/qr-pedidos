// Decodifica cada PNG generado con zxing2 (pure Dart) y compara el texto leído
// con el del manifest. Uso: dart run bin/verify.dart [--out <dir>]
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

void main(List<String> args) {
  var dir = '../../qr';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) dir = args[++i];
  }
  final manifest =
      jsonDecode(File('$dir/manifest.json').readAsStringSync()) as Map;
  final codes = (manifest['codes'] as List).cast<Map>();
  var ok = 0;
  for (final c in codes) {
    final file = c['file'] as String;
    final expected = c['text'] as String;
    String got;
    try {
      got = _decode('$dir/$file');
    } catch (e) {
      got = '<error: $e>';
    }
    final pass = got == expected;
    if (pass) ok++;
    stdout.writeln('${pass ? "OK  " : "FAIL"} $file -> '
        '${jsonEncode(got)} (esperado ${jsonEncode(expected)})');
  }
  stdout.writeln('Resultado: $ok/${codes.length}');
  if (ok != codes.length) exit(1);
}

String _decode(String path) {
  final im = img.decodePng(File(path).readAsBytesSync())!;
  final rgba = im.convert(numChannels: 4);
  final pixels = Int32List.fromList([
    for (final p in rgba)
      (0xFF << 24) | (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt()
  ]);
  final source = RGBLuminanceSource(im.width, im.height, pixels);
  final bitmap = BinaryBitmap(HybridBinarizer(source));
  return QRCodeReader().decode(bitmap).text;
}
