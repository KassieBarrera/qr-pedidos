# Declaración de uso de inteligencia artificial

## 1. Herramientas utilizadas

Utilicé herramientas de inteligencia artificial durante distintas etapas de esta prueba técnica. Su participación fue tanto para consultar decisiones de implementación como para revisar y corregir código.
| Herramienta | Modelo o modalidad | Uso principal |
| --- | --- | --- |
| ChatGPT (OpenAI) | Asistente conversacional; versión exacta no registrada para todas las sesiones | Orientación técnica, ejemplos de implementación, resolución de problemas de compilación, integración Flutter–Kotlin y explicación de conceptos. |
| Claude Code (Anthropic) | Agente principal Opus 5.5 y subagentes Sonnet | Planificación de pendientes, implementación de componentes, revisión de requisitos, corrección de defectos, pruebas y documentación. |

En la etapa con Claude Code se utilizó una organización con agente principal y subagentes especializados. El agente principal definió tareas, revisó entregables y coordinó correcciones.

## 2. Tareas asistidas y componentes afectados

### Etapa inicial: estructura e integración

Con apoyo de ChatGPT trabajé la integración nativa mediante `MethodChannel`y la base inicial del almacenamiento local y el carrito.

Durante esta etapa ejecuté comandos de compilación y depuración, corregí problemas de configuración e integración y comprobé en un dispositivo Android físico que una versión inicial del escáner podía leer `product:1`, cerrar la cámara y devolver el identificador a Flutter. También probé la respuesta ante códigos QR incompatibles.

### Etapa de implementación y revisión con Claude Code

| Área | Asistencia de IA | Componentes principales |
| --- | --- | --- |
| Seguimiento de requisitos | Comparación del avance con el enunciado y registro de pendientes. | `PROGRESO.md` |
| Contrato del escáner | Definición y revisión de la API nativa, códigos de resultado, validaciones y reglas de ciclo de vida. | `docs/CONTRATO_SCANNER.md` |
| Puente Flutter | Plugin local, `MethodChannel`, API Dart y manejo de conexión con actividad y motor Flutter. | `qr_scanner_bridge/`, `app_flutter/lib/main.dart`, `catalog_screen.dart` |
| Pruebas y simulación | Pruebas de repositorios, cliente HTTP simulado, fixtures y escenarios de fallos. | `app_flutter/test/`, `app_flutter/lib/core/network/fake/`, `assets/fixtures/` |
| Interfaz | Correcciones Visuales, correcciones en historial, mensajes y implementacion de Logs | `app_flutter/lib/core/theme/`, `app_flutter/lib/core/widgets/`, `app_flutter/lib/core/logging/app_log.dart` |
| Documentación | README, matriz de pruebas, modo simulado, ejemplos QR y declaración de IA. | `README.md`, `docs/`, `qr/`, `tools/qr_generator/`, `AI_USAGE.md` |

## 3. Solicitudes representativas y objetivos de uso

Los siguientes son **resúmenes fieles de los objetivos de las consultas**, no transcripciones literales ni prompts técnicos que no se hayan realizado:

- **Seguimiento del alcance:** contrastar los requisitos obligatorios del examen con el estado del repositorio, identificar brechas y priorizar funcionalidades comprobables.
- **Coordinación de agentes:** distribuir tareas delimitadas entre subagentes, proporcionarles el contexto del proyecto y exigir al agente principal que revisara los resultados frente al enunciado y solicitara correcciones cuando fueran necesarias.
- **Contrato e integración nativa:** implementar y comprobar el SDK Kotlin y su comunicación con Flutter, contemplando permisos, cancelación, QR inválidos y ciclo de vida.
- **Observabilidad y depuración:** incorporar logs de consola para comprender fallos sin mostrar información técnica innecesaria en la interfaz.
- **Ajustes de experiencia de uso:** incorporar controles de cantidad también en el catálogo, permitir quitar unidades y evitar mostrar una acción de envío cuando no hay pedidos pendientes.
- **Aclaración de alcance:** revisar si el enunciado exigía gestión de stock o inventario antes de ampliar funcionalidades no solicitadas.

En la etapa inicial con ChatGPT también solicité ayuda para resolver errores concretos de compilación y conexión entre el SDK Android y Flutter, además de explicaciones de las decisiones de implementación.

## 4. Decisiones, adaptaciones y correcciones

### Decisiones y verificaciones realizadas por mí

- Organicé el trabajo por prioridades para cubrir primero el flujo obligatorio del examen.
- Ejecuté y depuré la compilación e integración inicial entre Android y Flutter.


- Decidí utilizar subagentes para tareas delimitadas y solicitar una revisión de sus resultados contra el enunciado.
- Solicité registros de diagnóstico para investigar errores.

### Correcciones identificadas o implementadas por agentes de IA

Estas correcciones formaron parte del proceso automatizado de revisión y **no se presentan como modificaciones manuales mías**:

- **SDK:** ajuste del comportamiento ante `onStop` mientras estaba abierto el diálogo de permisos y correcciones de textos visibles.
- **Catálogo:** diferenciación entre fallos de conectividad, errores HTTP y respuestas inválidas, evitando describir todos los casos como ausencia de conexión.
- **Modo simulado:** sustitución de una convención especial en el cuerpo de la respuesta por códigos HTTP explícitos y ampliación de pruebas.
- **Base de datos:** corrección de una condición de carrera al abrir SQLite y ajuste para permitir reintentar una apertura fallida.
- **Interfaz:** corrección de avisos que interferían con botones, jerarquía de títulos, tamaño del ticket y presentación de estados inciertos; ajustes posteriores en controles de cantidad y acciones disponibles.
- **Pruebas y documentación:** corrección de conteos y pruebas afectadas por cambios de UI; sustitución de una traza ilustrativa por evidencia de ejecución.

## 5. Verificación, problemas encontrados y límites

### Verificaciones registradas durante el desarrollo

Según la matriz de pruebas preparada durante la implementación, se reportaron:

- **Pruebas automatizadas:** pruebas Kotlin/JVM, pruebas del puente y pruebas de la aplicación Flutter, sin dependencia de la red externa.
- **Análisis estático:** ejecución de `flutter analyze` sin problemas reportados en esa etapa.
- **Compilación:** generación del AAR del SDK y del APK debug, con configuraciones de API real y simulada.
- **Emulador Android:** revisión visual, escenarios de permiso de cámara y cancelación, envío simulado satisfactorio y timeout, con registros de ejecución.
- **Dispositivo físico:** lectura real de `product:1` y devolución del identificador a Flutter- 

Los resultados automatizados y del emulador fueron ejecutados o recopilados con ayuda de Claude Code.
### Problemas identificados

- Errores iniciales de compilación e integración nativa durante la configuración del proyecto.
- Comportamiento del ciclo de vida al solicitar permisos de cámara.
- Clasificación incorrecta de determinados errores del catálogo.

- Diferencias entre las pruebas de interfaz y los últimos cambios visuales.
- Ajustes de presentación y navegación detectados durante revisiones visuales.


---

**Nota de cierre:** Las herramientas de IA tuvieron un papel relevante en la revisión e integración del código para implementar temas desconocidos; También me sirvió para trabajar con temas que no conocía tanto y encontrar soluciones a los problemas que fueron surgiendo.
