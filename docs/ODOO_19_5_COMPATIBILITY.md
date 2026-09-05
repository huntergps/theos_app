# Compatibilidad Odoo 19.5

Fecha de actualización: 2026-09-05.

Última pasada: 1072 pruebas de app y analyzer sin incidencias. E2E con usuarios
reales Sebastián (uid 43, 14 s) y Jacqueline (uid 23, 12 s), además del anterior
administrador. Se corrigió el acceso a `ir.model.data` al resolver permisos de
inicio y el falso éxito al ignorar rechazos de confirmación de Odoo.
No certifica aún venta/cobro/cierre completos: ver `ODOO_SALES_FLOW_AUDIT.md`.

## Fuentes y alcance

La fuente local de referencia es `/Users/elmers/Documents/dev_odoo20`. Se
revisaron los modelos y wizard de los addons custom, sin credenciales ni
escrituras remotas durante la auditoría inicial. El despliegue autorizado
posterior se detalla a continuación.

La nueva comprobación autenticada contra ERP2 devolvió `36130` y HTTP 200 en
`res.partner/search_count`, tanto sin como con `X-Odoo-Database`. El smoke del
SDK para ERP2 pasó el contrato de esquema 19.5 (1 prueba real, no omitida) y
confirmó `wizard.line.line_type: false`. Los intentos anteriores habían dado
401; no está demostrada la causa del cambio y ya no es el bloqueo vigente.
No se imprimieron claves. Estas comprobaciones API fueron de lectura.

## Despliegue autorizado en ERP2 · 2026-09-05

Se desplegó únicamente el contrato base de `l10n_ec_collection_box_pos`, desde
el commit `e714324a4` de la rama `codex/erp2-pos-capabilities-20260905`.
Destino real: `/opt/odoo20/app_erp2/repo/addons`; base:
`erp2_tecnosmart_com_ec`. Dos archivos de runtime añadidos/modificados, sin
borrados. Se conservó el cambio remoto de `models/account_advance.py`.

`tools/desplegar.sh erp2 l10n_ec_collection_box_pos e714324a4` terminó con
`RC del -u: 0`, servicio activo y HTTP 200, sin errores registrados en la
ventana del despliegue. Log local: `/tmp/theos_erp2_pos_deploy_20260905.log`.
Por JSON-2 se verificó el marcador integer y `pos_app_capabilities` en tres
puntos: versión 1 e identidades de punto/compañía coincidentes.

Postchecks: 50/50 archivos remotos coincidentes con el commit; servicio sin
reinicios inesperados; crones activos 0; SRI producción false; correo whitelist.
El bloqueo de despliegue se liberó tras comprobar su propietario. Se conserva
el snapshot de código anterior en `/tmp/erp2_pos_runtime_20260905.tar.gz`.
E2E macOS posterior al despliegue: **1 prueba pasada en 16 s**, con la app actual
(login, restauración aislada, menús y rutas), sin operaciones contables.
Log: `/tmp/theos_erp2_post_deploy_e2e.log`.

El preflight descubrió que `l10n_ec_collection_panel` está **uninstalled** y
su código no existe en ERP2. El dueño autorizó posteriormente instalarlo, pero
aclaró que la app debe vender y cobrar con facilidad también sin panel. No se
instaló: la suite completa del candidato opcional ejecutó 202 pruebas con 26
errores; los dos tests de capacidades pasaron, sin certificar el módulo completo.
`counter_policies=null` es la respuesta correcta del contrato base. El panel
es referencia funcional y extensión opcional, no requisito de la app.
Los traslados de lógica a caja/POS requieren análisis resumido y autorización
específica. `newerp` quedó excluido de todas estas operaciones.

## Bancos

En el stack custom 19.5 auditado se reemplaza `res.bank`. El catálogo ecuatoriano es el modelo custom
`l10n.ec.bank`, definido en
`addons/l10n_ec_banks_base/models/l10n_ec_bank.py`, con estos campos:

- `name`: Char requerido e indexado.
- `code`: Char, código SPI opcional.
- `tipo`: Selection (`banco`, `cooperativa`, `mutualista`, `publico`, `otro`).
- `active`: Boolean.

Las cuentas `res.partner.bank` usan `bank_name` textual; no se debe enviar
`bank_id` ni intentar sincronizar `res.bank` en Odoo 19.5.

## Pagos y wizard

La línea persistente `l10n_ec_collection_box.sale.order.payment` y
`account.payment` usan `l10n_ec_bank_id` (Many2one a `l10n.ec.bank`) y
`bank_name_ec` (Char espejo). El wizard
`l10n_ec_collection_box.sale.order.payment.wizard` usa igualmente
`l10n_ec_bank_id`; para tarjeta lo valida como obligatorio. `partner_bank_id`
continúa siendo la cuenta `res.partner.bank` del emisor de un cheque.

El campo `line_type` pertenece al wizard padre, no a su modelo hijo de líneas;
el adaptador debe enviarlo únicamente cuando el esquema del modelo destino lo
declare. Esto evita confundir ambos contratos.

## Anticipos e idempotencia

El contrato de anticipos usa `advance_line_ids` en los modelos custom de
Odoo. La fuente local no basta para afirmar la ausencia de `cash_out_uuid`:
la consulta de campos del runtime ERP2 sí devuelve `cash_out_uuid` (Char,
writable). Por tanto, hay una divergencia fuente/runtime que
debe verificarse por host; la app no debe quitarlo sin sustituto ni asumir que
`external_id` es equivalente hasta cerrar ese contrato idempotente.

`getAdvance` ya carga los IDs de `advance_line_ids` y los registros hijos,
validando que la respuesta esté completa antes de reemplazar cabecera y líneas
en una transacción. La lectura offline reconstruye el detalle desde Drift.
Las líneas nuevas reciben IDs locales distintos y conservan el vínculo al padre
al reconciliar el ID remoto, incluso tras pérdida del ACK. La actualización local
v10/v11 → v12 conserva registros y cola, e incorpora el caché de capacidades.

Se añadieron pruebas reales con SQLite temporal: reapertura offline, reemplazo de
líneas, respuesta malformada/incompleta y dos anticipos con líneas nuevas.

## Entrada al cobro por rol

Cobrar/F6 comprueban permisos y sesión propia abierta antes de confirmar una
venta. Se conserva la excepción nativa de supervisor de caja/administrador sin
sesión; un administrador contable por sí solo no obtiene esa excepción.
Las ventas pendientes de aprobación, rechazadas o canceladas no entran al cobro.
Una pestaña Pagos restaurada tampoco muestra la UI de caja a un vendedor.
Las 17 pruebas nuevas comprueban el handler compartido y el contenido protegido;
no equivalen a una prueba de teclado/dispositivo contra ERP2.

## Targets públicos comprobados (histórico)

Con cabeceras HTTPS y sin credenciales: `newerp.tecnosmart.com.ec`,
`pvision.galapagos.tech`, `jb.galapagos.tech` y `dejavu.galapagos.tech`
respondieron con redirección HTTP 303 a `/odoo`. El hostname solicitado
`epr2.tecnosmart.com.ec` no resolvió DNS; se conserva sin corregirlo.
Estas consultas preceden a la exclusión explícita de producción: **newerp no
se toca, ni siquiera para lecturas**. El ejecutor E2E rechaza ese hostname.
El destino efectivo de pruebas autenticadas es `erp2.tecnosmart.com.ec`.

## E2E nativo contra ERP2

`read_only_session_navigation_test.dart -d macos`: **1 prueba pasada en 19 s**.
Comprueba acceso real, persistencia/restauración con un nuevo contenedor,
menús/acciones permitidas y redirección de ruta protegida. Usa preferencias,
credenciales y SQLite temporales, separados de los datos del operador, y
desactiva procesos automáticos de colas. Log:
`/tmp/theos_erp2_readonly_e2e_error_capture.log`.

No prueba reinicio del proceso/Keychain, roles restringidos reales ni el ciclo
venta → cobro → cierre. La credencial usada es administrativa. Hubo intentos
previos fallidos; no se atribuyen todos a una causa única. Se corrigieron la
espera del formulario y el desbordamiento de mensajes largos.

## Analyzer

`make analyze` finalizó con exit 0: los cinco paquetes sin incidencias.
Se corrigieron las aserciones no nulas redundantes en replay de ventas/pagos.

## Pruebas locales

- `theos_pos`: 1.057 pruebas pasadas tras conectar políticas de caja
  (`/tmp/theos_app_counter_policy_regression.log`). Incluye 31 focales de
  capacidades, visibilidad y entrada al cobro.
- `theos_pos_core`: 561 pruebas pasadas, incluida actualización v10/v11 → v12.
- Focales financieros de durabilidad/idempotencia: 12 pasadas (incluidas en app).
- SDK discovery: 5 pasadas.
- Anticipos y replay financiero: 37 pruebas focales pasadas.
- Build macOS debug: correcto (`Orbi ERP.app`), sin inyectar credenciales.

Estas pruebas no certifican los flujos autenticados en los cinco servidores.
El énfasis funcional solicitado para vendedor/cajero se detalla en
`specs/VENDEDOR_CAJERO_PANEL_19_5.md`, en implementación. La equivalencia de las
políticas por punto/compañía del panel aún no está cerrada: el contrato local
de capacidades ya transporta y persiste 13 booleanos y días de pendientes, pero
ya se aplica a Cobrar/F6, Anticipo y Salida de dinero; faltan otros consumidores.
El contrato base está desplegado en ERP2, pero no su extensión del panel.
La parte compartida reside en
`l10n_ec_collection_box_pos`, ampliada por herencia desde el panel; Flutter no
depende de una API obligatoria de `collection.panel`.
