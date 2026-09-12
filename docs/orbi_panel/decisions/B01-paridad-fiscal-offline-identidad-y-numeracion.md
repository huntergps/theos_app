# B01 — Paridad fiscal offline: identidad, numeración, respuesta incierta e importes

Fecha: 2026-09-11 · Rama `orbi/trabajo-pausado-2026-09-11`, commit base `28a11ea`.
Tarea: `B01` «Resolver paridad backend y fiscal offline» (`docs/orbi_panel/tasks.json`),
único bloqueo de `V01`. Cierra los pendientes `O01` y `O02` de
[`DESIGN_HANDOFF.md`](../DESIGN_HANDOFF.md) en lo que se puede cerrar sin instancia.

## Qué es evidencia aquí y qué no

Todo lo marcado **VERIFICADO** se leyó en código, con archivo y línea, en dos checkouts:

| Lado | Ruta | Commit observado |
|---|---|---|
| Cliente | este repositorio | `28a11ea` |
| Odoo | `/Users/elmers/Documents/dev_odoo20` | `a290d0b0d` |

Todo lo marcado **PROPUESTA** es mío y no está implementado ni autorizado.

**Revisión del 2026-09-11 (segunda pasada).** Esta versión sí midió contra **ERP2**
(`erp2.tecnosmart.com.ec`, Odoo 19.5.1.3), sólo lectura, por JSON-2 con la credencial de
`~/.config/tecnosmart/erp2_api.env`. Lo medido allí va marcado **MEDIDO EN ERP2** e
incluye fecha. No se escribió nada en ERP2 y no se tocó `newerp`.

Que un archivo exista no prueba que el módulo esté instalado, que la ACL resuelva ni que
el índice esté creado en la base de ERP2. Un `models.Constraint` en fuente es una promesa
de esquema; sólo `pg_indexes` la confirma.

### El terreno vivo, comprobado con grep

`theos_pos_core/lib/src/services/operations/operation_commands.dart` y la familia
`sale_operation_*` **no están enchufados**: no los importa ningún productor. El mecanismo
vivo es el trío

- `odoo_sdk/lib/src/sync/offline_queue_types.dart` — enum `OfflineLocalCommand` (:90-113),
- `theos_pos_core/lib/src/database/datasources/offline_queue_datasource.dart` — la cola real,
- `odoo_sdk/lib/src/sync/offline_queue_processor.dart` — el que la drena,

con productores en `theos_pos/lib/features/{sales,collection,sync}/…` y, del lado Orbi,
`orbi_runtime/lib/src/sales/sale_runtime_adapters.dart`. Este análisis se apoya sólo en
esos archivos.

---

## 1. Identidad estable — ¿qué impide crear dos documentos?

### La pregunta que hay que zanjar, y su respuesta

Hay **dos** escenarios distintos y la primera versión de este documento los mezcló. Vale
la pena separarlos, porque uno no existe y el otro sí:

| Escenario | ¿Alcanzable? | Qué lo decide |
|---|---|---|
| **A · Dos facturas con el MISMO número** | **No.** | El índice único del núcleo `account.move._unique_name` sobre `(name, journal_id) WHERE state='posted'` (`odoo/addons/account/models/account_move.py:821-824`). Y aunque pasara, el SRI rechaza el comprobante repetido. Esta alarma sobraba |
| **B · Dos facturas DISTINTAS, con números distintos, ambas válidas, para UNA SOLA venta** | **Sí**, por el camino numerado por el servidor | Nadie lo rechaza: el diario las acepta, el SRI las acepta, y el cliente se lleva dos comprobantes de una compra |

**El escenario B es el riesgo real, y es peor que A precisamente porque nada lo frena.**

### Por qué B es alcanzable — el mecanismo, paso a paso (VERIFICADO)

El punto que lo decide está en el núcleo, y su propio docstring lo dice sin ambigüedad.
`odoo/addons/account/models/sequence_mixin.py:357-366`, `_locked_increment`:

> «If the sequence is already locked by another transaction, it will wait until the other
> one finishes, **then grab the next available number**.»

Y el bucle de `:410-424` lo confirma: ante `UniqueViolation` **no falla**, hace
`sp.rollback()`, suma uno al secuencial y vuelve a intentar hasta encontrar uno libre.
Es decir: **la segunda transacción concurrente no choca, se corre de sitio.**

Encadenado con el camino del addon, la secuencia completa es:

1. La app llama `action_pos_confirm_and_invoice` sobre un diario **sin**
   `numbered_by_client`, así que no manda `sequential`: el número lo pone el servidor
   (`sale_order.py:1106-1128`, rama clásica `_create_invoices()` + `action_post()`).
2. El servidor tarda más que el `receiveTimeout` del cliente —30 s por omisión,
   `odoo_sdk/lib/src/api/client/odoo_http_client.dart:131`—. La app da la respuesta por
   perdida. **La transacción T1 sigue viva en el servidor.**
3. La cola reconcilia antes de reenviar (`orbi_runtime/lib/src/sync/operations_sync_job.dart:131-145`
   llama a `adapter.reconcile` antes de despachar). La consulta busca por
   `l10n_ec_pos_client_op_uuid` y **no encuentra nada, porque T1 no ha confirmado todavía**.
4. La app reenvía. La comprobación de idempotencia del servidor
   (`sale_order.py:618-626` y `:964-972`) hace la misma búsqueda por UUID y **tampoco
   encuentra nada, por la misma razón**: `READ COMMITTED` no muestra filas sin confirmar.
5. T2 crea su factura. Al postear, `_locked_increment` espera a T1, ve el número tomado,
   y **coge el siguiente**.
6. Confirman las dos. **Dos facturas posteadas, con números distintos, el mismo
   `client_op_uuid`, la misma venta.**

🔴 **Esto no es una carrera de microsegundos con la que haya que tener mala suerte.** La
condición que provoca el reintento —que el servidor tarde más que el tiempo de espera del
cliente— **es exactamente la condición que garantiza que las dos peticiones se solapen**.
Cuanto más lento va el servidor, más probable es el duplicado, no menos.

### Por qué A no es alcanzable, y dónde eso sí protege

Cuando el diario está marcado `numbered_by_client`, el reintento lleva **el mismo
secuencial** que el primer intento —la app lo persistió en Drift antes de imprimir y el
payload encolado no cambia—. Entonces T2 intenta postear con el mismo `name`, el índice
`_unique_name` del núcleo se dispara y la `UniqueViolation` **no** la absorbe
`_locked_increment` (ese camino ni se ejecuta: el `name` ya viene fijado por el inverse de
`l10n_latam_document_number`, `sale_order.py:1529`). La violación sube, el savepoint de
`_l10n_ec_pos_create_invoice_with_number` revierte, y **no queda factura**.

**Ahí el dueño tiene toda la razón: con numeración de la app, Odoo no deja.** Lo que hace
que el índice sirva es que el reintento reutilice el número; en cuanto el número lo pone
el servidor, el índice deja de ser una red y pasa a ser el mecanismo que reparte números
nuevos.

### El agravante: en ERP2 el camino protegido no está configurado (MEDIDO EN ERP2, 2026-09-11)

```
account.journal  search_read  [('numbered_by_client','=',True)]   ->  []
account.journal  search_read  [('type','=','sale')]               ->  3 diarios,
      id 9  "001-001 Facturas de cliente" (INV)  numbered_by_client=False
      id 22 "Recibos de Clientes"        (RSC)  numbered_by_client=False
      id 76 "Notas de Débito Ventas"     (NDCOM) numbered_by_client=False
collection.config  search_read (active_test=False) -> 5 registros, TODOS con
      journal_id = false  y  device_uuid = false
```

**Ni un solo diario de ERP2 tiene `numbered_by_client`, y ningún punto de cobro tiene
diario asignado.** Es decir: en ERP2, hoy, **toda** emisión POS caería por la rama clásica
—la del escenario B, la que no tiene red— y la protección del escenario A no llega a
entrar en juego. Falta configuración, no código.

Consecuencia colateral: `theos_pos` se niega a emitir offline si el diario no está marcado
`numbered_by_client` (`theos_pos/lib/features/sales/repositories/sales_repository_invoice.dart:64-72`),
así que **con ERP2 tal como está, la emisión offline de `theos_pos` no arranca**. Orbi sí
tiene rama para diario no numerado por el cliente
(`orbi_runtime/lib/src/sales/sale_runtime_adapters.dart:424-438` y `:1015-1029`) y es la
que quedaría expuesta.

### Lo que NO es el riesgo (y conviene decirlo para no gastar crédito en falsas alarmas)

Un reintento **ordinario** —el que sale después de que el primer intento ya confirmó— está
protegido **dos veces**:

1. la búsqueda por `client_op_uuid` encuentra la factura y devuelve idempotencia
   (`sale_order.py:618-659`); y si eso fallara,
2. `_create_invoices()` nativo se niega porque ya no queda línea por facturar.

Y el transporte HTTP **no** reenvía mutaciones por su cuenta: el interceptor de reintentos
es fail-closed y sólo replica métodos de lectura de una lista blanca
(`odoo_sdk/lib/src/api/interceptors/retry_interceptor.dart:14-17, 62-70`), y
`action_pos_confirm_and_invoice` no está en ella. **El duplicado no puede nacer de un
reintento automático de la capa HTTP.** Nace del solapamiento descrito arriba.

### Lo que hay hoy (VERIFICADO)

Hay **tres** capas distintas, y conviene no confundirlas porque protegen cosas distintas:

**(a) `operation_key` — deduplicación local, nunca sale del dispositivo.**
`offline_queue_datasource.dart:46-93` deriva una clave y, dentro de una transacción
Drift, colapsa un segundo encolado con la misma clave devolviendo la fila existente. La
columna es `UNIQUE` (`theos_pos_core/lib/src/database/tables/sync_tables.dart:55`). Pero
la clave **no forma parte de `values`**, así que no viaja en ninguna llamada a Odoo, y el
índice único es por base SQLite: dos instalaciones no se excluyen entre sí.
Demostrado en `theos_pos_core/test/operations/offline_fiscal_identity_gap_test.dart`,
pruebas 1 y 2.

Además `_deriveOperationKey` (:102-146) devuelve `null` cuando el payload no trae ninguno
de los diez marcadores de la lista y no es un `create` con id local negativo. Un comando
sin marcador **no tiene deduplicación local alguna**: dos encolados idénticos producen dos
filas (prueba 4 del archivo citado).

**(b) El marcador dentro de `values` — sí llega a Odoo, pero sólo si el productor lo puso.**
El caso completo y bien hecho es la factura offline de `theos_pos`:
`sales_repository_invoice.dart:559-577` encola `invoice_create_with_payments` con
`client_op_uuid = offlineInvoice.uuid`, un UUID v4 generado en el momento de la emisión
local (:146) y **persistido en Drift antes de imprimir**. Ese valor viaja como
`pos_client_op_uuid` al wizard (`offline_sync_payment.dart:184, 224`) y Odoo lo escribe en
`account.move.l10n_ec_pos_client_op_uuid`
(`addons/l10n_ec_collection_box_pos/models/sale_order.py:1523-1525`). Eso **sí** es un
identificador de comando extremo a extremo, durable y estable entre reintentos, para ese
camino.

**(c) La defensa del servidor — y aquí está el hueco.**
El backend protege con índice único de PostgreSQL prácticamente toda identidad offline:

| Modelo | Restricción | Evidencia |
|---|---|---|
| `sale.order` | `unique(x_uuid)` | `models/sale_order.py:61-64` |
| `sale.order.line` | `unique(x_uuid)` | `models/sale_order_line.py:37-40` |
| `collection.session` | `UNIQUE(session_uuid)` | `models/collection_session.py:19-22` |
| `collection.session.deposit` | `UNIQUE(deposit_uuid)` | `models/collection_session_deposit.py:20-23` |
| `l10n_ec.cash.out` | `UNIQUE(cash_out_uuid)` | `models/cash_out.py:20-23` |
| efectivo de sesión | `UNIQUE(cash_uuid)` | `models/collection_session_cash.py:20-23` |
| línea de cobro de factura existente | `unique(company_id, pos_collection_line_uuid)` | `models/existing_invoice_collection.py:22-23` |
| punto de cobro | `UniqueIndex(device_uuid)` y `UniqueIndex(journal_id)`, sólo activos | `models/collection_config.py:19-29` |

**`account.move.l10n_ec_pos_client_op_uuid` es la única excepción: `index=True`, sin
restricción única** (`models/account_move.py:20-27`; el barrido de `models.Constraint` y
`UniqueIndex` sobre todo el addon no devuelve ninguna para `account_move`). Es decir: **el
documento fiscal, el que de verdad importa, es justamente el que no tiene identidad única
a nivel de base.** Su idempotencia es «buscar antes de crear»:
`sale_order.py:620-666` busca por UUID antes de confirmar, y
`sale_order_payment_wizard.py:45-61` busca antes de facturar.

Y esa búsqueda **no toma candado de fila**. El único `FOR UPDATE` del addon está en el
camino de reparación de despacho (`sale_order.py:1439-1441`) y en el cobro de factura
existente (`existing_invoice_collection.py:243-244`). El camino de creación no lo tiene.
Con dos transacciones concurrentes en `READ COMMITTED`, ambas pueden buscar, no encontrar
nada, y crear.

### Qué falta

- Ninguna restricción de base garantiza «un `client_op_uuid` = un `account.move`». El
  campo es `index=True` y nada más (`models/account_move.py:20-27`); el barrido de
  `models.Constraint` y `UniqueIndex` sobre todo el addon no devuelve ninguna para
  `account_move`. **Es la única identidad offline del addon sin índice único**, y es
  justo la del documento fiscal.
- Ningún candado serializa dos peticiones solapadas del mismo comando. El único
  `FOR UPDATE` del addon está en reparación de despacho (`sale_order.py:1439-1441`) y en
  cobro de factura existente (`existing_invoice_collection.py:243-244`). El camino de
  creación no lo tiene.
- El índice `_unique_name` del núcleo **no es un contrato de idempotencia**: sólo actúa si
  las dos facturas llevan el mismo número. Con numeración del servidor no sólo lo esquiva,
  sino que `_locked_increment` **le entrega activamente un número nuevo** a la segunda
  transacción.

### Decisión propuesta — **D1** (PROPUESTA, requiere autorización backend)

Añadir en `l10n_ec_collection_box_pos/models/account_move.py` un índice parcial único:

```python
_pos_client_op_uuid_unique = models.UniqueIndex(
    "(company_id, l10n_ec_pos_client_op_uuid) "
    "WHERE l10n_ec_pos_client_op_uuid IS NOT NULL "
    "AND move_type = 'out_invoice' AND state != 'cancel'",
    "La operación POS ya emitió su factura.",
)
```

- **Origen / destino:** cambio de backend en el addon custom; ninguna app cambia.
- **Riesgo: ninguno de datos. MEDIDO EN ERP2 (2026-09-11): cero.** El conteo de
  `account.move` con `l10n_ec_pos_client_op_uuid` no nulo, `move_type='out_invoice'` y
  `state != 'cancel'` devuelve **0 facturas** —no hay ni una sola emitida con identidad
  POS—, y ninguna venta de ERP2 tiene más de una factura vigente (686 ventas facturadas,
  33 con más de un `account.move`, todas parejas factura+nota de crédito, **0** con dos
  facturas vivas). El índice se puede crear sin limpiar nada. Alcance por compañía porque
  `account.move` es multiempresa y el UUID lo genera el dispositivo, no el servidor.
- **Y D1 ya no es opcional ni preventiva:** mientras el índice no exista, el escenario B
  no tiene absolutamente nada que lo pare. Es la única de las nueve decisiones que corta
  el duplicado en la base, que es donde la carrera se resuelve.
- **Prueba:** un test concurrente que lance dos `action_pos_confirm_and_invoice` con el
  mismo `client_op_uuid` y compruebe que una gana y la otra recibe `UniqueViolation`
  traducida a respuesta idempotente, no a factura nueva. El repositorio ya tiene el patrón
  en `tests/test_collection_config_exclusivity.py`, que verifica índices contra
  `pg_indexes`.

### Decisión propuesta — **D2** (PROPUESTA)

Tomar candado de fila de la venta antes de la búsqueda por UUID en
`action_pos_confirm_and_invoice`, con el mismo `SELECT … FOR UPDATE` que ya usa el camino
de reparación. Serializa los reintentos del mismo pedido sin depender del índice.
Riesgo: contención si dos cajeros cobran la misma venta — que es exactamente lo que se
quiere serializar. D1 y D2 son complementarias: D1 protege entre pedidos, D2 dentro del
pedido.

### Decisión propuesta — **D3** (PROPUESTA, lado cliente)

Hacer obligatorio el marcador de identidad para **todo** comando que cree o mueva dinero:
`_deriveOperationKey` debe devolver una clave siempre para los `OfflineLocalCommand`
financieros, y `queueCommand` debe rechazar el encolado si el payload no trae UUID. Hoy un
productor puede olvidarlo y nadie se entera hasta el duplicado.

---

## 2. Numeración — quién asigna el número y qué pasa con dos dispositivos

### Lo que hay hoy (VERIFICADO)

**El servidor delega la numeración cuando el diario está marcado
`numbered_by_client`** (`models/account_journal.py:31-40`). Con el flag activo:

1. la app es la única autoridad del punto de emisión;
2. `account.move._post` **bloquea** cualquier posteo de factura de cliente de ese diario
   fuera del flujo POS (`models/account_move.py:39-68`), así que el servidor no puede
   morder el mismo secuencial por su cuenta;
3. al sincronizar, `_l10n_ec_pos_create_invoice_with_number` fija fecha y
   `l10n_latam_document_number`, postea, y **verifica que el número no fue reasignado**
   (`sale_order.py:1544-1553`) y que la clave de acceso calculada por el servidor coincide
   con la impresa por la app (`:1555-1559`). Si no coincide, el savepoint revierte y no
   queda factura.

**La exclusividad entre dispositivos está declarada en base, pero hoy no restringe nada.**
`collection_config.py:19-29` declara dos índices parciales únicos: un diario no puede
pertenecer a dos puntos de cobro activos, y un `device_uuid` no puede estar en dos puntos
activos. La intención es correcta.

🔴 **Corrección de la primera versión, que llamó a esto «garantía verificada».**
MEDIDO EN ERP2 (2026-09-11): los cinco `collection.config` existentes tienen
`journal_id = false` y `device_uuid = false`. Un índice único **no restringe NULL**: dos
filas con `journal_id` nulo no colisionan nunca. Así que la garantía es **vacía mientras
no se asigne diario y `device_uuid` a cada punto de cobro**. No está rota: está sin
estrenar. La frase «no es un escenario alcanzable» era demasiado tranquilizadora.

### Qué falta — y aquí sí hay un agujero, pero es otro

El riesgo real no es «dos dispositivos», es **un dispositivo que pierde su contador**.

`theos_pos` calcula el siguiente secuencial **sólo con datos locales**:
`sales_repository_invoice.dart:327-367` devuelve
`max(journal.lastInvoiceSequence, máximo secuencial en account_move local) + 1`.
Y `lastInvoiceSequence` es una **columna que sólo existe en el cliente**
(`theos_pos_core/lib/src/database/tables/account_journal_table.dart:17`): el barrido de
`last_invoice_sequence` sobre todo el checkout de Odoo no devuelve nada, y el único
escritor es la propia app (`sales_repository_invoice.dart:301`). Nada la siembra desde el
servidor.

Combinado con lo que advierte `CLAUDE.md` —«la estrategia de migración borra y recrea
todas las tablas para cualquier salto de esquema sin rama explícita»— el resultado es:
**si la base local se recrea, el contador fiscal vuelve a cero y la app empieza a emitir
secuenciales ya usados.** Demostrado en la prueba 7 del archivo de huecos: un diario recién
insertado nace con `lastInvoiceSequence == 0`.

Qué pasa entonces, exactamente: la app imprime un comprobante con un número ya emitido, y
al sincronizar el índice `account_move._unique_name` del core rechaza el posteo. No se
duplica en contabilidad —eso está bien— pero **queda un comprobante fiscal impreso que
nunca podrá sincronizarse**, que es el peor de los dos males desde el SRI.

### Decisión propuesta — **D4** (PROPUESTA, backend + cliente)

El contador no puede vivir sólo en el cliente. Dos formas, en orden de preferencia:

1. **Preferida:** exponer en el bootstrap de capacidades
   (`controllers/web_auth.py`, `/orbi/bootstrap`) el último secuencial emitido por el
   diario, calculado del servidor, y que `_getNextInvoiceSequence` tome
   `max(local, servidor) + 1`. Barato, y sana el caso de base recreada en cuanto hay red.
2. **Complementaria, para el caso sin red tras la recreación:** rango reservado. El punto
   de cobro pide un bloque de secuenciales al conectarse y sólo emite dentro de él; agotado
   el bloque sin red, se bloquea la emisión en vez de adivinar.

- **Riesgo de (1):** mientras el dispositivo esté sin red tras una recreación de base sigue
  desprotegido. Por eso (1) no cierra el hueco sola; cierra la mayoría de los casos.
- **Riesgo de (2):** un bloque reservado y no consumido deja huecos en la secuencia, y el
  SRI los tolera pero hay que declararlos.
- **Prueba:** recrear la base local con facturas ya emitidas y comprobar que el siguiente
  secuencial continúa la serie en lugar de reiniciarla.

### Decisión propuesta — **D5** (PROPUESTA, cliente, barata e inmediata)

Añadir rama explícita de migración para `schemaVersion` en `database.dart` o, como mínimo,
excluir `account_journal.last_invoice_sequence` y `offline_invoice` del borrado. Mientras
el contador fiscal pueda desaparecer en una migración, D4 punto 1 es un parche con red.

---

## 3. Respuesta incierta — cómo se consulta sin arriesgar duplicado

### Lo que hay hoy (VERIFICADO)

La cola distingue dos políticas (`offline_queue_types.dart:64-84`) y el predeterminado
seguro es `manual_after_ambiguous`, incluso para comandos desconocidos (`:78-83`). El
procesador las aplica en dos sitios:

- una operación recuperada tras un cierre abrupto (`processing` → `recovery_pending`, en
  `database.dart:355-373`) con política `manual_after_ambiguous` va directa a
  **dead letter** sin llamar al handler: `offline_queue_processor.dart:351-376`;
- una excepción cualquiera con esa política también va a dead letter en vez de reintentar:
  `:491-497`.

El procesador serializa además todo despacho del proceso con un lock global estático
(`:110-123`, `:233-243`) y reclama el lote entero como `processing` antes de despachar nada
(`:305-316`), de modo que dos ciclos concurrentes no se pisen el mismo lote. Eso está bien
resuelto y no lo toco.

Del lado Odoo, el camino de consulta existe y está bien pensado: si un UUID ya tiene
factura pero el cobro no está completo, `action_pos_confirm_and_invoice` responde
`idempotency_incomplete` en vez de crear nada (`sale_order.py:637-648`), y si el UUID
pertenece a otra venta responde `idempotency_scope_conflict` (`:628-632`).
`_l10n_ec_pos_replay_is_complete` (`:1342-1404`) se niega explícitamente a deducir que el
cobro terminó sólo porque el residual sea cero. Del lado Orbi,
`sale_runtime_adapters.dart:533-575` consulta por `l10n_ec_pos_client_op_uuid` y exige
`state='posted'`, `payment_state='paid'`, residual cero **y** que el importe coincida antes
de declarar sincronizado.

### Qué falta

**La protección depende enteramente de la etiqueta, y la etiqueta se reparte mal.**
`_deriveReplayPolicy` (`offline_queue_datasource.dart:148-195`) exige un marcador de
identidad para conceder `retry_safe` a casi todo… salvo a cuatro comandos, que lo obtienen
**incondicionalmente** (`:184-189`):

    session_open · session_closing_control · session_close · order_confirm

Sin marcador, esos comandos no tienen ni clave de deduplicación local ni identidad que
mandar al servidor, y aun así el procesador los **reenvía solo** tras una respuesta
incierta. Demostrado en las pruebas 3, 4 y 5 del archivo de huecos: un `order_confirm` sin
UUID sale `retry_safe`, con `operationKey == null`, y el handler se vuelve a invocar tras
`recovery_pending`. La prueba 6 fija el contraste: `payment_wizard_apply`, con política
manual, no se reenvía y termina en dead letter.

Que `order_confirm` sea inofensivo en la práctica dependerá de si `action_pos_confirm` es
idempotente sobre una venta ya confirmada — y eso **no lo puedo afirmar sin instancia**.
Lo que sí puedo afirmar es que la cola le está dando permiso de reenvío automático sin
exigirle nada a cambio, que es lo contrario del criterio que el propio archivo declara en
su comentario de `OfflineReplayPolicy`.

### Decisión propuesta — **D6** (PROPUESTA, cliente)

Quitar la excepción incondicional de `:184-189`. Esos cuatro comandos deben ganarse
`retry_safe` igual que los demás: presentando un marcador (`session_uuid` para los de
sesión, `order_uuid`/`x_uuid` para `order_confirm`, que ya existe en el modelo y ya tiene
índice único en Odoo). Sin marcador, política manual.

- **Riesgo:** operaciones que hoy se recuperaban solas pasarán a pedir intervención. Es el
  intercambio correcto para un documento financiero, pero hay que anticipar el ruido
  operativo y dar pantalla de resolución antes de activarlo.
- **Prueba:** las pruebas 3-6 de `offline_fiscal_identity_gap_test.dart` invertidas —hoy
  fijan el comportamiento inseguro, y esa corrección debe romperlas a propósito.

### Decisión propuesta — **D7** (PROPUESTA)

`retry_safe` no debería significar «reenvía», sino «puedes consultar y luego decidir». Es
decir, antes de reenviar una operación en `recovery_pending`, el handler debe estar
obligado por contrato a ejecutar primero una consulta por identidad, como ya hacen
`OdooCollectionReconciliationPort.findByCommandOrReference` y `_existingPaymentApplied`
(`sale_runtime_adapters.dart:304-358, 533-575`). En `theos_pos` eso es disciplina de cada
handler, no un requisito del procesador.

**Matiz, para no acusar de más:** en Orbi **ya está implementado**.
`orbi_runtime/lib/src/sync/operations_sync_job.dart:131-145` llama a `adapter.reconcile`
antes de despachar cualquier fila `retry_safe` o en `recovery_pending`, y sólo despacha si
la reconciliación devuelve `OperationNotApplied`. D7 queda entonces como deuda **de
`theos_pos`**, no de las dos apps.

Y hay que decir lo incómodo: **esa reconciliación, por buena que sea, no cierra el
escenario B**. Consulta por UUID, y cuando el reintento nace de un tiempo de espera
agotado la transacción original sigue viva y sin confirmar, así que la consulta no puede
encontrarla. Ninguna comprobación *previa* del cliente puede cerrar una carrera que se
resuelve en la base; sólo la puede cerrar un índice único (D1) o un candado (D2).

---

## 4. Impuestos y saldos — cuál manda y cómo se detecta la diferencia

### Lo que hay hoy (VERIFICADO)

**Manda el servidor, y de forma inequívoca.** La factura no se arma con importes enviados
por el cliente: `_l10n_ec_pos_create_invoice_with_number` llama al nativo
`_create_invoices()` sobre las líneas del `sale.order` que ya están en Odoo
(`sale_order.py:1503-1508`). El cliente aporta número, fecha y clave; **nunca los montos**.
La firma del endpoint (`sale_order.py:579-581`) no tiene parámetro de total.

Y hay un detector indirecto de divergencia, que funciona mejor de lo que parece: el wizard
exige, dentro del mismo savepoint, que toda línea de pago tenga asiento posteado y que el
residual de la factura quede en cero
(`models/sale_order_payment_wizard.py:89-93`); el endpoint directo exige lo propio antes de
aceptar un replay (`sale_order.py:1425-1435`). Si el cálculo local de impuestos hubiese
producido un total menor que el del servidor, los pagos enviados no cubren el residual y
toda la operación revierte. **El descuadre no pasa en silencio: falla cerrado.**

El cálculo local vive en
`theos_pos_core/lib/src/services/sales/order_totals_calculator.dart:66-135` y suma los
campos de línea (`priceSubtotal`, `priceTax`, `priceTotal`) — no recalcula el impuesto,
agrega lo que la sincronización trajo.

### Qué falta

1. **El comprobante ya está impreso cuando se detecta.** El fallo ocurre al sincronizar,
   no al emitir. El cliente se llevó un papel con un total calculado localmente; si diverge,
   el papel está mal y no hay factura que lo respalde.
2. **La clave de acceso no ata el importe.** `SRIKeyGenerator.generateAccessKey`
   (`odoo_sdk/lib/src/utils/latam/sri_key_generator.dart`) la calcula con fecha, tipo de
   documento, RUC, ambiente y número. El servidor verifica que su clave coincida con la
   impresa (`sale_order.py:1555-1559`), lo que valida identidad y fecha — **no montos**.
3. **La asimetría entre las dos apps.** Orbi sí compara importes al reconciliar
   (`sale_runtime_adapters.dart:568-575, 304-358`); `theos_pos` no compara nada al
   sincronizar. El mismo hueco tiene dos tratamientos distintos según la app.
4. `_pos_completed_invoice_action` (`sale_order_payment_wizard.py:45-61`) acredita una
   operación previa comparando diario, número, fecha, clave y estado — **no importe**. Un
   replay cuyo total cambió entre intentos se aceptaría como el mismo.

### Decisión propuesta — **D8** (PROPUESTA)

El cliente envía su total esperado (`expected_amount_total`, en unidades menores) junto con
el resto de la identidad fiscal, y el servidor lo compara contra `invoice.amount_total`
antes de postear; si difiere, revierte con un error tipado `total_mismatch` en vez de emitir.
Así el descuadre se detecta **antes** de que exista documento, y el mensaje dice qué
catálogo local está desactualizado.

- **Riesgo:** una diferencia legítima de redondeo por moneda tumbaría cobros válidos. La
  comparación tiene que ser en unidades menores con la precisión de la moneda de la factura,
  no con `float`, y el repositorio ya tiene el patrón: `MoneyRounding` en el cliente y
  `currency_id.is_zero` en Odoo.
- **Prueba:** desincronizar a propósito un impuesto en el catálogo local y comprobar que el
  cobro se rechaza con `total_mismatch` y no deja factura.

### Decisión propuesta — **D9** (PROPUESTA, cliente, barata)

Antes de imprimir, `theos_pos` debe verificar que el catálogo de impuestos y la posición
fiscal usados no estén vencidos respecto de la última sincronización, y negarse a emitir
offline con un catálogo cuya antigüedad supere un umbral configurado por punto de cobro.
Un impuesto caducado en el dispositivo es la vía más probable a un descuadre, y hoy nada
lo mira.

---

## Verificaciones contra instancia — estado

Medidas sobre **ERP2** (`erp2.tecnosmart.com.ec`, Odoo 19.5.1.3) el 2026-09-11, sólo
lectura por JSON-2. No se escribió nada y no se tocó `newerp`.

| ID | Qué comprobar | Estado |
|---|---|---|
| V-1 | Duplicados de `l10n_ec_pos_client_op_uuid` en `account.move` | ✅ **RESUELTA: cero.** No hay ni una factura con identidad POS en ERP2 (0 filas con el campo no nulo). Y 0 ventas con dos facturas vigentes sobre 686 facturadas. **D1 se puede crear sin limpiar nada** |
| V-2 | `pg_indexes` sobre `collection_config`, `sale_order`, `collection_session` | ⏳ **Abierta.** No es consultable por RPC; exige `psql` en el servidor de ERP2. Nota: el campo `numbered_by_client` sí existe en `account.journal` de ERP2, luego el addon está instalado y actualizado |
| V-3 | ¿Algún `collection.config` comparte `journal_id`? ¿Algún diario `numbered_by_client`? | ✅ **RESUELTA, y el resultado es el contrario del esperado:** **ningún** diario de venta tiene `numbered_by_client` (3 de 3 en `False`) y **ningún** `collection.config` tiene `journal_id` ni `device_uuid` (5 de 5 vacíos). El índice no puede colisionar porque no hay nada que indexar. La exclusividad del punto 2 está **sin estrenar**, no verificada |
| V-4 | Prueba de concurrencia real: dos `action_pos_confirm_and_invoice` solapados | ⏳ **Abierta, y es la única que falta para cerrar el punto 1 con evidencia de instancia.** Crea facturas reales en ERP2, así que requiere aviso y visto bueno previo. El mecanismo ya está demostrado por código (`sequence_mixin._locked_increment`), pero medirlo daría el número exacto de la ventana |
| V-5 | ¿`action_pos_confirm` es idempotente sobre una venta ya en `sale`/`done`? | ⏳ **Abierta.** Decide si la excepción de `order_confirm` del punto 3 es un riesgo vivo o sólo una inconsistencia de criterio |
| V-6 | Comparar totales locales contra los de Odoo con varios impuestos y posición fiscal | ⏳ **Abierta.** Mide si el hueco del punto 4 es teórico o ya está ocurriendo |

---

## Pruebas entregadas

`theos_pos_core/test/operations/offline_fiscal_identity_gap_test.dart` — siete pruebas que
usan la cola real (`OfflineQueueDataSource` sobre Drift en memoria) y el procesador real,
sin dobles. **Seis están marcadas `GAP:` y hoy pasan a propósito**: fijan el comportamiento
inseguro para que la corrección tenga que romperlas. La séptima fija el comportamiento sano
de `manual_after_ambiguous` para que una reclasificación futura no lo debilite en silencio.

No se escribió una prueba que falle hoy porque cinco agentes más están escribiendo en este
árbol y `make verify` es la compuerta de todos; una prueba roja dejada a propósito
bloquearía trabajo ajeno y se leería como un fallo, no como un hallazgo.

```
cd theos_pos_core && dart test test/operations/offline_fiscal_identity_gap_test.dart
00:00 +7: All tests passed!
```

---

## Efecto sobre `B01`

**`B01` no puede marcarse `done`.** Sus criterios exigen contrastar contra el despliegue
real de ERP2 y resolver numeración exclusiva, fecha/clave fiscal y cobro idempotente. De
los cuatro puntos:

| Punto | Estado |
|---|---|
| 1 · Identidad | **Hallazgo crítico confirmado, y reenfocado.** No se pueden crear dos facturas con el mismo número (el núcleo y el SRI lo impiden). **Sí se pueden crear dos facturas distintas, con números distintos, ambas válidas, para una sola venta**, por el camino numerado por el servidor — que es el único configurado hoy en ERP2 |
| 2 · Numeración | **La garantía entre dispositivos está declarada pero vacía en ERP2** (ningún punto de cobro tiene diario ni `device_uuid`); **hueco abierto** en el contador local, que puede reiniciarse |
| 3 · Respuesta incierta | **Mecanismo correcto, clasificación incoherente** — cuatro comandos se autorreenvían sin identidad |
| 4 · Importes | **Manda el servidor y falla cerrado**; falta detectar antes de imprimir y comparar importes en el replay |

D1 y D2 tocan el backend y, según la regla del repositorio, requieren propuesta
origen/destino/riesgo/prueba **y autorización expresa antes de aplicar**. Queda aquí la
propuesta; no se aplicó nada. D3, D5, D6, D7 y D9 son del lado cliente y tampoco se
aplicaron: este documento es análisis, no implementación.

El orden que recomiendo, ya con V-1 y V-3 medidas:

1. **D1 ya, sin condiciones previas.** V-1 dio cero: no hay nada que limpiar y el índice
   es lo único que corta el escenario B en la base. Es la decisión con mejor relación
   entre riesgo y protección de todo el documento.
2. **D2 junto con D1.** D1 protege entre pedidos, D2 dentro del pedido.
3. **Configurar ERP2**: marcar `numbered_by_client` en el diario de emisión y asignar
   `journal_id` y `device_uuid` a cada `collection.config`. Sin eso, ni la protección del
   escenario A entra en juego ni `theos_pos` puede emitir offline, y los índices de
   exclusividad del punto 2 siguen sin restringir nada.
4. **D6 y D7** (deuda de `theos_pos`; en Orbi D7 ya está).
5. **D4** para el contador fiscal.

Y una advertencia de alcance: **D1 y D2 no dejan de hacer falta aunque se configure la
numeración por cliente.** Basta con que un diario quede sin marcar —o que se añada uno
nuevo— para que el escenario B vuelva a estar abierto. La protección del escenario A
depende de una casilla de configuración; la de D1 no depende de nadie.
