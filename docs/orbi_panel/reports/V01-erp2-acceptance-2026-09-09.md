# V01 · aceptación ERP2 V06c · 2026-09-09

Estado: evidencia V06c capturada para el destino ERP2 permitido, con fixtures
conservadas para auditoría. Este informe no contiene claves, contraseñas ni el
contenido de la evidencia JSON.

## Alcance y fixtures

- Destino: `https://erp2.tecnosmart.com.ec`, base `erp2_tecnosmart_com_ec`.
- Prefijo exacto: `ORBI-E2E-f1b48c2d7e95`.
- Fixtures V06c: contado `sale.order 1942`, crédito `1943`, mixto `1944` y FSC
  `1945`.
- Infraestructura de caja comprobada por contrato: sesión `18`, configuración
  `5`, diario `30` y método de pago entrante `44`.
- Términos: contado/FSC `1`, crédito `2` y mixto `26`.
- Actores separados: vendedor, cajero, supervisor y bodega. Bodega usa a
  Miguel Mora (`miguel.mora`, usuario `34`); no se usa `admin` como sustituto.
- Cleanup: `retain-prefixed-fixtures`; los documentos se conservan para
  auditoría y no se archivan, desvinculan ni marcan `active=false`.

El destino exacto, la base, el prefijo, los cuatro actores, la compañía, los
partners, términos, sesión, configuración, diario y método se validan antes
de cualquier mutación. Los IDs transient de aprobación FSC y de los wizards de
cobro no son fixtures: nacen o se descubren dentro de su flujo nativo.

## Estados server-side resumidos

Los cuatro `sale.order` terminaron en `sale`; cada flujo tuvo factura
`posted` y dos tramos de picking (`internal` y `outgoing`) en `done`. El tramo
`outgoing` conserva `partner_venta_id == partner_id` y responsable de bodega.

| Flujo | Término | Factura | Pago nativo | Residual | Despacho |
| --- | --- | --- | --- | ---: | --- |
| Contado (1942) | 1 | `posted` | `posted`, `paid` | `0.00` | interno + salida `done` |
| Crédito (1943) | 2 | `posted` | sin pago inmediato | `0.55` / `not_paid` | interno + salida `done` |
| Mixto (1944) | 26 | `posted` | `posted`, `partial` | `0.44` | interno + salida `done` |
| FSC (1945) | 1 | `posted` | `posted`, `paid` | `0.00` | interno + salida `done` |

Mixto cobra sólo el importe inmediato contractual (`0.11` en la fixture), por
el wizard nativo de factura existente; no inventa identidad fiscal offline ni
genera picking antes del cobro. Contado verifica pago real y línea nativa,
crédito conserva factura impaga y controles de cupo/mora, y ambos recorren la
preparación/entrega con acciones públicas de stock.

FSC conserva dos puertas distintas: la solicitud comercial se resuelve según
el flujo de confirmación y la solicitud FSC viva se aprueba con
`sale.order.action_l10n_ec_aprobar_fsc`. Antes del pago, el intento de bodega
sobre la salida al cliente debe ser rechazado por el candado de factura
impaga; después del cobro nativo, la misma salida puede validarse. El harness
no escribe cantidades, no usa `skip_backorder` y no llama la reparación
administrativa `action_regenerar_despacho_contado`.

## Guardas y modos de panel

Los RPC operativos están fijos en el contrato allowlisted del harness. La
preparación y entrega usan `stock.picking.action_assign`,
`stock.picking.action_copiar_quien_retira` y `stock.picking.button_validate`;
la respuesta ambigua sólo se resuelve con una lectura server-side posterior.

La evidencia remota V06c corresponde al modo con panel. El modo
`without-panel` está validado localmente por contrato (`counter_policies` igual
a `null` como fallback), sin desinstalar módulos ni mutar ERP2; no se afirma una
corrida remota sobre una base sin panel. La presencia de un módulo instalado
por sí sola no acredita políticas efectivas: un `Map` de
`counter_policies` es la señal de políticas del panel.

`newerp` no fue consultado ni modificado. Tampoco se alteraron bases, órdenes,
facturas, pickings o pagos fuera de las fixtures explícitas V06c.

## Verificación local

Compuerta ejecutada el 2026-09-09, sin red:

- `flutter analyze` en `theos_pos_core`, `orbi_runtime` y `theos_panel`: OK,
  sin issues.
- Suites completas: `theos_pos_core` 605 tests, `orbi_runtime` 119 y
  `theos_panel` 135; el panel conserva un único skip opt-in del E2E remoto.
- Focales offline/sync/atomicidad: core 9, runtime ventas/atomicidad 23,
  runtime sync 16, panel colección 6 y panel sync 2; todos OK.
- `git diff --check`: OK.

Los builds registrados en la validación multiplataforma V02 son web, macOS e
iOS OK; APK y AAB release OK usando el workaround documentado de Flutter
(`--config-only` seguido de `--no-pub`). Esta actualización no ejecutó builds
ni el stage remoto.

## Proveniencia

- App: `43f3be3` (`test(orbi): deliver every sales flow through native stock`),
  con los contratos FSC/credit y UI/login en sus commits antecesores.
- Odoo local revisado: `03937c565` (`fix(collection-pos): persist client
  payment identities`), con los cambios previos de UUID, despacho idempotente y
  cierre de colección en `a2ba9a53e`, `c714ac9d8` y `10a7b70d4`.
- El checkout Odoo conserva cambios ajenos no incluidos en este informe; no se
  hizo commit ni despliegue desde esta actualización.

Evidencia externa local, referenciada sólo por ruta y no incorporada al repo:

- `/Users/elmers/.config/tecnosmart/orbi_erp2_v06c_evidence.json`
- `/Users/elmers/.config/tecnosmart/orbi_erp2_v06c_fixtures.env`
- `/Users/elmers/.config/tecnosmart/orbi_erp2_v06c_headless.sh`
