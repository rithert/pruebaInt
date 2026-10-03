# ADR-0002: Backend for Frontend (BFF) en Node + TypeScript

- **Estado:** Aceptada
- **Fecha:** 2026-10-03

## Problema a resolver

La solución debe interactuar con **servicios reales y procesar datos de forma dinámica**: las respuestas estáticas o simuladas en la app no son aceptables. Además necesitamos capacidades que solo puede dar un servidor:

- autenticación con tokens;
- persistencia de cuentas y movimientos;
- composición de la experiencia personalizada (SDUI);
- envío de notificaciones push;
- inyección controlada de fallos para demostrar resiliencia.

## Alternativas evaluadas

| Alternativa | A favor | En contra |
|---|---|---|
| **Solo Firebase** (Auth, Firestore, Functions) | Muy rápido de montar, push integrado | Lock-in; difícil controlar latencia y fallos para la demo; la lógica de SDUI y personalización queda dispersa en reglas y Functions |
| **BFF en Dart (shelf)** | Un solo lenguaje y modelos compartibles con la app | Ecosistema de servidor menor; sin SDK oficial de Firebase Admin, así que FCM habría que implementarlo a mano |
| **BFF en Node + TypeScript (Fastify)** | Ecosistema maduro, `firebase-admin` oficial, tipado estricto, Fastify es rápido y fácil de testear con `inject()` | Dos lenguajes en el repo; los contratos se duplican entre TS y Dart |

## Opción seleccionada

**BFF en Node 24 + TypeScript + Fastify**, con persistencia en SQLite mediante `node:sqlite` (nativo en Node 24, sin dependencias que compilar). El BFF agrega y adapta los datos para la app móvil: es el único punto de entrada del cliente.

## Trade-offs

- Los contratos de la API se mantienen en dos lenguajes. Lo mitigamos con DTOs validados en el servidor y tests de contrato en ambos lados.
- SQLite no escala horizontalmente. Es suficiente para la prueba y la capa de repositorios permite cambiar a Postgres sin tocar las rutas.

## Impacto a largo plazo

- El BFF es el lugar natural para orquestar los servicios de dominio que en producción pertenecerían a otros equipos (core bancario, KYC, motor de ofertas). La app no conoce esa complejidad.
- Evolución prevista: definir el contrato en OpenAPI y generar el cliente Dart; migrar a Postgres; separar el BFF por canal (móvil / web) si sus necesidades divergen.
