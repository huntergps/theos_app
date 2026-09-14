# Ronda 02 — propuestas visuales

2026-09-10. **Las 33 láminas están aprobadas por el usuario tras revisar la carpeta completa.**
Copias preservadas en `visual_baselines/approved/round-02/`.
Imágenes estáticas, no app implementada. Las notas de generación y QA de abajo
se conservan como historial anterior a la aprobación; no revocan ésta.

Regla de esta ronda: rejillas en desktop/iPad horizontal cuando hay datos tabulares; listas, tarjetas y formularios sin rejillas en iPad vertical/teléfono. Syncfusion es la elección para implementación futura, no el motor de estas imágenes.

Las imágenes son propuestas generativas: los logotipos aproximados, menús añadidos, estados, números y permisos deben cotejarse; no autorizan funciones nuevas. Las versiones aprobadas siguen intactas. Las muestras oscuras son detalles de referencia, no cuatro pantallas oscuras completas. Una lámina de un recorrido no prueba todos sus estados ni cada pestaña. Revisión exhaustiva pendiente con el usuario.

## Índice

| ID | Imagen |
|---|---|
| ACC-01 | [Acceso a Orbi](visual_baselines/proposed/round-02/ACC-01.png) |
| ACC-02 | [PIN de vendedor](visual_baselines/proposed/round-02/ACC-02.png) |
| ACC-03 | [Workspace multirrol](visual_baselines/proposed/round-02/ACC-03.png) |
| VEN-01 | [Órdenes y cotizaciones](visual_baselines/proposed/round-02/VEN-01.png) |
| VEN-03 | [Venta de mostrador](visual_baselines/proposed/round-02/VEN-03.png) |
| VEN-04 | [Venta consultiva](visual_baselines/proposed/round-02/VEN-04.png) |
| VEN-05 | [Clientes y catálogo](visual_baselines/proposed/round-02/VEN-05.png) |
| CAJ-02 | [Registros de Caja](visual_baselines/proposed/round-02/CAJ-02.png) |
| CAJ-03 | [Cobros de cartera](visual_baselines/proposed/round-02/CAJ-03.png) |
| CAJ-10 | [Apertura arqueo y cierre](visual_baselines/proposed/round-02/CAJ-10.png) |
| CAJ-11 | [Cobro combinado y recuperación](visual_baselines/proposed/round-02/CAJ-11.png) |
| BOD-01 | [Inventario de productos](visual_baselines/proposed/round-02/BOD-01.png) |
| BOD-02 | [Operaciones de Bodega](visual_baselines/proposed/round-02/BOD-02.png) |
| BOD-03 | [Preparación y entrega parcial](visual_baselines/proposed/round-02/BOD-03.png) |
| BOD-04 | [Conteo físico de productos](visual_baselines/proposed/round-02/BOD-04.png) |
| ENV-01 | [Estado de envases](visual_baselines/proposed/round-02/ENV-01.png) |
| ENV-02 | [Movimientos de envases](visual_baselines/proposed/round-02/ENV-02.png) |
| ENV-03 | [Pendientes de envases](visual_baselines/proposed/round-02/ENV-03.png) |
| ENV-06 | [Recepción devolución y diferencias](visual_baselines/proposed/round-02/ENV-06.png) |
| ENV-07 | [Compra y venta de envases](visual_baselines/proposed/round-02/ENV-07.png) |
| SUP-01 | [Aprobaciones comerciales](visual_baselines/proposed/round-02/SUP-01.png) |
| SYN-01 | [Preparar datos offline](visual_baselines/proposed/round-02/SYN-01.png) |
| SYN-02 | [Operaciones pendientes](visual_baselines/proposed/round-02/SYN-02.png) |
| SYN-03 | [Resolver conflicto](visual_baselines/proposed/round-02/SYN-03.png) |
| CFG-01 | [Configuración y equipos](visual_baselines/proposed/round-02/CFG-01.png) |
| NOT-01 | [Actividades y notificaciones](visual_baselines/proposed/round-02/NOT-01.png) |
| OPS-01 | [Continuidad y recuperación](visual_baselines/proposed/round-02/OPS-01.png) |
| CAJ-04-v2 | [Retención SRI revisión](visual_baselines/proposed/round-02/CAJ-04-v2.png) |
| CAJ-05-v2 | [Anticipo revisión](visual_baselines/proposed/round-02/CAJ-05-v2.png) |
| CAJ-06-v2 | [Depósito bancario revisión](visual_baselines/proposed/round-02/CAJ-06-v2.png) |
| CAJ-07-v2 | [Salida de efectivo revisión](visual_baselines/proposed/round-02/CAJ-07-v2.png) |
| CAJ-08-v2 | [Cruce de cuentas revisión](visual_baselines/proposed/round-02/CAJ-08-v2.png) |
| CAJ-09-v2 | [Contexto de Caja revisión](visual_baselines/proposed/round-02/CAJ-09-v2.png) |

## QA inicial

- VEN-01: respeta distribución ancha/listas verticales. El generador agregó menús (Compras/Reportes) y estados ilustrativos; no constituyen ampliación de alcance. Teléfono muestra detalle, falta comprobar listado telefónico en revisión.
- ENV-01: mantiene cantidades por producto y adaptación. Logotipo aproximado y navegación Inventario/Envases no sustituyen identidad Orbi ni workspace independiente acordado. Sólo se ilustran dos productos; no se valida volumen/rendimiento.
- Resto: generado y archivado; revisión visual individual detallada pendiente. No declarar cumplidos automáticamente los cuatro formatos por haberlos pedido en el prompt.
- CAJ-04..09-v2: intentos de corregir la primera ronda, no paridad de Odoo certificada.

## Prompts conservados

Herramienta integrada `imagegen` (skill imagegen); sin CLI externo.

### Instrucción común

Use case ui-mockup. Generate a professional high fidelity STATIC UI proposal board for ORBI ERP, Spanish, polished enterprise operational app, not marketing. Four clearly labeled complete views on a large high resolution board: Desktop, iPad horizontal, iPad vertical, Teléfono. Desktop and landscape use dense Syncfusion-style data grids where tabular data exists, frozen headers, zebra rows, sort/filter/columns, practical panels. ABSOLUTE RULE portrait iPad and phone NEVER tables/grids; use readable stacked record lists, labeled values, expandable cards and bottom actions. Same content/record across variants. Neutral white/light gray surfaces, restrained teal accent, charcoal text, professional typography, subtle borders, compact useful spacing, no giant empty cards. Desktop left rail navigation multi-role, top compact context, don't duplicate client data in sidebars. Put 'PROPUESTA · Datos ficticios' and screen ID on board. Show light theme main views and small dark-neutral theme detail swatch, not tinted whole UI. No browser, no code, no real personal data. All content fits artboards, no cropped buttons. Financial currency USD $. This is visual concept not actual Syncfusion screenshot.

### ACC-01 — Acceso a Orbi

Login Workspace: servidor, base de datos, usuario recordados; contraseña oculta, mostrar contraseña, Guardar clave voluntario, Usar API key, Entrar. Marca ORBI ERP y fondo fotográfico de amanecer muy suave, panel neutro legible. Small inset splash with logo, then login. No credentials real.

### ACC-02 — PIN de vendedor

Pantalla PIN con teclado numérico y nombre del equipo Mostrador 02. No lista de operadores recientes. Texto Modo vendedor. Acceso Workspace con credenciales separado. Insets PIN inválido y bloqueo parametrizado. Supervisor que entra por PIN sólo vende; no mostrar accesos elevados.

### ACC-03 — Workspace multirrol

Erik Supervisor autenticado ve Ventas Caja Bodega Envases Aprobaciones simultáneamente en navegación; no selector de rol. Inicio operativo compacto con documentos a continuar y actividad. Cabecera empresa ubicación identidad, menú Bloquear y Cambiar usuario. Inset dispositivo autorizado y modalidad, sin PIN de administrador.

### VEN-01 — Órdenes y cotizaciones

Listado comercial rico 8 registros realistas: número, cliente, vendedor, fecha, condición pago, total USD, estado comercial, sincronización separada. Búsqueda documental, filtros Mis ventas removible Todas Hoy, columnas ordenar y detalle seleccionado. Nueva orden. No pos.order.

### VEN-03 — Venta de mostrador

Venta rápida con contexto cliente arriba, vendedor Carlos, condiciones y total. Escritorio horizontal rejilla 6 productos ferretería, código producto cantidad unidad precio descuento IVA total, última fila vacía con búsqueda inline y sugerencias ancladas. Nunca buscador de añadir productos fuera de rejilla. Vertical teléfono líneas en lista editable; búsqueda dentro de nuevo ítem. Guardar cotización Confirmar venta, resultado enviada a Caja sin atribuir cobro al vendedor.

### VEN-04 — Venta consultiva

Cotización Constructora Andina con contexto superior B, términos 15 días de Odoo, vendedor Carlos. Rejilla secciones Herramientas y Seguridad, notas y productos, cantidades editables, descuentos según permiso, columna seleccionable. Agregar producto inline última fila. Guardar cotización Solicitar aprobación. Portrait stacked section and item cards no table. Inset seguimiento solicitud pendiente no confirmar sin aprobación.

### VEN-05 — Clientes y catálogo

Pantalla catálogo Productos con pestaña Clientes. Tabla normal de productos en anchos, código descripción unidad precio disponibilidad, búsqueda catálogo válida. Detalle seleccionado taladro con precio y existencias de Odoo fecha actualización. Retrato listas productos legibles y ficha expandida. Small inset cliente y preview comprobante Reimprimir sin nuevo número. Datos ficticios USD.

### CAJ-02 — Registros de Caja

Cabecera Punto005 sesiónCS-DEMO-005 cajeraJacqueline. Pestañas Facturas Pagos Anticipos Cheques Retenciones Depósitos Salidas Cruces en navegación accesible. Vista Pagos 8 filas referencia cliente fecha método importe estado documento origen. Filtros turno fecha cliente. Portrait lists grouped date no table. Detail payment115USD read-only with linked order and receipt. No crear pago duplicado por reintentar.

### CAJ-03 — Cobros de cartera

Seleccionar cliente Tienda Demo, facturas pendientes de Odoo. Wide table factura fecha vencimiento saldo importe aplicar: FAC014 saldo100 aplicar100 FAC015saldo80 aplicar50. Total aplicar150, pendiente30. Método efectivo y recibido150. Portrait selected invoice cards individual editable amount, no table. Revisar cobro then Confirmar one primary, result receipt150. Session cashier visible. No invented credit budgets.

### CAJ-10 — Apertura arqueo y cierre

Four device views show cash reconciliation form session Jacqueline Punto005. Wide denomination grid 20x5=100,10x5=50,5x10=50 totalcontado200 esperado200 diferencia0. Actions Revisar cierre not instant deletion. Portrait denomination list rows with large quantity controls no grid. Insets apertura fondo200, revisión movimientos, cierre completado comprobante. Mark datos demo, no fabricated accounting backend fields beyond illustration.

### CAJ-11 — Cobro combinado y recuperación

Total venta115USD pagos efectivo50 transferencia65 pendiente0. Wide payment lines grid; portrait payment cards. Confirmar cobro, after interruption panel Operación guardada localmente Pendiente de envío Ver comprobante, no pay again. Small alternate cash received120 cambio5 displayed separate from mixed example with clear label Otro caso. Session identity visible.

### BOD-01 — Inventario de productos

Bodeguero Miguel workspace Bodega, normal products not returnable packaging. Dashboard compact counts Recepciones3 Preparar8 Entregar4 then inventory data table código producto ubicación a mano reservado disponible. Portrait stacked product lists quantities label value. Filters almacén categoría búsqueda and inventory detail, source Odoo updated timestamp. No financial cash session required.

### BOD-02 — Operaciones de Bodega

Tabs Recepciones Preparaciones Entregas Transferencias. Listado Entregas references WH/OUT/001 etc origin sale customer warehouse planneddate status 8rows wide grids. Portrait cards not grid. Selected delivery details products quantities and next action Preparar. Related references visible. Do not universal stock block assume enterprise policy.

### BOD-03 — Preparación y entrega parcial

Order WH/OUT/014 customerTiendaDemo sourceVEN014. Wide preparation lines products solicitado preparado pendiente: taladro4/3/1 guantes10/10/0 cinta6/6/0. Scan input within item adding/work flow. Portrait list item cards per product with quantity controls and faltante reason. Revisar entrega. Inset bloqueo Entrega pendiente de autorización de Odoo and Ver motivo, never bypass. Partial handling as proposal.

### BOD-04 — Conteo físico de productos

Physical count inventory normal products, location Principal responsibleMiguel. Wide grid producto esperado contado diferencia taladros10/9/-1 guantes20/20/0 cintas15/16/+1. Portrait cards labels expected counted difference no columns. Guardar conteo Enviar a revisión; no automatic stock adjustment. Small state awaiting review reason.

### ENV-01 — Estado de envases

Workspace Envases responsableAna not cash. Separate content/product and owned container presentation. Wide dense matrix Producto Envase Presentación Guayaquil Galápagos GYE→GPS GPS→GYE Clientes Proveedores Total propio. Two rows Cola botella retornable unidad24 por jaba quantities100,200,24,24,120,12 total480; cerveza botella retornable unidad12 porjaba60,120,12,12,24,12 total240. Portrait product cards with location labeled metric stacks no table. Bottles unit jaba presentation not new asset. Ownership company. Filters product presentation location and freshness timestamp.

### ENV-02 — Movimientos de envases

Historical ledger wide grid date document product container units presentation origin destination type state. Several transfers GYE GPS both directions and deliveries clients returns providers. Portrait timeline cards not grid. Detail ENV014 Cola botella24units=1jaba24 sourceFacturaDEMO, senderreceiver and linked movements. No mixing content sold with returnable balance. No cash session.

### ENV-03 — Pendientes de envases

Tabs Entregas Devoluciones Tránsitos Clientes Proveedores Tomas. Wide transit grid referencia producto unidades origen destino fecha estado; selected GYE→Galápagos24botellas1jaba, another GPS→GYE48. Portrait transit list cards grouped route, accessible tabs. Detail custody customer borrowed48returned24pending24, clearly separate presentation conversion. No financial cupo.

### ENV-06 — Recepción devolución y diferencias

Batch returnable operation multi products: cola bottle48sent46received2damaged; beer bottle24sent24received0damaged. Wide editable grid each product and presentation units. Portrait repeated cards quantities, no individual bottle tracking. Context originClienteDemo destinationGalápagos responsibleAna. Reason damaged2, total received70 pending2 documented do not silently delete. Revisar Guardar recepción, source delivery linked.

### ENV-07 — Compra y venta de envases

Owned packaging purchases/sales linked Odoo invoices separate from beverage content. Wide list documents purchase12bottles and sale6bottles, product container units price total record separate. Portrait stacked documents no grids. Main sale form customerDemo container Cola retornable6 units x1USD=6, linked invoice BORRADOR, no duplicate content charge. Callout Venta de envases reduce propiedad al validar documento en Odoo. Actions Revisar documento Abrir factura, not autonomous new business logic.

### SUP-01 — Aprobaciones comerciales

Supervisor bandeja solicitudes with wide grid orderclient vendorreasonconditiontotaldate state. selected VEN014 credit15days discount request. Odoo credit information read-only updatedtimestamp not device budgets. Detail requested change and reason. Aprobar Rechazar Pedir corrección, mandatory explanatory rejection proposed. Portrait list then detail sheet no table. Origin userCarlos destinationErik clear.

### SYN-01 — Preparar datos offline

Catalog coverage products792 clients458 taxes143 paymentmethods missing. Wide grid catálogo locales cobertura ultimaactualizacion estado accion. Distinguish Sin conexión al servidor from local work available. Portrait catalog cards no table. Reintentar on failing category, offline can use downloaded data. No purge or delete pending. Progress incremental partial vs complete.

### SYN-02 — Operaciones pendientes

Outbox wide grid operationreference typeauthorcreated businessstatus technicalstatus dependencieslastattempt. Portrait timeline cards. Sale complete locally pending remote does not become draft. Detail order→invoice→payment dependencies, retry idempotent existing reference no new document. Error actionable, nextretry shown not endlessspinner. No Borrar todo.

### SYN-03 — Resolver conflicto

Conflict VEN014 Odoo price changed. Wide comparison grid Campo Local Odoo for price and conditions, preserve authorCarlos and saved draft. Portrait labeled local then server stacked cards no comparison table. Details reason timestamp dependency, options Revisar con supervisor Mantener pendiente; do not invent force overwrite capability. Resolve allowed decision reviewed before save. No silent loss or renumbering.

### CFG-01 — Configuración y equipos

Settings splitnav Apariencia Dispositivo Trabajo offline Seguridad. Form mode currentdevice Workspace or PIN ventas configurable, company other devices may differ. Neutral lightdark, accent from Odoo, textsize density, no full brown dark tint. Credential protection optional. Portrait sections accordions no tables. Authorized admin device revoked inset. No role switch to access multiple roles.

### NOT-01 — Actividades y notificaciones

Inbox approvalsready orderreadydispatch syncattention, actionable references actors timestamps unread. Wide grid optional and detail panel; portrait chronological list cards. Mark read Ver documento. No leaking other users work when switching. Preferences channels available no fabricated OS permission accepted. Header multirole and discreet count.

### OPS-01 — Continuidad y recuperación

Operational safety screen session expired but local documents preserved. Wide table pending records and support detail no secrets; portrait record cards. States inset reconectar, almacenamiento insuficiente conservar pendientes liberar solo cache segura, diagnostico exportable sin credenciales. Primary Volver a iniciar sesión secondary Ver trabajo local. No automatic delete. Clear offline vs session states.

### CAJ-04-v2 — Retención SRI revisión

Corrected proposal access key49digit field blank Consultar; main loaded readonly customerdate document SRI and wide lines grid invoice taxcodebaseamount. Portrait document cards no grids. Only unresolved invoice selector editable. Registrar after review Cambiar clave Cerrar. No client supplier selector, no fabricated workflow states. Small inset consultation failure retry. Demo figures not fiscal advice.

### CAJ-05-v2 — Anticipo revisión

CustomerDemo date session readonly for cashier, glosa. Wide paymentgrid cash100 transfer50 total150, conditional card/check expansion. Portrait payment cards no grid. Procesar then processed receipt available150 used0. No invented500char counter or freely editable session. USD.

### CAJ-06-v2 — Depósito bancario revisión

Cash1000 check500 count2 total1500USD typeMixto bankjournalBancoDemo slipDEMO depositdate accountingdate, notes. SessionCS005 pointPunto de cobro005 cashierJacqueline readonly context. No invented check detail table. Portrait stackedform no grids. Guardar Contabilizar Ver asiento only afterposting.

### CAJ-07-v2 — Salida de efectivo revisión

Type Pago de facturas partnerProveedorDemo amount150 date and session. Wide invoicegrid FAC021saldo100pagar100 FAC022saldo80pagar50. Portrait invoicecards no grid. Motivo and Aceptar Cancelar. No new Movimiento CajaBanco selector. Other type inset general contrapartida if applicable. USD.

### CAJ-08-v2 — Cruce de cuentas revisión

Fullwidth two grids sources RET01available50apply50 NC02available100apply100, destinations FAC014saldo200apply150. Total fuente150 aplicado150 disponible0. Portrait source cards then destinationcards no tables. Customer date session stateBorrador. Confirmar. No inventedNotes. Print only valid corresponding state. No cashcharging button.

### CAJ-09-v2 — Contexto de Caja revisión

Persistent point005 sessionCS005 cashierJacqueline. All actions Nueva Orden Cobros de cartera Retención SRI Anticipo Depósito bancario Salida efectivo Cruce cuentas. Wide pendingordergrid, portrait ordercards. Mi turno accessible list Órdenes Facturas Pagos Anticipos Cheques Salidas Retenciones Cruces Cierre de caja; phone expandable actions panel all accessible. Not opening closing forms.
