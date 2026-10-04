# Super App Financiera

Plataforma financiera digital, sin atención física, construida en **Flutter** sobre un **BFF en Node + TypeScript**. Está diseñada para:

- crecer por **dominios independientes**;
- **personalizar** la experiencia por perfil, contexto y comportamiento;
- incorporar **nuevas experiencias sin publicar una nueva versión** (Server-Driven UI);
- seguir siendo útil ante **conectividad limitada o caídas parciales**.

> 🚧 En construcción. Las secciones marcadas con _(pendiente)_ se completan a medida que avanzan las fases.

## Estructura del monorepo

```
apps/super_app/          Shell: compone los módulos de dominio
packages/core/           Red y resiliencia, caché offline (Drift), sesión, observabilidad, contrato de módulos
packages/design_system/  Tokens, tema y componentes accesibles
packages/features/auth/  Onboarding, login, sesión y desbloqueo biométrico
packages/features/accounts/  Saldos, movimientos y transferencias entre cuentas propias
backend/                 BFF (Fastify + TypeScript + SQLite)
docs/                    Arquitectura, ADRs, operación, uso de IA
```

## Requisitos

| Herramienta | Versión |
|---|---|
| Flutter | 3.47.6 (Dart 3.13), fijada en [`.fvmrc`](.fvmrc) |
| [FVM](https://fvm.app) | 4.x |
| Node.js | 24.x |
| Android SDK + emulador | API 33 o superior |

La versión de Flutter se gestiona con FVM: el proyecto usa la versión fijada sin tocar el Flutter global. El CI lee el mismo `.fvmrc`. Si prefieres no usar FVM, instala Flutter 3.47.6 y omite el prefijo `fvm` en los comandos.

## Puesta en marcha

```bash
# 0. SDK de Flutter del proyecto (agrega %LOCALAPPDATA%\Pub\Cache\bin al PATH)
dart pub global activate fvm
fvm install                      # descarga la versión de .fvmrc

# 1. Dependencias de Flutter (todo el workspace de una vez) y runner de scripts
fvm flutter pub get
dart pub global activate melos

# 2. Backend
cd backend
npm install
npm run dev          # http://localhost:3000/health

# 3. App (en otra terminal, con el teléfono conectado por USB o el emulador abierto)
adb reverse tcp:3000 tcp:3000   # el localhost:3000 del dispositivo apunta al PC
cd apps/super_app
fvm flutter run                 # usa http://localhost:3000 por defecto
```

> `adb reverse` se pierde al desconectar el cable o reiniciar adb: si la app muestra "Sin conexión", vuelve a ejecutarlo. Para un teléfono físico, activa **Opciones de desarrollador → Depuración por USB** y acepta la huella del PC al conectarlo.

### Desde VS Code (recomendado)

En *Run and Debug* (`Ctrl+Shift+D`), elige **"BFF + App"** y presiona **F5**: levanta el BFF en modo watch, ejecuta `adb reverse` y lanza la app en el dispositivo conectado. También hay lanzadores individuales: *App (dev)*, *App (profile)* y *BFF*.

Para apuntar la app a otro backend: `fvm flutter run --dart-define=API_BASE_URL=https://mi-bff.example.com`.

## Pruebas

```bash
melos run test     # unitarias y de widgets de todos los paquetes
melos run analyze  # análisis estático
cd backend && npm test      # tests del BFF
```

## API del BFF

Todas las respuestas de error usan el formato `{ error: { code, message, correlationId } }`.

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST | `/v1/auth/register` | — | Onboarding: crea el cliente, sus productos e historial |
| POST | `/v1/auth/login` | — | Inicia sesión |
| POST | `/v1/auth/refresh` | — | Rota el refresh token y emite una sesión nueva |
| POST | `/v1/auth/logout` | — | Revoca la sesión |
| GET | `/v1/me` | Bearer | Perfil y segmento del cliente |
| GET | `/v1/accounts` | Bearer | Cuentas, saldos y totales |
| GET | `/v1/accounts/:id/transactions` | Bearer | Movimientos paginados por cursor (`limit`, `cursor`, `category`) |
| GET | `/v1/transactions/:id` | Bearer | Detalle de un movimiento |
| POST | `/v1/transfers` | Bearer + `Idempotency-Key` | Transferencia entre cuentas propias |
| POST | `/admin/activity/tick` | `x-admin-key` | Fuerza un movimiento (demo de push) |
| GET/PUT/DELETE | `/admin/chaos` | `x-admin-key` | Inyección de latencia, errores y caídas por servicio |

La configuración del backend está en [backend/.env.example](backend/.env.example).

## Documentación

- [Guía de colaboración y Trunk Based Development](CONTRIBUTING.md)
- [Decisiones de arquitectura (ADRs)](docs/adr/)
- [Uso de IA durante el desarrollo](docs/ai-usage.md)
- Arquitectura y diagramas _(pendiente)_
- Despliegue y operación _(pendiente)_
- Resiliencia y escenarios degradados _(pendiente)_
