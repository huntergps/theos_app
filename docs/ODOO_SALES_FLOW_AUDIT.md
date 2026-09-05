# Auditoría de ventas y candados · 2026-09-05

Estado: en curso. El dueño precisó los cuatro flujos y sus invariantes; esta
auditoría no certifica todavía su cumplimiento por la app actual ni el
ciclo de cobro/cierre real. Fuente custom examinada en el árbol
`/Users/elmers/Documents/dev_odoo20`, HEAD observado `de6bfc8da`; el árbol es
compartido y continúa cambiando. ERP2 y el checkout local no son equivalentes
por el mero hecho de usar la versión 19.5.

## Los cuatro flujos: criterio de aceptación confirmado por el dueño

Puerta común: **aprobación comercial antes de los cuatro recorridos**.
Confirmar deja el pedido bloqueado. Los clasifican el término de pago y, en
Facturar sin Cobro, la aprobación adicional; no se crea un campo de tipo de venta.

| Flujo | Condición | Nacimiento del despacho | Control obligatorio |
| --- | --- | --- | --- |
| Crédito puro | Solo cuotas a plazo | Al confirmar | Cupo y mora antes de confirmar |
| Contado puro | Cuota inmediata, sin cuotas a plazo | Al cobrar en Caja | El cobro es condición para generar el despacho |
| Mixto | Cuotas inmediatas y a plazo | Al pulsar Generar Despacho | Lo vencido a la fecha |
| Facturar sin Cobro | Contado con aprobación adicional | Al aprobarse | Entrega final exige 100 % pagado |

`is_cash` e `is_credit` NO son excluyentes: ambos verdaderos representan mixto.
La rama mixta debe distinguirse antes de aplicar una regla de contado puro.
`is_cash_sale` es una marca heredada usada por el reporte «Facturas Contado
del Cierre»; no clasifica el flujo ni sirve para medir ventas de contado.
Momento de factura: crédito/mixto al confirmar; contado al cobrar; contado
con FSC al aprobarse esa autorización.

- Facturar sin Cobro emite factura, genera despacho y **enciende** el candado de
  pago. Autoriza preparar, no entregar sin cobrar.
- Preparar y mover a zona de salida no exige cobro. El control actúa en el
  último movimiento a **Customers**, preservando los pasos de preparación.
- Crédito y mixto emiten automáticamente la factura al SRI al confirmar;
  contado puro no. No confundir generación/publicación con autorización fiscal
  efectiva: las pruebas deben verificar el estado correspondiente.
- El dueño informa validación E2E en ERP2 el **18 de agosto**, con vendedor,
  supervisor, bodeguero y cajero operando por pantalla, contrastada aparte por
  SQL. Es un antecedente aportado por el dueño; falta localizar sus evidencias
  y contrastar el código/app actuales, no repetir una conclusión a ciegas.

Evidencia histórica localizada en
`dev_odoo20/.claude/memory/flujos-de-venta-son-cuatro-y-el-control-esta-en-el-ultimo-paso.md`
y `bitacoras/bitacora-2026-08-17.md`: pedidos VENTA127519 (crédito),
VENTA127520 (contado), VENTA127518 (mixto) y VENTA127509/FSC00015 (FSC).
La memoria registra resultados e IDs, pero no conserva la consulta/salida SQL
independiente literal. Esto no sustituye la nueva validación de la app.

## Clasificación técnica y escenarios del panel

El código de `l10n_ec_sale_credit/models/account_payment_term.py:29` distingue
tres combinaciones: contado puro, mixto y crédito puro. Corrige el cálculo de
`l10n_ec_sale_payment_term`: `nb_days == 0` no basta; la cuota inmediata también
requiere `delay_type == 'days_after'`. El cálculo nativo de vencimientos está en
`odoo/addons/account/models/account_payment_term.py:304`.

| Modalidad observada | Condición | Control que la app debe conservar |
| --- | --- | --- |
| Contado puro | `is_cash` y no `is_credit` | No consume cupo por esa venta, pero la mora puede exigir aprobación. Cobro exigible antes de liberar entrega. |
| Mixto | `is_cash` y `is_credit` | Control de crédito y cuota inmediata/vencida; no cobrar automáticamente el saldo futuro como si todo fuera contado. |
| Crédito puro | no `is_cash` y `is_credit` | Aprobación y cupo/mora; factura automática con variante postfechada cuando corresponde. |

Fuentes: `sale_credit/models/sale_order.py:315,694,1005` y
`collection_box/wizards/sale_order_payment_wizard.py:365,2450`.
La facturación sin cobro tiene grupo y aprobación propios
(`collection_box/models/sale_order.py:736`) y constituye el cuarto **recorrido**
confirmado por el dueño. La investigación anterior confundía tres combinaciones
de indicadores con el número de flujos; esa conclusión queda corregida por la
matriz de aceptación anterior. La facturación postfechada no reemplaza a FSC.

Enterprise `account_followup/models/res_partner.py:94` calcula cartera desde
apuntes/residuales con contexto de compañía. Su indicador `total_overdue` no
debe reemplazar sin contraste la política custom `_credit_overdue_status`.
No se encontró allí una cuarta rama de confirmación de ventas.

Los casos del panel (`docs/DISENO_COLLECTION_BOX_LIGHT.md:425`) son:

- Solís: vendedor prepara; caja recupera/cobra; vendedor entrega.
- Mega Primavera: caja busca/escanea, vende y cobra.
- TecnoSmart: venta consultiva en Ventas; caja recupera la orden pendiente.
- Vendedor de mostrador: prepara a precio de lista, sin permisos de caja.

El acceso al panel y el permiso de caja son diferentes. La app debe soportar
estos recorridos sin exigir la instalación del panel. Negociar precio, validar
una entrega y cobrar no son permisos implícitos de una pantalla simplificada.

## Hallazgos relevantes para la app

1. **Cadena POS distinta de la nativa.**
   `collection_box_pos/models/sale_order.py:326` escribe
   `credit_check_bypassed=True` y `state='approved'` antes del `super`.
   El panel usa `set_approved()` → `confirm_approved_order()` y conserva las
   acciones de aprobación (`collection_panel/models/collection_panel.py:2468`).
   Que `skip_credit_check` esté protegido por grupo no demuestra equivalencia
   de toda la cadena comercial. No se ha modificado este backend ni se ha
   trasladado lógica entre módulos durante esta auditoría.
2. **Falso éxito local ante rechazo de Odoo.** La confirmación genérica de la
   app y el replay offline ignoraban la respuesta `success:false`. Corregido
   localmente: exigir `success:true`, identidad coincidente y estado `sale/done`
   antes de limpiar la confirmación pendiente. Una acción/wizard pendiente no
   equivale a éxito. Tres pruebas del repositorio fallaron al desactivar la
   guarda y pasaron al restaurarla; el replay también tiene casos negativos.
3. **Inicio de sesión restringido.** La prueba real de Sebastián encontró HTTP
   403 al consultar `ir.model.data` durante sincronización de permisos. La
   resolución inicial usa ahora `res.users.all_group_ids` y
   `res.groups.get_external_id`, conservando `has_group` como autoridad y
   publicación atómica del snapshot. No se cambiaron grupos de operadores.
4. **Divergencia del árbol fuente.** El commit `abbc8f911` eliminó
   `stock_conversion/models/politica_cobro.py`, pero
   `despachos/models/politica_cobro.py:31` todavía lo importa. Es un hallazgo
   local; no demuestra por sí solo que ese módulo esté activo o roto en ERP2.
   No se desplegará ese conjunto por inferencia ni se restaurará código viejo
   sin revisar el refactor vigente.

## Pruebas y límites

- Claves de pruebas creadas con autorización para uid 43 y uid 23; identidad
  JSON-2 verificada y secretos guardados en el llavero, no en este documento.
- Ambos usuarios acceden al contrato base `pos_app_capabilities` del punto 5
  con `counter_policies=null`: escenario ERP2 sin panel.
- La sesión existente de Jacqueline (13) no se cerró ni se alteró.
- Navegación E2E real: Sebastián uid 43, 1/1 en 14 s
  (`/tmp/theos_erp2_sebastian_operator_20260905.log`); Jacqueline uid 23,
  1/1 en 12 s (`/tmp/theos_erp2_jacqueline_operator_20260905.log`). Incluye
  identidad esperada, restauración aislada, menús y acción principal de su rol.
  El harness anterior esperaba acciones de supervisor en una pantalla de
  operador; se corrigió para verificar su botón real, no omitir esa prueba.
- Regresión: 1072/1072 (`/tmp/theos_role_flow_regression_20260905.log`). Análisis
  estático sin incidencias después de retirar un import de los tests nuevos
  (`/tmp/theos_role_flow_analyze_fixed_20260905.log`).
- No confundir acceso/restauración con venta, factura, pago, despacho o cierre
  comprobados. Los recorridos anteriores usaron almacenes locales temporales,
  sin poblar ni modificar datos comerciales de los operadores.
- Newerp permanece excluido. Cualquier traslado panel → caja/POS requiere
  análisis resumido y autorización específica del dueño.
