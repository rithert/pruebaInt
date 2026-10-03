# ADR-0001: Monorepo modular con Dart pub workspaces

- **Estado:** Aceptada
- **Fecha:** 2026-10-03

## Problema a resolver

La plataforma debe evolucionar hacia **múltiples dominios funcionales administrados por equipos independientes** (onboarding, cuentas, personalización, mini apps, notificaciones…). Esos equipos deben poder trabajar sin pisarse, pero la app se entrega como un único binario y tiene que ser consistente.

## Alternativas evaluadas

| Alternativa | A favor | En contra |
|---|---|---|
| **App única con carpetas `lib/features/*`** | Arranque más rápido, cero configuración | Las fronteras entre dominios no se imponen: cualquier feature puede importar internals de otra. No escala a varios equipos |
| **Multi-repo** (un repo y paquete versionado por dominio) | Autonomía máxima, ownership claro | Coordinar versiones es costoso, los cambios transversales son lentos y hace falta un registro privado de paquetes |
| **Monorepo con paquetes locales + pub workspaces** | Fronteras explícitas (cada dominio es un paquete con API pública), una sola resolución de dependencias, cambios atómicos entre paquetes, CI selectivo | Requiere disciplina en las dependencias entre paquetes y algo de tooling (melos) |
| Monorepo con `melos bootstrap` clásico (sin workspaces) | Probado en la industria | Duplica `pubspec.lock` y `.dart_tool` por paquete; más lento y propenso a versiones inconsistentes |

## Opción seleccionada

**Monorepo con Dart pub workspaces** (nativo desde Dart 3.6), con melos solo como ejecutor de scripts. Estructura:

- `apps/super_app`: *shell* que compone los módulos.
- `packages/core`, `packages/design_system`: capacidades transversales.
- `packages/features/*`: un paquete por dominio, que expone solo su API pública (`lib/<paquete>.dart`) y oculta `lib/src`.
- `backend/`: BFF en Node + TypeScript.

Reglas de dependencia: `feature → core/design_system`, **nunca** `feature → feature`. La comunicación entre dominios pasa por contratos de `core` (rutas, eventos) y la orquesta el shell.

## Trade-offs

- Todos los dominios comparten versión de Flutter y de dependencias. Es bueno para la consistencia, pero obliga a coordinar las actualizaciones mayores.
- La autonomía de los equipos es lógica (por paquete y CODEOWNERS), no física (por repo).

## Impacto a largo plazo

- Un dominio se puede extraer a su propio repo o paquete versionado sin reescribirlo, porque ya tiene una API pública aislada.
- El CI puede ejecutar solo los paquetes afectados (`melos --diff`), así que el tiempo de pipeline no crece linealmente con el número de equipos.
- Señal para revisar la decisión: cuando haya más de 5 equipos con cadencias de release distintas, o cuando un dominio necesite publicarse fuera de la app.
