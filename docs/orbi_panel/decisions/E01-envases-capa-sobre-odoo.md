# E01 — Envases en Orbi: capa sobre `l10n_ec_stock_envases` (13-sep-2026)

Estado: **borrador de diseño**, sin código. Decide team-lead; implementan agentes contra este texto.

## Órdenes del dueño que lo fijan

- «no vamos a inventar nada nuevo, lo que vamos a hacer es una capa más sobre Odoo, revisa las
  imágenes que se aprobaron para envases».
- Alcance elegido: **«Solo lo que Odoo tiene»**. Quedan fuera hasta que Odoo lo tenga: ENV-07
  (compra/venta ligada a factura), ENV-FACTURA (registrar desde factura), ENV-TOMA-FISICA y la
  propuesta de facturación por envases no devueltos.
- Todo debe funcionar sin conexión (memoria `orbi-todo-debe-funcionar-offline`).
- Nada de nombres de sedes cableados: columnas y sedes salen del servidor.
- Se prueba en Mepriga (`https://mepriga.galapagos.tech`, base `envases`), que es de pruebas, sin crear
  datos de prueba.

## Contrato de Odoo (dev_odoo20 `docs/especificaciones/envases/CONTRATO_PARA_ORBI.md`, `b2f8aab56`+)

| Uso | Llamada | Estado |
|---|---|---|
| Existencias | `l10n_ec.envases.existencias.datos()` | en Mepriga 19.5.1.2.0 |
| Por recibir | `stock.picking.envases_por_recibir()` | llega en 19.5.1.3.0 |
| Movimientos | `stock.move.line.envases_movimientos(desde, hasta, limite, desplazamiento)` | llega en 19.5.1.3.0 |
| Enviar | crear `l10n_ec.stock.envases.wizard.envio` + `action_enviar` | en Mepriga |
| Recibir | crear `l10n_ec.stock.envases.wizard.recepcion` (picking_id) + ajustar `llegaron`/`danadas` + `action_recibir` | en Mepriga |
| Dar por perdido | `stock.picking.action_envases_dar_por_perdido` (solo gerencia) | en Mepriga |
| Saldo por tercero | `l10n_ec.envases.saldo.tercero` | solo si la empresa enciende la custodia |
| Sedes del usuario | `res.users.envases_warehouse_ids` (vacío = ninguna) | en Mepriga |
| Idempotencia | `envases_operacion_uuid` en los tres asistentes y en `stock.picking` | acordado 13-sep, llega en 19.5.1.3.0 |

## Pantallas ← láminas aprobadas (solo lo que Odoo respalda)

| Pantalla Orbi | Lámina | Fuente |
|---|---|---|
| Existencias (tabla en escritorio/iPad horizontal, tarjetas en vertical/teléfono) | BODEGA-ENVASES-v1 «Existencias», ENV-01 | `datos()`: columnas dinámicas por sede y sentido; totales; «Trabajo de hoy» con `pendientes` |
| Por recibir / En tránsito + detalle del traslado | BODEGA-ENVASES iPad horizontal, ENV-03 pestaña Tránsitos | `envases_por_recibir()` |
| Recibir (llegaron / dañadas, lo no recibido queda pendiente) | ENV-06, BODEGA-ENVASES teléfono | asistente recepción |
| Enviar a otra sede | BODEGA-ENVASES botón «Enviar traslado» | asistente envío (origen solo de las sedes del usuario; destino ≠ origen) |
| Movimientos + detalle | ENV-02 | `envases_movimientos()` |
| Clientes / Proveedores (saldo por tercero) | BODEGA-ENVASES «Clientes», ENV-03 pestañas Clientes/Proveedores | `saldo.tercero`, **solo visible si el servidor tiene custodia encendida**; fila «sin cliente asignado» visible |
| Dar por perdido | acción en detalle del traslado | solo con permiso de gerencia |

Lo que las láminas muestran y NO se construye: «Registrar compra/venta», «Preparar facturación»,
«Propuesta de facturación», «Recibir compra», «Desde factura», «Toma física», y cualquier
«Nuevo movimiento» libre.

## Lectura sin conexión

- Un caché Drift por lectura (existencias, por recibir, movimientos, saldo por tercero), con el molde de
  `EnvasesDashboardCache` / `StockQuantCache`: payload JSON + `cached_at` + versión de payload, atado a
  `SessionLease` y `CompanyContext`. Sin conexión se muestra lo último con su hora.
- Composición con el molde de `warehouse_existences_composition.dart` (readerFactory perezoso y error
  explícito sin conexión), no el `reader = null` silencioso de `envases_composition.dart`.
- Se retiran `EnvasesDashboardReader` (`l10n_ec.envases.panel`, retirado en Odoo) y
  `EnvasesLocationReader` si nada del contrato nuevo lo necesita; `EnvasesPartnerBalanceReader` se
  revisa contra los campos actuales de `saldo.tercero`.

## Escritura sin conexión

- Productor con el molde de `durable_collection_producers.dart`: estado local en Drift y
  `queue.queueOperation` en la misma transacción, `operationKey` `envases.envio:<uuid>` /
  `envases.recepcion:<uuid>` / `envases.perdido:<picking_id>`.
- Dispatcher con el molde de `_applyNativePaymentWizard`: `create` del transitorio con `vals_list`,
  id creado, `action_*`. Se registra en un adaptador propio de envases, no en el `if` de 2.500 líneas de
  ventas, si el coordinador lo permite.
- Idempotencia acordada con la sesión Envases (13-sep): un uuid NUEVO por operación que el usuario confirma y
  el MISMO en todos sus reintentos, en `envases_operacion_uuid` del asistente. Odoo lo escribe en los pickings
  que esa operación deja HECHOS (envío: el de salida, no la recepción pendiente; recepción: el recibido, no el
  pendiente que quede). Con un uuid repetido Odoo no hace nada y devuelve lo mismo. Dos llamadas simultáneas
  se ordenan con un bloqueo en la base.
- `replayPolicy` `retry_safe` para envío y recepción una vez desplegada la 19.5.1.3.0; `reconcile()` busca
  `stock.picking` por `envases_operacion_uuid` (y `envases_por_recibir()` devuelve
  `envases_envio_operacion_uuid`; `envases_movimientos()` devuelve `envases_operacion_uuid`). Contra un
  servidor sin ese campo, `manual_after_ambiguous`.
- «Dar por perdido» es idempotente por estado en Odoo: la segunda llamada falla con «ya no está pendiente».
- El servidor manda: si al reenviar Odoo rechaza (sin disponible, sede ajena), la operación queda en la
  cola con el mensaje de Odoo, sin «arreglarlo» en la app.
- Mientras un envío está en la cola, las existencias locales muestran «pendiente de enviar», sin
  recalcular cifras de Odoo en la app.

## Permisos

- `envases_read` (ya existe, `group_envases_user` o `group_envases_manager`): ver y operar enviar/recibir.
- **Nuevo** `envases_manage` (`group_envases_manager`): dar por perdido.
- Custodia: visible solo si el usuario tiene `group_envases_custodia`.
- Operar en una sede exige que esté en `envases_warehouse_ids`; la app solo ofrece esas sedes, y Odoo
  vuelve a comprobarlo.

## Abiertos

1. ~~Idempotencia~~: acordada como `envases_operacion_uuid` (ver Escritura sin conexión).
2. 19.5.1.3.0 desplegado en Mepriga con `envases_por_recibir` y `envases_movimientos`.
3. Catálogos: un usuario solo de bodega (Mepriga) no debe sincronizar ventas ni caja — decisión aparte
   (sección 7 del mapa, pendiente).
