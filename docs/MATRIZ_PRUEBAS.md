# Matriz de pruebas

> Última ejecución: 2026-10-10 · macOS (Darwin 25.6) · Flutter 3.47.7 · Gradle 9.3.1 · AGP 9.1.0 · JBR de Android Studio.
> Las pruebas automatizadas no usan la red: todas las respuestas HTTP vienen de `MockClient` o del cliente simulado.

## Resumen

| Suite | Comando | Pruebas | Resultado |
| --- | --- | ---: | --- |
| SDK Kotlin (JVM) | `cd android_sdk && ./gradlew :qrscanner:testDebugUnitTest` | 17 | ✅ 17/17 |
| Puente Dart | `cd qr_scanner_bridge && flutter test` | 18 | ✅ 18/18 |
| App Flutter | `cd app_flutter && flutter test` | 52 | ✅ 52/52 (2 corridas seguidas, sin inestabilidad) |
| Análisis estático | `flutter analyze` en `app_flutter` y `qr_scanner_bridge` | — | ✅ sin problemas |
| Compilación AAR | `cd android_sdk && ./gradlew :qrscanner:assembleRelease` | — | ✅ `qrscanner-release.aar` |
| Compilación APK | `flutter build apk --debug` (real) y `--dart-define=API_MODE=fake` | — | ✅ ambos |

## Cobertura de lo que pide el enunciado (sección 8)

| Requisito | Dónde se prueba | Estado |
| --- | --- | --- |
| **Kotlin:** QR válido, inválido y fuera de rango | `QrValidatorTest` (todos los casos de la sección 4, más `Long.MAX_VALUE` y `…808`) | ✅ |
| **Kotlin:** una sola terminación por sesión ante detecciones repetidas | `ScanSessionManagerTest` (incluye 16 hilos concurrentes) | ✅ |
| **Kotlin:** cancelación y liberación de recursos | `ScanSessionManagerTest` (gancho de cierre y liberación exactamente una vez, id viejo sin efecto) | ✅ |
| **Dart:** repositorio carga desde caché y conserva datos ante fallo de red | `product_repository_test.dart` (red caída, HTTP 500, JSON inválido, refrescar no borra pedidos) | ✅ |
| **Dart:** pedido, persistencia y recuperación, cantidades y total | `order_repository_test.dart` (cierre y reapertura de la base), `cart_controller_test.dart` | ✅ |
| **Dart:** cola: éxito, HTTP o timeout, doble ejecución, reintento, exclusión de confirmados | `order_repository_test.dart`, `widgets/orders_screen_test.dart` | ✅ |
| **Dart:** contrato del puente: conversión y propagación de cancelación o error | `qr_scanner_bridge/test/qr_scanner_bridge_test.dart`, `widgets/catalog_screen_test.dart` | ✅ |
| Producto inexistente `product:999999` con doble de prueba | `product_repository_test.dart`, `catalog_screen_test.dart`, `fake_dummyjson_client_test.dart` | ✅ |

## Detalle de la app Flutter (52)

| Archivo | Pruebas | Qué cubre |
| --- | ---: | --- |
| `order_repository_test.dart` | 8 | Persistencia tras reabrir la base; éxito → Confirmado simulado sin reenvío; doble toque = 1 POST; HTTP 500 → Error y reintento con el mismo ID; JSON inválido; sin conexión; timeout → Resultado desconocido fuera del lote; pedido que quedó en Enviando → desconocido |
| `product_repository_test.dart` | 11 | Primera carga; caché con red caída (`isOffline`); HTTP 500 y JSON inválido conservan la copia (y no se marcan como offline); refrescar no borra pedidos; sin caché ni red; `findById` local sin red, remoto y guardado, 999999 → no encontrado, sin red → no disponible offline, HTTP 500 → fallo del servidor |
| `api_client_test.dart` | 11 | URLs de DummyJSON; cuerpo del POST con `userId: 1` y clave `id`; 400, 404 y 503 como error conocido; respuesta sin `id`; clasificación de timeout, sin conexión y conexión cortada |
| `fake_dummyjson_client_test.dart` | 7 | El modo simulado ejercita los clientes reales: fixtures, 404 para 999999, referencia simulada, sin conexión frente a HTTP 500, conexión cortada → desconocido, HTTP 400 |
| `widgets/catalog_screen_test.dart` | 8 | Estado vacío sin datos ni red; aviso de sin conexión con caché; escaneo: agrega, volver a escanear suma, cancelado, QR inválido, permiso denegado, 999999 sin agregar línea |
| `widgets/orders_screen_test.dart` | 3 | Historial vacío; doble toque en **Enviar pendientes** = 1 POST y estado mostrado con texto; pedido desconocido con aviso y diálogo, y Cancelar no envía |
| `cart_controller_test.dart` | 2 | Volver a escanear suma cantidad y total; bajar a 0 quita la línea |
| `product_test.dart` | 2 | `Product.fromJson`, incluido un precio entero |

## Pruebas manuales en dispositivo

> **Pendiente de ejecutar.** Llenar con el dispositivo real o el emulador usado en el video (modelo, versión de Android y cámara).

Dispositivo: _____ · Android: _____ · Build: APK debug del tag de entrega

| # | Escenario | Pasos | Esperado | Resultado |
| --- | --- | --- | --- | --- |
| M1 | Lectura real con cámara | Escanear `product:1` impreso o en otra pantalla | Se agrega al pedido con aviso | ⬜ |
| M2 | Permiso rechazado y recuperación | Rechazar el permiso; volver a escanear y aceptar | Mensaje `permissionDenied`; el segundo intento funciona | ⬜ |
| M3 | Cancelación | Botón Cancelar o atrás en el escáner | Mensaje "Escaneo cancelado." | ⬜ |
| M4 | QR inválido | Escanear `product:01` o `hola` | Mensaje de QR inválido; no se agrega nada | ⬜ |
| M5 | Producto inexistente | Escanear `product:999999` | "no encontrado"; no se agrega nada | ⬜ |
| M6 | Segundo plano durante el escaneo | Abrir el escáner y pulsar Home | La sesión se cancela; la app no se bloquea | ⬜ |
| M7 | Pedido sin conexión | Cargar el catálogo, activar modo avión, crear un pedido | Aviso sin conexión; pedido Pendiente | ⬜ |
| M8 | Cierre y reapertura | Cerrar la app por completo y abrirla | El catálogo y el pedido siguen ahí | ⬜ |
| M9 | Envío y doble toque | Recuperar la conexión y tocar **Enviar pendientes** dos veces | Un solo envío; Confirmado simulado | ⬜ |
| M10 | Sin reenvío | Tocar de nuevo **Enviar pendientes** | El pedido confirmado no se envía | ⬜ |
| M11 | Fallos reproducidos (modo simulado) | APK con `API_MODE=fake`: HTTP 500, timeout y conexión cortada | Error, Resultado desconocido y reintento manual con aviso | ⬜ |

## Limitaciones conocidas de la evidencia

- `QrScannerActivity` (cámara, diálogo de permiso, ML Kit, segundo plano) no tiene prueba instrumentada: su lógica de sesión está extraída en `ScanSessionManager` y probada en la JVM, y la parte de hardware se demuestra en M1–M6.
- El Kotlin del plugin del puente (`QrScannerBridgePlugin`) se verifica compilando el APK. Su comportamiento se prueba desde Dart con un doble del canal.
