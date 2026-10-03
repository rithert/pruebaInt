import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { createDeps } from './container.js';

const config = loadConfig();
const deps = createDeps(config);
const app = await buildApp(deps);

deps.activityEngine.start(config.activityIntervalMs);

// Apagado ordenado: deja de aceptar tráfico, detiene jobs y cierra la BD.
const shutdown = async (signal: string) => {
  app.log.info({ signal }, 'apagando servidor');
  deps.activityEngine.stop();
  await app.close();
  deps.db.close();
  process.exit(0);
};
process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));

try {
  await app.listen({ port: config.port, host: config.host });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
