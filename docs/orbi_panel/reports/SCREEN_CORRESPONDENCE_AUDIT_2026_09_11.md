# Auditoría de correspondencia: pantallas aprobadas vs. implementadas

Foto tomada en el commit `28a11eadceed7d06f7c53c6ce76e337c9fc72b3f` (rama
`orbi/trabajo-pausado-2026-09-11`), 2026-09-11. Había 5 agentes escribiendo en el
árbol al mismo tiempo; el código puede haber cambiado después de esta lectura.
Fuentes de lo aprobado: `APPROVED_SCREEN_INDEX.md`, `APPROVAL_REGISTER.md`,
`visual_baselines/approved/**`, `NAVIGATION_CAPABILITY_MATRIX.md`. Fuente de lo
implementado: `theos_panel/lib/features/`, `theos_panel/lib/app/router.dart`,
`theos_panel/lib/ui/layouts/operational_shell.dart`. No se contaron archivos: se
leyó el `build()` de cada pantalla candidata para verificar que cubre lo que la
lámina aprobada muestra, no solo que existe una ruta con nombre parecido.

## Tabla

| Pantalla aprobada | Evidencia aprobada | Código que la implementa | Veredicto |
|---|---|---|---|
| ACC-01 (acceso servidor/BD/usuario) | round-02/ACC-01.png | `features/auth/login_screen.dart`, `saved_servers.dart`, `server_manager_dialog.dart` | Implementada |
| ACC-02 (PIN vendedor) | round-02/ACC-02.png | ninguna | Ausente — no hay ningún identificador `pin`/`PIN` en `theos_panel/lib` (grep sin resultados) |
| ACC-03 (Workspace multirol: ver áreas, bloquear, cambiar usuario) | round-02/ACC-03.png | `ui/layouts/operational_shell.dart` (sidebar por áreas) | Parcial — "ver áreas" existe en el sidebar agrupado; no hay botón de bloqueo ni de cambio de usuario en ningún widget (grep `bloquear`/`switchUser`/`lock` sin resultados de UI) |
| VEN-01 (órdenes/cotizaciones) | round-02/VEN-01.png | `features/orders/orders_screen.dart`, ruta `/sales` | Implementada — filtros "Mis ventas/Todas/Pendientes de caja" presentes |
| VEN-03 (venta mostrador) | round-02/VEN-03.png | `features/sales/sale_editor.dart` (`SalePresentation.counter`), ruta `/sales/counter` | Implementada |
| VEN-04 (venta consultiva) | round-02/VEN-04.png | `features/sales/sale_editor.dart` (`SalePresentation.consultive`), ruta `/sales/consultive` | Implementada — incluye botón "Solicitar aprobación" |
| VEN-05 (clientes y catálogo) | round-02/VEN-05.png | `features/clients/clients_screen.dart`, `features/products/products_screen.dart` | Implementada |
| CAJ-02 (registros de turno, pestañas) | round-02/CAJ-02.png | ninguna | Ausente — `collection_screen.dart` no tiene pestañas de órdenes/facturas/pagos; solo lista de pendientes y editor de cobro |
| CAJ-03 (cartera) | round-02/CAJ-03.png | ninguna | Ausente — grep `cartera` en `theos_panel/lib` sin resultados |
| CAJ-10 (apertura/arqueo/cierre) | round-02/CAJ-10.png | `collection_screen.dart` (`_shiftCard`, `_cashCountEditor`, conteo por denominación) | Implementada |
| CAJ-11 (cobro combinado/recuperación) | round-02/CAJ-11.png | `collection_screen.dart` (`_editor`, `_lines`, medios múltiples) | Implementada |
| CAJ-04-v2 (retención SRI) | round-02/CAJ-04-v2.png | ninguna | Ausente — `collection_contracts.dart` define `CollectionCapability.withholdings` pero `collection_screen.dart` línea 460 la etiqueta "requiere confirmación fiscal" y nunca la conecta (`wired.contains` la excluye) |
| CAJ-05-v2 (anticipo) | round-02/CAJ-05-v2.png | `app/router.dart` (`collectionFinancialActionsProvider`, acción `advance`) | Implementada — como acción offline dentro de Caja, no lámina propia |
| CAJ-06-v2 (depósito) | round-02/CAJ-06-v2.png | `app/router.dart` (acción `deposit`) | Implementada — ídem, botón dentro de Caja |
| CAJ-07-v2 (salida efectivo) | round-02/CAJ-07-v2.png | `app/router.dart` (acción `cashOut`), `collection_screen.dart` (selector "Tipo de salida") | Implementada |
| CAJ-08-v2 (cruce cuentas) | round-02/CAJ-08-v2.png | ninguna | Ausente — grep `cruce` en `theos_panel/lib` sin resultados |
| CAJ-09-v2 (contexto punto/sesión) | round-02/CAJ-09-v2.png | ninguna | Ausente — no hay pantalla de "abrir acciones del turno / ir a cierre"; solo el `_shiftCard` embebido en Caja |
| BOD-01 (inventario/existencias) | round-02/BOD-01.png | ninguna | Ausente — `warehouse_screen.dart` solo lista despachos, no existencias por disponibilidad |
| BOD-02 (operaciones: recepción/preparación/entrega/transferencia) | round-02/BOD-02.png | `features/warehouse/warehouse_screen.dart` | Parcial — solo cubre validar entrega de picking con bloqueo por cobro; no hay recepción, transferencia ni menú de operaciones |
| BOD-03 (preparación/entrega parcial) | round-02/BOD-03.png | `warehouse_screen.dart` (diálogo "Backorder requerido") | Parcial — cubre backorder sí/no; no escaneo, no edición de cantidades ni indicar faltante línea a línea |
| BOD-04 (conteo físico) | round-02/BOD-04.png | ninguna | Ausente |
| ENV-01 (dashboard estado) | round-02/ENV-01.png | `features/envases/envases_dashboard_screen.dart` | Implementada — filtro por producto, lista de filas, reintento |
| ENV-02 (movimientos/trazabilidad) | round-02/ENV-02.png | ninguna | Ausente |
| ENV-03 (pendientes/tránsitos) | round-02/ENV-03.png | ninguna | Ausente |
| ENV-06 (recepción/devolución) | round-02/ENV-06.png | ninguna | Ausente |
| ENV-07 (compra/venta recipiente) | round-02/ENV-07.png | ninguna | Ausente |
| SUP-01 (aprobaciones comerciales) | round-02/SUP-01.png | `features/approvals/approvals_screen.dart`, ruta `/approvals` | Implementada — aprobar/rechazar/"Preparar FSC" |
| SYN-01 (provisión offline, cobertura/catálogo) | round-02/SYN-01.png | `features/sync/sync_center.dart` (lista `snapshot.catalogs`, botón "Reintentar sincronización") | Implementada |
| SYN-02 (cola de operaciones) | round-02/SYN-02.png | `sync_center.dart` (contadores en cola/fallidos/conflictos) | Implementada |
| SYN-03 (conflicto: comparar local/Odoo) | round-02/SYN-03.png | `app/router.dart` ruta `/sync` (`onOpenConflicts`) | Parcial — el botón abre un `AlertDialog` con texto fijo ("hay operaciones que requieren revisión"); no compara local vs. Odoo ni lista los conflictos |
| CFG-01 (configuración/equipo) | round-02/CFG-01.png | `features/settings/settings_screen.dart` | Parcial — cubre apariencia, Modo Ruta, reintentos de sync y permisos de notificación; no hay sección de seguridad/equipo que la lámina muestra |
| NOT-01 (actividades/avisos) | round-02/NOT-01.png | `features/notifications/notification_inbox.dart`, `features/activities/activity_center.dart` | Implementada |
| OPS-01 (continuidad/recuperación) | round-02/OPS-01.png | ninguna en `theos_panel` | Ausente como pantalla — `recovery_pending` existe en `theos_pos_core/lib/src/database` como mecanismo de datos, no como pantalla de reautenticación/diagnóstico en Orbi |
| SHELL-01 (shell multirol) | round-03/SHELL-01.png | `ui/layouts/operational_shell.dart` | Implementada — sidebar agrupado, cabecera, pie con servidor/BD/hora |
| ALERT-01 (avisos internos) | round-03/ALERT-01.png | ninguna dedicada | Ausente — no hay banner de validación separado de `notification_inbox.dart`; grep `Alert`/banner específico sin resultados |
| ALERT-02 (avisos de dispositivo) | round-03/ALERT-02.png | ninguna | Ausente |
| CONT-01 (continuidad A→B→A) | round-03/CONT-01.png | `features/sales/durable_sale_draft_store.dart`, `sale_draft_workspace.dart` | Parcial — hay persistencia de borrador durable, pero no pantalla/indicador visible de "cambio A→B→A" que la lámina describe |
| OUT-01 (salidas Odoo: previsualizar/imprimir/reintentar) | round-03/OUT-01.png | `features/reports/document_view.dart`, `offline_qweb_report.dart` | Parcial — hay estado fiscal/sync del documento; no se encontró acción de imprimir/compartir ni reintento de envío en el `build()` leído |
| AI-01 (asistente opcional) | round-03/AI-01.png | ninguna | Ausente — grep `asistente`/`assistant` en `theos_panel/lib` sin resultados |
| VENTAS-B-v1 (histórica) | `approved/VENTAS-B-v1.png` | superada por VEN-01/sale_editor | Implementada (vía VEN-01/VEN-03), la lámina original quedó sustituida según `APPROVAL_REGISTER.md` |
| VENTAS-TABLET-MOVIL-v1 (histórica) | `approved/VENTAS-TABLET-MOVIL-v1.png` | `sale_editor.dart` + `LayoutBuilder` responsive en `collection_screen.dart`/paneles | Parcial — hay adaptación responsive genérica; no verifiqué las variantes exactas de la lámina histórica |
| VENTAS-VERTICAL-COBRO-v1 (histórica) | `approved/VENTAS-VERTICAL-COBRO-v1.png` | `collection_screen.dart` (`wide`/`LayoutBuilder`) | Parcial — mismo motivo: adaptación existe, correspondencia lámina-a-lámina no verificada al detalle |
| PENDIENTES-RESULTADO-COBRO-v1 (histórica) | `approved/PENDIENTES-RESULTADO-COBRO-v1.png` | `collection_screen.dart` (`_pendingList`) | Implementada |
| BODEGA-ENVASES-v1 (histórica) | `approved/BODEGA-ENVASES-v1.png` | `envases_dashboard_screen.dart` cubre solo el dashboard | Parcial — el registro dice aplicar aclaraciones posteriores; el dashboard actual (ENV-01) no cubre bodega ni el resto de envases de esta lámina |
| ENV-FACTURA-v1 (histórica) | `approved/ENV-FACTURA-v1.png` | ninguna | Ausente |
| ENV-TOMA-FISICA-v1 (histórica) | `approved/ENV-TOMA-FISICA-v1.png` | ninguna | Ausente |

## Huecos verificables, ordenados por importancia

1. **Envases**: de 7 láminas aprobadas (ENV-01/02/03/06/07 + ENV-FACTURA-v1 +
   ENV-TOMA-FISICA-v1) solo ENV-01 (dashboard) tiene código. Los flujos de
   registro desde factura y desde toma física — las dos únicas aprobaciones
   *explícitas por nombre* en `APPROVAL_REGISTER.md` línea 19 — no existen.
2. **Caja**: 5 de 9 láminas sin código o sin conexión real: CAJ-02 (registros),
   CAJ-03 (cartera), CAJ-04-v2 (retención SRI, explícitamente marcada
   "requiere confirmación fiscal" en el propio código), CAJ-08-v2 (cruce de
   cuentas), CAJ-09-v2 (contexto punto/sesión).
3. **Bodega**: BOD-01 (existencias) y BOD-04 (conteo físico) sin código; BOD-02
   y BOD-03 solo cubren la validación de entrega/backorder, no recepción,
   preparación ni transferencia.
4. **ACC-02 (PIN)**: aprobada y sin ningún rastro en el código; es la puerta de
   entrada declarada para el rol vendedor en `NAVIGATION_CAPABILITY_MATRIX.md`.
5. **Round-03 completo** (SHELL-01 aparte): ALERT-01, ALERT-02, AI-01 sin
   código; CONT-01, OUT-01, SYN-03 con mecanismos parciales pero sin la
   pantalla/interacción que la lámina aprobada muestra.
6. **ACC-03**: bloqueo y cambio de usuario (parte central de la lámina) no
   están implementados; solo la navegación por áreas.

Nota: ningún hallazgo de esta lista se basó en el estado `done` de
`tasks.json`; todos se verificaron leyendo el `build()` o el archivo de
contrato correspondiente en el código fuente.
