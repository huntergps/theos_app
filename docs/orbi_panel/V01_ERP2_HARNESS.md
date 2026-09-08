# V01 ERP2 harness · contrato de ejecución

`theos_panel/erp2_harness.dart` contiene las guardas, el plan de cuatro
recorridos y el ejecutor JSON-2. `integration_test/orbi_erp2_test.dart` lo usa
únicamente de forma opt-in. Importar la librería no hace red; el ejecutor no
alcanza un método mutante si falla el preflight local o el preflight server-side.

El destino permitido es exactamente `https://erp2.tecnosmart.com.ec` por HTTPS.
`newerp`, cualquier puerto/ruta/query alterna y cualquier login `admin` son
rechazados. Los cuatro actores son credenciales independientes: vendedor,
cajero, supervisor y bodega. Una cuenta con más de un grupo no sustituye la
identidad del actor esperado.

## Variables externas

Ninguna clave se escribe en código, argumentos, logs o evidencia; el harness usa
API keys del stage opt-in y no solicita contraseñas de actores.
Los siguientes nombres solo identifican variables; sus valores se entregan al
proceso por el gestor de secretos del entorno.

### Destino y guardas

| Variable | Uso |
| --- | --- |
| `ORBI_ERP2_SERVER_URL` | Debe ser la URL HTTPS exacta de ERP2. |
| `ORBI_ERP2_DATABASE` | Base ERP2; nunca `newerp`. |
| `ORBI_ERP2_PANEL_MODE` | `with-panel` o `without-panel`; el conector se verifica con `collection.config.pos_app_contract_version` y el panel por `counter_policies` Map/null. |
| `ORBI_ERP2_ENABLE_WRITES` | Debe ser `I_UNDERSTAND_ORBI_E2E_WRITES`. |
| `ORBI_ERP2_RUN_WRITES` | Segundo consentimiento, con el mismo valor, para alcanzar mutaciones. |
| `ORBI_ERP2_WRITE_PREFIX` | `ORBI-E2E-` seguido por al menos ocho hexadecimales. |
| `ORBI_ERP2_CLEANUP_MODE` | Debe ser `retain-prefixed-fixtures`; conserva los artefactos para auditoría. |
| `ORBI_ERP2_EVIDENCE_FILE` | Archivo local para evidencia redactada. |
| `ORBI_ERP2_AUDIT_API_KEY` | API key read-only del preflight server-side. |

### Actores

Para cada valor de `SELLER`, `CASHIER`, `SUPERVISOR` y `WAREHOUSE` se requieren:

* `ORBI_ERP2_<ACTOR>_LOGIN`
* `ORBI_ERP2_<ACTOR>_USER_ID`
* `ORBI_ERP2_<ACTOR>_API_KEY` (solo el stage de escritura)

### Fixtures e infraestructura

Cada flujo requiere `ORBI_ERP2_<FLOW>_ORDER_ID` y
`ORBI_ERP2_<FLOW>_REFERENCE`, con `FLOW` igual a `CASH`, `CREDIT`, `MIXED` o
`FSC`, más `ORBI_ERP2_<FLOW>_APPROVAL_ID` para la puerta de crédito común. Para
FSC el nombre de esa puerta común es
`ORBI_ERP2_FSC_COMMERCIAL_APPROVAL_ID` y requiere además un segundo
`ORBI_ERP2_FSC_APPROVAL_ID`, enlazado a la venta y a una categoría FSC. La
referencia debe comenzar por el prefijo de esta ejecución. FSC requiere además
`ORBI_ERP2_FSC_PAYMENT_WIZARD_ID` para cobrar la factura ya emitida.
El cobro posterior de la factura existente requiere
`ORBI_ERP2_FSC_PAYMENT_WIZARD_ID`, un wizard ya creado que apunte a esa venta;
si falta, el preflight bloquea antes de mutar.

Mixto requiere además `ORBI_ERP2_MIXED_PAYMENT_WIZARD_ID` y
`ORBI_ERP2_MIXED_CASH_AMOUNT`. El wizard debe apuntar a la venta mixta y sus
líneas persistidas deben sumar exactamente ese importe. Al confirmar la venta
mixta debe existir la factura, pero no un `stock.picking`; el wizard oficial
`l10n_ec_collection_box.sale.order.payment.wizard.action_apply_and_create_invoice`
persiste/cobra la parte inmediata y llama la generación nativa de despacho.
Después de esa llamada, y solo si el servidor ya creó el picking, bodega puede
usar `stock.picking.action_assign`. `action_regenerar_despacho_contado` queda
fuera del recorrido operativo.

Cobro contado requiere `ORBI_ERP2_CASH_SESSION_ID`,
`ORBI_ERP2_CASH_JOURNAL_ID` y `ORBI_ERP2_CASH_PAYMENT_METHOD_ID`.

No se aceptan nombres RPC por variables. El harness usa únicamente métodos
allowlisted y comprobados: `sale.order.action_pos_confirm`,
`sale.order.action_pos_confirm_and_invoice`,
`sale.order.action_l10n_ec_solicitar_facturar_sin_cobro`,
`sale.order.action_l10n_ec_aprobar_fsc`, `approval.request.action_approve`,
`collection.session.action_session_open`,
`collection.session.close_control_session_pos`,
`stock.picking.action_assign` y `stock.picking.button_validate`. Si falta un
ID o contrato server-side, el preflight termina antes de mutar.

La secuencia FSC confirma primero el contado; si `action_pos_confirm` deja
`approval_required`, se localiza la solicitud enlazada y supervisor la aprueba.
Luego vendedor solicita FSC, se localiza la segunda solicitud viva por venta y
categoría FSC, supervisor la aprueba y recién entonces se ejecuta
`action_l10n_ec_aprobar_fsc`. Nunca se aprueba ciegamente una solicitud común
como si fuera la FSC.

Para cobrar la factura FSC ya emitida se usa exclusivamente el wizard nativo
`l10n_ec_collection_box.sale.order.payment.wizard.action_apply`, cuyo ID debe
ser una fixture externa validada contra `sale_id`; no se crea un wizard ni se
adivinan sus líneas dentro del harness.

Los flujos normales deben producir sus `stock.picking` según el evento del
servidor. El harness nunca llama una acción de despacho inventada sobre
`sale.order`: cuando ya existe el picking, bodega puede preparar con
`stock.picking.action_assign`; no se entrega con `button_validate` durante este
recorrido FSC, porque la entrega debe seguir bloqueada hasta el pago total.

## Evidencia y replay

La clasificación se obtiene leyendo el término y sus líneas del servidor:
cuota inmediata (`delay_type=days_after` y `nb_days=0`) y cuotas futuras producen contado,
crédito o mixto; FSC es contado más su aprobación explícita. Nunca se usa
`is_cash_sale`.

Después de cada RPC se vuelve a leer `sale.order` y, cuando aplica, la solicitud
de aprobación. `success: true` o HTTP 200 no limpia una operación por sí solo.
Una excepción/timeout queda `ambiguous` hasta que la lectura server-side pruebe
el estado final; una respuesta rechazada queda `rejected` y puede reintentarse
según el contrato. Esto evita duplicar cobros tras una respuesta ambigua.

El recorrido FSC intenta `stock.picking.button_validate` con bodega antes del
cobro y exige rechazo server-side con factura residual; luego caja aplica el
wizard de factura existente y bodega valida de nuevo, verificando estado `done`.
Contado exige factura pagada y línea nativa `sale.order.payment` publicada;
crédito exige factura/despacho tras confirmar y conserva snapshot de cupo/mora;
mixto exige factura al confirmar y picking server-generated antes de preparar.

Los fixtures son datos ERP2 dedicados y se conservan para auditoría. El cleanup
`retain-prefixed-fixtures` solo vuelve a leer y registra los `sale.order` con el
prefijo; no archiva, no hace `unlink`, no escribe `active=false` y tampoco
intenta modificar `sale.order`, `account.move`, `stock.picking` ni pagos. La
retención/finalización fiscal queda bajo el procedimiento ERP2 de pruebas.

No se ejecutó el stage remoto de este cambio.
