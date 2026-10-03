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
packages/core/           Red y resiliencia, almacenamiento, observabilidad, flags
packages/design_system/  Tokens, tema y componentes accesibles
backend/                 BFF (Fastify + TypeScript + SQLite)
docs/                    Arquitectura, ADRs, operación, uso de IA
```

## Requisitos

| Herramienta | Versión |
|---|---|
| Flutter | 3.35.x (Dart 3.9) |
| Node.js | 24.x |
| Android SDK + emulador | API 33 o superior |

## Puesta en marcha

```bash
# 1. Dependencias de Flutter (todo el workspace de una vez) y runner de scripts
flutter pub get
dart pub global activate melos   # agrega %LOCALAPPDATA%\Pub\Cache\bin al PATH

# 2. Backend
cd backend
npm install
npm run dev          # http://localhost:3000/health

# 3. App (en otra terminal, con el emulador abierto)
cd apps/super_app
flutter run          # usa http://10.0.2.2:3000 por defecto
```

Para apuntar la app a otro backend: `flutter run --dart-define=API_BASE_URL=https://mi-bff.example.com`.

## Pruebas

```bash
melos run test     # unitarias y de widgets de todos los paquetes
melos run analyze  # análisis estático
cd backend && npm test      # tests del BFF
```

## Documentación

- [Guía de colaboración y Trunk Based Development](CONTRIBUTING.md)
- [Decisiones de arquitectura (ADRs)](docs/adr/)
- [Uso de IA durante el desarrollo](docs/ai-usage.md)
- Arquitectura y diagramas _(pendiente)_
- Despliegue y operación _(pendiente)_
- Resiliencia y escenarios degradados _(pendiente)_
