# Control de avance — Examen QR Pedidos

> Última revisión: 2026-10-10. Primer commit: 2026-10-07 → si el examen se recibió ese día, **el plazo vence aprox. el 2026-10-12** (confirmar fecha/hora exacta en la invitación).
>
> Leyenda: ✅ hecho · 🟡 parcial · ⬜ pendiente

## Resumen

| Bloque (puntos) | Estado | Comentario |
| --- | --- | --- |
| SDK Android (25) | ✅ | API pública `QrScanner`, 5 códigos, cancelación, ciclo de vida, gradlew, 17 pruebas JVM, AAR compila. Falta probar con cámara real |
| Puente Flutter (20) | ✅ | Plugin local `qr_scanner_bridge/` con `scanProduct`/`cancelScan`, errores tipados, desconexión, 18 pruebas Dart. Falta probar en dispositivo |
| REST, BD y offline (25) | ✅ | Pedidos, líneas, cola manual, POST, 5 estados, búsqueda por ID. Falta probar en dispositivo |
| Pruebas (10) | 🟡 | 87 pruebas en verde (17 Kotlin + 18 puente + 52 app), matriz en `docs/MATRIZ_PRUEBAS.md`, modo simulado. Faltan las pruebas manuales en dispositivo y el video |
| UI (10) | 🟡 | 3 vistas (Catálogo, Pedido, Historial) con estados vacío/offline/error. Falta tema propio y pulido |
| Docs + IA (10) | ⬜ | Sin README raíz ni `AI_USAGE.md` |
| Entrega GitHub | ⬜ | Sin Release, AAR, APK ni video |

## 1. SDK Android (`android_sdk/`)

- ✅ Módulo Android Library con CameraX 1.4.2 + ML Kit barcode-scanning 17.3.0 (modelo empaquetado → funciona offline)
- ✅ `QrValidator` (prefijo exacto, sin ceros iniciales, rango `Long`)
- ✅ Solicitud de permiso de cámara y `AtomicBoolean` para un solo resultado
- ✅ Añadir **Gradle wrapper** (`gradlew`, `gradlew.bat`, `gradle-wrapper.jar`) para compilar el AAR por separado: `./gradlew :qrscanner:assembleRelease`
- ✅ Borrar archivos sobrantes: `qrscanner/settings.gradle.kts` y `qrscanner/src/build.gradle.kts`
- ✅ Declarar `androidx.activity` explícitamente (se usa `ComponentActivity` / `registerForActivityResult`)
- ✅ **API pública** independiente de Flutter: p. ej. `QrScanner.createIntent()`, `QrScanner.parseResult()` y un `sealed class ScanResult { Success(productId) / Error(code) / Cancelled }`
- ✅ Códigos estables: `permissionDenied`, `cameraUnavailable`, `invalidQr`, `cancelled`, `scanInProgress` (hoy: `CAMERA_PERMISSION_DENIED`, `CAMERA_ERROR`)
- ✅ Cámara no disponible: comprobar `PackageManager.FEATURE_CAMERA_ANY` / `hasCamera` antes de abrir
- ✅ Decidir y documentar QR inválido: hoy muestra toast y sigue escaneando (válido, pero documentarlo) o terminar con `invalidQr`
- ✅ Cancelación explícita: botón “Cancelar” en la vista + manejo de “atrás” → `cancelled`
- ✅ Segundo intento con sesión activa → `scanInProgress` (en el SDK, no solo en el puente)
- ✅ Ciclo de vida: en `onStop`/cambio de configuración cancelar la sesión de forma controlada (o `configChanges` en manifiesto) y documentar; evitar callbacks tardíos tras `onDestroy`
- ✅ Cancelación remota (para `cancelScan()` desde Flutter): p. ej. broadcast local o registro estático de la sesión activa
- ✅ Pantalla de captura con marco/guía, texto y botón Cancelar (UX)
- ✅ README del SDK: integración en app nativa, dependencias, versiones, licencias (CameraX Apache 2.0, ML Kit términos de Google)

## 2. Puente Flutter

- ✅ `MethodChannel('com.qrpedidos/scanner')` con método `scanQr` y bloqueo de doble llamada
- ✅ Mover a **plugin local** (p. ej. `packages/qr_scanner_bridge/`) o clase separada con `ActivityAware` en lugar de `MainActivity`
- ✅ Contrato Dart: `scanProduct()` → `ScanResult(productId)` y `cancelScan()`; excepción tipada `ScanException(code)`
- ✅ Mapear códigos nativos → enum Dart; un único criterio para cancelación (resultado o error)
- ✅ Devolver `productId` como entero (hoy convierte a String y de vuelta)
- ✅ `onDetachedFromActivity` / `onDetachedFromEngine`: resolver la llamada pendiente con `cancelled` (ninguna llamada colgada)
- ✅ Justificar MethodChannel vs Pigeon en README

> Decisiones fijadas en [docs/CONTRATO_SCANNER.md](docs/CONTRATO_SCANNER.md): cancelación = error tipado `cancelled`; QR inválido = terminal `invalidQr`; segundo plano cancela (salvo durante el diálogo de permiso); rotación no recrea.
>
> Compilar el SDK requiere `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"` (el Java del sistema no está instalado).

## 3. App Flutter — REST, BD, pedidos, cola

- ✅ `GET /products?limit=30` con timeout y validación de formato
- ✅ Tabla `products` (id, title, price, updated_at) y transacción al guardar
- ✅ Repositorio conserva caché si falla la red
- ✅ Carrito en memoria (`features/order/cart_controller.dart`) con +/−, quitar y total estimado
- ✅ Buscar producto escaneado: BD local → si no está, `GET /products/{id}` → mensajes distintos para **no encontrado (404)** y **no disponible offline**
- ✅ Tablas `orders` (id local UUID, status, created_at, updated_at, attempts, last_error, remote_ref) y `order_lines` (order_id, product_id, quantity > 0, title, price) — migración `version: 2`
- ✅ Guardar pedido en transacción (pedido + líneas atómicos)
- ✅ Cliente `POST /carts/add` (`userId: 1`, `products: [{id, quantity}]`, `Content-Type: application/json`, timeout)
- ✅ Estados: `pending`, `sending`, `confirmed` (Confirmado simulado), `error`, `unknown`
- ✅ Cola manual “Enviar pendientes”: candado contra doble toque, excluye `confirmed` y `unknown`, error por pedido
- ✅ Clasificar fallos: 4xx/5xx y JSON inválido → `error`; timeout/conexión tras enviar → `unknown`; sin conexión antes de enviar → `error` reintentable
- ✅ Al iniciar la app: pedidos en `sending` → `unknown`
- ✅ Reintento manual individual de `unknown` con aviso de incertidumbre
- ✅ Total estimado (precio × cantidad, redondeo a 2 decimales documentado)
- ✅ Modo offline inferido por fallo de red (banner “mostrando catálogo guardado”)

## 4. UI (10 pts)

- ⬜ Tema propio coherente (colores, tipografía, espaciado) — hoy `ColorScheme.fromSeed(teal)` por defecto
- ✅ Navegación: Catálogo · Pedido actual · Historial/pendientes (p. ej. `NavigationBar`)
- ✅ Pedido actual: +/- cantidades, quitar, total estimado, botón “Guardar pedido”
- ✅ Historial: chips de estado con **icono + texto** (no solo color), detalle de error, botón reintentar
- 🟡 Estados de carga, vacío (sin datos y sin conexión), error y banner offline (hechos; falta revisarlos en dispositivo)
- 🟡 Feedback visible tras escanear, guardar y enviar (SnackBars); revisar áreas táctiles

## 5. Pruebas

**Kotlin**
- ✅ QR válido, inválido y fuera de rango (`QrValidatorTest`, `ScanSessionManagerTest`)
- ✅ Una sola terminación por sesión ante detecciones repetidas (extraer la lógica a una clase `ScanSession` testeable)
- ✅ Cancelación y liberación de recursos (abstracción falsa de cámara o prueba instrumentada)

**Dart** (con `http/testing.dart` `MockClient` y `sqflite_common_ffi` para BD en memoria)
- ✅ Repositorio: carga desde caché y conserva datos ante fallo de red (`product_repository_test.dart`)
- ✅ Pedido: persistencia y recuperación (cierre/reapertura de BD), cantidades, total
- ✅ Cola: éxito, HTTP 500, JSON inválido, sin conexión, timeout, doble ejecución, reintento, exclusión de confirmados, recuperación de `sending` (`test/order_repository_test.dart`)
- ✅ Puente: conversión de resultado y propagación de cancelación/error con doble (`TestDefaultBinaryMessengerBinding`)
- ✅ `widget_test.dart` renombrado a `product_test.dart`; widget tests de catálogo e historial en `test/widgets/`

**Manual / evidencia**
- ✅ Matriz de lo ejecutado: [docs/MATRIZ_PRUEBAS.md](docs/MATRIZ_PRUEBAS.md) (falta llenar las pruebas manuales M1–M11)
- ⬜ Video 3–5 min: cámara real + cancelación + permiso rechazado; pedido offline; cierre y reapertura; envío, doble toque, no reenvío
- ⬜ Documentar dispositivo (modelo, versión Android)
- ✅ Modo simulado `--dart-define=API_MODE=fake` con fixtures e inyección de fallos ([app_flutter/docs/MODO_SIMULADO.md](app_flutter/docs/MODO_SIMULADO.md))

## 6. Datos de prueba QR

- ⬜ Carpeta `qr/` con PNG de `product:1/2/3`, inválidos y `product:999999`, + script reproducible (p. ej. `qrencode` o Python `qrcode`)
- ✅ Doble de prueba para el caso de producto inexistente (999999): `MockClient` en pruebas y 404 en el modo simulado

## 7. Documentación

- ⬜ `README.md` raíz: arquitectura, contrato SDK/puente, estados, errores, dependencias del AAR, decisiones, herramientas y versiones, dispositivo, tiempo, limitaciones, implementado vs probado vs pendiente, pasos offline, qué haría falta en una API real (idempotency key + consulta de estado)
- ⬜ `AI_USAGE.md` con las 5 secciones
- ⬜ Registro de tiempo aproximado

## 8. Repositorio y entrega

- ⬜ `.gitignore` raíz: `android_sdk/.gradle/`, `android_sdk/.idea/`, `android_sdk/local.properties`, `build/`
- ⬜ Revisar que no se suban `local.properties` ni rutas personales
- ⬜ Repo público en GitHub (`KassieBarrera/qr-pedidos`) — verificar visibilidad
- ⬜ Tag (p. ej. `v1.0.0`) + **GitHub Release** con `qrscanner-release.aar` y `app-debug.apk`
- ⬜ Enlaces directos en README a Release, AAR, APK y video
- ⬜ Comprobar acceso en ventana de incógnito
- ⬜ Enviar URL + hash completo del commit

## Orden sugerido (lo que más puntos desbloquea primero)

1. ~~Pedidos + líneas en BD, pantalla de pedido e historial, cola de envío con estados~~ ✅ 2026-10-10
2. ~~Contrato SDK + puente~~ ✅ 2026-10-10
3. ~~Pruebas Dart y Kotlin faltantes~~ ✅ 2026-10-10
4. Pulido de UI
5. QR, README, AI_USAGE, `.gitignore`, gradlew
6. Build AAR/APK, Release, video

## Bitácora

| Fecha | Avance |
| --- | --- |
| 2026-10-07 | Estructura Flutter, catálogo offline (GET + SQLite) |
| 2026-10-08 | Estructura inicial del SDK Android |
| 2026-10-09 | `QrScannerActivity` con CameraX + ML Kit, validador + prueba, MethodChannel, escaneo agrega al carrito |
| 2026-10-10 | Creado este control de avance |
| 2026-10-10 | Punto 3 (subagentes Sonnet, revisado): 41 pruebas Dart nuevas, modo simulado con fixtures, matriz de pruebas. Corregido: un HTTP 500 ya no se muestra como "sin conexión" |
| 2026-10-10 | Punto 2 (con subagentes Sonnet, revisado): SDK con API pública y ciclo de vida, plugin `qr_scanner_bridge`, AAR y APK compilan, 17 pruebas Kotlin + 18 Dart |
| 2026-10-10 | Punto 1: pedidos, líneas, cola de envío con 5 estados, búsqueda por ID, 3 vistas, 11 pruebas Dart en verde, APK debug compila |
