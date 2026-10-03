# Uso de herramientas de IA en el desarrollo

## Enfoque: el desarrollador dirige, la IA ejecuta

Usé la IA como **par de programación con roles definidos**:

| Responsabilidad | Desarrollador | IA |
|---|---|---|
| Alcance, prioridades y plazos | ✅ decide | Propone opciones |
| Decisiones de arquitectura (ADRs) | ✅ elige entre alternativas | Presenta alternativas y trade-offs |
| Código de piezas críticas | ✅ escribe o reescribe | Revisa y sugiere |
| Boilerplate, configuración, scaffolding | Revisa | ✅ genera |
| Tests | Define los casos críticos | ✅ amplía la cobertura |
| Documentación | Valida el contenido | ✅ redacta borradores |
| Control de versiones (commits, historial TBD) | ✅ exclusivo | Sin acceso de escritura a git |

## Herramientas

| Herramienta | Uso |
|---|---|
| Claude Code (Claude Opus 5.5) en VS Code | Planificación, scaffolding, implementación asistida, tests y documentación |

## Bitácora de decisiones y delegación

Cada fila registra **qué decidí, qué delegué y dónde intervine**. Las correcciones y los rechazos se anotan tal como ocurrieron.

| Fecha | Fase | Objetivo / decisión (desarrollador) | Delegado a la IA | Intervención del desarrollador | Verificación |
|---|---|---|---|---|---|
| 2026-10-03 | Análisis | Fijé el plazo (2,5 días) y elegí: BFF en Node + TS (entre Firebase, Dart y Node), solo Android, Bloc/Cubit | Desglose del enunciado en requisitos explícitos e implícitos; borrador del plan MoSCoW | Definí el stack y el alcance; acoté las plataformas según los dispositivos disponibles | — |
| 2026-10-03 | Proceso | Los commits los hago yo, para controlar el historial TBD y la autoría | — | Le quité a la IA el permiso de escritura sobre git | — |
| 2026-10-03 | F0 Fundaciones | Monorepo modular (ADR-0001) y BFF (ADR-0002) | Scaffolding del workspace, lints, CI, esqueleto del BFF, borradores de ADRs | Revisión de la estructura y commits manuales | `dart analyze` sin issues; 5 tests Flutter + 3 del BFF en verde. Al ejecutar se detectó que los scripts de melos requerían instalación global; se corrigió antes de integrar |
| 2026-10-03 | F1 Backend | Elegí entre 3 alternativas en cada punto: sesiones JWT + refresh rotativo, segmento por onboarding + comportamiento, datos con generador + motor de actividad (ADR-0003, ADR-0004) | Implementación de auth, cuentas, transferencias idempotentes, generador y motor; 45 tests | Me reservé el middleware de chaos: la IA solo dejó el contrato y los tests como especificación; implementé `ChaosController`, el hook y las rutas admin. En la revisión, la IA detectó 2 bugs en mi código (un import de `config` desde `process` por autocompletado del IDE, que rompía el arranque, y `z.record` con enum, que en Zod 4 exige todas las claves) y sugirió mejoras (`.strict()`, delegar en el manejador de errores global); se aplicaron a petición mía | Los tests detectaron un bug real (los correos con espacios del autocompletado eran rechazados). La prueba de humo por HTTP detectó que el disparo manual del motor podía no generar movimiento; se corrigió con un test de regresión |
| 2026-10-03 | Tooling | Ante el choque de versiones (Flutter 3.35 vs ecosistema actual), elegí FVM con Flutter 3.47.6 por proyecto entre 3 alternativas, para no romper mi entorno global y dar reproducibilidad al evaluador | Diagnóstico del conflicto de dependencias y configuración de FVM, melos (`sdkPath`) y CI (`flutter-version-file`) | Elegí la estrategia | `analyze` y tests de F0 en verde con el nuevo SDK |
| 2026-10-03 | F2 Core Flutter | Elegí `Result` sellado, Drift, get_it y reservarme el interceptor de retry (ADR-0005) | Result/AppFailure, ApiClient, interceptores de correlation-id, auth single-flight, circuit breaker y telemetría; SWR, caché Drift, shell con DI, router y pantalla de diagnóstico; 37 tests del core + 4 de widgets (incl. guías de accesibilidad) | Me reservé el `RetryInterceptor`: la IA dejó el contrato y 23 tests de especificación; lo implementé (23/23 a la primera). La revisión de la IA encontró un aviso de lint que bloqueaba el CI, un `catch` genérico muerto que habría ocultado el error real y un cálculo de intento duplicado; se aplicaron a petición mía. La revisión también detectó un test de la IA que fallaba (Completer completado con error antes de ser escuchado), y la IA lo corrigió. Avisé que pruebo en teléfono físico: se cambió a `localhost` + `adb reverse` | Al escribir los tests se detectó que un refresh fallido por red cerraba la sesión (corregido con test). Al revisar el manifiesto se detectó que la plantilla de Flutter no declaraba `INTERNET` en release |
| 2026-10-03 | Proceso | Rediseñé esta bitácora y el modo de trabajo: yo elijo el diseño antes de cada fase y escribo piezas clave | — | La primera versión centraba la bitácora en lo que hacía la IA; la reorienté a decisiones y delegación | — |

## Dónde no delegué en la IA

- Elección de alcance y priorización ante el plazo.
- Decisiones de arquitectura: la IA presenta alternativas, yo elijo.
- Commits e historial de versiones.
- Validación manual en el emulador y guion de la demostración.

## Métricas de impacto

> Se completan al cierre de la prueba.

- **Productividad:** _pendiente_
- **Calidad** (defectos detectados por tests o revisión en código generado): _pendiente_
- **Documentación:** _pendiente_
- **Pruebas:** _pendiente_

## Riesgos observados y mitigación

- *Código plausible pero incorrecto:* tests obligatorios y análisis estático estricto (`strict-casts`, `strict-inference`).
- *Dependencias inventadas o desactualizadas:* se verifican las versiones reales al instalar (`npm ls`, `pubspec.lock`).
- *Pérdida de comprensión del código:* cada fase cierra con una explicación del diseño y las piezas críticas las escribo yo.
