# ADR-0009: Notificaciones push con FCM, opcionales por entorno

- **Estado:** Aceptada
- **Fecha:** 2026-10-04

## Problema a resolver

El cliente debe enterarse de los movimientos de su cuenta en tiempo real, aunque la app esté cerrada. Además, el repositorio debe poder **clonarse y ejecutarse sin credenciales** (un evaluador o un equipo nuevo) y no puede exponer secretos.

## Alternativas evaluadas

| Alternativa | A favor | En contra |
|---|---|---|
| Polling desde la app | Sin dependencias | No funciona con la app cerrada y gasta batería y datos |
| WebSocket / SSE | Tiempo real con la app abierta | Igual que el polling cuando la app está cerrada |
| **Firebase Cloud Messaging** | Es el estándar de Android, entrega con la app cerrada, gratuito | Dependencia de Google; requiere configuración por entorno |

## Opción seleccionada

**BFF**

- Tabla `device_tokens`. `POST /v1/devices` hace un *upsert*: si otro cliente inicia sesión en el mismo teléfono, el token pasa a él.
- `DELETE /v1/devices/:token` da de baja el dispositivo.
- Un listener de `transaction.created` construye el mensaje con monto es-EC y un deep link `route: /transactions/<id>`, y lo envía con `firebase-admin`.
- Los tokens que FCM marca como inválidos se borran.
- Sin credenciales, `LogPushSender` solo deja el envío en el log.
- Solo se notifica la actividad externa, no las transferencias que el propio cliente hizo.

**App**

- **Firebase es opcional:**
  - `google-services.json` **no se versiona**.
  - El plugin de Gradle solo se aplica si ese archivo existe.
  - Si `Firebase.initializeApp()` falla, se usa `DisabledPushService` y la telemetría de consola.
- **`PushCoordinator`** (en el shell) conecta las notificaciones con la sesión y la navegación:
  - registra el dispositivo al autenticarse;
  - lo da de baja **antes** de borrar las credenciales (`SessionCubit.addBeforeEndHook`);
  - con la app abierta, muestra el aviso dentro de la app con un botón "Ver";
  - al tocar la notificación abre el detalle. Si la app está bloqueada, la ruta espera al desbloqueo.
- **Deep links:** solo se aceptan rutas internas (`routeFromData`).

## Trade-offs

- Si la sesión **expira** sin un logout explícito, la baja del dispositivo falla porque ya no hay sesión. El teléfono sigue recibiendo push hasta que otro cliente inicie sesión en él o FCM invalide el token.
- No hay canales de notificación personalizados: crearlos requeriría `flutter_local_notifications` y *desugaring*; se usa el canal por defecto de FCM.
- Los push se envían en el mismo proceso que el BFF. A gran escala irían a una cola (Pub/Sub) con reintentos.

## Impacto a largo plazo

- `PushSender` es un puerto: se puede cambiar FCM por otro proveedor, o agregar APNs para iOS, sin tocar el dominio.
- La telemetría `push_permission` y `push_opened` mide la tasa de aceptación del permiso y la de apertura de notificaciones (en Firebase Analytics).
