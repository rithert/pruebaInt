# ADR-0004: Datos dinámicos con generador por segmento y motor de actividad

- **Estado:** Aceptada
- **Fecha:** 2026-10-03

## Problema a resolver

No hay un core bancario real disponible y el enunciado penaliza las soluciones con datos simulados o estáticos. Los datos deben ser **reales en el sentido operativo**: persistidos, consistentes (saldos que cuadran), distintos por cliente, y deben cambiar en el tiempo para que las notificaciones y la personalización tengan sentido.

## Alternativas evaluadas

| Alternativa | A favor | En contra |
|---|---|---|
| Seed fijo de usuarios demo | Lo más rápido | Es exactamente lo que el enunciado valora mal; datos idénticos para todos |
| Integrar un sandbox de open banking | Datos de un tercero real | Registro y aprobación lentos; fuera del plazo; dependencia externa en la demo |
| **Generador por segmento + motor de actividad + transferencias reales** | Cada registro crea productos e historial propios; los saldos se calculan, no se escriben; hay actividad continua | Hay que mantener el generador; los datos no son de un banco real |

## Opción seleccionada

- **PortfolioGenerator:** al registrarse, crea las cuentas según el segmento (ahorrador: bolsillo de metas; inversionista: inversión; emprendedor: cuenta negocio) y 90 días de historial coherente con sus hábitos. Los movimientos se aplican en orden cronológico y el saldo es siempre la suma de los movimientos. Nunca queda negativo.
- **ActivityEngine:** un job periódico (`ACTIVITY_INTERVAL_MS`) genera compras y transferencias recibidas y emite `transaction.created`. Ese evento alimenta las notificaciones push (F7) y la personalización (F5). `POST /admin/activity/tick` lo fuerza durante la demo.
- **Transferencias entre cuentas propias:** operación real iniciada por el cliente, atómica e **idempotente** (`Idempotency-Key`).

## Trade-offs

- El "core bancario" vive dentro del BFF. En producción sería un servicio externo, y el BFF solo lo orquestaría.
- `setInterval` en proceso no sirve con varias réplicas, porque se duplicaría la actividad. Es suficiente para una instancia.

## Impacto a largo plazo

- Los repositorios aíslan el acceso a datos: reemplazar el generador por un adaptador al core real no cambia las rutas ni el contrato con la app.
- Los eventos de dominio (`DomainEvents`) son el punto de extensión natural hacia un bus de mensajes (Pub/Sub, Kafka) cuando haya varios servicios.
