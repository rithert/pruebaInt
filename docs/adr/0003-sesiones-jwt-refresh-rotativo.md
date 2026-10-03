# ADR-0003: Sesiones con JWT de vida corta y refresh token rotativo

- **Estado:** Aceptada
- **Fecha:** 2026-10-03

## Problema a resolver

Una app financiera necesita sesiones largas (el cliente no quiere iniciar sesión a cada rato), pero un token robado no puede servir indefinidamente. Además, la app debe distinguir "sesión expirada, renuévala" de "sesión inválida, vuelve al login".

## Alternativas evaluadas

| Alternativa | A favor | En contra |
|---|---|---|
| JWT de vida larga sin refresh | Muy simple | Un token filtrado sirve hasta que expira; no se puede revocar |
| Token opaco de sesión validado en BD | Revocación inmediata, simple | Una consulta a BD en cada request; no escala igual de bien entre servicios |
| **JWT corto (15 min) + refresh opaco rotativo con detección de reuso** | Validación sin estado en cada request; revocación efectiva en ≤15 min; detecta robo de refresh tokens | Más piezas: tabla de refresh tokens, lógica de rotación y renovación *single-flight* en el cliente |

## Opción seleccionada

JWT HS256 de 15 minutos (librería `jose`) + refresh token opaco de 256 bits, guardado **hasheado** (SHA-256) en BD y agrupado por *familia*:

1. Cada `/auth/refresh` invalida el token usado y emite uno nuevo de la misma familia.
2. Si llega un refresh **ya rotado**, se asume robo: se revoca la familia entera y todos los dispositivos de esa sesión vuelven al login.
3. Los errores tienen códigos estables: `token_expired` → la app refresca; `invalid_token` / `refresh_token_reused` → la app cierra la sesión.

Complementos de seguridad:

- Contraseñas con scrypt y comparación en tiempo constante.
- Respuesta idéntica para correo inexistente y contraseña errónea, para evitar la enumeración de usuarios.
- Rate limit de 10 intentos por minuto en `/auth/*`.

## Trade-offs

- El cliente **debe serializar el refresh** (*single-flight*). Si dos peticiones paralelas refrescan con el mismo token, la segunda dispararía la detección de reuso y cerraría la sesión. Esto condiciona el diseño del interceptor HTTP en Flutter (F2).
- Un access token comprometido sigue siendo válido hasta 15 minutos.
- HS256 usa un secreto compartido. Si otros servicios tuvieran que validar tokens, convendría RS256/EdDSA con JWKS.

## Impacto a largo plazo

- Se puede migrar a un proveedor de identidad (OIDC) manteniendo el mismo contrato con la app: access + refresh con los mismos códigos de error.
- La tabla de familias habilita funciones de producto como "dispositivos con sesión activa" y "cerrar sesión en todos los dispositivos".
