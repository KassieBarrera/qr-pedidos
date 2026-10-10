# Modo simulado del servicio REST

## Para qué existe

El servicio externo (`https://dummyjson.com`) puede no estar disponible, y la
demostración manual exige mostrar envío simulado, doble toque y fallos de forma
reproducible. El modo simulado reemplaza **solo el transporte HTTP** por un
`http.BaseClient` falso (`FakeDummyJsonClient`, en
`lib/core/network/fake/`). `ProductApi` y `OrderApi` (el cliente REST real) no
cambian: el parsing, la validación y la clasificación de errores
(`guardedRequest`, timeout de 10 s) son exactamente los mismos.

## Cómo activarlo

Por defecto la app usa el servicio real (`API_MODE=real`).

```bash
flutter run --dart-define=API_MODE=fake
flutter build apk --debug --dart-define=API_MODE=fake
```

Cuando está activo, una franja persistente sobre la barra de navegación muestra
"Modo simulado · datos de prueba locales". Al tocarla se abre el panel
**Escenario de prueba**, con un interruptor "Sin conexión" y selectores de fallo
para catálogo y envío de pedidos. En modo real nada de esto se muestra.

El APK de entrega se compila **sin** `--dart-define` y por tanto usa el modo real.

## Endpoints simulados

| Endpoint | Comportamiento |
|---|---|
| `GET /products?limit=30` | `assets/fixtures/products.json` (12 productos, IDs 1 a 12) |
| `GET /products/{id}` | Producto del fixture; cualquier otro ID (p. ej. `999999`) devuelve 404 `{"message":"Product with id '999999' not found"}` |
| `POST /carts/add` | HTTP 201 con `assets/fixtures/cart_add_response.json` (`id`: 51) |

Latencia por defecto: 800 ms, para que se aprecien el estado "Enviando" y el doble toque.

## Escenarios de fallo

Catálogo (`GET /products` y `GET /products/{id}`):

| Escenario | Excepción / respuesta | Resultado en la app |
|---|---|---|
| Sin fallo | 200 con fixture | Catálogo cargado |
| Sin conexión | `SocketException('Failed host lookup: dummyjson.com')` | Error de red; se usa la caché local si existe |
| HTTP 500 | Respuesta 500 | Error de servidor; caché local si existe |
| JSON inválido | 200 con `<html>not json</html>` | Error de formato; caché local si existe |

Envío de pedido (`POST /carts/add`):

| Escenario | Excepción / respuesta | Estado esperado del pedido |
|---|---|---|
| Sin fallo | 201 con `id` numérico | Confirmado simulado |
| Sin conexión | `SocketException('Failed host lookup: dummyjson.com')` tras la latencia | Error (no se envió; reintentable) |
| HTTP 500 | Respuesta 500 | Error |
| HTTP 400 | Respuesta 400 | Error |
| JSON inválido | 200 con `<html>not json</html>` | Error |
| Timeout | No responde nunca; actúa el timeout real de 10 s | Resultado desconocido |
| Conexión cortada tras enviar | `http.ClientException('Connection reset by peer')` tras la latencia | Resultado desconocido |

El interruptor "Sin conexión" es un atajo que pone catálogo y envío en
"Sin conexión".

## Limitaciones

- El escenario vive solo en memoria: se restablece al cerrar la app (intencional).
- Los fixtures no incluyen imágenes.
