# W02 — La web sí puede conectar: corrección a W01

Estado: **para decidir**. Corrige una afirmación falsa de `W01-web-auth.md`.

## La respuesta corta

| Pregunta | Hoy |
|---|---|
| ¿Puede la app web conectarse a un Odoo? | **Sí, pegando una clave API.** Es el camino de `theos_pos` |
| ¿Puede la web *fabricar* la clave desde una contraseña? | No, y está bien que no |
| ¿Puede Orbi hacerlo hoy? | **No.** El interruptor existe, pero en web no hay servicio detrás |
| ¿Alguien lo probó de verdad contra un Odoo desde el navegador? | **No hay ninguna evidencia** de eso en el repo |

W01 dice «el build web ya compila… este pendiente es de identidad». Eso es cierto.
Lo que no es cierto es leerlo como «web no puede conectar»: sí puede, por la clave
pegada, y la app vieja lo hace explícitamente.

## 1. Cómo entra `theos_pos` desde el navegador

- `theos_pos/.../screens/login_screen.dart:56-58` — en `kIsWeb` el modo arranca en
  `LoginCredentialMode.apiKey`, no en contraseña.
- `login_screen.dart:258` y `:346` — pasa `nativePasswordLoginAvailable: !kIsWeb`, y
  `widgets/login_form.dart:174-190` sólo dibuja el enlace «Usar usuario y contraseña»
  cuando ese flag es verdadero. **En web no hay forma de llegar al modo contraseña.**
- `login_screen.dart:735-737` — la clave pegada se usa tal cual como bearer.
  `:744-757` — el bootstrap `authenticateAndCreateApiKey` sólo corre en modo contraseña,
  o sea nunca en web.
- `login_screen.dart:1025-1028` — el propio mensaje de error lo dice al usuario:
  «En Web usa una clave API desde Opciones avanzadas.»
- La base de datos no se pide: viaja en el servidor guardado, y `server_service.dart:236-243`
  siembra por defecto `erp2.tecnosmart.com.ec` / `erp2_tecnosmart_com_ec`.

Diferencia con nativo: nativo pide usuario y contraseña **una vez**, fabrica la clave y la
guarda en el llavero del sistema. Web pide la clave ya hecha y no guarda nada.

## 2. Dónde guarda la credencial el navegador: **en ningún lado**

No es una concesión: es lo contrario, y está mejor pensado de lo que W01 supone.

- `core/security/platform_credential_store.dart:3-5` — importación condicional; web resuelve
  a `platform_credential_store_web.dart`, que devuelve `EphemeralCredentialStore`
  (`platform_credential_store_web.dart:5-8`, `isPlatformCredentialStoreDurable = false`).
- `core/security/ephemeral_credential_store.dart:3-8` — mapa en memoria. El comentario es
  literal: «Creating a new instance, such as after a web page refresh, starts with no
  credentials.»
- `server_service.dart:72-79` — `ServerConfig.toJson()` **omite `apiKey` a propósito**. A
  `SharedPreferences` (localStorage en web) sólo van nombre, URL, base, login y partner.
- `core/security/development_credentials.dart:21` — la clave de desarrollo inyectada se
  anula en web (`if (!isDebugMode || isWeb) return ''`).

**Consecuencia real, que sí es una deuda no declarada:** en web la clave vive sólo en la RAM
de la pestaña. Cada recarga (F5, cierre de pestaña, reinicio del equipo) obliga a **volver a
pegar la clave**. No hay reanudación de sesión ni arranque offline en web, aunque la base
IndexedDB sí persista. Eso no está escrito en ninguna parte.

Veredicto: el almacenamiento es aceptable —es el más conservador posible—, pero la
experiencia que produce no está documentada y nadie decidió que fuera así.

## 3. Origen cruzado: **sin resolver, y encima mal documentado**

> 🔴 **Actualizado el 12-sep-2026 — medido contra ERP2, y el resultado es el CONTRARIO
> de lo que dice esta sección.** Con una clave válida, `POST /json/2` desde otro
> dominio devuelve **200 con `access-control-allow-origin: *`**: la clave pegada SÍ
> funciona hoy desde cualquier dominio. Mi primera medición usó un 401, y nginx no
> añade cabeceras a los errores sin `always`. Lo que sigue, sobre el core, es cierto;
> la conclusión práctica no. La evidencia está en `W03-web-usuario-y-contrasena.md`,
> sección 1. Lee W03 antes que esto.

Esto es lo que de verdad puede tumbar el camino, y no es lo que W01 argumenta.

Lo comprobado en código:

- `odoo_sdk/.../odoo_http_client.dart:304-313` — en modo bearer manda `Authorization: Bearer`
  y `X-Odoo-Database`. El comentario afirma: «JSON-2 CORS explicitly allows X-Odoo-Database».
- **Esa afirmación es falsa contra el core 19.5** (`/Users/elmers/Documents/dev_odoo18/odoo`,
  `odoo/release.py:15`):
  - `addons/rpc/controllers/json2.py:47-55` — la ruta `/json/2/<model>/<method>` **no declara
    `cors=`**.
  - `odoo/http/dispatcher.py:128-142` — las cabeceras `Access-Control-Allow-*` se emiten
    **sólo si** `routing.get('cors')` tiene valor. Sin él, Odoo no responde el preflight.
  - Y aun con `cors` puesto, la lista de `Access-Control-Allow-Headers` (`:140-141`) es
    `Origin, X-Requested-With, Content-Type, Accept, Authorization, Range` — **no incluye
    `X-Odoo-Database`**. El comentario del SDK está doblemente equivocado.
- El despliegue web publica en GitHub Pages con `--base-href /theos_app/`
  (`.github/workflows/deploy-web.yml:46-49`): origen `github.io`, **siempre** cruzado
  respecto a cualquier Odoo.
- El CSP de la página **no** es el problema: `theos_pos/web/index.html:22` permite
  `connect-src ... https:`.

Lo que es suposición y no comprobé: si el nginx delante de erp2 añade
`Access-Control-Allow-Origin` por su cuenta. Eso lo zanja **un solo comando**, sin tocar datos:

```
curl -sS -i -X OPTIONS https://erp2.tecnosmart.com.ec/json/2/res.users/read \
  -H 'Origin: https://example.org' -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: authorization,content-type,x-odoo-database' | head -20
```

Si no aparece `Access-Control-Allow-Origin`, la app web de GitHub Pages **no puede** hablar
con ese Odoo, por mucha clave que se pegue.

Y no hay evidencia de que nadie lo haya probado: todos los informes de web del repo dicen
«compila» o «build correcto» (`reports/V02.md:23`, `reports/F06.md:24`, `reports/U08.md:56`),
y el único que corre en Chrome de verdad, `reports/V01-web-db.md`, ejercita IndexedDB, **no
la red contra Odoo**. `deploy-web.yml` es `workflow_dispatch`: ni siquiera corre solo.

## 4. Qué costaría en Orbi

Menos de lo que parece: **la mitad ya está construida**.

Ya existe: `theos_panel/.../login_screen.dart:254` (`_apiKeyMode`), el interruptor de la
interfaz (`:806-820`), el envío (`:888-895`) y todo el contrato
(`auth_controller.dart:19-26`, `native_auth_service.dart:307-400`, que no importa `dart:io`).

Lo que falta, y es lo único que bloquea:

1. `theos_panel/lib/app/bootstrap.dart:374-380` — en `kIsWeb` se instala
   `_WebSessionAuthService`, que **no implementa `ApiKeyAuthServicePort`** y cuyo `login()`
   devuelve siempre `required` (`:177-182`). Por eso hoy el usuario ve
   «El modo API key no está configurado en esta plataforma» (`auth_controller.dart:229-233`).
2. Hace falta un `CredentialBackend` en memoria y usar el valor
   `CredentialDurability.webSessionOnly`, que **está declarado y no se usa en producción**
   (`orbi_runtime/.../credential_store.dart:96`; sólo aparece en un test).
3. Nada cambia en el selector de entorno recién rehecho: la base sigue viniendo del servidor
   guardado (`login_screen.dart:885`), que es exactamente lo que hace `theos_pos`. El campo
   de base de datos sigue oculto y debe seguir oculto.

Coste estimado: un archivo nuevo (backend en memoria), unas 40 líneas en `bootstrap.dart`
y sus pruebas. **El camino de la clave pegada es viable en Orbi ya mismo** — con la reserva
de la sección 3: si el CORS de erp2 no responde, funcionará en escritorio y móvil y seguirá sin
funcionar en navegador, igual que `theos_pos`.

## 5. Qué se equivoca W01, y qué no

**Se equivoca en:** presentar el asunto como bloqueado sin decir que existe una vía abierta
y en uso por la app vieja. Su lista de «alternativas descartadas» encabeza con «pegar una
clave API larga en el navegador» — pero eso no está descartado: es **lo que hace hoy
`theos_pos` en su compilación web**. Descartarlo en Orbi mientras la otra app lo usa no es una
decisión, es una incoherencia.

**Sigue teniendo razón en:** que publicar bajo el mismo origen del Odoo con un conector es
la solución buena a futuro. Es la única que elimina el CORS de raíz, evita que el usuario
maneje una clave de larga vida y permite reanudar sesión tras una recarga. De hecho Orbi ya
tiene ese camino escrito: `_WebSessionAuthService` llama a `/orbi/bootstrap` con la cookie
`HttpOnly` (`bootstrap.dart:95-136`) y el SDK tiene el transporte de sesión
(`odoo_http_client.dart:56`, `:370-390`, con `withCredentials`). Lo único que falta ahí es
el addon que sirva ese endpoint.

**Las dos cosas conviven:** clave pegada como vía disponible hoy, conector como destino.
Lo que no puede sostenerse es seguir diciendo que hoy no hay ninguna vía.

---
Líneas citadas verificadas el 11-sep-2026 sobre `orbi/trabajo-pausado-2026-09-11`. Las de
`theos_panel/lib/features/auth/**` pueden correrse: había trabajo en curso en esa carpeta.
