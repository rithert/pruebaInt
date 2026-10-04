// Servidor estático de las mini apps: simula el hosting de un tercero o de
// otro equipo, en un origen distinto al BFF y a la app (puerto 3100).
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('.', import.meta.url)));
const port = Number(process.env.PORT ?? 3100);
const apiOrigin = process.env.API_ORIGIN ?? 'http://localhost:3000';

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
};

// Solo se publican estas carpetas; nada más del disco es accesible.
const apps = { '/credit-simulator/': 'credit_simulator' };

createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', `http://localhost:${port}`);
  const prefix = Object.keys(apps).find((p) => url.pathname.startsWith(p));
  if (!prefix) return send(res, 404, 'No encontrado');

  const relative = url.pathname.slice(prefix.length) || 'index.html';
  const base = join(root, apps[prefix]);
  const file = normalize(join(base, relative));
  if (!file.startsWith(base)) return send(res, 403, 'Prohibido'); // path traversal

  try {
    const body = await readFile(file);
    res.writeHead(200, {
      'content-type': types[extname(file)] ?? 'application/octet-stream',
      // La mini app solo puede hablar con el BFF; sin scripts de terceros.
      'content-security-policy': `default-src 'self'; connect-src ${apiOrigin}; style-src 'self'; img-src 'self' data:`,
      'x-content-type-options': 'nosniff',
      'cache-control': 'no-cache',
    });
    res.end(body);
  } catch {
    send(res, 404, 'No encontrado');
  }
}).listen(port, () => {
  console.log(`Mini apps en http://localhost:${port}/credit-simulator/ (API: ${apiOrigin})`);
});

function send(res, status, text) {
  res.writeHead(status, { 'content-type': 'text/plain; charset=utf-8' });
  res.end(text);
}
