# Diagnóstico previo · login/shell de Orbi contra ERP2 (solo lectura)

Estado propuesto: blocked

## Encargo

Averiguar, antes de que el dueño prueba a mano, si Orbi puede hoy autenticar
contra ERP2 y pintar el shell, qué credenciales hacen falta, y qué se va a
encontrar. Todo lo hecho aquí fue de **solo lectura** contra ERP2; ninguna
escritura, en ningún momento.

## 1. ¿El login nativo funciona hoy?

**El código existe y está enchufado; no lo pude ejercitar de punta a punta
sin escribir.**

- `odoo_sdk/lib/src/auth/native_auth_bootstrap_io.dart` implementa el
  bootstrap completo: `POST /web/session/authenticate` → chequeo de
  identidad fresca → crea `res.users.apikeys.description` → `make_key` →
  devuelve la API key. Es real, no un stub.
- `theos_panel/lib/app/bootstrap.dart:345` construye `NativeAuthService(...)`
  **sin** `bootstrap` propio → usa el adaptador real (`NativeOdooAuthBootstrap()`),
  no un mock, en plataforma nativa (`!kIsWeb`). En web se usa otro camino
  (`_WebSessionAuthService`), bloqueado a propósito (punto 4.3).
- `login_screen.dart` ofrece dos modos: con contraseña (llama al bootstrap
  de arriba, **crea una API key nueva**) y con API key ya emitida
  (`loginWithApiKey`, solo prueba identidad con `context_get`, sin escribir).
- **No pude probar el modo con contraseña**: crea una API key en ERP2, y el
  encargo prohíbe cualquier escritura. Verificado por código, no en vivo.
- **Sí probé el modo con API key contra ERP2, en solo lectura**, y **falló**:
  las 4 claves guardadas (`SELLER`, `CASHIER`, `SUPERVISOR`, `WAREHOUSE`) en
  `~/.config/tecnosmart/orbi_erp2_actors.env` fueron rechazadas por el
  servidor con `401 Invalid apikey` (mensaje literal del servidor). El
  formato de las 4 es correcto (40 caracteres alfanuméricos) — no es un
  problema de copiado, el servidor ya no las reconoce. Tienen apenas 3 días
  (creadas 8-sep-2026); el bootstrap siempre pide la duración MÁS LARGA que
  el servidor permita (`_preferredAllowedDuration`, tope interno 90 días),
  así que si expiraron en 3 días es porque ERP2 solo ofrece duraciones
  cortas para esa acción, o la clave fue revocada a mano.

**Conclusión: hoy, con lo que hay en el disco, el login contra ERP2 NO
funciona en ningún modo** — ni contraseña (no probado, regla de no
escritura) ni API key (probado, y rechazado).

## 2. Credenciales y variables

Ya existen en la máquina, en `~/.config/tecnosmart/`:

- **`orbi_erp2_actors.env`** — `ORBI_ERP2_SERVER_URL`, `ORBI_ERP2_DATABASE`,
  y por actor (`SELLER`/`CASHIER`/`SUPERVISOR`/`WAREHOUSE`): `_LOGIN`,
  `_USER_ID`, `_API_KEY`. Es exactamente lo que
  `Erp2HarnessConfig.fromEnvironment` (`theos_panel/lib/erp2_harness.dart`)
  espera. **Las 4 API key están muertas** (ver punto 1).
- **`orbi_erp2_audit.env`** — hace `source` del anterior y define
  `ORBI_ERP2_AUDIT_API_KEY`, alias de la clave de supervisor, pensado para
  una auditoría de solo lectura como esta. También murió (mismo `401`).
- El servidor y la base **sí están bien apuntados**: `ORBI_ERP2_SERVER_URL`
  resuelve al host exacto que exige `targetErrors()`
  (`https://erp2.tecnosmart.com.ec`), y `ORBI_ERP2_DATABASE` no es vacío —
  confirmado vía el endpoint público sin autenticación (punto 3).

**Falta**: emitir 4 API key nuevas (una por actor) desde el propio ERP2 —
login con contraseña + creación de clave, una escritura que **no me
corresponde hacer bajo esta regla de solo lectura**. Lo hace el dueño (o
autoriza el modo contraseña en una sesión aparte con permiso de escritura),
y luego actualiza `orbi_erp2_actors.env` con las claves nuevas.

## 3. Estado real del servidor (leído, no escrito)

- **Versión**: `19.5a1+e` (`server_serie: "19.5"`), vía el endpoint público
  `/web/webclient/version_info` — sin autenticación, confirmado sin ninguna
  API key. Nota sin impacto: el `traceback` del 401 (abajo) muestra la ruta
  del servidor como `/opt/odoo20/app_erp2/odoo/...` — es solo el nombre de
  la carpeta; la versión reportada y el protocolo (JSON-2) siguen siendo
  Odoo 19.5, consistente con lo que el proyecto ya asume.
- **Modelos/campos de login y shell, y capacidades del usuario**: NO se
  pudieron comprobar. El camino real (`res.users.all_group_ids`,
  `res.groups.get_external_id`, `fields_get` de sanity) exige un bearer
  válido, y las 5 claves disponibles (4 actores + auditoría) están todas
  muertas.
- Dejé listo (no lo pude correr) un probe que replica el contrato exacto de
  la app: `context_get` → `res.users.read([...,'all_group_ids'])` →
  `res.groups.get_external_id` → cruce contra los grupos que necesita el
  menú del shell (`sales_team.*`, `l10n_ec_collection_box.*`, `stock.*`,
  `approvals.*`). Con una API key viva, responde en segundos.

## 4. Huecos que va a encontrar el dueño, en orden

1. **Ninguna credencial viva contra ERP2 hoy.** Las 4 API key de actor y la
   de auditoría devuelven `401 Invalid apikey`. Sin esto no arranca nada.
2. **El modo con contraseña nunca se ha probado en vivo** contra ERP2 en
   este repo, solo se auditó por código. Es el candidato más directo para
   destrabar el punto 1, pero crea estado en el servidor (la API key), así
   que quien lo pruebe necesita autorización de escritura que esta sesión
   no tiene.
3. **Probar por navegador queda descartado por diseño**:
   `docs/orbi_panel/decisions/W01-web-auth.md` documenta que la PWA no
   puede autenticar contra ERP2 a propósito, y sigue bloqueado esperando
   autorización. **La prueba debe hacerse en escritorio nativo
   (`make run-macos`), no en Chrome.**
4. **Con una clave viva**, aún falta confirmar si el usuario de prueba tiene
   los grupos que el shell necesita para el menú completo
   (`sales_team.group_sale_salesman`, `l10n_ec_collection_box.*`, `stock.*`)
   — el probe ya escrito lo responde en segundos.

## Evidencia ejecutada

| Comando | Resultado |
| --- | --- |
| `POST /web/webclient/version_info` (sin auth) | 200, `server_serie: 19.5` |
| `POST /json/2/ir.module.module/search_read` con `ORBI_ERP2_AUDIT_API_KEY` | 401 Invalid apikey |
| Igual, con las 4 claves de actor (SELLER/CASHIER/SUPERVISOR/WAREHOUSE) | 401 Invalid apikey ×4 |
| `git status --porcelain` en el repo | limpio |

## Limitaciones

No se pudo verificar capacidades/grupos por usuario ni el `fields_get` de
sanity contra ERP2 real: requiere una API key viva y no hay ninguna
disponible sin escribir. El probe de lectura queda listo para cuando exista
una clave nueva.
