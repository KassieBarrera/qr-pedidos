# QR de prueba

Códigos QR para probar el escaneo de la app (sección 4 del enunciado). Cada QR codifica exactamente el texto indicado, en texto plano y sin salto de línea final. Bajo cada QR aparece el texto codificado.

- Hoja imprimible con los 10 códigos: [`hoja_qr.png`](hoja_qr.png)
- Un PNG por código (660 px, zona silenciosa de 4 módulos): `valid_*`, `invalid_*`, `notfound_*`
- [`manifest.json`](manifest.json): archivo, texto, categoría y resultado esperado de cada código

## Texto codificado y resultado esperado

| Archivo | Texto codificado | Categoría | Resultado esperado en la app |
| --- | --- | --- | --- |
| `valid_product_1.png` | `product:1` | válido | Se agrega el producto 1 al pedido |
| `valid_product_2.png` | `product:2` | válido | Se agrega el producto 2 al pedido |
| `valid_product_3.png` | `product:3` | válido | Se agrega el producto 3 al pedido |
| `invalid_product_0.png` | `product:0` | inválido | "El código no es un QR de producto válido"; no se agrega nada |
| `invalid_product_minus1.png` | `product:-1` | inválido | Igual que el anterior |
| `invalid_product_01_leading_zero.png` | `product:01` | inválido | Igual que el anterior |
| `invalid_PRODUCT_1_uppercase.png` | `PRODUCT:1` | inválido | Igual que el anterior |
| `invalid_product_abc.png` | `product:abc` | inválido | Igual que el anterior |
| `invalid_hola.png` | `hola` | inválido | Igual que el anterior |
| `notfound_product_999999.png` | `product:999999` | válido pero inexistente | Mensaje de producto "no encontrado" con conexión; no se agrega una línea incompleta |

Los IDs 1 a 3 existen en DummyJSON y en los fixtures del modo simulado. El formato válido es `^product:([1-9][0-9]*)$`, el mismo que usa `QrValidator` del SDK.

## Cómo usarlos

Muestra los PNG en otra pantalla (monitor o tablet) o imprime `hoja_qr.png`, y apunta la cámara del dispositivo o emulador al código. La etiqueta VÁLIDO / INVÁLIDO / NO EXISTE de la hoja es solo para quien prueba; la app decide por el contenido.

## Regenerarlos

Requiere solo Dart (paquetes `qr`, `image` y `zxing2`, versiones fijadas en `tools/qr_generator/pubspec.yaml`):

```bash
cd tools/qr_generator && dart pub get
```

```bash
dart run bin/generate.dart --out ../../qr
```

La generación es determinista: la misma entrada produce los mismos archivos byte a byte. Los textos y nombres están definidos en `tools/qr_generator/lib/qr_codes.dart`.

## Verificarlos

Decodifica cada PNG con `zxing2` (decodificador Dart puro) y comprueba que el texto leído sea exactamente el del manifest:

```bash
dart run bin/verify.dart --out ../../qr
```

Salida esperada: diez líneas `OK` y `Resultado: 10/10`. Esto prueba que las imágenes codifican los bytes correctos; la lectura con la cámara real (ML Kit) sigue siendo una prueba manual.

## Recomendación para la demostración

En la hoja los códigos están cerca. Si la cámara ve dos a la vez en el mismo cuadro y uno es válido, el SDK devuelve el válido (decisión documentada en `docs/CONTRATO_SCANNER.md`). Para demostrar un QR **inválido**, muestra su PNG individual a pantalla completa o tapa los vecinos en la hoja impresa.
