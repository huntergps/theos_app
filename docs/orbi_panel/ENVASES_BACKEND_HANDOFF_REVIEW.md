# Revisión de handoff backend: Envases

Fecha de revisión: 2026-09-11. Alcance: lectura de fuentes locales únicamente.
No se consultó una BD Odoo, no se instaló/actualizó el módulo y este documento no
demuestra disponibilidad instalada.

## Fuente inspeccionada

La ruta singular solicitada no existe. La implementación encontrada, acotando la
búsqueda por nombre, es:

`/Users/elmers/Documents/dev_odoo20/addons/l10n_ec_stock_envases`

Evidencia adicional de diseño: `/Users/elmers/Documents/dev_odoo20/docs/especificaciones/envases/CONTRATO_PARA_ORBI.md`,
`DISENO_UBICACIONES.md` y `ESTADO.md`. El contrato de Orbi declara expresamente
que el módulo aún no estaba instalado en su estado de referencia; esta revisión
no vuelve a comprobar una BD. El addon declara sólo `stock` en
`__manifest__.py` (`depends`, versión `19.5.1.0.0`); no declara Caja/POS/HR,
ventas ni compras como dependencia.

## Se puede integrar ya (sujeto a verificar instalación, ACL y configuración)

- **Fuente de saldo:** no crea un saldo/modelo físico paralelo. Los envases son
  productos y el saldo se lee de `stock.quant` en ubicaciones con
  `envases_rol`; el dominio común está en
  `models/stock_location.py:_envases_dominio_existencias()`.
- **Dimensiones físicas:** `stock.location` añade roles `sede`, `danados`,
  `custodia_cliente`, `custodia_proveedor` y `transito`, además de tercero y
  origen/destino. Hay restricción de coherencia y unicidad por par ordenado de
  tránsito (`models/stock_location.py`, `_transito_par_unico`).
- **Tránsito por sentido:** `stock_warehouse.py` crea ubicaciones `transit`
  por origen→destino y reapunta las rutas nativas; busca ubicaciones archivadas
  y reactivas. Hay pruebas fuente para ambos sentidos, parciales y conservación
  del total en `tests/test_transito_por_sentido.py`.
- **Panel nativo:** `l10n_ec.envases.panel` es una vista SQL `_auto=False`,
  agrupada por producto/empresa, con total, sede, dañados, custodias y tránsito.
  Sus botones abren `stock.quant` usando el mismo dominio vivo
  (`models/envases_panel.py`; `views/envases_panel_views.xml`). Menú y acción
  pública del panel: `views/menus.xml` y `action_envases_panel`.
- **Custodia/devolución:** el wizard crea y valida transferencias nativas
  `stock.picking`/`stock.move`, separa devolución buena y dañada, admite
  cantidades parciales y no cambia propiedad al usar ubicaciones `internal`
  (`wizards/wizard_custodia.py`).
- **Contenido/presentación:** el producto tiene relación contenido→envase,
  factor por unidad, interruptor explícito al vender e intercambiables; usa la
  conversión UoM de Odoo y no comparte saldos por omisión
  (`models/product_template.py`). Esto es configuración y cálculo local, no un
  puente comercial completo.
- **Permisos nativos:** existen grupos `group_envases_user` y
  `group_envases_manager`, con implicación de grupos de Inventario, y pruebas
  de operación sin Caja, separación usuario/gerencia y multiempresa
  (`security/envases_security.xml`, `tests/test_permisos.py`). `ESTADO.md` añade
  una condición operativa importante: el candado de `l10n_ec_stock_base` y las
  listas de envío/recepción del almacén pueden ser necesarios para validar
  cualquier transferencia; el grupo de este addon no los sustituye. La empresa
  y ubicación efectivas todavía deben verificarse en una BD instalada.

## Gaps frente al contrato Orbi

1. **Binding Orbi público/versionado:** no hay `controllers/`, rutas HTTP ni
   esquema JSON/versionado específico para Orbi. Esto no significa que los
   modelos sean inaccesibles: los métodos públicos de modelos Odoo pueden ser
   invocados por RPC respetando ACL/reglas. Lo que falta verificar/diseñar es
   una superficie Orbi estable, documentada y probada que exponga el dominio y
   las acciones correctas sin depender de detalles de la UI.
2. **Binding offline/replay de Orbi:** el contrato de Orbi exige `commandId`, actor,
   dispositivo, precondiciones, versión, resultado incierto y replay atómico.
   No hay evidencia de ese binding en el addon. Las operaciones nativas de
   Odoo sí conservan trazabilidad de `stock.move`/`stock.move.line`, documento
   origen y actor; no hay que duplicar esa auditoría en Orbi. La creación de
   ubicaciones con búsqueda previa y el constraint de tránsito protegen
   duplicados de configuración, pero no demuestran idempotencia atómica de un
   comando offline completo bajo concurrencia.
3. **Toma física y reconciliación:** el contrato de Orbi deja pendientes reglas
   para conciliar facturas históricas con una toma física y para la factura por
   no devolución. El addon aporta el stock nativo y sus transferencias, pero no
   se debe inventar desde esta revisión un snapshot `needs_reconcile` ni una
   semántica de ajuste que el contrato aún no decidió.
4. **Puentes comerciales opcionales:** compra, venta y facturación nativas de
   Odoo siguen siendo capacidades reutilizables del ERP; este addon declara no
   depender de ellas. Lo que no está probado aquí es el puente específico que
   determine cuándo una factura/venta de envases actualiza existencias o cómo se
   evita doble conteo con una toma inicial.
5. **Formato de acceso:** `security/ir.access.csv` usa literalmente la cabecera
   `id,name,model_id,group_id/id,operation,domain`. Se documenta como evidencia
   del árbol; no se califica como inválido ni se compara con otro formato sin
   confirmar el cargador Odoo 19.5 de este checkout.

## Decisión para Orbi

Puede prepararse una lectura futura del panel/detalle y del wizard sólo después
de confirmar instalación, configuración de almacenes (`controla_envases`),
grupos efectivos, listas de envío/recepción y permisos en Odoo. El saldo,
trazabilidad y transferencias deben reutilizar los modelos nativos. No habilitar
replay offline ni prometer una superficie Orbi estable hasta contar con una
matriz/API versionada, idempotencia atómica probada y las decisiones pendientes
de toma física/facturación.

## Verificación realizada

Se inspeccionaron manifest, modelos Python, wizard, XML de vistas/acciones/menús,
seguridad y nombres de pruebas con `find`, `sed` y `rg`. No se ejecutaron tests
contra servidor ni comandos Odoo; por tanto las pruebas presentes son evidencia
de código fuente, no evidencia de que el módulo esté instalado o disponible.
# Corrección de custodia por tercero — 11/09/2026

Prevalece sobre cualquier desglose anterior por tercero de ubicación:

- Una ubicación compartida de clientes y otra de proveedores por bodega.
  `envases_partner_id` de ubicación NO identifica al tenedor en Orbi.
- El tercero procede de `stock.picking.partner_id`.
- Saldos individuales: `l10n_ec.envases.saldo.tercero`, derivado de líneas de
  movimiento hechas (`state = done`), con entregas menos devoluciones.
- Totales agregados de custodia: siguen en `l10n_ec.envases.panel` desde quants.
  Su lector/caché agregado no reparte cantidades entre clientes ni proveedores.

Evidencia local revisada por agente: `models/envases_saldo_tercero.py:97-145`,
`wizards/wizard_custodia.py:166-180`, `models/envases_panel.py:46-105` dentro de
`addons/l10n_ec_stock_envases` del repositorio Odoo.

Desajustes encontrados para el agente backend, no corregidos desde Orbi:
`models/envases_panel.py:155-165` todavía agrupa el detalle por
`envases_partner_id`; Orbi no debe reproducir ese desglose. La restricción en
`models/stock_location.py:113-138` tampoco impone que dicho campo permanezca
vacío en ubicaciones de custodia. La decisión del dueño sigue siendo vacío.
