# qr_scanner_bridge

Plugin Flutter local (solo Android) que conecta la app con el SDK nativo de lectura QR (`android_sdk/qrscanner`). SDK, puente y app viven en carpetas separadas:

```
android_sdk/          SDK Android (QrScanner, CameraX/ML Kit, vista de captura)
qr_scanner_bridge/    este plugin (MethodChannel + API Dart tipada)
app_flutter/          la app
```

El contrato completo (canal, métodos, códigos y API Kotlin del SDK) está en [`docs/CONTRATO_SCANNER.md`](../docs/CONTRATO_SCANNER.md) y es la fuente única de verdad.

## Contrato resumido

Canal `MethodChannel('com.qrpedidos/qr_scanner')`.

| Método | Éxito | Error |
| --- | --- | --- |
| `scanProduct` | `{"productId": <int>}` | `PlatformException(code, message)` |
| `cancelScan` | `bool` (true si había sesión) | — |

Códigos: `permissionDenied`, `cameraUnavailable`, `invalidQr`, `cancelled`, `scanInProgress`. En Dart se suma `unknown` (código no reconocido, `MissingPluginException` o `productId` ausente/no positivo).

## API Dart

```dart
final scanner = QrScannerBridge(); // opcional: QrScannerBridge(channel: MethodChannel(...)) para pruebas
try {
  final result = await scanner.scanProduct(); // ScanResult(productId)
} on ScanException catch (e) {
  switch (e.code) { /* ScanErrorCode.* */ }
}
final hadSession = await scanner.cancelScan();
```

## Decisiones

- **MethodChannel y no Pigeon.** El contrato son 2 métodos sin argumentos y 5 códigos de error: un mapa `{productId}` y un `PlatformException` bastan. Pigeon añadiría generación de código y un paso de build extra sin aportar seguridad real aquí; empieza a convenir con más métodos o tipos de datos complejos. La tipificación se logra en la capa Dart (`ScanErrorCode`, `ScanException`) y se prueba con tests.
- **Cancelación como error tipado.** Atrás, el botón Cancelar, `cancelScan()`, pasar a segundo plano o desmontar la actividad terminan `scanProduct` con `ScanException(cancelled)`, nunca con `null`. Así el llamador distingue "no hubo resultado" de "hubo resultado" sin valores nulos ambiguos, y no hay que tratar la cancelación como un fallo (la app la muestra como mensaje neutro).
- **Una sola respuesta por llamada.** Cada llamada `scanProduct` se asocia a su propio `Result` y se responde exactamente una vez. Una segunda llamada con otra pendiente recibe `scanInProgress` sin tocar la primera (en Dart ni siquiera llega al canal).

## Ciclo de vida

- Sin actividad adjunta: `scanProduct` responde `cameraUnavailable`.
- `onDetachedFromActivity`, `onDetachedFromActivityForConfigChanges` y `onDetachedFromEngine`: si hay una llamada en vuelo se cancela la sesión del SDK y se responde `cancelled` (con try/catch, el motor puede estar muerto). Nada queda colgado.
- Todas las respuestas se entregan en el hilo principal.
- Rotación: la actividad declara `configChanges`, no se recrea y la cámara sigue.

## Integrarlo en otra app Flutter

1. `pubspec.yaml`: `qr_scanner_bridge: { path: ../qr_scanner_bridge }`.
2. **Requisito Gradle:** el plugin depende de `implementation(project(":qrscanner"))`, así que la app anfitriona debe declarar ese proyecto en `android/settings.gradle(.kts)`:

   ```kotlin
   include(":qrscanner")
   project(":qrscanner").projectDir = file("../../android_sdk/qrscanner")
   ```
3. `MainActivity` queda como un `FlutterActivity` vacío; el registro del plugin es automático.
4. La app necesita `minSdk` compatible con el SDK (24 o superior).

## Pruebas

`flutter test` (mock del canal con `setMockMethodCallHandler`): éxito, los 5 códigos, código desconocido, respuestas inválidas, `MissingPluginException`, `cancelScan` y doble llamada concurrente.
