# Contrato del escáner QR (SDK ↔ puente ↔ app)

Fuente única de verdad para el punto 2. El SDK (`android_sdk/`) y el puente (`qr_scanner_bridge/`) deben respetarlo literalmente.

## Decisiones

| Tema | Decisión |
| --- | --- |
| Cancelación | **Error tipado** `cancelled` en todo el recorrido (SDK → puente → Dart). Nunca `null`. |
| QR inválido | **Resultado terminal** `invalidQr`: la sesión termina al primer QR con formato inválido. No se devuelve el texto leído. |
| Rotación / cambio de configuración | La actividad declara `configChanges` y **no se recrea**; la cámara sigue. |
| Segundo plano (`onStop` sin `isChangingConfigurations`) | **Cancela** la sesión de forma controlada con `cancelled`. No se restaura. |
| Kill del proceso | Si la actividad se recrea sin sesión activa, termina sin entregar nada (no hay a quién entregar). |
| Hilo de entrega | El callback se ejecuta siempre en el hilo principal. |
| Resultado por sesión | Exactamente uno. Después de entregar, cualquier detección o cancelación posterior se ignora. |
| Segunda apertura con sesión activa | El **nuevo** llamador recibe `scanInProgress` de inmediato; la sesión activa no se altera. |
| Canal | **MethodChannel** `com.qrpedidos/qr_scanner`: solo 2 métodos y 5 códigos; no justifica la generación de código de Pigeon. |

## Códigos estables

| Código (wire) | Cuándo |
| --- | --- |
| `permissionDenied` | El usuario rechazó el permiso de cámara |
| `cameraUnavailable` | El dispositivo no tiene cámara, o no se pudo abrir/vincular |
| `invalidQr` | Se leyó un QR que no cumple `^product:[1-9][0-9]*$` o no cabe en `Long` |
| `cancelled` | Atrás, botón Cancelar, `cancelScan()`, paso a segundo plano, o desconexión de la actividad/motor Flutter |
| `scanInProgress` | Se pidió un escaneo mientras otro estaba activo |

## API pública del SDK (Kotlin, paquete `com.qrpedidos.sdk`)

```kotlin
enum class ScanErrorCode(val code: String) {
    PERMISSION_DENIED("permissionDenied"),
    CAMERA_UNAVAILABLE("cameraUnavailable"),
    INVALID_QR("invalidQr"),
    CANCELLED("cancelled"),
    SCAN_IN_PROGRESS("scanInProgress"),
}

sealed interface ScanResult {
    data class Success(val productId: Long) : ScanResult
    data class Failure(val error: ScanErrorCode, val message: String) : ScanResult
}

fun interface ScanCallback {
    fun onResult(result: ScanResult)
}

object QrScanner {
    /** Abre la vista de captura. Entrega exactamente un resultado en el hilo principal. */
    fun startScan(context: Context, callback: ScanCallback)

    /** Cancela la sesión activa (su callback recibe CANCELLED) y cierra la vista. false si no había sesión. */
    fun cancelScan(): Boolean

    val isScanning: Boolean

    /** Adición no rompiente: activa/silencia los logs de Logcat del SDK (tag QrSdk). Por defecto true. */
    fun setLoggingEnabled(enabled: Boolean)
}

object QrValidator {
    fun validate(qrContent: String): Long?   // ya existe
}
```

`QrScannerActivity` deja de ser parte del contrato público (se mantiene en el manifiesto, `exported=false`).

## Contrato del MethodChannel `com.qrpedidos/qr_scanner`

| Método | Argumentos | Éxito | Error |
| --- | --- | --- | --- |
| `scanProduct` | ninguno | `{"productId": <int>}` | `PlatformException(code: <código wire>, message: <texto>)` |
| `cancelScan` | ninguno | `bool` (true si había sesión) | — |

## API Dart (paquete `qr_scanner_bridge`)

```dart
enum ScanErrorCode { permissionDenied, cameraUnavailable, invalidQr, cancelled, scanInProgress, unknown }

class ScanResult { final int productId; }

class ScanException implements Exception {
  final ScanErrorCode code;
  final String? message;
}

class QrScannerBridge {
  Future<ScanResult> scanProduct();   // lanza ScanException
  Future<bool> cancelScan();
}
```

`unknown` cubre cualquier código no reconocido, `MissingPluginException` o un `productId` ausente/no positivo.
