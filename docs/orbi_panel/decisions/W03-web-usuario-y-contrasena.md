# W03 — Orbi web desde un dominio propio, contra un Odoo en otro dominio

Estado: **vía elegida por el dueño el 12-sep-2026** («no entiendo para qué hay que bajar la
aplicación, debe ser como cualquier web y no necesariamente en el mismo dominio que Odoo»).
Este documento diseña ESE camino. Sustituye a `W01-web-auth.md` y corrige la sección 3 de
`W02-web-clave-api-pegada.md`.

> **Me equivoqué en la versión anterior de este documento** y conviene decirlo primero.
> Concluí que sólo funciona bajo el mismo dominio porque medí el CORS con una respuesta
> **401**, y nginx no añade cabeceras a los errores salvo que se lo pidas con `always`. Con
> una clave válida, la respuesta **200 sí las trae**. La conclusión anterior era falsa.

## La respuesta a la pregunta que decide

**SÍ. El camino sin cookies —credencial en cada petición— funciona hoy desde cualquier
dominio contra ERP2, sin cambiar nada en el servidor.** Medido, no supuesto (sección 1).

El dueño tenía razón en el fondo y el razonamiento del encargo es exacto: **las tres barreras
que encontré eran barreras de cookies**. El bearer no usa cookies, así que sólo le aplica la
primera —la política de origen cruzado— y ésa ya está resuelta en ERP2.

| | Mismo dominio | **Dominio propio** |
|---|---|---|
| Llamadas de trabajo (bearer) | Sí | **Sí, hoy, sin tocar nada** |
| Entrar con usuario y contraseña | Sí | **Sí, con un endpoint nuevo en el conector** (sección 3) |
| Safari / iPhone | Sí | **Sí** — sin cookies no hay bloqueo de terceros |
| Recargar sin volver a escribir la contraseña | Sí | Sí, con la salvedad de la sección 4 |

## 1. Lo que respondió ERP2 (12-sep-2026)

Seis preguntas al servidor, todas de lectura. Producción (`newerp`) no se tocó.

| # | Petición | Resultado |
|---|---|---|
| A | `OPTIONS /json/2/res.users/read` con `Origin` ajeno | **204** con `access-control-allow-origin: *` y `allow-headers` que **incluye `Authorization` y `X-Odoo-Database`** |
| B | `POST /json/2/res.users/read` con **clave válida** y `Origin` ajeno | **200 con `access-control-allow-origin: *`** ← la prueba que faltaba |
| C | El mismo POST con clave inválida | 401 **sin** cabeceras CORS |
| D | `GET /web/health` con `Origin` | 200 **sin** cabeceras CORS |
| E | `OPTIONS /web/webclient/translations` (ruta del core con `cors='*'`) | 204 con CORS |
| F | `OPTIONS /web/session/authenticate` | **415 de Odoo**, sin una sola cabecera CORS |

**La medición B, literal, porque es la que zanja el asunto** (la clave va por `source` desde
`~/.config/tecnosmart/erp2_api.env` y no se imprime en ninguna parte):

```
$ set -a; . ~/.config/tecnosmart/erp2_api.env; set +a
$ curl -sS -D - -X POST "$ERP2_URL/json/2/res.users/read" \
    -H 'Origin: https://orbi.ejemplo.com' \
    -H "Authorization: Bearer $ERP2_API_KEY" \
    -H 'Content-Type: application/json' \
    -H "X-Odoo-Database: $ERP2_DB" \
    -d '{"ids":[2],"fields":["login","name"]}'
HTTP/2 200
server: nginx
date: Sat, 12 Sep 2026 03:31:58 GMT
content-type: application/json; charset=utf-8
content-length: 54
access-control-allow-origin: *
access-control-allow-methods: POST, OPTIONS
x-content-type-options: nosniff
x-powered-by: EasyEngine v4.12.0

[{"id": 2, "login": "admin", "name": "Administrator"}]
```

**Lectura de esto, en orden de importancia:**

1. **B es la prueba decisiva y sale a favor.** Un navegador pasa el preflight (A) y **puede
   leer la respuesta real** (B). El camino de la clave funciona desde cualquier dominio.
2. **C es un defecto real que hay que arreglar, aunque no bloquee.** nginx sólo añade
   cabeceras a respuestas 4xx si la directiva lleva `always`. Sin eso, el navegador **oculta
   el cuerpo del error** y la aplicación ve un fallo de red genérico en vez de «clave
   inválida». Y eso tiene consecuencia en nuestro código: `isOfflineFallbackEligible`
   (`theos_pos/.../offline_session_attempt_guard.dart:7-10`) trata un error de conexión como
   caída de red, así que **una clave equivocada metería al usuario en modo offline en vez de
   decirle que la clave está mal**.
3. **F confirma que el camino de la cookie está muerto entre dominios** — y da igual, porque
   el diseño de la sección 3 no usa cookies.
4. **D avisa de que esto es configuración de un servidor concreto, no una ley de Odoo.** El
   core no declara `cors=` en `/json/2` (`addons/rpc/controllers/json2.py:47-55`;
   `odoo/http/dispatcher.py:128-142` sólo emite cabeceras si ese parámetro existe). En ERP2
   lo pone el nginx de EasyEngine. **En un Odoo de cliente sin esa línea no hay nada**, y por
   eso la sección 2 existe.

## 2. Qué hay que configurar, exactamente y dónde

Dos vías. La primera es la que ya funciona en ERP2; la segunda es la portátil.

### Vía 1 — nginx delante del Odoo (la que ERP2 ya tiene, a la que le falta un remate)

En el `location` que sirve `/json/2` (y el que sirva las rutas del conector):

```nginx
add_header Access-Control-Allow-Origin  "https://app.tudominio.com" always;
add_header Access-Control-Allow-Methods "POST, OPTIONS"             always;
add_header Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization, X-Odoo-Database" always;
add_header Access-Control-Max-Age       "86400"                      always;
if ($request_method = OPTIONS) { return 204; }
```

Tres precisiones que no son cosméticas:

- **`always` en todas.** Es lo único que le falta a ERP2 y es lo que provoca el punto 2 de
  arriba: sin `always`, los errores llegan al navegador sin CORS y se leen como caída de red.
- **`X-Odoo-Database` tiene que estar en la lista.** El kit la manda siempre en modo bearer
  (`odoo_sdk/.../odoo_http_client.dart:304-313`). ERP2 ya la permite; un servidor nuevo no.
- **Nombrar el origen en vez de `*` es más estricto y aquí no cuesta nada**, porque sin
  cookies no hace falta `Allow-Credentials`. `*` también funciona.

### Vía 2 — en el conector de Odoo, sin tocar el servidor web

El CORS de Odoo se emite en `Dispatcher.pre_dispatch` (`odoo/http/dispatcher.py:118-142`),
que es la clase **base**: vale para cualquier `type`, incluido `json2`. Así que el conector
puede publicar sus propias rutas con `cors='*'` y quedan servidas sin tocar nginx.

⚠️ **Pero con un límite que hay que conocer antes de elegir esta vía:** cuando el CORS lo
pone Odoo, la lista de cabeceras permitidas es **fija** (`dispatcher.py:140-141`):
`Origin, X-Requested-With, Content-Type, Accept, Authorization, Range`. **No incluye
`X-Odoo-Database`.** Consecuencias:

- Para el endpoint de acceso de la sección 3 da igual: la base viaja en el cuerpo.
- Para las llamadas de trabajo hay dos salidas: (a) **dejar de mandar `X-Odoo-Database`** —
  la base se resuelve por host, que es como funciona hoy `/orbi/bootstrap`— o (b) que el
  conector publique su propia ruta de RPC con `cors='*'` y `auth='bearer'`, envolviendo el
  mismo despacho que `/json/2`. La opción (a) es un cambio de una línea en el cliente y es
  la que recomiendo para instalaciones de una sola base por dominio.
- La ruta `/json/2` del core **no** se puede «poner a CORS» sin parchear el core. No se hace.

**Recomendación:** vía 1 donde haya control del nginx (ERP2 ya está), vía 2 como respaldo
portátil para clientes donde sólo se pueda instalar el addon.

## 3. Entrar con usuario y contraseña, sin cookies

El arranque de hoy (`odoo_sdk/.../native_auth_bootstrap_io.dart`) encadena cuatro llamadas y
**se apoya en la cookie de sesión** para las tres últimas: la captura a mano de la respuesta
(`:203-213`) y la reinyecta como cabecera `Cookie` (`:177`). Un navegador prohíbe las dos
cosas, y además `/web/session/authenticate` no tiene CORS (medición F). Ese camino no se
arregla: **se sustituye por un único endpoint en el conector**.

### Lo que hay que construir

Una ruta en `l10n_ec_collection_box_pos/controllers/web_auth.py`, junto a las que ya sirven
`/orbi` (`:29-43`) y `/orbi/bootstrap` (`:59-60`):

```
POST /orbi/auth/token      type='json2'  auth='none'  cors='*'  save_session=False
cuerpo:    {"db": ..., "login": ..., "password": ...}
respuesta: {"api_key": ..., "uid": ..., "login": ..., "expires_at": ...}
```

Los siete cuidados, y por qué cada uno evita un agujero concreto:

1. **Autenticar con el camino del core, no con uno propio.** `env['res.users'].authenticate(
   credential, wsgienv)` (`odoo/addons/base/models/res_users.py:776`). Pasa por `_login`
   (`:752-773`), que ya envuelve el intento en `_assert_can_auth` — el **antifuerza bruta**
   por IP del core (`:1233-1260`, `base.login_cooldown_after` 5 intentos,
   `base.login_cooldown_duration` 60 s). Escribir la comprobación a mano perdería eso.
2. **Rechazar si la cuenta tiene segundo factor.** `auth_info.get('mfa')` y `user._mfa_url()`
   (el helper del core lo usa así en `odoo/http/session.py:213-250`). **Éste es el agujero
   grave y el único que de verdad me preocupa:** un endpoint que convierte contraseña en
   clave de larga vida **sin mirar el MFA es un bypass de MFA**. Si el usuario tiene
   segundo factor, se devuelve un error explícito y no se emite clave.
3. **Sólo usuarios internos.** Replicar `check_access_make_key`
   (`res_users.py`, `ResUsersApikeysDescription.check_access_make_key`): «Only internal users
   can create API keys». Un portal no debe poder fabricarse una clave de RPC.
4. **Emitir con la API privada, con caducidad acotada.**
   `env['res.users.apikeys'].sudo()._generate('rpc', nombre, fecha_caducidad)`
   (`res_users.py:1553-1580`). Nunca sin fecha: una clave perpetua en un navegador es
   exactamente lo que no queremos. El guardián `_ensure_can_manage_keys_programmatically`
   protege la API *pública* `generate` (`:1617`), no la privada, así que no hace falta
   habilitar ningún parámetro de sistema.
5. **Nunca aceptar un `uid` del cliente.** La identidad sale de `authenticate`, punto.
6. **HTTPS obligatorio y contraseña sólo en el cuerpo**, jamás en la URL ni en un log.
   Devolver la clave una sola vez y no volver a exponerla.
7. **`save_session=False`** para que la llamada no fabrique cookie, y `type='json2'`/
   `jsonrpc` para que el control CSRF no aplique — vive sólo en `HttpDispatcher.dispatch`
   (`dispatcher.py:177,197-204`), es decir, sólo en rutas `type='http'`.

**Por qué esto no abre un agujero nuevo:** el endpoint no concede nada que el usuario no
pudiera obtener ya escribiendo su contraseña en `/web/login` y creando la clave desde el
menú de Odoo. Hereda el antifuerza bruta del core, respeta el segundo factor, no acepta
identidad del cliente y emite una credencial **caducable y revocable** desde la ficha del
usuario. Que `cors` sea `*` no debilita nada: sin cookies, el origen no autoriza nada por sí
mismo; lo que autoriza es la contraseña.

## 4. La credencial entre recargas

En este escenario **no hay cookie de Odoo que recuerde la sesión**, así que la paridad con el
escritorio depende de qué se guarde en el navegador. No hay caja fuerte del sistema; las
opciones son tres y hay que elegir con los ojos abiertos:

| Postura | Sobrevive a un F5 | Riesgo |
|---|---|---|
| Memoria — lo que hace hoy `theos_pos` (`platform_credential_store_web.dart:5-8`) | **No** | Ninguno, pero se reescribe la contraseña en cada recarga |
| **Clave acotada en IndexedDB/`localStorage`** | Sí | La lee cualquier script de **nuestro** dominio |
| Clave en memoria + PIN para reabrir | Parcial | No resuelve el cierre de pestaña |

**Recomiendo la segunda, y es defendible precisamente por el punto 4 de la sección 3:** lo
que se guarda no es la contraseña ni una clave perpetua, sino **una clave de alcance `rpc`
con caducidad corta**, emitida para ese dispositivo y revocable desde Odoo. El riesgo real
se reduce a un XSS en **nuestro propio dominio**, que es un dominio que sólo sirve esta
aplicación —a diferencia del dominio de Odoo, donde convive con todo el backend. Es decir:
el dominio propio no sólo es lo que pidió el dueño, **también aísla mejor este secreto**.

**La frase para el dueño:** *en el escritorio la llave se guarda en la caja fuerte del
sistema; en el navegador no hay caja fuerte, así que guardamos una llave de repuesto que
caduca sola y se puede anular desde Odoo cuando quieras — no la contraseña.*

Lo que se pierde frente al escritorio: cuando esa clave caduque habrá que volver a escribir
la contraseña. Los datos en IndexedDB no se pierden.

## 5. Plan

**Esta semana, sin depender de nadie:**

1. `odoo_sdk/lib/src/auth/native_auth_bootstrap_web.dart` — hoy es un muro (`:14-16` lanza
   `unsupportedPlatform`). Implementarlo como **una sola llamada** a `/orbi/auth/token`;
   nada de la coreografía de cookies de `_io`. Mantener de `_io` la exigencia de HTTPS
   (`:84-92`) y la comprobación de que la identidad devuelta coincide con el usuario escrito.
2. `theos_panel/lib/app/bootstrap.dart:374-380` — en `kIsWeb` instala hoy
   `_WebSessionAuthService`, cuyo `login()` devuelve siempre `required` (`:177-182`).
   Sustituirlo por `NativeAuthServicePort` con un `CredentialBackend` respaldado por
   `localStorage`/IndexedDB y `CredentialDurability.webSessionOnly` (declarado y sin usar,
   `orbi_runtime/.../credential_store.dart:96`). `NativeAuthService` no importa `dart:io`.
3. Decidir si el cliente sigue mandando `X-Odoo-Database` (sección 2). Si se va por la vía 2,
   dejar de mandarla.
4. Pruebas con `mocktail` sobre el transporte, más una de regresión que verifique que el
   cliente **no** intenta poner la cabecera `Cookie`.
5. Corregir el comentario de `odoo_http_client.dart:305-311`. **No lo toco yo** — ese
   archivo lo está editando otro agente. Texto recomendado, para quien lo aplique:

   ```dart
   // Odoo needs this header to select the database when the host serves more
   // than one. Note it is NOT allowed by JSON-2 itself: the core declares no
   // `cors=` on /json/2, and Odoo's own CORS header list never includes it
   // (odoo/http/dispatcher.py). Cross-origin browser calls therefore depend on
   // the reverse proxy in front of Odoo allowing X-Odoo-Database explicitly,
   // as ERP2's nginx does. On a server without that rule, drop this header and
   // let the database be resolved by host instead.
   ```

**Requiere construir en el servidor (autorización aparte, `newerp` intocable):**

6. El endpoint `/orbi/auth/token` de la sección 3, en el conector.
7. `always` en las directivas CORS del nginx de ERP2, para que los errores lleguen legibles
   (sección 1, punto 2). Sin esto, una clave equivocada se confunde con una caída de red.
8. Publicar el bundle web en el dominio propio. `deploy-web.yml` sirve tal cual para eso:
   cambiar `--base-href /theos_app/` por la ruta del dominio definitivo.

**Recomendación al dueño, que no ejecutamos nosotros:** hasta que los puntos 6 y 7 estén,
lo publicado hoy en GitHub Pages es una aplicación que **nunca ha podido hablar con un
Odoo** — el arranque web es un muro (`native_auth_bootstrap_web.dart:14-16`) y no existe el
endpoint de acceso. Recomiendo retirar o marcar como no funcional ese despliegue, **pero es
decisión suya**: retirar algo publicado no es una llamada que hagamos por nuestra cuenta.

**Orden sugerido:** 7 primero (es una línea y evita diagnósticos falsos), luego 6, luego el
bloque del cliente. Los puntos 1 a 5 se pueden escribir en paralelo contra el contrato.

## 6. Lo que sigue siendo verdad de la otra vía

Servir bajo el dominio del Odoo sigue existiendo y ya está desplegado en
`https://erp2.tecnosmart.com.ec/orbi/` (`reports/V02-prevalidation-2026-09-08.md:13,21-25`,
`web_auth.py:29-43`). Queda como **respaldo**, no como plan: es útil el día que un cliente no
deje tocar ni su nginx ni instalar la ruta de acceso. No es la vía elegida.

---
Medido el 12-sep-2026 contra ERP2 con peticiones de lectura y preflight; ninguna escritura.
Core Odoo 19.5 en `/Users/elmers/Documents/dev_odoo18/odoo` (`odoo/release.py:15`);
`web_auth.py` leído en `dev_odoo20_worktrees/salidas-telegram/addons/l10n_ec_collection_box_pos`,
no en este repositorio. `newerp` no se tocó.
