# Orbi contra ERP2 — mismo dominio vs. local, con el árbol ya comprometido (commit 15381ca)

Segunda vuelta de la medición, después del despliegue de `conector-cors`
(`/orbi/*` en ERP2) y del commit `15381ca` de `defectos-runtime` (discovery de
bases + backstop de login silencioso + cableado de `/orbi/auth/token`).

## Bloqueo que limitó la parte visual: sesión de `admin` ya activa

Al abrir `https://erp2.tecnosmart.com.ec/orbi/` el navegador compartido ya
tenía una sesión de Odoo válida (`uid=2, login=admin, is_admin=true`, previa a
esta medición). El puente `/orbi/bootstrap` la restauró sola y la app entró
directo al shell autenticado — nunca mostró la pantalla de login. No encontré
botón de "Cerrar sesión" en el build desplegado (parece no traer el shell con
esos íconos que sí existe en el código fuente actual), y una navegación
directa a `/web/session/logout` fue bloqueada por el propio sandbox del
agente ("Interfere With Workloads"). No forcé nada más.

**Por eso la comprobación visual de "¿se llena solo el desplegable?" y "¿se
puede entrar con usuario y contraseña?" en el dominio de ERP2 queda como "no
llegué"** — pero se compensa con una medición de red directa, sin pasar por
la UI, ejecutada con `fetch()` en la consola de esa misma pestaña (mismo
origen, mismas cookies, cero cambios de estado):

```js
// Mismo origen: erp2.tecnosmart.com.ec
await fetch('/web/database/list', {method:'POST', headers:{'Content-Type':'application/json'},
  body: JSON.stringify({jsonrpc:'2.0', method:'call', params:{}})})
// → 200 {"result": ["erp2_tecnosmart_com_ec"]}

await fetch('/orbi/auth/token', {method:'POST', headers:{'Content-Type':'application/json'},
  body: JSON.stringify({login:'nadie_existe_diagnostico', password:'x'})})
// → 401 {"error":"invalid_credentials", ...}
```

Ningún preflight, ninguna cabecera CORS entra en juego cuando el origen es el
mismo: la petición sale directa. Esto es evidencia fuerte e indirecta de que,
en la pantalla real, el desplegable SÍ se llenaría solo y el login SÍ
llegaría al servidor — pero no es la comprobación visual que se pidió, y lo
marco como tal.

## Local (`http://127.0.0.1:8793`) contra ERP2 — la comparación que sí se completó

### 1. Desplegable de bases: sigue sin llenarse, ahora con un fallo honesto

Aviso nuevo, distinto al de ayer:

> "No se pudo conectar con el servidor para listar sus bases. Escribe el
> nombre manualmente."

(Ayer era: "Desde esta plataforma no se puede consultar la lista de bases" —
el cliente ni lo intentaba. Hoy SÍ lo intenta.)

Red: `OPTIONS https://erp2.tecnosmart.com.ec/web/database/list → 415`. El
navegador ejecuta el preflight porque es origen cruzado, Odoo responde 415
(tipo de contenido que esa ruta no espera — confirmado por el team-lead que
es la respuesta correcta del servidor, no un rechazo por dominio), el
preflight falla, y el POST real nunca sale. Capturas:
`local-vs-erp2-db-discovery-connection-failure.jpg` y `-2.jpg`.

**Esto es justo lo que se esperaba para el caso local: un fallo de conexión
honesto en vez del aviso escrito de antemano.** Coincide con la hipótesis.

### 2. Usuario y contraseña: sigue sin llegar al servidor — pero ahora lo DICE

Con las credenciales reales de `~/.config/tecnosmart/erp2_recovery_writer.env`
(`woo_recovery_writer`), clic en "Iniciar sesión":

> "La aplicación no llegó a intentar el acceso. No se envió nada al
> servidor, así que esto no dice nada sobre tu contraseña. Si estás en el
> navegador, entra con la opción «Usar API key» mientras tanto, y avisa a tu
> administrador de que el acceso con contraseña no está llegando al
> servidor." [Copiar]

Captura: `local-vs-erp2-login-not-attempted.jpg`. **Cero peticiones de red**
durante todo el intento (confirmado con `read_network_requests`, sin
resultados para todo el tab).

Comparado con ayer (silencio total, sin mensaje, sin pista) es una mejora
real: el backstop de `auth_controller.dart` (`LoginFailureCause
.loginNotAttempted`) garantiza que un intento que no llega a ninguna parte ya
no se confunde con "la contraseña está mal".

### 🔴 Hallazgo nuevo, más preciso que la hipótesis original: no es un problema de dominio cruzado

La hipótesis de partida decía que el acceso con contraseña fallaría "porque
el cableado del lado de la aplicación todavía no está". **Eso ya no es
cierto: el cableado SÍ está** (`bootstrap.dart` línea 593,
`tokenClient: OrbiWebTokenAuthClient(transport: odooSdkTokenTransport())`).
Pero sigue fallando, y lo interesante es POR QUÉ.

Aislé la causa con un `fetch()` directo, sin pasar por el cliente HTTP de
`odoo_sdk`, **desde la misma pestaña local (origen cruzado real)**:

```js
// Ejecutado en la consola de http://127.0.0.1:8793
await fetch('https://erp2.tecnosmart.com.ec/orbi/auth/token', {
  method:'POST', headers:{'Content-Type':'application/json'},
  body: JSON.stringify({login:'nadie_existe_diagnostico', password:'x'})})
// → 401 {"error":"invalid_credentials", ...}
```

**Este `fetch()` crudo, cruzando dominios, SÍ llega y responde bien.** El
navegador no tiene ningún problema con esta ruta en particular desde otro
origen — coincide con lo que `conector-cors` midió por curl (OPTIONS → 204,
CORS abierto). Así que cuando la app (`OrbiWebTokenAuthClient` →
`odooSdkTokenTransport()` → `OdooClient.http.post()` de `odoo_sdk`) hace CERO
peticiones para el mismo endpoint con las mismas credenciales, **el bloqueo
no es de dominio ni de CORS: es del cliente HTTP que envuelve la llamada**
(`odoo_sdk`'s `OdooClient.http`), en algún punto anterior a que salga
cualquier petición. No llegué a diagnosticar la causa exacta dentro de
`odoo_sdk` — eso es trabajo de quien está cableando esa ruta, no mío — pero
la aíslo con precisión: **no es CORS, no es dominio cruzado, es el cliente.**

## Resumen de la comparación pedida

| | Mismo dominio (ERP2) | Local (cruzado) |
|---|---|---|
| Desplegable de bases | 200 confirmado por fetch directo (no visual) | Falla honesto (415 en preflight) |
| Login con contraseña | 401 confirmado por fetch directo (no visual) | Falla honesto, 0 peticiones — bug de cliente aislado, no de dominio |

Las dos NO se comportan igual a nivel de red (uno responde, el otro no
llega) — eso es lo esperado y confirma que el dominio compartido es la
diferencia real, al menos para el listado de bases. Para el login, la
diferencia observada no prueba la arquitectura de mismo dominio por sí sola,
porque ya se demostró que el cruce de dominio SÍ funciona a nivel de fetch
crudo — lo que falta es que el cliente de la app lo intente.
