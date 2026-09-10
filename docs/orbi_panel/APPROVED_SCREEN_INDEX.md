# Índice único de pantallas aprobadas — Orbi

Actualizado: 2026-09-10. Inventario documental de los PNG realmente conservados en
`visual_baselines/approved/`. El índice reúne las 46 imágenes aprobadas: 7 históricas,
33 de round-02 y 6 de round-03.

Este documento cruza cada imagen con su familia, recorrido, acciones principales y
escenarios de [INTERACTION_ACCEPTANCE_SPEC](INTERACTION_ACCEPTANCE_SPEC.md). Las
referencias a acciones y escenarios son cobertura documental; no significan que la
imagen haya sido inspeccionada visualmente en este índice, que la pantalla esté
implementada, ni que exista binding, permiso, método Odoo o prueba ejecutada. Para
familias y límites de cobertura prevalecen [APPROVAL_REGISTER](APPROVAL_REGISTER.md),
[ROUND_02_REVIEW](ROUND_02_REVIEW.md), [ROUND_03_REVIEW](ROUND_03_REVIEW.md) y
[VISUAL_COVERAGE](VISUAL_COVERAGE.md).

## Inventario exhaustivo

| ID | Archivo aprobado | Familia / recorrido | Acciones principales; specs / escenarios | Límite de aprobación |
|---|---|---|---|---|
| VENTAS-B-v1 | [PNG](visual_baselines/approved/VENTAS-B-v1.png) | VEN; distribución B y ficha | Consultar catálogo, seleccionar producto; VEN-C / VC-4 | Sólo opción B desktop y ficha representada; no recorridos completos. |
| VENTAS-TABLET-MOVIL-v1 | [PNG](visual_baselines/approved/VENTAS-TABLET-MOVIL-v1.png) | VEN; adaptaciones | Editar venta en tamaños; VEN-M / VM-1, VM-5 | Sólo adaptaciones mostradas; no todas las variantes comerciales. |
| VENTAS-VERTICAL-COBRO-v1 | [PNG](visual_baselines/approved/VENTAS-VERTICAL-COBRO-v1.png) | VEN/CAJ; vertical y cobro | Revisar venta, pasar a cobro; CAJ / CJ-2 | Importes ilustrativos no definen cálculo fiscal ni Caja completa. |
| PENDIENTES-RESULTADO-COBRO-v1 | [PNG](visual_baselines/approved/PENDIENTES-RESULTADO-COBRO-v1.png) | CAJ; pendientes y resultado | Seleccionar pendiente, cobrar, consultar resultado; CAJ / CJ-5, CJ-6 | Sólo estados representados; no operaciones auxiliares ni cierre. |
| BODEGA-ENVASES-v1 | [PNG](visual_baselines/approved/BODEGA-ENVASES-v1.png) | BOD/ENV; primeras vistas | Consultar existencias y envases; BOD / BD-1, ENV / EV-1 | Primera propuesta; aplicar aclaraciones posteriores y no asumir todo Inventario. |
| ENV-FACTURA-v1 | [PNG](visual_baselines/approved/ENV-FACTURA-v1.png) | ENV; registro desde factura | Importar factura, revisar líneas, registrar; ENV / EV-2 | Sólo flujo desde factura y formatos mostrados; bindings pendientes. |
| ENV-TOMA-FISICA-v1 | [PNG](visual_baselines/approved/ENV-TOMA-FISICA-v1.png) | ENV; toma física | Capturar cantidades, revisar diferencia, registrar; ENV / EV-3 | Sólo flujo desde toma y formatos mostrados; no ajuste automático. |
| ACC-01 | [PNG](visual_baselines/approved/round-02/ACC-01.png) | ACC; acceso Workspace | Completar servidor/BD/usuario, credencial, entrar; ACC / ACC-1, ACC-3 | Estados y credenciales son ficticios; bindings de acceso y almacenamiento pendientes. |
| ACC-02 | [PNG](visual_baselines/approved/round-02/ACC-02.png) | ACC; PIN vendedor | Introducir PIN, bloqueo y acceso vendedor; ACC / ACC-2, ACC-5 | PIN sólo representa Ventas; no eleva permisos ni certifica parametrización. |
| ACC-03 | [PNG](visual_baselines/approved/round-02/ACC-03.png) | ACC/MUL; Workspace multirrol | Ver áreas, bloquear, cambiar usuario; ACC / ACC-4, MUL / MU-1 | No selector de rol; enrolamiento, revocación y permisos siguen pendientes. |
| VEN-01 | [PNG](visual_baselines/approved/round-02/VEN-01.png) | VEN-C; órdenes/cotizaciones | Buscar, filtrar, ordenar, abrir, crear; VC-1, VC-4 | Datos ficticios; ACL, campos y `sale.order` requieren binding. |
| VEN-03 | [PNG](visual_baselines/approved/round-02/VEN-03.png) | VEN-M; venta mostrador | Buscar inline, editar líneas, guardar/confirmar, pasar a Caja; VM-1..VM-5 | No aprueba cobro del vendedor, precios, escáner ni reglas Odoo no mostradas. |
| VEN-04 | [PNG](visual_baselines/approved/round-02/VEN-04.png) | VEN-C; venta consultiva | Cliente, secciones/notas, condiciones, solicitar aprobación; VC-1..VC-4, FL-1..FL-4 | No confirma sin aprobación; importes y descuentos son ilustrativos. |
| VEN-05 | [PNG](visual_baselines/approved/round-02/VEN-05.png) | VEN; clientes y catálogo | Buscar producto/cliente, ver detalle, previsualizar/reimprimir; VC-4 | Sólo vistas representadas; no nuevos números ni catálogo completo. |
| CAJ-02 | [PNG](visual_baselines/approved/round-02/CAJ-02.png) | CAJ; registros de turno | Navegar pestañas, filtrar, abrir detalle read-only; CAJ / CJ-1, CJ-7 | No crea pagos ni aprueba todos los formularios; métodos/campos pendientes. |
| CAJ-03 | [PNG](visual_baselines/approved/round-02/CAJ-03.png) | CAJ; cartera | Seleccionar facturas, aplicar importe, revisar y confirmar cobro; CJ-2..CJ-5 | Saldos ficticios; no presupone cupos, acción masiva o binding de cartera. |
| CAJ-10 | [PNG](visual_baselines/approved/round-02/CAJ-10.png) | CAJ; apertura/arqueo/cierre | Contar denominaciones, revisar diferencia, cerrar y ver comprobante; CJ-1, CJ-7 | Datos demo; no certifica contabilidad, sesión offline ni cierre real. |
| CAJ-11 | [PNG](visual_baselines/approved/round-02/CAJ-11.png) | CAJ; cobro combinado/recuperación | Añadir medios, confirmar, recuperar operación pendiente, consultar comprobante; CJ-3, CJ-5, CJ-6 | Ejemplos de importes no fijan cálculo; idempotencia y medios requieren binding. |
| BOD-01 | [PNG](visual_baselines/approved/round-02/BOD-01.png) | BOD; inventario productos | Filtrar inventario, consultar disponibilidad y detalle; BD-1, BD-4 | Productos y cantidades ficticios; no bloquea stock ni exige Caja. |
| BOD-02 | [PNG](visual_baselines/approved/round-02/BOD-02.png) | BOD; operaciones | Abrir recepción/preparación/entrega/transferencia, preparar; BD-1, BD-2 | No universaliza bloqueo ni valida movimientos reales. |
| BOD-03 | [PNG](visual_baselines/approved/round-02/BOD-03.png) | BOD; preparación/entrega parcial | Escanear/editar cantidades, indicar faltante, revisar entrega; BD-2, BD-3 | Parcial y autorización son propuesta; no permite bypass de Odoo. |
| BOD-04 | [PNG](visual_baselines/approved/round-02/BOD-04.png) | BOD; conteo físico | Capturar esperado/contado/diferencia, guardar, enviar a revisión; BD-4 | No ejecuta ajuste automático ni aprueba revisión. |
| ENV-01 | [PNG](visual_baselines/approved/round-02/ENV-01.png) | ENV; dashboard estado | Filtrar por producto/envase/presentación/ubicación, consultar custodia; EV-1, EV-2 | Dashboard representado; no aprueba el último dashboard histórico no mostrado. |
| ENV-02 | [PNG](visual_baselines/approved/round-02/ENV-02.png) | ENV; movimientos/trazabilidad | Filtrar ledger, abrir detalle y movimientos vinculados; EV-2, EV-5 | No mezcla contenido con recipiente; datos y trazabilidad requieren binding. |
| ENV-03 | [PNG](visual_baselines/approved/round-02/ENV-03.png) | ENV; pendientes/tránsitos | Navegar entregas/devoluciones/tránsitos, revisar custodia y saldo; EV-4 | No aprueba cupos ni operaciones financieras. |
| ENV-06 | [PNG](visual_baselines/approved/round-02/ENV-06.png) | ENV; recepción/devolución | Capturar múltiples líneas, recibido/dañado, revisar y guardar; EV-2, EV-4 | No recipiente por recipiente ni borrado silencioso; decisiones de diferencia pendientes. |
| ENV-07 | [PNG](visual_baselines/approved/round-02/ENV-07.png) | ENV; compra/venta recipiente | Revisar documento, abrir factura y vincular compra/venta; EV-5 | No crea lógica autónoma ni confunde contenido con envase. |
| SUP-01 | [PNG](visual_baselines/approved/round-02/SUP-01.png) | MUL; aprobaciones comerciales | Abrir solicitud, revisar motivo, aprobar/rechazar/pedir corrección; VC-3, MU-2 | No concede descuentos, crédito ni confirmación automática; ACL pendientes. |
| SYN-01 | [PNG](visual_baselines/approved/round-02/SYN-01.png) | SYN; provisión offline | Revisar cobertura, reintentar catálogo, continuar con datos locales; SY-1, SY-2 | Cobertura ficticia; no significa catálogo completo ni sincronización probada. |
| SYN-02 | [PNG](visual_baselines/approved/round-02/SYN-02.png) | SYN; cola de operaciones | Consultar dependencia/estado, reintentar idempotente, ver resultado; SY-3, SY-5 | No ofrece borrar cola; contratos de outbox y remoto pendientes. |
| SYN-03 | [PNG](visual_baselines/approved/round-02/SYN-03.png) | SYN; conflicto | Comparar local/Odoo, revisar y mantener pendiente; SY-4, SY-7 | No autoriza sobrescritura forzada ni resuelve conflicto automáticamente. |
| CFG-01 | [PNG](visual_baselines/approved/round-02/CFG-01.png) | ACC/MUL; configuración/equipo | Configurar apariencia, modalidad, offline y seguridad; ACC-5, MU-4, SY-6 | Sólo opciones representadas; no crea roles, permisos ni políticas nuevas. |
| NOT-01 | [PNG](visual_baselines/approved/round-02/NOT-01.png) | MUL; actividades/avisos | Leer aviso, abrir documento, marcar leído, preferencias disponibles; MU-2, MU-3 | No certifica entrega con app cerrada ni permisos OS. |
| OPS-01 | [PNG](visual_baselines/approved/round-02/OPS-01.png) | SYN; continuidad/recuperación | Reautenticar, ver trabajo local, diagnosticar sin secretos, conservar pendientes; SY-3, SY-5, SY-6 | Estados son propuesta; no autoriza borrado automático ni soporte real. |
| CAJ-04-v2 | [PNG](visual_baselines/approved/round-02/CAJ-04-v2.png) | CAJ; retención SRI | Consultar clave, revisar datos, registrar o reintentar; operación Retención SRI, CJ-4 | Cifras demo; no define flujo fiscal, selector ni estados no representados. |
| CAJ-05-v2 | [PNG](visual_baselines/approved/round-02/CAJ-05-v2.png) | CAJ; anticipo | Seleccionar cliente/medios, procesar, consultar disponible/usado; operación Anticipo, CJ-4 | No fija límites ni campos inventados; binding de anticipo pendiente. |
| CAJ-06-v2 | [PNG](visual_baselines/approved/round-02/CAJ-06-v2.png) | CAJ; depósito | Capturar depósito, guardar, contabilizar, ver asiento; operación Depósito | No certifica diarios, contabilización ni detalles de cheque. |
| CAJ-07-v2 | [PNG](visual_baselines/approved/round-02/CAJ-07-v2.png) | CAJ; salida efectivo | Seleccionar tipo/documentos, aplicar, aceptar; operación Salida de efectivo | No inventa selector de movimiento; tipos y documentos dependen de Odoo. |
| CAJ-08-v2 | [PNG](visual_baselines/approved/round-02/CAJ-08-v2.png) | CAJ; cruce cuentas | Identificar fuentes/destinos, aplicar, revisar y confirmar; operación Cruce, CJ-4 | No es recepción de efectivo; saldos y permisos requieren binding. |
| CAJ-09-v2 | [PNG](visual_baselines/approved/round-02/CAJ-09-v2.png) | CAJ; contexto punto/sesión | Abrir acciones del turno, consultar registros, ir a cierre; CJ-1, CJ-7 | No aprueba apertura/cierre; sólo contexto y acciones representadas. |
| SHELL-01 | [PNG](visual_baselines/approved/round-03/SHELL-01.png) | MUL; shell multirrol | Navegar menú, ver cabecera/pie, servidor/BD/hora; MU-1, MU-4 | Sólo seis láminas de round-03 aprobadas; no variantes oscuras completas. |
| ALERT-01 | [PNG](visual_baselines/approved/round-03/ALERT-01.png) | MUL; avisos internos | Ver aviso/validación/banner, abrir actividad sin robar foco; MU-2 | No certifica notificación, permisos ni entrega fuera de app. |
| ALERT-02 | [PNG](visual_baselines/approved/round-03/ALERT-02.png) | MUL/ACC; avisos dispositivo | Revisar permiso/privacidad y estado del dispositivo; ACC-5, MU-3 | No aprueba permisos OS ni operación con app cerrada. |
| CONT-01 | [PNG](visual_baselines/approved/round-03/CONT-01.png) | SYN/MUL; continuidad | Conservar borrador/foco, búsqueda inline y cambio A→B→A; ACC-4, VM-4, SY-3, MU-3 | Sólo comportamiento representado; no certifica persistencia implementada. |
| OUT-01 | [PNG](visual_baselines/approved/round-03/OUT-01.png) | CAJ/MUL; salidas Odoo | Previsualizar, imprimir/compartir cuando habilitado, reintentar salida; CJ-6 | Canales sólo si existen en Odoo; no repite cobro ni certifica impresión. |
| AI-01 | [PNG](visual_baselines/approved/round-03/AI-01.png) | MUL; asistente opcional | Consultar asistente condicionado, revisar contexto y límites; SY-1, MU-2 | Sólo si IA está instalada/habilitada en Odoo; no crea proveedor ni permiso nuevo. |

## Verificación del inventario

- Archivos aprobados encontrados: **46** (7 en `approved/`, 33 en
  `approved/round-02/`, 6 en `approved/round-03/`).
- Cada fila enlaza al PNG aprobado, no a la copia `proposed/`; las copias aprobadas
  permanecen sin modificarse.
- La cobertura documental usa las familias/escenarios de la especificación. Una fila
  puede cubrir sólo parte de un recorrido; la columna de límites lo hace explícito.
- Las imágenes no inspeccionadas visualmente durante la elaboración no se describen como
  auditadas. Este índice inventaría evidencia y documentación, no sustituye una
  auditoría visual ni pruebas funcionales.
