# Guía de colaboración

## Trunk Based Development

- `main` es el único tronco y **siempre debe estar desplegable**.
- Se integra a `main` al menos una vez al día. Si se usa rama, debe vivir **menos de un día** (`feat/<tema-corto>`) y se integra con un PR pequeño.
- El trabajo incompleto entra a `main` **oculto tras un feature flag**, no en ramas largas.
- No se integra nada con el CI en rojo. Si `main` se rompe, arreglarlo (o revertir) es la prioridad.
- Los releases se marcan con tags (`v0.1.0`, …) sobre `main`. Solo se crearía una rama `release/x.y` para aplicar un hotfix a una versión ya publicada.

## Convención de commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/):

```
<tipo>(<alcance>): <descripción en imperativo>
```

| Tipo | Uso |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de un bug |
| `test` | Solo pruebas |
| `docs` | Solo documentación (ADRs, README…) |
| `refactor` | Cambio interno sin cambio de comportamiento |
| `ci` / `build` | Pipelines, dependencias, tooling |
| `chore` | Mantenimiento menor |

Alcances habituales: `app`, `core`, `design-system`, `auth`, `accounts`, `home`, `sdui`, `mini-apps`, `notifications`, `bff`, `docs`.

Ejemplos: `feat(accounts): mostrar saldo en caché cuando no hay red`, `test(bff): cubrir refresh de tokens expirados`.

## Definition of Done de cada cambio

- [ ] Estados de UI cubiertos: cargando, vacío, error, sin conexión y datos en caché.
- [ ] Tests unitarios y/o de widgets que acompañan el cambio; CI en verde.
- [ ] Accesibilidad: `Semantics` en elementos clave, soporte de escalado de texto y áreas táctiles de 48dp como mínimo.
- [ ] Telemetría de eventos y errores relevantes, **sin datos personales** en los logs.
- [ ] ADR en `docs/adr/` si hubo una decisión de arquitectura.
- [ ] Entrada en `docs/ai-usage.md` si se usó IA de forma relevante.

## Comandos útiles

```bash
flutter pub get                     # resuelve todo el workspace
melos run analyze          # análisis estático
melos run format:check     # formato
melos run test             # tests de todos los paquetes
(cd backend && npm test)            # tests del BFF
(cd backend && npm run format)      # formatea el BFF con Prettier (el CI lo verifica)
```
