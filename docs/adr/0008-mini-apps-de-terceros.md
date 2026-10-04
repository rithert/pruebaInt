# ADR-0008: Mini apps de terceros con WebView aislado, bridge versionado y tokens delegados

- **Estado:** Aceptada
- **Fecha:** 2026-10-04

## Problema a resolver

El ecosistema debe integrar **servicios propios o de terceros** (por ejemplo, un simulador de un aliado o un marketplace) que:

- se despliegan y evolucionan **sin publicar la app**;
- los desarrollan **otros equipos**, con su propio stack;
- no deben poder **leer la sesión del cliente** ni ejecutar operaciones sensibles.

## Alternativas evaluadas

| Alternativa | A favor | En contra |
|---|---|---|
| Módulo Flutter dentro del monorepo | Experiencia 100 % nativa | No es de terceros; cada cambio exige publicar la app |
| WebView pasando la sesión del cliente | Simple | Un tercero obtendría acceso total a la cuenta |
| **WebView aislado + bridge versionado + token delegado** | Despliegue independiente, alcance mínimo, revocable con un flag | Hay que mantener el contrato del bridge; la UX web es menos nativa |

## Opción seleccionada

- **Hosting propio de la mini app** en otro origen (`mini_apps/`, puerto 3100), con CSP que solo permite conectar con el BFF y protección contra *path traversal*.
- **`MiniAppPage`:**
  - Solo carga mini apps del catálogo y **solo navega dentro de su origen**.
  - Valida cada mensaje con `parseBridgeMessage`: un `sealed class` con versión, tipo y payload tipado. Lo inválido se descarta y se reporta.
  - Entrega los datos con `jsonEncode`, que impide la inyección de JS.
- **Token delegado** (`POST /v1/mini-apps/:id/token`):
  - Es un JWT de 5 minutos con audience `mini-app:<id>` y scope `credit:quote`.
  - No sirve como sesión, ni la sesión sirve en `/v1/mini-api`.
  - Al expirar, la mini app pide uno nuevo por el bridge (`get_token`).
- **Las operaciones sensibles las ejecuta la app:** la mini app solo propone `request_credit`. La app muestra una **confirmación nativa** y crea la solicitud con la sesión del cliente (`POST /v1/credit/applications`).
- **Kill switch:** el flag `miniApps` oculta la acción en el home, rechaza la emisión de tokens y bloquea la cotización.
- **CORS** limitado a `MINI_APP_ORIGINS`.

## Trade-offs

- El protocolo del bridge es un contrato público: cambiarlo exige versionarlo (`v`) y mantener compatibilidad.
- Una mini app en WebView es menos fluida y menos accesible que la UI nativa; se mitiga con el tema heredado del anfitrión, controles de 48 dp y `aria-live`.
- La confirmación nativa agrega un paso, a propósito: es la frontera de confianza.

## Impacto a largo plazo

- Es la base de un **marketplace de servicios**: agregar un aliado consiste en registrarlo en el catálogo con sus scopes, más su origen en CORS y en la app.
- Los scopes permiten auditar y revocar por aliado.
- El catálogo de la app podría servirse desde el BFF para incorporar aliados sin publicar.
