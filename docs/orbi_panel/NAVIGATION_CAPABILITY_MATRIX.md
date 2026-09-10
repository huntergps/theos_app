# Orbi ERP — matriz de navegación y capacidades

Fecha: 2026-09-10. Estado: contrato documental para revisión e implementación posterior.

Este documento fija la navegación observable y la separación entre capacidades. No
declara ACL, modelos, campos, endpoints, métodos ni módulos instalados. Todo binding
desconocido queda explícito y debe resolverse contra Odoo antes de considerar una
acción implementada.

## 1. Reglas comunes

- El menú es la unión de las capacidades efectivas del servidor/BD, empresa, ubicación,
  usuario y, cuando corresponda, punto/sesión. Se omiten grupos sin capacidad visible,
  conservando el orden estable de las seis áreas.
- Un usuario multirrol permanece en el mismo Workspace: cambiar de área no cambia de
  perfil, vendedor, cajero, supervisor ni autoría. El usuario puede ver Ventas y otras
  áreas sólo en la medida de sus capacidades efectivas.
- Un vendedor accede mediante Workspace con sus credenciales y capacidades efectivas;
  no se le fuerza a un flujo PIN. El PIN es una modalidad limitada a Ventas, incluso
  si la misma persona es supervisora. PIN no concede Caja, Bodega, Envases,
  Aprobaciones, Sistema administrativo ni privilegios de supervisor.
- Sistema, en esta matriz, sólo expone operación propia y diagnóstico personal
  autorizado. No convierte al usuario en administrador ni ofrece configuración o
  diagnóstico privilegiado sin la capacidad efectiva correspondiente.
- En contexto de empresa mixta o multiempresa, cada destino y acción se evalúa para la
  empresa activa. No se mezclan registros, preferencias privadas, capacidades ni
  documentos entre empresas. Cambiar empresa, servidor, BD o usuario invalida la vista
  anterior y revalida capacidades; no borra borradores ni hechos conservados.
- Ocultar una entrada no sustituye la validación del servidor. Cada lectura y acción
  vuelve a comprobar permisos, documento, empresa, destinatario, punto/sesión y
  configuración aplicables.

## 2. Modelo de capacidad

Cada entrada distingue cuatro verbos independientes. Tener uno no implica tener los
otros:

| Verbo | Alcance observable | Binding requerido |
|---|---|---|
| Ver | Listar, buscar, abrir o consultar datos visibles | Modelo/consulta pública, alcance por empresa/usuario y permiso efectivo; pendiente si no está resuelto |
| Editar | Crear o cambiar un borrador/campo/línea permitido | Campos editables, estado, reglas y permiso efectivo; pendiente si no está resuelto |
| Ejecutar | Confirmar, cobrar, registrar, aprobar, enviar, imprimir o producir otro efecto | Método público, documento, aprobación, punto/sesión, transporte y resultado real; pendiente si no está resuelto |
| Administrar | Configurar capacidades, módulos o infraestructura | No forma parte de la navegación operativa por defecto; sólo mostrar si existe capacidad administrativa real y documentada |

`No autorizado`, `no configurado`, `módulo ausente`, `offline` y `temporalmente no
disponible` son estados distintos. Un binding pendiente nunca se rellena con un nombre
de ACL o método inventado.

## 3. Menú estable y submenús

El orden siguiente no cambia por rol. Sólo se muestran las áreas/submenús para los que
exista capacidad efectiva visible en el contexto actual.

| Orden | Área y submenús | Ver | Editar | Ejecutar | Notas de acceso y binding |
|---:|---|---|---|---|---|
| 1 | **Ventas** — Órdenes/cotizaciones; Mostrador; Clientes; Productos | Documentos, clientes y productos visibles | Líneas, cliente, condiciones y borradores según reglas vigentes | Guardar, solicitar aprobación, confirmar o compartir sólo si el documento y la capacidad lo permiten | PIN sólo puede llegar a capacidades de Ventas. Bindings de productos, precios, descuentos, cliente, confirmación y aprobación: **pendientes de enlazar a Odoo**. |
| 2 | **Caja** — Pendientes; Cartera; Registros; Operaciones existentes; Mi turno | Documentos, saldos y operaciones visibles | Composición de cobro, conteo o turno sólo cuando el estado lo permita | Cobrar, registrar pago/anticipo/cheque/retención/depósito/salida/cruce, abrir/pausar/arqueo/cerrar turno según autorización | Requiere Workspace, capacidad de Caja y punto/sesión efectivos por operación. Vendedor no recibe Caja por usar PIN. Bindings de diarios, saldos, punto y sesión: **pendientes**. |
| 3 | **Bodega** — Existencias; Recepciones; Preparación; Entregas; Transferencias; Conteos | Movimientos y documentos con alcance autorizado | Cantidades, lotes/series o conteo cuando la operación lo permita | Registrar recepción, preparación, entrega, transferencia o ajuste sólo por proceso real | No exige ser cajero ni turno de Caja. Preparar y entregar son acciones separadas; no se inventa reserva ni bloqueo universal. Bindings de movimientos y acciones: **pendientes**. |
| 4 | **Envases** — Dashboard; Movimientos; Entregas/devoluciones; Tránsitos; Tomas desde factura o toma física | Productos, recipientes, presentaciones, ubicaciones y tránsitos visibles | Líneas/cantidades y toma física según configuración | Enviar, recibir, entregar, devolver, contar o comprar/vender envases sólo por documento/procedimiento autorizado | No exige sesión de Caja. Contenido, recipiente y presentación permanecen diferenciados. Bindings de modelos, equivalencias, custodia y operaciones: **pendientes**. |
| 5 | **Aprobaciones** — Pendientes; Historial | Solicitudes y estados que Odoo permite consultar | Sólo edición de una solicitud si el proceso vigente lo permite | Resolver/aprobar/rechazar sólo si Odoo autoriza al usuario para ese objeto | Abrir un aviso no aprueba. Bindings de alcance, estados, responsables y métodos: **pendientes**. |
| 6 | **Sistema** — Actividades; Sincronización; Cola/conflictos; Configuración | Estado de la operación propia y preferencias permitidas | Preferencias y recuperación autorizadas | Reintentar o resolver sólo acciones permitidas; no limpiar colas destructivamente | Diagnóstico personal no equivale a administración. Configuración de módulos, credenciales, canales o políticas se gestiona en Odoo y requiere capacidad real. Bindings: **pendientes**. |

Los nombres anteriores son etiquetas de navegación de producto, no nombres de modelos,
permisos ni métodos reales. El texto final de cada entrada debe derivarse del catálogo
de capacidades efectivas; no crear una entrada vacía para una capacidad ausente.

## 4. Contexto de cabecera, pie y dimensiones

Registros de Caja incluye órdenes, facturas, pagos, anticipos, cheques, retenciones,
depósitos, salidas y cruces. Operaciones incluye Retención SRI, Anticipo, Depósito
bancario, Salida de efectivo y Cruce de cuentas. Mi turno reúne apertura, arqueo,
cierre y resultado; pausa sólo si existe el proceso real. Cada acción exige capacidad.
Empresas con equipos personales y compartidos pueden usar Workspace y PIN en paralelo;
este escenario mixto no significa necesariamente multiempresa.

La cabecera conserva marca, empresa, ubicación/almacén, usuario activo y título. En
Caja añade el punto y la sesión efectivos. El pie técnico persistente en escritorio y
tablet horizontal muestra separadamente servidor, BD, hora del servidor, zona horaria,
conexión y sincronización. En vertical/teléfono se ofrece el mismo dato mediante un
indicador compacto desplegable.

La referencia mostrada es la recibida del servidor; no determina por sí sola la
fecha fiscal del documento, que depende del proceso Odoo. Nunca se presenta el reloj
local como hora de servidor. Si la referencia está vieja u offline, se rotula como
última hora recibida/desactualizada; si nunca se obtuvo, se muestra «Hora del servidor
no disponible». La fuente, método y tolerancia de antigüedad requieren binding de
backend. No exponer servidor/BD/hora en notificaciones del sistema o pantalla bloqueada.

| Vista | Composición de navegación | Rejillas |
|---|---|---|
| Escritorio | Barra lateral expandible, cabecera y pie persistentes; detalle conserva retorno y contexto | Permitidas cuando aportan utilidad |
| Tablet horizontal | Barra lateral colapsable con etiquetas accesibles; cabecera y pie persistentes | Permitidas sólo si queda ancho útil |
| Tablet vertical | Menú accesible con grupos/subopciones; listas, tarjetas y formulario de una columna | No usar rejilla UI |
| Teléfono | Menú accesible con grupos/subopciones; lista, detalle y formulario compacto | No usar rejilla UI |

No comprimir una rejilla de escritorio dentro de teléfono. El resize conserva filtros,
selección, edición dirty, autoría y posición si el contexto continúa autorizado.

## 5. Cambio de usuario, deep links y continuidad

Al cambiar usuario, se congela el contexto anterior, se retira de la vista su contenido
privado y se cargan de nuevo empresa/ubicación/servidor/BD, sesión/punto y capacidades.
No se reutilizan historial privado, respuestas de IA, permisos, notificaciones ni
acciones pendientes del usuario anterior. Los borradores, documentos, caché persistida
y operaciones pendientes autorizadas se conservan aislados por servidor/BD/empresa/
usuario y mantienen autoría.

Todo deep link o aviso que apunte a un registro debe, después de autenticar, revalidar
contexto y acceso y abrir el documento exacto sólo si sigue autorizado. Un enlace que
pertenezca al usuario anterior no revela contenido: vuelve a una ruta segura o explica
que el recurso no está disponible. Una respuesta tardía de A nunca modifica la pantalla
de B. Al volver, se restauran filtros, selección y posición sólo dentro del contexto
autorizado actual.

## 6. IA y salidas opcionales

Asistente, impresión, WhatsApp y Telegram sólo aparecen cuando el módulo/capacidad de
Odoo está instalado y además configurado, autorizado, compatible con el documento,
destinatario y transporte. La caché no concede privilegios; la ejecución revalida todo.
No existe fallback de proveedor IA, SDK, bot, cola, plantilla o canal paralelo en Orbi.

- IA separa consultar, proponer y ejecutar; una propuesta no factura, cobra ni
  confirma. Sólo usa agentes, herramientas y proveedores autorizados en Odoo.
- Impresión distingue trabajo generado, enviado al transporte, entregado y fallo.
  Generar bytes no prueba impresión física; reimprimir no repite venta ni cobro.
- WhatsApp reutiliza la salida/documento real que Odoo autorice. Telegram no se marca
  como PDF/adjunto entregado: sólo está acreditado el canal de texto existente hasta
  que Odoo lo amplíe.
- Offline no llama IA remota ni asegura envíos externos. Una salida pendiente conserva
  el resultado comercial y muestra su estado técnico separado.

## 7. Matriz de escenarios de aceptación

Estado global de esta matriz: **no ejecutado**. Preparar o aprobar este documento no
marca escenarios como pasados. Un prototipo sólo acredita interacción; el efecto real
requiere bindings autorizados y verificación de servidor.

| ID | Escenario | Aceptación observable | Binding/estado |
|---|---|---|---|
| NAV-1 | Usuario con Ventas, Caja y supervisión recorre áreas | Mismo Workspace, usuario y autoría; no aparece selector de perfil | No ejecutado; capacidades efectivas pendientes |
| NAV-2 | Vendedor-supervisor entra con PIN y luego Workspace | PIN muestra sólo Ventas; Workspace reúne áreas reales sin elevar privilegios | No ejecutado; enrolamiento/PIN/autorización pendientes |
| NAV-3 | Vendedor accede sin PIN | Puede usar Workspace según capacidades; no se presume rol administrativo | No ejecutado; binding de autenticación pendiente |
| NAV-4 | Usuario en empresa mixta cambia empresa | Menú y documentos se recalculan; no se mezclan entidades ni preferencias privadas | No ejecutado; alcance multiempresa pendiente |
| NAV-5 | Cambio A→B con deep link o respuesta tardía de A | B no ve contenido ni recibe mutaciones de A; enlace revalida y abre sólo recurso autorizado | No ejecutado; invalidación/continuidad pendientes |
| NAV-6 | Operación de Caja con punto/sesión | Sólo se ejecuta con punto y sesión efectivos; vendedor no hereda turno ajeno | No ejecutado; binding de punto/sesión pendiente |
| NAV-7 | Pie online, offline y hora vieja | Muestra servidor/BD y hora recibida; diferencia claramente última hora, offline y no disponible | No ejecutado; hora remota pendiente |
| NAV-8 | Mismo recorrido en cuatro vistas | Rejillas sólo escritorio/horizontal; vertical/teléfono usan listas/tarjetas/formulario sin perder contexto | No ejecutado; responsive pendiente |
| NAV-9 | Capacidad IA/salida ausente o sin configuración | Acción ausente o bloqueada con causa; no aparece proveedor/canal alternativo | No ejecutado; catálogo efectivo Odoo pendiente |
| NAV-10 | Enlace a aprobación, impresión o envío | Documento exacto, acceso revalidado; abrir aviso no ejecuta; resultado distingue efecto real | No ejecutado; métodos públicos/resultados pendientes |

La evidencia futura debe registrar escenario, versión, viewport, actor/capacidades,
precondiciones, pasos, resultado visible, efecto local/remoto, captura o vídeo,
incidencias y estado: `no ejecutado`, `bloqueado por binding`, `falló`, `pasó en
prototipo` o `pasó con integración real autorizada`.
