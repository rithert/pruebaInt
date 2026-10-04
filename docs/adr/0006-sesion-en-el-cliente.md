# ADR-0006: Sesión en el cliente: SessionCubit, redirect declarativo y bloqueo biométrico

- **Estado:** Aceptada
- **Fecha:** 2026-10-03

## Problema a resolver

La sesión puede cambiar desde muchos lugares:

- login o registro exitoso;
- logout;
- expiración detectada por la capa de red al fallar el refresh;
- arranque de la app con una sesión guardada.

Si cada pantalla navega por su cuenta, aparecen inconsistencias: pantallas privadas visibles sin sesión, o usuarios expulsados a medio flujo. Además, una app financiera no debe abrirse sin confirmar la identidad de quien tiene el teléfono.

## Alternativas evaluadas

| Alternativa | A favor | En contra |
|---|---|---|
| Splash que decide y navega de forma imperativa | Simple | Cada pantalla debe manejar la expiración; la lógica de acceso queda dispersa |
| **`SessionCubit` global + `redirect` de GoRouter** | Una sola fuente de verdad; el router reacciona a cualquier cambio de sesión desde cualquier pantalla | Hay que exponer el estado como `Listenable` y mantener la regla de redirección |
| Guardas por ruta (middleware por pantalla) | Control fino | Se duplica la lógica y es fácil olvidar una ruta |

Para la biometría se evaluó: ninguna, PIN propio, o **`local_auth`** con *fallback* a contraseña (esta última fue la elegida).

## Opción seleccionada

- **`SessionCubit`** con los estados `unknown → unauthenticated | locked | authenticated`. Es la única pieza que decide el acceso. Escucha `SessionEvents.onExpired` (publicado por el `AuthInterceptor`) para expulsar al usuario cuando el BFF rechaza la renovación.
- **`sessionRedirect(status, location)`** es una función pura con tests de todas las combinaciones. GoRouter la reevalúa en cada cambio del cubit (`refreshListenable`).
- **Bloqueo biométrico:** con una sesión guardada y biometría disponible, la app arranca en `locked`. La huella desbloquea; "Ingresar con mi contraseña" descarta la sesión local y lleva al login.
- **Logout:** revoca en el BFF como mejor esfuerzo, y siempre borra los tokens y **toda la caché**, para no dejar datos financieros del cliente anterior.

## Trade-offs

- El bloqueo solo ocurre al arrancar la app en frío. Bloquear también al volver del segundo plano tras N minutos queda como evolución: requiere `AppLifecycleListener` y un umbral configurable.
- La biometría usa `biometricOnly: true`. Un dispositivo sin huella registrada entra directo con su sesión guardada, una decisión de UX que se podría endurecer pidiendo un PIN.
- El shell conoce `SessionCubit`: auth es un módulo de plataforma, no un dominio de negocio más.

## Impacto a largo plazo

- Nuevas reglas de acceso (por ejemplo, rutas que exigen *step-up* biométrico antes de transferir) se agregan en un solo lugar.
- La telemetría registra `session_started`, `session_expired` y `biometric_unlock` sin datos personales: permite medir cuántas sesiones expiran de forma inesperada, un indicador temprano de problemas con el refresh en producción.
