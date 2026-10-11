# SDK Android de escaneo QR (`qrscanner`)

Librería Android (Kotlin) que abre una pantalla de cámara, coordina el permiso, lee un QR con formato `product:<id>` y entrega **exactamente un resultado** por sesión. No depende de Flutter, pedidos ni REST: solo cámara, permiso, ciclo de vida, validación y resultado. Funciona sin conexión (el modelo de ML Kit viene empaquetado).

- Paquete: `com.qrpedidos.sdk` · `minSdk 24` · `compileSdk 36` · Kotlin/JVM 17
- Contrato compartido con el puente Flutter: `docs/CONTRATO_SCANNER.md`

## API pública

```kotlin
enum class ScanErrorCode(val code: String) {
    PERMISSION_DENIED("permissionDenied"), CAMERA_UNAVAILABLE("cameraUnavailable"),
    INVALID_QR("invalidQr"), CANCELLED("cancelled"), SCAN_IN_PROGRESS("scanInProgress"),
}
sealed interface ScanResult {
    data class Success(val productId: Long) : ScanResult
    data class Failure(val error: ScanErrorCode, val message: String) : ScanResult
}
fun interface ScanCallback { fun onResult(result: ScanResult) }

object QrScanner {
    fun startScan(context: Context, callback: ScanCallback)
    fun cancelScan(): Boolean
    val isScanning: Boolean
    fun setLoggingEnabled(enabled: Boolean)   // logs de Logcat, por defecto true
}
object QrValidator { fun validate(qrContent: String): Long? }
```

Todo lo demás (`QrScannerActivity`, `ScanSessionManager`) es `internal`.

### Ejemplo en una app Android nativa

```kotlin
QrScanner.startScan(this) { result ->            // siempre en el hilo principal
    when (result) {
        is ScanResult.Success -> abrirProducto(result.productId)
        is ScanResult.Failure -> when (result.error) {
            ScanErrorCode.PERMISSION_DENIED   -> mostrar("Permiso de cámara denegado")
            ScanErrorCode.CAMERA_UNAVAILABLE  -> mostrar("Cámara no disponible")
            ScanErrorCode.INVALID_QR          -> mostrar("QR no válido")
            ScanErrorCode.CANCELLED           -> Unit
            ScanErrorCode.SCAN_IN_PROGRESS    -> Unit
        }
    }
}
// Desde otro punto de la app: QrScanner.cancelScan()
```

`startScan` acepta cualquier `Context` (si no es una `Activity` se añade `FLAG_ACTIVITY_NEW_TASK`).

## Códigos de error

| `ScanErrorCode` | Wire | Cuándo |
| --- | --- | --- |
| `PERMISSION_DENIED` | `permissionDenied` | El usuario rechazó el permiso de cámara |
| `CAMERA_UNAVAILABLE` | `cameraUnavailable` | Sin cámara (`FEATURE_CAMERA_ANY`) o falla al obtener/vincular la cámara o abrir la vista |
| `INVALID_QR` | `invalidQr` | QR que no cumple `^product:[1-9][0-9]*$` o no cabe en `Long` |
| `CANCELLED` | `cancelled` | Botón Cancelar, atrás, `cancelScan()`, paso a segundo plano |
| `SCAN_IN_PROGRESS` | `scanInProgress` | Se llamó a `startScan` con otra sesión activa (lo recibe solo el nuevo llamador) |

## Decisiones de ciclo de vida

| Tema | Decisión |
| --- | --- |
| Cancelación | Error tipado `CANCELLED`, nunca `null` |
| QR inválido | Resultado terminal `INVALID_QR` en la primera lectura inválida (no se devuelve el texto leído) |
| Rotación / cambio de configuración | La actividad declara `configChanges` y no se recrea; la cámara sigue |
| Segundo plano (`onStop` sin cambio de configuración) | Cancela con `CANCELLED`; no se restaura. **Excepción:** no cancela mientras se muestra el diálogo de permiso del sistema, porque en varios Android (y fabricantes) ese diálogo deja la actividad detenida y se perdería la sesión antes de que el usuario responda. Si el sistema destruye la actividad con el diálogo abierto, `onDestroy` sí cancela |
| Muerte del proceso | Si la actividad se recrea sin sesión activa con su id, hace `finish()` sin entregar nada |
| Hilo de entrega | Siempre el hilo principal |
| Resultado por sesión | Exactamente uno; detecciones, cancelaciones o errores posteriores se ignoran (también resultados tardíos de ML Kit) |
| Segunda apertura con sesión activa | El nuevo llamador recibe `SCAN_IN_PROGRESS`; la sesión activa no se altera |
| Recursos | Al terminar: `unbindAll()`, `BarcodeScanner.close()`, `ExecutorService.shutdown()`, una sola vez. `onDestroy` sin resultado entregado cancela |
| Ids de sesión | Cada sesión tiene un id; una actividad antigua no puede completar una sesión nueva |

La lógica de sesión vive en `ScanSessionManager` (JVM puro, sin Android) para poder probarla sin dispositivo.

## Logs

El SDK escribe logs de diagnóstico en Logcat con el tag `QrSdk` (formato `evento clave=valor`, correlacionados con `session=<n>`). No cambian el comportamiento y nunca registran el contenido completo del QR (solo el largo y, en nivel D, los primeros 20 caracteres de un QR inválido). Las detecciones repetidas y los fallos por fotograma se limitan a 1 línea cada 2 s.

```bash
adb logcat -s QrSdk:V
```

Para silenciarlos desde una app nativa: `QrScanner.setLoggingEnabled(false)`. Tabla de eventos: `docs/LOGS.md`.

## Manifiesto

El AAR aporta (se fusiona en la app):

- `<uses-permission android:name="android.permission.CAMERA"/>`
- `<uses-feature android:name="android.hardware.camera" android:required="false"/>` (la app se instala en dispositivos sin cámara; el SDK devuelve `CAMERA_UNAVAILABLE`)
- `QrScannerActivity` con `exported="false"` y `configChanges="orientation|screenSize|screenLayout|smallestScreenSize|keyboardHidden"`

El permiso se solicita en tiempo de ejecución desde la propia pantalla del SDK.

## Compilar el AAR

```bash
cd android_sdk
./gradlew :qrscanner:assembleRelease
# salida: android_sdk/qrscanner/build/outputs/aar/qrscanner-release.aar
```

Requiere JDK 17+ y el SDK de Android (`sdk.dir` en `local.properties`, que no se versiona).

## Pruebas

```bash
./gradlew :qrscanner:testDebugUnitTest
```

JUnit 4 en JVM: `QrValidatorTest` (válidos, inválidos, límites de `Long`) y `ScanSessionManagerTest` (una sola terminación incluso concurrente, `SCAN_IN_PROGRESS`, cancelación + cierre, cancelación tras éxito, liberación única, ids antiguos, `isScanning`).

## Dependencias

| Dependencia | Versión | Licencia |
| --- | --- | --- |
| CameraX (`camera-core`, `-camera2`, `-lifecycle`, `-view`) | 1.4.2 | Apache 2.0 |
| ML Kit `com.google.mlkit:barcode-scanning` | 17.3.0 | ML Kit Terms of Service de Google; modelo **empaquetado** en el APK, sin descarga en runtime |
| `androidx.activity:activity-ktx` | 1.9.3 | Apache 2.0 |
| `androidx.core:core-ktx` | 1.15.0 | Apache 2.0 |
| JUnit (solo pruebas) | 4.13.2 | EPL 1.0 |

**Importante:** un `.aar` suelto no trae sus dependencias transitivas. Si se integra copiando el archivo (`implementation(files("libs/qrscanner-release.aar"))`), la app debe declarar también CameraX, ML Kit, `activity-ktx` y `core-ktx` con las versiones de la tabla.
