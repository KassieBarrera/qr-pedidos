# Logs de diagnóstico (consola)

Logs técnicos para entender qué ocurre en cada capa. **No se muestran al usuario.** No registran datos personales; los IDs de pedido se acortan a 8 caracteres.

## Convención común

Una línea por evento, con el formato `evento clave=valor clave=valor`:

```
scan.start session=3
http.response method=POST path=/carts/add status=201 ms=812
queue.order.result order=eb470beb status=unknown reason=timeout attempt=2
```

- **Evento:** en minúsculas, con puntos (`area.accion` o `area.objeto.accion`) y en inglés, para poder buscarlo con grep.
- **Valores:** sin espacios. Los textos libres van entre comillas (`msg="..."`).
- **Correlación:**
  - `session=<n>`: id de sesión del SDK. Aparece en el SDK y en el plugin; en Dart, `scanner.call`/`scanner.result` quedan justo antes y después en la misma traza.
  - `order=<8 chars>`: pedido local.
  - `batch=<n>`: lote de **Enviar pendientes**.
- **Niveles:**
  - `D`: detalle.
  - `I`: hitos del flujo.
  - `W`: fallo esperado o recuperable, como sin conexión, QR inválido o cancelación.
  - `E`: fallo inesperado.

| Capa | Dónde aparece | Tag / nombre |
| --- | --- | --- |
| SDK Android (`android_sdk/`) | Logcat | `QrSdk` |
| Plugin Kotlin (`qr_scanner_bridge/android`) | Logcat | `QrBridge` |
| Dart (app y puente) | `flutter run` y Logcat (`flutter`) | prefijo `[qr_pedidos/<area>]` |

Áreas de Dart: `catalog`, `lookup`, `http`, `db`, `orders`, `queue`, `scanner`, `fake`.

## Cómo verlos

```bash
adb logcat -s QrSdk:V QrBridge:V flutter:V
```

O con `flutter run`, donde los logs de Dart aparecen en la misma consola.

## Android (QrSdk / QrBridge)

Los logs del SDK usan el tag `QrSdk` y se pueden silenciar con `QrScanner.setLoggingEnabled(false)`. Los del plugin usan `QrBridge` (siempre activos). El QR nunca se registra completo: solo `len` y, en nivel D, los primeros 20 caracteres de un QR inválido. Las líneas por fotograma (`qr.ignored`, `qr.frame.error`) tienen límite de 1 cada 2 s por actividad.

### SDK (`QrSdk`)

| Evento | Nivel | Significado |
| --- | --- | --- |
| `session.begin session=N` | I | Se abrió una sesión |
| `session.rejected reason=scanInProgress active=N` | W | Segundo `startScan` con otra sesión activa |
| `session.attach session=N ok=true\|false` | D / W | La actividad se enlazó (false: sesión vieja, la actividad se cierra) |
| `session.complete session=N result=success productId=7` | I | Resultado exitoso |
| `session.complete session=N result=failure code=invalidQr` | W | Resultado con error (no cancelación) |
| `session.cancel session=N source=user\|back\|api\|background\|destroy` | W | Cancelación y su origen |
| `session.ignored session=N reason=alreadyTerminated\|staleId` | D | Resultado tardío o duplicado descartado: un solo resultado por sesión |
| `session.release session=N` | D | Cámara y detector liberados |
| `session.startActivity.failed session=N msg="..."` | E | `startActivity` lanzó excepción |
| `activity.create session=N recreated=..` | D | `onCreate` |
| `activity.back session=N` | D | Botón atrás |
| `activity.stop session=N changingConfig=.. awaitingPermission=..` | D | `onStop` |
| `activity.destroy session=N` | D | `onDestroy` |
| `permission.request session=N` | I | Se muestra el diálogo del sistema |
| `permission.result session=N granted=true\|false` | I / W | Respuesta del permiso |
| `camera.unavailable session=N reason=noFeature` | W | El dispositivo no tiene cámara |
| `camera.unavailable session=N reason=bindFailed msg="..."` | E | Falló obtener/vincular la cámara |
| `camera.bound session=N` / `camera.unbound session=N` | I / D | Cámara vinculada / liberada |
| `qr.detected session=N valid=true productId=7` | I | QR válido |
| `qr.detected session=N valid=false len=N` | W | QR inválido |
| `qr.detected.sample session=N value="..."` | D | Primeros 20 caracteres del QR inválido |
| `qr.ignored session=N reason=finished` | D | Detección posterior al fin de la sesión (rate-limit) |
| `qr.frame.error session=N msg="..."` | D | Fallo de ML Kit en un fotograma (rate-limit) |

### Plugin (`QrBridge`)

El plugin no conoce el id de sesión; se correlaciona por orden temporal con `QrSdk` (`session.begin` aparece justo después de `sdk.start`).

| Evento | Nivel | Significado |
| --- | --- | --- |
| `call.scanProduct` | I | Llega `scanProduct` desde Dart |
| `call.rejected reason=noActivity\|scanInProgress` | W | Llamada rechazada |
| `sdk.start` | D | Se invoca `QrScanner.startScan` |
| `sdk.start.failed msg="..."` | E | `startScan` lanzó excepción |
| `reply.success productId=7` | I | Respuesta exitosa a Dart |
| `reply.error code=cancelled` | W | Respuesta de error a Dart |
| `reply.error code=cancelled source=detach` | W | Cancelación por desconexión de actividad/motor |
| `reply.skipped reason=alreadyReplied` | D | Se evitó una segunda respuesta a la misma llamada |
| `call.cancelScan cancelled=true\|false` | D | Resultado de `cancelScan` |
| `lifecycle.configChange pending=..` | D | Actividad desconectada por cambio de configuración |
| `lifecycle.detachedFromActivity pending=..` | D | Actividad desconectada |
| `lifecycle.detachedFromEngine pending=..` | D | Motor Flutter desconectado |

### Traza real (emulador `Medium_Phone_API_37.0`, Android 17)

`adb logcat -d -s QrSdk:V QrBridge:V`. Primer escaneo: permiso **rechazado**. Segundo escaneo: permiso concedido, cámara abierta y **atrás**. Los `session.ignored` muestran que `onStop` y `onDestroy` intentan cancelar una sesión ya terminada y el SDK lo descarta: un solo resultado por sesión.

```
I QrBridge: call.scanProduct
D QrBridge: sdk.start
I QrSdk   : session.begin session=1
D QrSdk   : activity.create session=1 recreated=false
D QrSdk   : session.attach session=1 ok=true
I QrSdk   : permission.request session=1
W QrSdk   : permission.result session=1 granted=false
W QrSdk   : session.complete session=1 result=failure code=permissionDenied
W QrBridge: reply.error code=permissionDenied
D QrSdk   : session.release session=1
D QrSdk   : activity.stop session=1 changingConfig=false awaitingPermission=false
D QrSdk   : session.ignored session=1 reason=alreadyTerminated
D QrSdk   : activity.destroy session=1
D QrSdk   : session.ignored session=1 reason=alreadyTerminated
I QrBridge: call.scanProduct
D QrBridge: sdk.start
I QrSdk   : session.begin session=2
D QrSdk   : activity.create session=2 recreated=false
D QrSdk   : session.attach session=2 ok=true
I QrSdk   : permission.request session=2
I QrSdk   : permission.result session=2 granted=true
I QrSdk   : camera.bound session=2
D QrSdk   : activity.back session=2
W QrSdk   : session.cancel session=2 source=back
W QrBridge: reply.error code=cancelled
D QrSdk   : session.release session=2
D QrSdk   : camera.unbound session=2
D QrSdk   : activity.stop session=2 changingConfig=false awaitingPermission=false
D QrSdk   : session.ignored session=2 reason=alreadyTerminated
D QrSdk   : activity.destroy session=2
D QrSdk   : session.ignored session=2 reason=alreadyTerminated
```

La lectura de un QR válido (`qr.detected valid=true` → `session.complete result=success` → `reply.success`) queda pendiente de capturar con la cámara de un dispositivo físico.

## Dart

Logger de la app: `app_flutter/lib/core/logging/app_log.dart` (`AppLog.d/i/w/e`). Escribe con `debugPrint` (consola de `flutter run` y Logcat, tag `flutter`) y con `dart:developer` `log` (DevTools, nombre `qr_pedidos.<area>`). Está apagado en release y, por defecto, bajo `flutter test`. El paquete `qr_scanner_bridge` no puede depender de la app, así que tiene su propio logger mínimo interno (`src/bridge_log.dart`) con el mismo formato y el área `scanner`. Además de las áreas de arriba, `app` cubre el arranque.

Las solicitudes HTTP se registran con un decorador (`LoggingClient`) que envuelve al cliente real o simulado en `main.dart`; los clientes REST no cambian. No se registran cuerpos: del POST solo `lines` y `units` (en `queue.order.send`).

| Área | Evento | Nivel | Campos |
| --- | --- | --- | --- |
| `app` | `app.start` | I | `apiMode=real\|fake` |
| `fake` | `fake.mode.active` | I | |
| `fake` | `fake.scenario` | I | `catalog`, `cart`, `latencyMs` |
| `http` | `http.request` | D | `method`, `path` |
| `http` | `http.response` | I (W si no es 2xx) | `method`, `path`, `status`, `ms` |
| `http` | `http.failure` | W | `method`, `path`, `kind=timeout\|noConnection\|connectionLost`, `outcomeUnknown`, `ms` |
| `catalog` | `catalog.refresh.start` / `.ok` | I | `count` en `.ok` |
| `catalog` | `catalog.refresh.fallback` | W | `cached`, `offline`, `reason` |
| `catalog` | `catalog.empty` | W | `offline`, `reason` (sin caché ni red) |
| `lookup` | `lookup.local.hit` | D | `id` |
| `lookup` | `lookup.remote.found` | I | `id` |
| `lookup` | `lookup.notFound` / `.offline` / `.failed` | W | `id` (`reason` en `.failed`) |
| `db` | `db.open` | I | `version`, `path` (solo el archivo) |
| `db` | `db.migrate` | I | `from`, `to` |
| `db` | `db.order.insert` / `.claim` / `.finish` | D | `order`, `lines` / `from`, `ok` / `status` |
| `db` | `db.recover.interrupted` | D (W si `count>0`) | `count` |
| `orders` | `orders.create` | I | `order`, `lines`, `units`, `total` |
| `queue` | `queue.batch.start` | I | `batch`, `candidates` |
| `queue` | `queue.batch.joined` | I | `batch` (doble toque: se une al lote en curso) |
| `queue` | `queue.batch.end` | I | `batch`, `confirmed`, `failed`, `unknown`, `ms` |
| `queue` | `queue.order.send` | I | `order`, `attempt`, `lines`, `units` |
| `queue` | `queue.order.result` | I confirmado, W error/unknown, E inesperado | `order`, `status`, `ref` o `reason`, `httpStatus` |
| `queue` | `queue.order.skip` | W | `order`, `reason=alreadySending\|notClaimable` |
| `queue` | `queue.retry` | W | `order`, `from=unknown` (reintento manual) |
| `scanner` | `scanner.call` / `scanner.result` | I | `productId` en `.result` (puente) |
| `scanner` | `scanner.error` | W | `code` (puente) |
| `scanner` | `scanner.rejected` | W | `reason=scanInProgress` (puente; la pantalla añade `source=ui`) |

### Traza real: catálogo, pedido, envío y timeout

Capturada en el emulador con `--dart-define=API_MODE=fake` (`adb logcat -d -s flutter:V`, sin el prefijo de Logcat). Se guardó un pedido de 2 líneas, se envió, y luego se activó el escenario de timeout en la franja de modo simulado y se envió otro pedido.

```
[qr_pedidos/app] I app.start apiMode=fake
[qr_pedidos/fake] I fake.mode.active
[qr_pedidos/catalog] I catalog.refresh.start
[qr_pedidos/http] D http.request method=GET path=/products?limit=30
[qr_pedidos/http] I http.response method=GET path=/products?limit=30 status=200 ms=1533
[qr_pedidos/db] I db.open version=2 path=qr_pedidos.db
[qr_pedidos/db] D db.recover.interrupted count=0
[qr_pedidos/catalog] I catalog.refresh.ok count=12
[qr_pedidos/db] D db.order.insert order=f9a0c064 lines=2
[qr_pedidos/orders] I orders.create order=f9a0c064 lines=2 units=2 total=59.98
[qr_pedidos/queue] I queue.batch.start batch=1 candidates=1
[qr_pedidos/db] D db.order.claim order=f9a0c064 from=pending,error ok=true
[qr_pedidos/queue] I queue.order.send order=f9a0c064 attempt=1 lines=2 units=2
[qr_pedidos/http] D http.request method=POST path=/carts/add
[qr_pedidos/http] I http.response method=POST path=/carts/add status=201 ms=809
[qr_pedidos/db] D db.order.finish order=f9a0c064 status=confirmed
[qr_pedidos/queue] I queue.order.result order=f9a0c064 status=confirmed ref=51
[qr_pedidos/queue] I queue.batch.end batch=1 confirmed=1 failed=0 unknown=0 ms=1290
[qr_pedidos/fake] I fake.scenario catalog=none cart=timeout latencyMs=800
[qr_pedidos/db] D db.order.insert order=823f6316 lines=1
[qr_pedidos/orders] I orders.create order=823f6316 lines=1 units=1 total=49.99
[qr_pedidos/queue] I queue.batch.start batch=2 candidates=1
[qr_pedidos/db] D db.order.claim order=823f6316 from=pending,error ok=true
[qr_pedidos/queue] I queue.order.send order=823f6316 attempt=1 lines=1 units=1
[qr_pedidos/http] D http.request method=POST path=/carts/add
[qr_pedidos/http] W http.failure method=POST path=/carts/add kind=timeout outcomeUnknown=true ms=10008
[qr_pedidos/db] D db.order.finish order=823f6316 status=unknown
[qr_pedidos/queue] W queue.order.result order=823f6316 status=unknown reason="El servidor no respondió a tiempo."
[qr_pedidos/queue] I queue.batch.end batch=2 confirmed=0 failed=0 unknown=1 ms=10075
```

### Doble toque en Enviar pendientes

En la app el botón se deshabilita mientras hay un lote activo, así que el segundo toque casi nunca llega al repositorio; la barrera está en `OrderRepository.sendPending`. Este es el log real de la prueba `app_log_test.dart` (dos llamadas seguidas), donde la segunda se une al lote 1 y no hay un segundo `queue.batch.start` ni un segundo POST:

```
[qr_pedidos/queue] I queue.batch.joined batch=1
[qr_pedidos/queue] I queue.batch.start batch=1 candidates=1
[qr_pedidos/queue] I queue.order.send order=a6a87f24 attempt=1 lines=1 units=2
[qr_pedidos/queue] I queue.order.result order=a6a87f24 status=confirmed ref=51
[qr_pedidos/queue] I queue.batch.end batch=1 confirmed=1 failed=0 unknown=0 ms=12
```

`joined` aparece antes de `start` porque el lote ya está registrado pero aún espera la lectura de candidatos en la base.
