# Ronda 04 — checklist visual de oscuro y estados

Estado: criterios para preparar nuevas propuestas. No afirma que existan imágenes,
que estén aprobadas ni que la app esté implementada.

**Corrección posterior del dueño:** no crear una imagen oscura por pantalla.
El tema se valida mediante componentes y 2–3 ejemplos representativos. Los cuatro
formatos siguen siendo criterio responsive y de prueba futura, no multiplicador
obligatorio de imágenes de tema. Véase PERSONALIZATION_SPEC.md.

## Regla de cada lámina

- Presentar cuatro vistas completas: Desktop, iPad horizontal, iPad vertical y teléfono.
- Desktop/iPad horizontal pueden usar rejillas para datos tabulares: encabezado fijo,
  búsqueda, filtros, orden, columnas y acceso al detalle.
- iPad vertical/teléfono no usan rejillas: listas, tarjetas, formularios y acciones
  agrupadas, con texto legible y scroll seguro.
- Repetir el mismo registro/datos entre formatos. Identificar viewport, tema y estado.
- Revisar oscuro en muestras representativas; no duplicar todas las vistas por color.
- Mantener menú de seis grupos en el orden Ventas, Caja, Bodega, Envases, Aprobaciones,
  Sistema; no inventar grupos, ACL, campos o modelos.
- Cabecera: marca/logo Orbi, empresa, ubicación e identidad; en Caja, punto y sesión.
- Pie: servidor, base, hora/zona del servidor, conexión/sincronización y última
  referencia. En portrait puede ser compacto, pero debe abrir la misma información.
- Rotular cada artefacto como propuesta/datos ficticios hasta recibir aprobación explícita.

## Estados comunes por variante

- `loading`: esqueleto/progreso, límite de espera y recuperación; nunca spinner infinito.
- `empty`: distinguir catálogo vacío de filtro sin resultados; CTA sólo si autorizado.
- `error`: causa comprensible, datos conservados y reintento seguro.
- `forbidden`: motivo accionable y regreso; no mostrar CTA ejecutable sin permiso.
- `offline`: antigüedad, capacidades locales y límites; separar negocio de sincronización.
- `pending/sync`: operación local hecha pero pendiente de Odoo, sin convertirla en borrador.
- `conflict`: comparar versiones, preservar ambas y resolver sólo con autorización.
- `partial result`: éxito/fallo por salida o línea, sin booleano global engañoso.
- `recovery`: reinicio, respuesta perdida, sesión expirada y reintento no duplican hechos.

## Acceso e identidad

- Workspace: servidor/base/usuario, credencial oculta, restauración y desconexión segura.
- PIN: sólo ventas; mostrar bloqueo/error y ruta separada a Workspace, sin privilegios.
- Cambio de usuario/empresa/base: conserva borradores autorizados, aísla autoría y
  revalida capacidades; no filtra historial privado al usuario siguiente.
- Oscuro: contraste de campos, errores, foco, teclado numérico y botones en los cuatro
  formatos; no usar fondos fotográficos que reduzcan lectura.
- Estados: credencial inválida, servidor inaccesible, sesión expirada, usuario sin
  permiso y almacenamiento local no disponible.

## Ventas

- Listado de órdenes/cotizaciones: columnas sólo en wide, tarjetas en portrait;
  `Mis ventas` activo/removible y `Todas` limitado a visibles por Odoo.
- Mostrador: búsqueda inline en nueva línea, lector, cliente/condición/total, guardar,
  confirmar y resultado enviado a Caja. No atribuir cobro al vendedor.
- Consultiva: secciones/notas, términos de pago, descuentos según permiso, solicitar
  aprobación y seguimiento; no confirmar mientras la política lo impida.
- Estados por flujo: borrador, enviada, pendiente de aprobación, aprobada, confirmada,
  bloqueada por cupo/mora, error de guardado y sincronización pendiente.
- Oscuro: distinguir estados comerciales de sincronización y conservar foco/edición dirty.

## Caja

- Cabecera debe identificar punto, sesión y cajero. Menú agrupa pendientes, cartera,
  registros, operaciones existentes y Mi turno sin ocultar el contexto efectivo.
- Cobro: saldo, abono, vuelto, resultado y recuperación; doble pulsación/reintento no
  crea otro pago. Cartera debe verse como recorrido distinto.
- Auxiliares: retención, anticipo, depósito, salida y cruce muestran permisos,
  documentos, estado y resultado; no presentarlos como pasos obligatorios consecutivos.
- Turno: apertura, movimientos, arqueo, diferencias, cierre y comprobante; estados
  `en curso`, `requiere revisión`, `cerrado`, error y recuperación.
- Listados de registros: facturas, pagos, anticipos, cheques, retenciones, depósitos,
  salidas y cruces; tabs/listas deben indicar vacío, prohibido y filtro sin resultados.
- Impresión/reimpresión/scanner: mostrar generado, transporte, entregado o fallo;
  nunca confirmar venta ni repetir cobro por imprimir.

## Bodega y Envases

- Bodega: existencias, recepciones, preparación, entregas, transferencias y conteos.
  Separar preparado/trasladado de entregado; mostrar faltantes y bloqueo Odoo.
- Estados Bodega: operación asignada, en preparación, parcial, bloqueada, entregada,
  conteo con diferencia, error, offline y conflicto.
- Envases: workspace separado de Caja; dashboard, movimientos, entregas/devoluciones,
  tránsitos y tomas desde factura o física.
- Envases mantiene producto, recipiente, presentación, propiedad/custodia y equivalencia
  separados; soporta múltiples líneas/cantidades y no suma conteos repetidos.
- Estados Envases: pendiente, parcial, diferencia, deterioro, conciliado, prohibido,
  offline y conflicto. Compra/venta de envases permanece separada del contenido.
- Portrait usa tarjetas/formularios; wide muestra tablas cuando el dato lo exige.

## Aprobaciones y Sistema

- Aprobaciones: bandeja pendientes/historial, detalle, aprobar, devolver y motivo;
  sólo acciones permitidas. Estados pendiente, aprobada, devuelta, expirada, error.
- Sistema: actividades, sincronización, cola/conflictos y configuración; diferenciar
  preferencias de capacidades/permisos y no ofrecer configuración de secretos al operador.
- Avisos: transient, banner inline, modal o centro persistente según severidad; OS sólo
  con consentimiento y sin secretos/importes en pantalla bloqueada.
- IA, WhatsApp, Telegram e impresión aparecen sólo si Odoo los tiene instalados,
  configurados y autorizados. Telegram no anuncia adjuntos sin contrato backend.
- Offline no promete entrega OS con app cerrada; mostrar pendiente y conservar trabajo.

## Evidencia y cierre

Cada propuesta debe registrar ID nuevo/versionado, formato, tema, estados, datos ficticios,
alcance y diferencias con la baseline. Revisar que menú, cabecera, pie, foco, contraste
y textos sean coherentes entre familias. No sobrescribir PNG aprobado. La aprobación
visual posterior debe citar exactamente la versión presentada; no certifica bindings,
permisos efectivos, APIs, impresión física, seis plataformas ni comportamiento Odoo.
