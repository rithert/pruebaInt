# Uso de herramientas de IA en el desarrollo

## Herramientas

| Herramienta | Uso principal |
|---|---|
| Claude Code (Claude Opus 5.5) en VS Code | Análisis del enunciado, planificación, scaffolding, implementación asistida, tests y documentación |

## Principios de uso

1. **La IA propone y el desarrollador decide.** Las decisiones de arquitectura (ADRs) se discuten y las aprueba el desarrollador antes de implementarlas.
2. **Todo lo generado se verifica** con análisis estático, tests y ejecución real antes de integrarse a `main`.
3. **Los commits los hace el desarrollador** tras revisar el diff. La IA no tiene permiso de escritura sobre git.
4. **Sin secretos ni datos personales** en los prompts.

## Bitácora

| Fecha | Fase | Qué hizo la IA | Qué revisó o corrigió el desarrollador | Impacto |
|---|---|---|---|---|
| 2026-10-03 | Análisis | Desglosó el enunciado en requisitos explícitos e implícitos (backend real, SDUI, chaos testing) y propuso un plan MoSCoW ajustado a 2,5 días | Definió plazo, stack del backend, plataforma (Android) y gestor de estado | Plan priorizado en minutos; se detectó temprano el riesgo de "solo datos simulados" |
| 2026-10-03 | F0 Fundaciones | Generó el monorepo (pub workspaces), lints estrictos, CI con filtros por ruta, BFF base con correlation-id, ADRs 0001-0002 | Revisión de estructura y convenciones | Fundaciones listas con CI en verde desde el primer commit |

## Métricas de impacto

> Se completan al cierre de la prueba.

- **Productividad:** _pendiente_
- **Calidad** (defectos detectados por los tests o la revisión en código generado): _pendiente_
- **Documentación:** _pendiente_
- **Pruebas:** _pendiente_

## Riesgos observados y mitigación

- *Código plausible pero incorrecto:* mitigado con tests y análisis estático estricto (`strict-casts`, `strict-inference`).
- *Dependencias inventadas o desactualizadas:* se verifican las versiones reales al instalar (`npm ls`, `flutter pub get`).
