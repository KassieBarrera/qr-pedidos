import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner_bridge/qr_scanner_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/qr_scanner');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late QrScannerBridge bridge;
  late List<String> calls;

  void mock(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      return handler(call);
    });
  }

  setUp(() {
    bridge = QrScannerBridge(channel: channel);
    calls = [];
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<ScanException> failure(Future<ScanResult> f) async {
    try {
      await f;
    } on ScanException catch (e) {
      return e;
    }
    fail('Se esperaba ScanException');
  }

  test('el canal por defecto sigue el contrato', () {
    expect(QrScannerBridge.channelName, 'com.qrpedidos/qr_scanner');
  });

  test('éxito se convierte en ScanResult', () async {
    mock((_) async => {'productId': 42});
    expect(await bridge.scanProduct(), const ScanResult(42));
    expect(calls, ['scanProduct']);
  });

  for (final entry in {
    'permissionDenied': ScanErrorCode.permissionDenied,
    'cameraUnavailable': ScanErrorCode.cameraUnavailable,
    'invalidQr': ScanErrorCode.invalidQr,
    'cancelled': ScanErrorCode.cancelled,
    'scanInProgress': ScanErrorCode.scanInProgress,
  }.entries) {
    test('código ${entry.key} se propaga como ScanException', () async {
      mock((_) async => throw PlatformException(code: entry.key, message: 'm'));
      final e = await failure(bridge.scanProduct());
      expect(e.code, entry.value);
      expect(e.message, 'm');
    });
  }

  test('código desconocido pasa a unknown', () async {
    mock((_) async => throw PlatformException(code: 'rarisimo'));
    expect((await failure(bridge.scanProduct())).code, ScanErrorCode.unknown);
  });

  for (final bad in <Object?>[
    null,
    <String, Object?>{},
    {'productId': -3},
    {'productId': 0},
    {'productId': '7'},
    'texto',
  ]) {
    test('respuesta inválida $bad pasa a unknown', () async {
      mock((_) async => bad);
      expect((await failure(bridge.scanProduct())).code, ScanErrorCode.unknown);
    });
  }

  test('MissingPluginException pasa a unknown', () async {
    // Sin handler registrado el binding responde MissingPluginException.
    expect((await failure(bridge.scanProduct())).code, ScanErrorCode.unknown);
  });

  test('cancelScan invoca el método y devuelve el bool', () async {
    mock((_) async => true);
    expect(await bridge.cancelScan(), isTrue);
    mock((_) async => false);
    expect(await bridge.cancelScan(), isFalse);
    expect(calls, ['cancelScan', 'cancelScan']);
  });

  test(
    'doble llamada concurrente: la segunda es scanInProgress sin ir al canal',
    () async {
      final completer = Completer<Object?>();
      mock((_) => completer.future);

      final first = bridge.scanProduct();
      final e = await failure(bridge.scanProduct());
      expect(e.code, ScanErrorCode.scanInProgress);
      expect(calls, ['scanProduct']);

      completer.complete({'productId': 5});
      expect(await first, const ScanResult(5));

      // Liberado el vuelo, se puede volver a escanear.
      mock((_) async => {'productId': 6});
      expect(await bridge.scanProduct(), const ScanResult(6));
    },
  );

  test('tras un error se puede volver a escanear', () async {
    mock((_) async => throw PlatformException(code: 'cancelled'));
    await failure(bridge.scanProduct());
    mock((_) async => {'productId': 9});
    expect(await bridge.scanProduct(), const ScanResult(9));
  });
}
