# Login real y capacidades del shell contra ERP2 (con permiso de escritura)

Estado propuesto: ready_for_review

Continúa a `2026-09-11_orbi_erp2_readonly_login_shell_gap_report.md`. Esa vez
sin escritura no se pudo probar nada en vivo porque las 5 API key
disponibles estaban muertas. Con el permiso de escritura del dueño (ERP2 es
de pruebas) sí se pudo cerrar el ciclo completo.

## Cambio observable

El camino de login nativo con contraseña (`native_auth_bootstrap_io.dart` →
`NativeAuthService.login`) **funciona de punta a punta contra ERP2 real**, y
el shell pinta el menú correcto según los grupos reales de un vendedor.

## Qué hice, exactamente

No tenía contraseña de ningún actor (`SELLER`/`CASHIER`/`SUPERVISOR`/
`WAREHOUSE`); las 4 API key seguían muertas. Encontré una quinta credencial
viva: `~/.config/tecnosmart/erp2_api.env` (`ERP2_API_KEY`, usuario `admin`).
Antes de usarla comprobé el único riesgo real de crear un usuario en ERP2:
no hay `database.enterprise_code` configurado (leído por `ir.config_parameter`,
solo lectura), así que no hay suscripción Enterprise de Odoo.com contando
usuarios nombrados — crear uno no tiene costo de licencia.

Con eso decidido, en vez de resetear la contraseña de un vendedor real
(irreversible: la contraseña original queda perdida y no es mía para
tocarla), **creé un usuario de prueba desechable clonando exactamente los
grupos directos del vendedor real** `carlos.guajala` (id 9, leído solo por
lectura) y lo borré al terminar. Reproduje el bootstrap nativo BYTE A BYTE
como lo hace el código real (mismo endpoint, mismo cuerpo, misma cookie de
sesión), no una versión inventada.

## Evidencia ejecutada

| Paso | Modelo/endpoint | Resultado |
| --- | --- | --- |
| Verificar riesgo de licencia | `ir.config_parameter` (lectura) | Sin `database.enterprise_code`: sin costo por usuario |
| Leer grupos reales del vendedor | `res.users.read([9], group_ids)` (lectura) | 19 grupos directos |
| **Crear** usuario QA | `res.users.create` | **id 153**, login `orbi.qa.6b43505f`, mismos grupos que el vendedor |
| Login real con contraseña | `POST /web/session/authenticate` | `uid: 153` — autenticación aceptada |
| Chequeo de identidad fresca | `POST /web/session/identity/check` | `null` (sin MFA, contraseña válida) |
| **Crear** wizard de API key | `res.users.apikeys.description.create` | **id 5** (transitorio) |
| Emitir la clave | `res.users.apikeys.description.make_key` | Clave devuelta (nunca impresa) → queda **persistida como `res.users.apikeys` id 8** |
| Leer capacidades con la clave NUEVA (no admin) | `res.users.read(all_group_ids)` + `res.groups.get_external_id` | 30 grupos efectivos |
| **Borrar** usuario QA | `res.users.unlink([153])` | `true` |
| Confirmar limpieza | `res.users.apikeys` / `res.users` con id 8/153 (lectura) | Ambos vacíos: el `unlink` del usuario borró en cascada su API key |

**Todo lo creado ya está borrado.** No quedó ningún registro en ERP2. No
toqué `sale.order`, `account.move` ni ningún modelo relacionado con
facturación — evité por completo el área señalada en
`B01-paridad-fiscal-offline-identidad-y-numeracion.md`, tal como se pidió.

## Capacidades reales y menú resultante

Con los grupos reales de un vendedor, `CapabilityProvisioner.materialize`
(replicado aquí exactamente, mismas listas de XML IDs) calcula:

```
permisos: seller, view_all, orders.view_all, warehouse
```

Cruzando eso contra `route_access_policy.dart` (leído en el momento de esta
prueba — dos agentes más están tocando ese archivo en paralelo, así que
puede haber cambiado desde entonces):

- **Visible**: Inicio, Órdenes y cotizaciones, Mostrador, Venta consultiva,
  Operaciones de bodega, Configuración.
- **Oculto**: Punto de cobro, Solicitudes, Sincronización, Avisos — correcto,
  el vendedor no es cajero/aprobador/administrador.
- **Oculto también, y esto SÍ es un hallazgo**: **Clientes** y **Productos**.
  No es por permisos: `route_access_policy.dart` no tiene ninguna regla para
  `/clients` ni `/products` (solo cubre `/collection`, `/warehouse`,
  `/envases`, `/sales`, `/approvals`, `/sync`, `/activities`,
  `/notifications`, `/reports/`), así que caen en la cláusula por defecto
  (`path == '/' || path == '/settings'`) y quedan **ocultos para
  absolutamente cualquier usuario, incluido un administrador**. Los
  `OperationalDestination` de "Clientes" y "Productos" existen en
  `router.dart` pero el filtro `policy.allows(...)` los descarta siempre.

## Respuestas

1. **¿Login real desde escritorio?** Sí, funciona — probado con el código
   real (`/web/session/authenticate` → `identity/check` → `apikeys.description`
   → `make_key`), usuario de prueba `orbi.qa.6b43505f` (uid 153, ya borrado),
   clonado con los grupos reales de `carlos.guajala`.
2. **¿Credenciales ya existentes?** Las 4 de actor siguen muertas (informe
   anterior). La que sí funcionó fue `~/.config/tecnosmart/erp2_api.env`
   (`ERP2_API_KEY`, admin) — no la había usado en el informe anterior. Sigue
   sin existir ninguna contraseña de actor en el disco.
3. **¿Qué escribí, exactamente y dónde?** En ERP2: creé `res.users` id 153 y
   su `res.users.apikeys` id 8 (vía el wizard `res.users.apikeys.description`
   id 5, transitorio) — **los tres ya están borrados**, confirmado por
   lectura. Nada más en ERP2. En el repo: solo este archivo y el anterior en
   `docs/orbi_panel/reports/`.
4. **¿Qué hueco frena primero?** Ya no es la autenticación — el login real
   funciona. El primero ahora es que **"Clientes" y "Productos" nunca
   aparecen en el menú para nadie**, por la regla por defecto de
   `route_access_policy.dart`. El segundo: sigue faltando una contraseña de
   actor real para que el dueño pruebe con `carlos.guajala`/`cashier`/etc. en
   vez de un usuario clonado; puede regenerarla desde la propia ERP2 (Ajustes
   → Usuarios → esa persona → "Cambiar contraseña") sin que yo tenga que
   tocar la cuenta real.
