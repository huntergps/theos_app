# Matriz operativa de interacción y offline

Fecha: 2026-09-10. Documento de enlace para implementación y aceptación posterior.
No declara que una pantalla, permiso, endpoint, cola offline o política fiscal esté
implementada.

## Cómo leerla

- **D (definido):** requisito acordado en los contratos de producto/interacción.
- **I (interacción):** comportamiento observable de esta matriz, sin inventar reglas
  empresariales.
- **B (binding por verificar):** falta comprobar campo, método, ACL, configuración,
  provisión o resultado real en Odoo. Una fila B no habilita la acción.

«Local» significa conservar una consulta, edición o comando con identidad estable; no
significa confirmado en remoto. Guardar localmente no equivale a confirmar, cobrar,
contabilizar, entregar, imprimir ni enviar. Si el contrato offline de una operación no
está explícitamente vinculado, la aplicación conserva un borrador o intención y muestra
que la ejecución queda pendiente; no afirma que la política la permita.

Las filas reutilizan escenarios ya definidos: [INTERACTION_ACCEPTANCE_SPEC.md](INTERACTION_ACCEPTANCE_SPEC.md)
(`VM-*`, `VC-*`, `CJ-*`, `BD-*`, `EV-*`, `MU-*`, `SY-*`) y
[KEYBOARD_AND_INPUT_CONTRACT.md](KEYBOARD_AND_INPUT_CONTRACT.md) (`KI-*`). No se copian
los casos; esos IDs son la referencia de ejecución.

## Reglas transversales

Prevalecen las políticas reales: comprobar stock/crédito no impone un bloqueo
universal ni confirmar implica bloquear automáticamente una orden. Un hecho local
autorizado puede completarse offline y seguir pendiente de confirmación remota.
Sin conexión no se consulta SRI; registrar datos ya verificados depende del contrato
real, no de una prohibición universal. Identificadores citados requieren contraste
con fuentes; no acreditan campos existentes ni transporte implementado.
Si falta binding, preparar trabajo local autorizado no programa ejecución futura
automática. Estas precisiones prevalecen sobre las abreviaciones de las filas.

Archivos pendientes viven en almacenamiento durable protegido de limpieza de caché.
Fallo de disco impide anunciar guardado; no prometer recuperar bytes no persistidos.
Véase [componentes reactivos](REACTIVE_COMPONENTS_SPEC.md).

| Tema | Requisito operativo | Binding/evidencia pendiente |
|---|---|---|
| Identidad y actor | Cada documento, cobro, turno, despacho, aprobación y comando conserva `commandId`/UUID, empresa, contexto y actor original. Una lista reordenada nunca identifica por índice. | Revalidar ACL, compañía, usuario y versión en servidor; no aceptar `user_id` libre del cliente. |
| Texto y selección | Editar un campo es edición local del formulario, no un widget SQL ni una escritura remota implícita. Nombre visible e ID de cliente/producto se actualizan juntos. | Campos reales, precisión, reglas y método de persistencia por verificar. |
| Búsqueda de producto | Se hace inline en la última/nueva línea (o tarjeta editable en portrait), con destino explícito. Enter acepta sólo la sugerencia enfocada; búsqueda obsoleta no reemplaza cursor, línea o entidad. | Consulta, escáner, consolidación y cobertura de catálogo por verificar. |
| Resultado | Separar `businessState` de `syncState` (`localOnly`, `queued`, `sending`, `synced`, `conflict`, `failed`) y, cuando aplique, `fiscalState`. Respuesta perdida es `unknown`, no éxito. | Garantía atómica de replay, consultas de estado e idempotencia concurrente por verificar. |
| Retorno | Volver/cerrar selector devuelve foco al llamador, conserva filtros, scroll y borrador autorizado. Descartar requiere intención explícita y sólo afecta al borrador elegido. | Persistencia después de reinicio, cambio de usuario, actualización y falta de espacio por verificar. |

## Ventas

| Operación | Acción explícita y validación | Efecto local / expectativa del servidor | Resultado, rechazo, conflicto o incierto | Retorno / borrador |
|---|---|---|---|---|
| Mostrador: crear/editar venta | Identidad vendedor → buscar producto inline o escanear → cantidad/unidad/condiciones → cliente/término → **Guardar**, **Solicitar aprobación** o **Confirmar**. Validar entidad, cantidad, precio, descuento, crédito y requisitos configurados; Enter no confirma globalmente. | Con catálogo/precios/clientes provisionados se puede editar un borrador local si la política lo autoriza. Servidor debe revalidar `sale.order`, ACL, compañía, stock/precio/crédito y autoría. | `localOnly/queued` no es `sale/done`; confirmación sólo es éxito cuando Odoo confirma y bloquea. Rechazo conserva valores y causa. UUID/versión permite consultar; sin garantía atómica queda `unknown` y no se reintenta ciegamente. | Suspender A y crear B mantiene unidades separadas. Volver al catálogo no crea otra venta; recuperar abre el mismo ID. Referencia/QR o impresión no confirma. Referencias: `VM-1…VM-5`. |
| Consultiva: cotización y seguimiento | Buscar documento por alcance visible → cliente → productos inline, secciones/notas y condiciones → revisar → **Guardar/Compartir/Solicitar aprobación/Confirmar**. Cliente, término y condiciones se validan sin sobrescribir un campo dirty. | Edición local sólo conserva propuesta y revisión. Servidor recalcula y comprueba ACL, condiciones, aprobación y revisión esperada. Compartir/impresión sólo cambia salida si el canal lo acredita. | Rechazo comercial deja cotización editable con motivo. Cambio concurrente es `conflict`; no mezcla precios ni autoría. Respuesta incierta se consulta por identidad. | Aviso de aprobación vuelve a la cotización exacta sin confirmar. Filtros, posición y borrador se conservan. Referencias: `VC-1…VC-4`, `FL-1…FL-4`, `MU-2`. |
| Edición de imagen de producto/cliente | Control **Editar imagen**, elegir/reemplazar/eliminar y confirmar la intención; conservar el resto del formulario. | Preparar una vista previa local no muta Odoo. Subir, reemplazar o eliminar exige permiso y validación del servidor (modelo, compañía, tamaño/formato, ACL). Offline sólo puede quedar pendiente si existe autorización explícita para esa operación y caché durable de archivos. | Sin permiso, archivo inválido o conflicto de versión: rechazo visible, archivo original intacto. Corte tras subida: `unknown`, consultar antes de duplicar. Nunca perder imagen seleccionada, borrador ni error por reinicio/falta de espacio. | Volver conserva la imagen local y el borrador etiquetados como pendientes; no presentarlos como imagen remota actualizada. Binding de campos, permisos, endpoint y política offline: **B**. |

## Caja: cobro y operaciones auxiliares

| Operación | Acción explícita y validación | Efecto local / expectativa del servidor | Resultado, rechazo, conflicto o incierto | Retorno / borrador |
|---|---|---|---|---|
| Encontrar cartera y cobrar | Seleccionar documento por identidad → revisar deuda, pagos y saldo → elegir medio(s) → recibido/vuelto si aplica → **Cobrar <importe>**. Validar sesión/punto, moneda, precisión, medios y abono permitido. Enter en importe/referencia sólo valida ese campo. | Puede conservar compositor y medios localmente. Servidor valida venta, sesión, diario, permisos, saldo y reglas fiscales; no inventar saldo ni autorización. | Aceptado separa cobro y salida de impresión. Sobrepago produce vuelto cuando el proceso lo permite. Doble pulsación no duplica. Timeout consulta UUID/clave; `unknown` no crea otro pago. | Cambiar documento abre compositor propio. Resultado persistente identifica cliente/documento, aplicado, saldo, vuelto y estados. Referencias: `CJ-2…CJ-6`, `KI-07`, `KI-08`, `KI-17`. |
| Retención SRI | Capturar → **Consultar SRI** → revisar datos descargados → **Registrar**. No editar libremente datos obtenidos ni convertir estados visuales en estados backend. | Sin conexión SRI no se consulta ni registra; sólo conservar intención/datos si una política futura lo autoriza. Servidor/SRI valida clave, factura, impuestos, compañía y ACL. | Rechazo conserva captura y causa. Resultado incierto se reconcilia por clave/documento; no repetir registro. | Regresa al cobro conservando compositor. Binding fiscal y offline: **B**. |
| Anticipo | **Registrar anticipo** o **Aplicar anticipo existente** (acciones distintas); elegir cliente/medio y revisar disponible/usado. | Borrador local no aumenta `amount_available`. Servidor valida cliente, sesión, medios, montos y permisos antes de postear/aplicar. | Rechazo por saldo/ACL conserva datos. Sin UUID atómico identificado, timeout exige consulta antes de reintentar. | Retorna al documento con resultado y saldo del contrato, sin pedir seleccionar de nuevo. Binding completo/offline: **B**. |
| Nota de crédito | Seleccionar documento autorizado → aplicar importe → revisar saldo → **Aplicar/Crear** sólo si el binding lo ofrece. | Sólo preparar datos localmente salvo política explícita; servidor valida documento, saldo, compañía y permiso de creación/reversión. | Conflicto de saldo queda pendiente/rechazado, nunca descuenta localmente como hecho remoto. Resultado incierto se consulta por documento. | Conserva cobro preparado y vuelve con salida disponible. Binding: **B**. |
| Depósito bancario | Abrir formulario existente → completar variante, monto, moneda, banco/papeleta y sesión → **Guardar** y, separadamente si corresponde, **Contabilizar**. | Registro local sólo si política explícita; asiento y `move_id` requieren servidor. Validar desglose real de sesión, ACL, diario y compañía. | Error contable no borra registro preparado. `deposit_uuid`/`move_id` se consulta ante timeout; conflicto queda visible. | Vuelve a registros del turno con borrador y estado separado. Referencia: `CJ-7`; binding/offline: **B**. |
| Salida de efectivo | Elegir tipo existente → completar motivo/aplicación que el formulario exija → **Registrar**. No inventar selector de movimiento. | Sólo encolar si backend declara operación offline-capable; saldo local no es cupo. Servidor asigna sesión propia y valida diario, punto y ACL. | Rechazo conserva motivo y datos. No hay UUID propio demostrado: timeout es `unknown`, no repetir `create`. | Retorna a Caja/registros con autoría de cajero y sesión. Binding/offline: **B**. |
| Cruce de cuentas | Identificar fuentes/destinos → revisar saldos e importes → **Confirmar cruce** con supervisor cuando corresponda. | No aplicar fondos contra saldos locales. Servidor valida ambos lados, documentos vivos, supervisor y conciliación. | Rechazo/conflicto conserva evidencia; incierto consulta conciliaciones antes de reintentar. No se presenta como recepción de efectivo. | Retorna al origen con resultado auditado. Binding/offline: **B**. |
| Registros del turno | **Abrir registros** y consultar órdenes, facturas, pagos, anticipos, cheques, salidas, retenciones y cruces dentro del turno autorizado. | Lectura de snapshot local muestra antigüedad/cobertura. Servidor sigue siendo fuente de verdad y revalida sesión/alcance. | Catálogo parcial muestra cobertura/error propio; no afirma lista completa. Respuesta tardía no cruza usuario o turno. | Conserva búsqueda, selección y punto/turno. Referencia: `CJ-7`; capacidades: **B**. |
| Apertura de turno | **Abrir turno** explícito, seleccionar único punto autorizado sólo si hace falta, y confirmar datos requeridos. | Un formulario local puede ser borrador; crear sesión exige permiso, punto, compañía y contrato offline explícito. `session_uuid` estable evita reintento ciego. | Distinguir sin turno, punto ocupado, falta de asignación y fallo de consulta. Timeout consulta sesión; nunca crea duplicado. | Cancelar conserva borrador; volver no lo convierte en turno abierto. Referencia: `CJ-1`; binding/offline: **B**. |
| Pausa, bloqueo y recuperación | **Pausar/Bloquear/Recuperar** como acciones distintas; cambiar usuario no cierra contablemente. Validar estado y actor. | Cachear estado local no transfiere turno ni amplía autorización. Servidor valida propietario, estado y configuración. | Rechazo mantiene estado conocido; respuesta incierta requiere consultar sesión. | Recuperar sólo sesión propia/autorizada, con cobro pendiente intacto. Binding: **B**. |
| Arqueo/conteo | Abrir editor → introducir denominaciones/conteo → revisar total/diferencia → **Guardar conteo**. No simular cero por campo vacío. | Conteo local es observación/borrador; servidor valida corte, sesión, moneda y cálculo cuando el proceso lo permite. | Distinguir sin dato, diferencia, incidencia y cierre. No cerrar ni ajustar por navegar o escanear. | Cerrar editor conserva conteo y vuelve a la revisión. Referencia: `CJ-7`; binding: **B**. |
| Cierre de turno | **Cerrar** tras revisar turno → arqueo/diferencias/incidencias → acción permitida → **Confirmar cierre**. | Preparar cierre local sólo si autorizado; servidor valida pendientes, conteo, diferencias, estado, permisos y contabilización. | Red no equivale a cierre. Rechazo conserva turno y evidencia; timeout consulta estado/comprobante, sin duplicar cierre. | Resultado persistente separa cierre, sync y fiscalidad; pendientes se muestran. Binding de cierre offline: **B**. |

## Bodega, Envases y aprobaciones

| Operación | Acción explícita y validación | Efecto local / expectativa del servidor | Resultado, rechazo, conflicto o incierto | Retorno / borrador |
|---|---|---|---|---|
| Bodega: preparar/transferir/recibir | Bandeja → identificar documento, origen, destino y responsable → revisar líneas, unidades, lotes/series → **Preparar/Registrar recepción/Transferir**. **Entregar** es acción distinta. | Preparación interna puede conservarse localmente sólo si está provisionada/autorizada. Servidor valida ACL, ubicación, trazabilidad, parciales y candado de cobro donde corresponda. | Faltante/parcial conserva entregado y restante. No crear reserva universal. Timeout consulta picking/`date_done`; no crear despacho paralelo ni declarar entrega. | Vuelve a la bandeja exacta con tarea, remanente y borrador. Referencias: `BD-1…BD-4`. |
| Envases: envío, recepción, devolución, compra/venta | Responsable (sin requerir Caja) → seleccionar líneas de contenido/recipiente/presentación → revisar equivalencia, propiedad, custodia, origen/destino y cantidad → **Enviar/Recibir/Devolver/Comprar/Vender**. Devolución parcial lleva condición y causa. | No hay binding funcional identificado. Local sólo puede conservar comando/datos si política y API autorizadas existen; no crear stock/saldo paralelo. Servidor es fuente de verdad de movimientos y permisos. | Sin modelo, ACL, identidad e idempotencia verificados: acción no habilitada, `unknown` no se reintenta. Diferencia/deterioro queda pendiente de decisión; no sumar dos veces. | Dashboard/toma/factura conserva referencia y borrador propio. Responsable puede operar sin Caja sólo como requisito conceptual, no como capacidad implementada. Referencias: `EV-1…EV-5`; binding: **B**. |
| Envases: toma física y ajuste | Capturar ubicación/custodia/momento/cantidades → **Guardar toma** → revisar diferencia → **Aplicar ajuste** sólo como acción autorizada. | Observación local no altera existencia. Servidor compara corte y registrado; ajuste compensatorio requiere autoridad y auditoría. | Diferencia, conflicto de propiedad o recepción parcial quedan explícitos; no corregir snapshot en silencio. | Volver conserva observación y propuesta, no la convierte en movimiento. Binding/offline: **B**. |
| Aprobación comercial/FSC | Abrir aviso → revalidar pedido exacto → revisar motivo, consecuencias y responsable → **Aprobar/Rechazar/Solicitar corrección** explícitamente. | Local puede conservar solicitud pendiente; resolver exige permiso, documento y revisión esperada en servidor. No confirmar automáticamente al abrir aviso. | `approval_required` no es éxito. Rechazo conserva pedido; revisión cambiada es conflicto; incierto se consulta por pedido/solicitud. | Retorna al solicitante/pedido exacto sin robar foco ni mezclar usuario. Referencias: `VC-3`, `MU-2`, `FL-1…FL-4`; binding: **B**. |

## Sincronización, recuperación y soporte

| Operación | Acción explícita y validación | Efecto local / expectativa del servidor | Resultado, rechazo, conflicto o incierto | Retorno / borrador |
|---|---|---|---|---|
| Catálogo y búsqueda | **Actualizar/reintentar catálogo** por familia; consultar cobertura antes de presentar disponibilidad. Buscar producto mantiene consulta y cursor. | Cache local sólo representa página/cobertura descargada con antigüedad. Servidor entrega versión, alcance y progreso; no se inventa stock, crédito o saldo. | Error de una familia conserva las anteriores correctas y marca `failed`; respuesta tardía obsoleta no reemplaza selección. | Vuelve a la línea/formulario sin perder entrada; no se ofrece producto no cubierto como disponible. Referencias: `SY-1`, `SY-2`, `KI-04`, `KI-12`. |
| Replay de comandos | **Reintentar** sólo desde incidencia concreta, con el mismo `commandId`, actor, entidad, precondiciones y versión. | Encolar conserva identidad y dependencias. Servidor debe ofrecer clave única/endpoint transaccional probado; buscar y luego crear no basta. | `synced` sólo con respuesta empresarial verificable. Rechazo explica causa. `conflict` requiere decisión; `unknown` exige consultar/reconciliar, nunca reintento ciego. | Operación y borrador quedan recuperables tras reinicio; no existe “borrar cola” como recuperación. Referencias: `SY-3`, `SY-4`, `KI-17`. |
| Sesión/contexto | **Revalidar sesión**, cambiar usuario/empresa/base o recuperar pendientes como acciones explícitas. | Lectura local no extiende permisos. Servidor revalida autenticación, alcance y actor; respuestas tardías se descartan al cambiar contexto. | Sesión expirada se distingue de sin red. Datos privados de A no aparecen en B; conflicto conserva autoría. | A→B→A recupera sólo borradores de A permitidos; reinicio no borra hechos guardados. Referencias: `ACC-4`, `ACC-5`, `MU-3`, `MU-4`, `SY-5`. |
| Archivos, comprobantes e imágenes pendientes | **Reintentar subida/impresión/compartir** desde su resultado, nunca desde un botón de cobro/registro nuevo. Validar destino y autorización. | Archivo pendiente sólo se conserva en caché durable autorizada; debe sobrevivir reinicio, error y conflicto sin perder el draft. Impresión/compartir no cambia por sí solo el estado empresarial. | Fallo de impresora conserva cobro. Archivo rechazado o conflicto conserva original y evidencia; respuesta incierta consulta salida/adjunto antes de duplicar. | Resultado ofrece reimprimir/continuar sólo si la capacidad está disponible; salida pendiente se etiqueta como tal. Binding de archivos/canales: **B**. |

## Checks de cierre

- [ ] Cada acción sensible tiene control explícito; Enter, Escape, escáner y notificación
  no disparan otra operación por propagación.
- [ ] Cada fila distingue edición/guardado local de confirmación remota y conserva actor,
  identidad, empresa, dependencias y versión.
- [ ] Cada rechazo conserva el borrador corregible; cada `unknown` consulta identidad
  antes de reintentar; cada `conflict` requiere resolución autorizada.
- [ ] No se afirma offline permitido sin binding de API, ACL, configuración, provisión,
  idempotencia atómica y evidencia de aceptación.
- [ ] Campos de texto se editan localmente; cliente/producto se seleccionan como entidad
  atómica; búsqueda de producto permanece inline.
- [ ] Edición de imágenes valida permisos en servidor; una pendiente offline sólo usa
  caché de archivos durable explícitamente autorizada, con draft/error/conflicto intactos.
- [ ] Validar escenarios referenciados (`VM/VC/CJ/BD/EV/MU/SY/KI`) sin duplicarlos aquí,
  en las cuatro vistas y con teclado/tacto/lector de pantalla según sus contratos.

Referencias normativas: [INTERACTION_ACCEPTANCE_SPEC.md](INTERACTION_ACCEPTANCE_SPEC.md),
[KEYBOARD_AND_INPUT_CONTRACT.md](KEYBOARD_AND_INPUT_CONTRACT.md),
[ODOO_OFFLINE_CONTRACT_MATRIX.md](ODOO_OFFLINE_CONTRACT_MATRIX.md),
[ENVASES_DOMAIN_CONTRACT.md](ENVASES_DOMAIN_CONTRACT.md),
[CONTRACTS.md](CONTRACTS.md).
