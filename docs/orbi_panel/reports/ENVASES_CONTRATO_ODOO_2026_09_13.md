# Envases: qué ofrece Odoo para ENV-02, 03, 06 y 07

Sólo lectura sobre `dev_odoo20/addons/l10n_ec_stock_envases`, 13-sep-2026. El trabajo quedó en
pausa porque el dueño priorizó el marco general de la app. Esto es lo que se encontró, para
retomarlo sin repetir la lectura.

| Pantalla | Qué ofrece Odoo | Veredicto |
| --- | --- | --- |
| ENV-02 movimientos | No hay libro propio. `l10n_ec.envases.panel` (`models/envases_panel.py:61`) es sólo saldo actual. `stock.location.envases_rol` (`models/stock_location.py:66`) permite filtrar `stock.move.line` nativo por punto. Lectura por ACL nativo. | Se construye sólo en la app. Cómo agrupar «movimientos vinculados» (por `picking_id`/`origin`) lo decide Orbi. |
| ENV-03 tránsitos y custodia | Tránsito: `stock.quant` con `envases_rol='transito'` (`envases_panel.py:225`). Custodia: `l10n_ec.envases.saldo.tercero` (`models/envases_saldo_tercero.py:81`), grupo `group_envases_user`. El asistente de custodia es todo o nada (`wizards/wizard_custodia.py:173-212`): no existe un registro «pendiente». | Se construye sólo en la app, con la advertencia de la bodega de tránsito de Mepriga. |
| ENV-06 recepción/devolución | `l10n_ec.stock.envases.wizard.custodia`, operación `devolucion` (`wizards/wizard_custodia.py:30`): líneas con `cantidad` y `cantidad_danada` (262-273), `action_confirmar()` (78). | **Ambiguo.** Si la lámina es la devolución de custodia, se construye hoy. Si es la recepción de un tránsito con remanente parcial, el asistente prohíbe backorders y habría que usar las transferencias nativas. |
| ENV-07 compra/venta de recipiente | El manifiesto depende sólo de `stock` y deja lo comercial a «puentes opcionales» que no existen. `product_template.py:60-79,148` trae campos y un ayudante que nadie llama. | **Falta en Odoo:** no hay vínculo factura↔recipiente. |

- **Mepriga, bodega de tránsito única con el 49,5 % del inventario:** el modelo exige origen
  y destino por ubicación de tránsito, únicos por par (`stock_location.py:81-102`). Afecta a la
  columna «En tránsito» de ENV-01 (`envases_panel.py:257-299`) y a ENV-03.
- **`saldo.tercero` sin tercero:** es a propósito (`envases_saldo_tercero.py:40-57,99-103`). La
  fila debe decir «sin cliente asignado», no esconderse.
