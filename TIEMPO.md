# Registro de tiempo aproximado


> Zona horaria: hora local de la máquina de desarrollo (UTC−6).

## Bloques de trabajo

| # | Fecha | Ventana (evidencia) | Actividad | Evidencia | Horas efectivas |
| --- | --- | --- | --- | --- | ---: |
| 1 | 2026-10-07 | Hasta las 22:33 | Lectura del enunciado, estructura Flutter, catálogo offline (GET + SQLite) | Commit `b7a1944` | ~0.35 |
| 2 | 2026-10-08 | ~21:00 – 22:54 | Estructura del SDK Android (módulo Library, Gradle) | Archivos modificados entre las 21:00 y las 23:00; commit `82c8fd9` (22:54) | ~1.35 |
| 3 | 2026-10-09 | ~08:18 y ~19:00 – 21:59 | `QrScannerActivity` con CameraX + ML Kit, `QrValidator` y su prueba, MethodChannel inicial, escaneo al carrito | Wrapper de Gradle de la app, `QrScannerActivity`, `MethodChannel` | ~2.30 |
| 4 | 2026-10-10 | 14:23 – 19:06 | Control de avance; **punto 1**: pedidos, cola de envío y 3 vistas; **punto 2**: contrato, SDK y puente; **punto 3**: pruebas, modo simulado y matriz | Primeros archivos de la sesión; commit `7e61236`  | ~4.75 |
| 5 | 2026-10-10 | 16:06 – 18:25 | **Punto 4**: interfaz "Mostrador" (2 rondas de revisión con capturas del emulador); logs de diagnóstico; contador en el catálogo y botón de envío | Capturas del emulador; archivos de logs; `quantity_stepper.dart` | ~3.25 |
| 6 | 2026-10-11 | ~00:45 – 01:25 | Consulta sobre el stock de la API; README raíz | `app_flutter/README.md` | ~0.50 |
| 7 | 2026-10-11 | ~11:55 – 12:05 | Ejecutar las pruebas automatizadas tras los últimos cambios de UI | Commit `88edef7`; `qr/**` y `tools/qr_generator/**` | ~0.25 |
| 8 | 2026-10-11 | 12:05 – 13:45 | Revisión y cierre de `AI_USAGE.md`; registro de tiempo | `AI_USAGE.md` | ~0.50 |
| | | | **Total tiempo invertido** | | **13.25** |


## Fuera del alcance de este registro

- El bono iOS no se intentó.
- No se cuenta el tiempo de instalación de herramientas (Flutter, Android Studio, emulador).
