# Resiliencia: conectividad limitada, alta latencia y caídas parciales

Qué hace la app en cada escenario degradado, con qué mecanismo y **cómo demostrarlo en vivo** desde **Diagnóstico → panel de demo** (solo en builds de desarrollo).

## Mecanismos

| Mecanismo | Dónde | Qué hace |
|---|---|---|
| **Timeouts** | `createHttpClient` | Conexión 5 s, respuesta 10 s: ninguna pantalla queda cargando indefinidamente |
| **Reintentos con backoff + jitter** | `RetryInterceptor` | Solo errores transitorios (timeouts, sin conexión, 502/503/504) y solo peticiones idempotentes (GET/PUT/DELETE o POST con `Idempotency-Key`). Respeta `Retry-After` |
| **Circuit breaker por servicio** | `CircuitBreakerInterceptor` | 5 fallas seguidas → corta 30 s sin tocar la red, luego deja pasar una petición de prueba. La falta de red y los 4xx no cuentan |
| **Stale-while-revalidate** | `CachedFetcher` + Drift | Muestra la caché al instante (también sin red) y la actualiza al responder el servidor |
| **Layout embebido** | `fallbackHomeLayout` | Sin servicio de experiencia y sin caché, el home básico (cuentas + transferir) sigue disponible |
| **Idempotencia** | BFF `transfers` + `TransferCubit` | Reintentar una transferencia nunca mueve el dinero dos veces |
| **Distinguir causas** | `ApiClient` + `ConnectivityMonitor` | "Sin conexión" (el teléfono no tiene red) frente a "servicio no disponible" (red sí, servidor no) |
| **Recuperación automática** | `AccountsCubit`, `HomeCubit` | Al volver la red se actualizan solos; la transferencia invita a reintentar, pero no reintenta sola (dinero) |
| **Aislamiento de componentes** | `SduiView`, `MiniAppPage` | Un componente o una mini app que falla no tumba la pantalla ni la app |
| **Sesión robusta** | `AuthInterceptor` | Refresh *single-flight*; si el refresh falla **por red** no expulsa al usuario |

## Escenarios

| # | Escenario | Comportamiento esperado | Cómo demostrarlo |
|---|---|---|---|
| 1 | **Sin conexión** (modo avión) | Home y saldos visibles desde caché con el banner "Sin conexión · datos de hace X min". Los movimientos muestran la última página guardada. Al quitar el modo avión todo se actualiza solo | Modo avión → navegar por la app → desactivarlo |
| 2 | **Alta latencia** | Skeletons al cargar; si hay caché se ve al instante con un indicador sutil de actualización. Las respuestas llegan tras ~3 s sin bloquear la app | Panel: *Cuentas → Lento (3 s)* → pull-to-refresh en Inicio |
| 3 | **Errores intermitentes** (50 %) | Los reintentos con backoff los absorben de forma casi transparente. En Diagnóstico se ve el circuito "normal" | Panel: *Cuentas → Errores 50 %* → refrescar varias veces |
| 4 | **Caída de cuentas** | Saldos y movimientos desde caché con banner. Tras 5 fallas el circuito pasa a "abierto" (visible en Diagnóstico) y las siguientes peticiones fallan al instante. Al restaurar, se recupera solo | Panel: *Cuentas → Caído* → Inicio → Diagnóstico (circuito) → *Restaurar* |
| 5 | **Caída del servicio de experiencia** | El home usa el último layout guardado; sin caché, el **layout embebido** con aviso "versión básica". Las cuentas siguen funcionando | Panel: *Experiencia → Caído* → pull-to-refresh en Inicio |
| 6 | **Caída de transferencias durante una operación** | Mensaje claro, "Reintentar" seguro con la misma clave de idempotencia. Al volver la red: "Conexión recuperada" | Panel: *Transferencias → Caído* → transferir → restaurar → reintentar |
| 7 | **Caída de la mini app** (otro equipo u origen) | "El simulador no está disponible" con reintentar; el resto de la app intacto | Detener el lanzador *Mini apps* → abrir *Simular crédito* |
| 8 | **Funcionalidad problemática en producción** | Se apaga con un *kill switch* sin publicar la app | Panel: apagar *Promociones*, *Insights* o *Mini apps* → refrescar Inicio |
| 9 | **Sesión expirada** | El access token se renueva solo; si el refresh es rechazado, vuelve al login con "Tu sesión expiró" | Esperar 15 min o reiniciar el BFF con otra `JWT_SECRET` |
| 10 | **Servidor caído por completo** | El home y los saldos se ven desde caché; las acciones muestran "servicio no disponible" y no un error genérico | Detener el BFF |

## Límites conocidos

- Las **operaciones de escritura no se encolan sin red**: la transferencia se reintenta manualmente. La evolución natural es un *outbox* persistente en Drift con la misma idempotencia.
- La **caché** guarda la primera página de movimientos por filtro, no el historial completo.
- El **circuit breaker** vive en memoria y se reinicia al reabrir la app.
