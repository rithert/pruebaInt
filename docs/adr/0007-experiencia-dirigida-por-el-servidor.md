# ADR-0007: Experiencia personalizada dirigida por el servidor (SDUI + motor de reglas)

- **Estado:** Aceptada
- **Fecha:** 2026-10-04

## Problema a resolver

El enunciado pide tres cosas:

1. adaptar la experiencia al **contexto, perfil, comportamiento o preferencias**;
2. **incorporar experiencias o contenidos sin publicar una nueva versión** de la app;
3. como bonus, **experiencias generadas dinámicamente**.

Si el home se arma en código Flutter, cada cambio de contenido u orden exige pasar de nuevo por la tienda.

## Alternativas evaluadas

| Tema | Alternativas | Elegida |
|---|---|---|
| Contrato UI | Solo feature flags · Remote Flutter Widgets (`rfw`) · **JSON propio + catálogo** | Catálogo cerrado de componentes nativos: el servidor decide qué, cuándo y en qué orden, pero nunca puede inyectar UI arbitraria. Más seguro que `rfw` y fácil de auditar |
| Decisión | Layout fijo por segmento · Reglas + LLM · **Reglas + insights calculados** | Determinista, testeable y explicable; cada regla es una función pura con su test |
| Comportamiento | Ninguno · **Eventos de uso (`tapped`, `dismissed`)** | Lo descartado no vuelve en 7 días; las acciones rápidas se ordenan por uso real |

## Opción seleccionada

**BFF**

- `GET /v1/experience/home` responde `{ schemaVersion, layoutId, components: [{ id, type, version, props }] }`.
- `collectSignals` lee los datos reales del cliente: segmento, saldo, gasto por categoría del mes contra el mes anterior, ingresos y ventas de 7 días, descartes y toques.
- `buildHomeLayout(signals, flags)` es una **función pura** con reglas priorizadas: saldo bajo, aumento de gasto, tendencia de ventas, ingreso recibido y progreso de la meta.
- `POST /v1/events` recibe eventos por lotes.
- `PUT /admin/flags` funciona como *kill switch* en caliente: insights, promociones y mini apps.

**App**

- **Paquete `sdui`** (motor genérico):
  - `SduiParser` es defensivo: un `schemaVersion` futuro invalida el layout completo, pero un componente desconocido, mal formado, duplicado o de una versión no soportada se **omite sin romper el resto**.
  - `SduiRegistry` recibe los componentes que aporta cada dominio, con `SduiContributor`.
  - `SduiView` aísla cada componente: si uno falla, se reporta a telemetría y los demás siguen.
- **Paquete `home`:**
  - Usa stale-while-revalidate del layout.
  - Tiene un **layout embebido de respaldo** (saludo + cuentas + transferir), de modo que el cliente siempre ve sus cuentas aunque falle la personalización.
  - Los descartes son optimistas.
  - `EventTracker` envía eventos por lotes con una cola acotada.
- **Navegación:** las acciones del servidor solo aceptan rutas internas (`/...`); las URLs externas se ignoran.

## Trade-offs

- **Un componente nuevo requiere publicar la app una vez** para agregarlo al catálogo. Una vez publicado, cuándo, a quién y en qué orden mostrarlo se decide desde el servidor. Es el equilibrio deliberado entre flexibilidad y seguridad.
- **Las reglas viven en código del BFF**, así que cambiarlas exige desplegar el BFF, no la app. La evolución natural es moverlas a un motor configurable o a un servicio de decisiones.
- **Los flags viven en memoria:** se reinician con el proceso. En producción irían en una base de datos o en un servicio de configuración remota.

## Impacto a largo plazo

- **Cada equipo de dominio aporta componentes** al catálogo sin tocar el home: es el camino hacia micro-frontends dentro de una sola app.
- **La telemetría `sdui_components_skipped`** detecta cuando el servidor envía componentes que una versión vieja de la app no conoce. Sirve para decidir cuándo es seguro usar un componente nuevo.
- **Las reglas son el punto de extensión** para recomendaciones con ML o LLM: se puede agregar un generador de insights con IA detrás del mismo contrato, con fallback a las reglas.
