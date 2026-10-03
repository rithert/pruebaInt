# ADR-0005: Resiliencia en el cliente: errores tipados, cadena de interceptores y stale-while-revalidate

- **Estado:** Aceptada
- **Fecha:** 2026-10-03

## Problema a resolver

La app debe seguir siendo útil con conectividad limitada, alta latencia o caída parcial de servicios, y debe **demostrarlo**. Eso exige decidir:

1. cómo viajan los errores entre capas sin que la UI olvide casos;
2. dónde vive la lógica de reintentos, protección de servicios y renovación de sesión;
3. qué se muestra cuando no hay red.

## Alternativas evaluadas

| Tema | Alternativas | Elegida |
|---|---|---|
| Errores | Excepciones tipadas · `Either` (fpdart) · **`Result` sellado propio** | `Result` + `AppFailure` `sealed`: el `switch` exhaustivo de Dart 3 obliga a manejar cada falla, sin dependencias ni curva funcional |
| Resiliencia | En cada repositorio · paquetes (`dio_smart_retry`) · **interceptores propios en cadena** | Interceptores: un solo lugar, transparente para los módulos y testeable con un adaptador falso |
| Caché offline | Hive CE · sqflite sin ORM · **Drift** | Drift: SQL tipado, migraciones y transacciones (la base para el outbox de operaciones) |
| DI | RepositoryProvider · get_it + injectable · **get_it** | get_it: cada módulo registra lo suyo sin que el shell lo conozca; sin codegen extra |

## Opción seleccionada

**Cadena de interceptores (el orden importa):**

```
CorrelationId → Telemetry → Auth (refresh single-flight) → CircuitBreaker → Retry
```

- **CorrelationId:** un id por petición que se conserva en los reintentos, para cruzar con los logs del BFF.
- **Auth:** ante `token_expired` hace un único refresh aunque fallen N peticiones en paralelo (lo exige la rotación de ADR-0003). Si el refresh falla **por red**, no cierra la sesión.
- **CircuitBreaker:** por servicio. Con 5 fallas consecutivas (5xx o timeout) se abre 30 s y rechaza localmente; luego deja pasar una petición de prueba (*half-open*). La falta de red y los 4xx **no** cuentan como falla del servicio.
- **Retry:** solo errores transitorios (timeouts, sin conexión, 502/503/504) y solo peticiones idempotentes (GET/PUT/DELETE o POST con `Idempotency-Key`). Usa backoff exponencial con *full jitter* y respeta `Retry-After`.

**Stale-while-revalidate (`CachedFetcher`):** emite primero la caché (al instante y también sin red) y después la respuesta del servidor. Si el servidor falla, conserva la caché y adjunta la falla. La UI combina los dos estados: "datos de hace X min" más un aviso, en lugar de una pantalla de error.

## Trade-offs

- Más piezas que un `try/catch` por pantalla, pero cada una es pequeña y tiene sus tests: 37 en el core.
- La caché guarda datos financieros en SQLite **sin cifrar** dentro del sandbox de la app. Mitigación: se borra al cerrar sesión. En producción se usaría SQLCipher (`sqlcipher_flutter_libs`).
- El circuit breaker vive en memoria por proceso: se reinicia al reabrir la app, y es aceptable.

## Impacto a largo plazo

- Un dominio nuevo hereda toda la resiliencia con solo usar `ApiClient` y `CachedFetcher`.
- Los umbrales (`RetryPolicy`, umbral del circuito) se pueden mover a configuración remota para ajustarlos sin publicar la app.
- Señal para revisar la decisión: si aparecen operaciones que deban funcionar 100 % offline (por ejemplo, transferencias programadas), se agrega un *outbox* persistente en Drift con la misma idempotencia del BFF.
