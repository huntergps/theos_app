# Cobertura visual y huecos — Orbi

Actualizado 2026-09-10. Inventario de revisión, NO autorización de desarrollo.
Complementa APPROVAL_REGISTER.md; una definición funcional aceptada no aprueba una imagen.

Extensión de alcance documentada: [capacidades opcionales de Odoo](ODOO_OPTIONAL_CAPABILITIES.md).
Ronda 03 aprobada: propuestas de asistente condicionado a IA instalada, salidas,
avisos, contexto y continuidad; sólo para los estados efectivamente representados.
No se crean proveedores o canales independientes en Orbi.

## Ronda 02 generada

Se generaron y archivaron 33 láminas: [índice y prompts](ROUND_02_REVIEW.md).
**Aprobación posterior: el usuario revisó round-02 y aprobó todas sus imágenes.**
Los 33 IDs quedan aprobados visualmente para el alcance representado y copiados
a `visual_baselines/approved/round-02/`. Lo siguiente conserva el estado histórico
de generación; no es el estado vigente de aprobación.
Los IDs de la matriz que tienen enlace en ese índice pasan de «sin lámina» a
**propuesta generada, pendiente de revisión y aprobación**. La situación anterior
se conserva abajo como línea base; generar no cierra automáticamente la cobertura
de todos los estados/pestañas ni acredita fidelidad a Odoo.

Última instrucción del usuario: **rejillas sólo en escritorio y tablet horizontal;
tablet vertical y teléfono sin rejillas**, usando listas/tarjetas/formularios.
Esta regla prevalece sobre adaptaciones previas para las nuevas propuestas.

## Estados y evidencia

- **Aprobación parcial**: existe PNG aprobado, sólo para el alcance registrado.
- **Presentada / corregir**: existe propuesta, falta corrección y aprobación.
- **Sin lámina identificada**: no hay propuesta de ese recorrido enlazada con aprobación.
- Cada nuevo ID necesita desktop, iPad horizontal, iPad vertical y teléfono;
  registrar claro/oscuro por separado. No asumir que aprobar desktop aprueba otros tamaños.
- Los estados vacío, carga inicial, error, offline, permisos y resultado forman parte
  de la cobertura de cada recorrido; pueden ser variantes, no páginas separadas.

## Matriz histórica anterior a round-02 (no estado vigente)

| ID | Pantallas / recorrido a revisar | Situación actual |
|---|---|---|
| ACC-01 | Splash, login Workspace, servidor/DB/usuario recordados y credencial segura | Sin lámina identificada para esta nueva ronda; capturas históricas de desarrollo no bastan |
| ACC-02 | PIN vendedor, bloqueo parametrizado, cambio de usuario y acceso denegado | Sin lámina identificada |
| ACC-03 | Navegación conjunta multirrol; empresa, ubicación y equipo; enrolamiento/revocación | Sin lámina identificada; PIN no eleva a supervisor |
| VEN-01 | Listado de cotizaciones/órdenes, filtros, selección y apertura del registro | Falta propuesta completa; Pendientes de Caja no sustituye este listado |
| VEN-02 | Edición B y ficha de producto, adaptación de rejilla | Aprobación parcial: VENTAS-B, VENTAS-TABLET-MOVIL, VENTAS-VERTICAL-COBRO; sólo B desktop |
| VEN-03 | Mostrador: búsqueda inline, lector, edición rápida, guardar/confirmar y siguiente venta | Falta recorrido completo; no basta VEN-02 |
| VEN-04 | Consultiva: cotizaciones, secciones/notas, condiciones, aprobación y seguimiento | Falta recorrido completo; no basta VEN-02 |
| VEN-05 | Consulta de clientes/productos, selección y detalle; impresión/vista previa/reimpresión | Ficha de producto parcial; faltan listados y estados del recorrido |
| CAJ-01 | Pendientes y resultado de cobro | Aprobación parcial: PENDIENTES-RESULTADO-COBRO y VENTAS-VERTICAL-COBRO |
| CAJ-02 | Listados de facturas, pagos, anticipos, cheques, retenciones, depósitos, salidas y cruces | Sin láminas completas identificadas; definir vistas/pestañas reutilizables, no una app por listado |
| CAJ-03 | Cobros de cartera: documentos, selección, aplicación y resultado | Sin lámina completa identificada |
| CAJ-04 | Retención SRI: captura, consulta, revisión, registro y errores | CAJA-RETENCION-v1 presentada / corregir |
| CAJ-05 | Anticipo: captura, medios de pago y resultado | CAJA-ANTICIPO-v1 presentada / corregir |
| CAJ-06 | Depósito bancario: captura y contabilización | CAJA-DEPOSITO-v1 presentada / corregir |
| CAJ-07 | Salida de efectivo y variantes según tipo | CAJA-SALIDA-v1 presentada / corregir |
| CAJ-08 | Cruce de cuentas: fuentes, destinos y confirmación | CAJA-CRUCE-v1 presentada / corregir |
| CAJ-09 | Punto de cobro, sesión y acciones/contadores del turno | CAJA-SESION-v1 presentada / corregir; no cubre apertura/cierre |
| CAJ-10 | Apertura, arqueo, diferencias, cierre y comprobante | Sin lámina identificada |
| CAJ-11 | Variantes de cobro, abono, saldo, vuelto y recuperación de operación interrumpida | Cobro básico parcial; falta cobertura según procesos reales Odoo |
| BOD-01 | Workspace bodeguero y vistas de productos normales/existencias | BODEGA-ENVASES-v1 parcial; no considerar todo Inventario aprobado |
| BOD-02 | Listados y detalle de recepciones, preparación, entregas y transferencias | Sin conjunto completo identificado |
| BOD-03 | Preparación/entrega parcial, escaneo, faltantes y bloqueo de entrega según Odoo | Sin recorrido completo identificado |
| BOD-04 | Conteo físico de productos normales y revisión de diferencias | Sin lámina identificada; no confundir con toma de envases |
| ENV-01 | Dashboard consolidado por producto/envase/presentación y ubicación/custodia/tránsito | Definición aceptada; último dashboard sin aprobación visual explícita |
| ENV-02 | Listado histórico de movimientos y detalle/trazabilidad | Sin lámina identificada |
| ENV-03 | Listados de entregas/devoluciones, tránsitos, clientes/proveedores y tomas | Sin conjunto completo identificado |
| ENV-04 | Registrar desde factura | ENV-FACTURA-v1 aprobado |
| ENV-05 | Registrar desde toma física | ENV-TOMA-FISICA-v1 aprobado |
| ENV-06 | Operación por múltiples líneas: envío/recepción, devolución parcial, diferencias y deterioro | Falta recorrido visual completo; sin sesiones de Caja |
| ENV-07 | Compra adicional / venta de envases y enlace con documentos de Odoo | Definición aceptada; falta recorrido visual, separado de venta del contenido |
| SUP-01 | Bandeja de aprobaciones comerciales, detalle, decisión y devolución al solicitante | Sin lámina identificada |
| SYN-01 | Preparación/sincronización de catálogos y cobertura offline | Sin lámina del nuevo panel identificada |
| SYN-02 | Cola de operaciones, detalle, dependencias, reintento y resultado | Sin lámina identificada |
| SYN-03 | Conflictos: comparación, decisión autorizada y recuperación sin pérdida | Sin lámina identificada |
| CFG-01 | Configuración, preferencias, equipo compartido y modalidad Workspace/PIN | Sin lámina identificada |
| NOT-01 | Actividades/notificaciones, lectura y acceso al documento | Sin lámina identificada |
| OPS-01 | Sesión expirada, reconexión, almacenamiento insuficiente y diagnóstico sin secretos | Sin variantes visuales identificadas |

## Rejillas — decisión del usuario

Usar paquetes Syncfusion para las rejillas de la implementación futura.
Referencia indicada: https://pub.dev/publishers/syncfusion.com/packages
No se ha instalado nada ni se da por validada la licencia, versión o compatibilidad.
La selección concreta del componente se verificará antes de implementar.

Los listados de registros tendrán búsqueda de documentos, filtros, ordenamiento,
columnas configurables, selección y acceso al detalle. Esa búsqueda del listado
no sustituye la búsqueda **inline** de productos al editar líneas de una venta.
No representar acciones masivas financieras/inventario como autorizadas sin validar
los métodos y permisos existentes en Odoo.

## Ampliación transversal — ronda 03

Ver [ROUND_03_REVIEW.md](ROUND_03_REVIEW.md): SHELL-01 (menú/pie), ALERT-01
(avisos internos), ALERT-02 (avisos del dispositivo), CONT-01 (continuidad),
OUT-01 (salidas Odoo) y AI-01 (asistente Odoo).
SHELL-01, ALERT-01 y ALERT-02 **aprobadas el 10/09/2026**, versiones mostradas en
Vista Previa archivadas en `approved/round-03/`. CONT-01, OUT-01 y AI-01 fueron
aprobadas posteriormente el mismo día, también archivadas. Las revisiones no
mostradas de cualquiera de las seis no heredan aprobación.
Complementan los diseños aprobados sin reemplazarlos. La definición textual
está en SHELL_AND_INTERACTION_SPEC.md y ODOO_OPTIONAL_CAPABILITIES.md.

## Procedimiento para cerrar un hueco

1. Crear imagen versionada en `visual_baselines/proposed/` y enlazarla al ID.
2. Registrar dispositivos, tema, estados y alcance realmente representados.
3. Revisar coherencia con Odoo y con las aclaraciones del usuario.
4. Presentar la imagen; guardar la respuesta de aprobación con su alcance.
5. Copiar el original aprobado a `approved/`, sin reemplazar versiones anteriores.
6. Actualizar esta matriz y APPROVAL_REGISTER.md. Ningún bloque queda aprobado
   por proximidad a otro, por una captura de theos_pos o por un «procede».

La prioridad histórica VEN-01, CAJ-02, BOD-02, ENV-02 y ENV-03 ya tiene láminas
aprobadas en round-02; no debe interpretarse como trabajo visual aún no presentado.
Esta matriz hace visibles los huecos conocidos; no afirma que una auditoría de
modelos haya probado todos los casos posibles ni añade reglas de negocio nuevas.
