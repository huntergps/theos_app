# Orbi ERP — interacción y aceptación por tarea

Fecha: 2026-09-10. Estado: especificación documental para revisión e implementación posterior.
No declara pantallas implementadas, pruebas ejecutadas ni nuevos permisos o métodos Odoo.

## 1. Alcance, decisiones y evidencia

Este documento concreta cómo se operan las familias de pantallas y cómo se comprobará su
usabilidad. Complementa, sin duplicar reglas empresariales, la
[especificación de producto](ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md), el
[shell y sus interacciones](SHELL_AND_INTERACTION_SPEC.md) y los
[contratos C01–C07](CONTRACTS.md).

Se distinguen tres estados:

- **D — definido:** requisito del dueño o decisión recogida en los documentos anteriores.
- **I — interacción especificada:** comportamiento observable desarrollado aquí para
  completar el recorrido. No supone aprobación de una nueva imagen ni validación con usuarios.
- **B — binding pendiente:** falta enlazar el comportamiento con campos, permisos,
  métodos públicos, configuración o resultados reales del backend. No se sustituye por
  lógica inventada en un widget.

Las reglas de negocio son D; los detalles de manejo de foco y los escenarios de este
documento son I cuando no estaban ya expresados en las fuentes. Cada familia enumera sus B.
La aprobación visual vigente se consulta en [APPROVAL_REGISTER.md](APPROVAL_REGISTER.md):
round-02 y las seis versiones presentadas de round-03 están aprobadas para lo representado.
Las notas históricas que aún dicen «pendiente» no revierten esas aprobaciones. Una lámina
aprobada no acredita campos, errores, variantes o recorridos que no muestra.

La [cobertura visual](VISUAL_COVERAGE.md) fija cuatro vistas y la regla vigente: rejillas
sólo en desktop e iPad horizontal; iPad vertical y teléfono usan listas, tarjetas y
formularios. Las tablas de este documento organizan requisitos; no proponen rejillas en
la UI vertical. La selección del paquete de rejillas no cambia el comportamiento de la tarea.

### 1.1 Evidencia local usada

- [Venta actual](../../theos_panel/lib/features/sales/sale_editor.dart),
  [órdenes](../../theos_panel/lib/features/orders/orders_screen.dart),
  [Caja](../../theos_panel/lib/features/collection/collection_screen.dart),
  [Bodega](../../theos_panel/lib/features/warehouse/warehouse_screen.dart) y
  [sincronización](../../theos_panel/lib/features/sync/sync_center.dart) de `theos_panel`:
  sirven para reconocer límites actuales; su existencia no demuestra paridad.
- [Cobros en theos_pos](../../theos_pos/lib/features/sales/screens/fast_sale/widgets/pos_payment_tab.dart),
  [captura por medio](../../theos_pos/lib/features/sales/screens/fast_sale/widgets/add_payment_dialog.dart)
  y [sesión de Caja](../../theos_pos/lib/features/collection/screens/collection_session_screen.dart):
  referencias de contexto, desglose, recibido/vuelto y jornada.
- [Revisión de formularios de Caja](CASH_FORMS_REVIEW.md): las correcciones de fidelidad
  prevalecen sobre campos ilustrativos de imágenes históricas. No introducir, por ejemplo,
  selectores o restricciones sólo porque aparecieron dibujados.
- Las decisiones de Envases proceden del registro de aprobaciones y de cobertura; no se
  atribuye a la aplicación actual un módulo de Envases ya enlazado o probado.

## 2. Contrato común de interacción

### 2.1 Unidad de trabajo e identidad

**D.** Cada pedido, cobro, despacho, aprobación, turno o toma conserva identidad estable,
autor, empresa y documento origen. Selección visual y objetivo de la acción son la misma
entidad; nunca se identifica el registro mediante su posición en una lista reordenable.
`sale.order.user_id` sigue siendo el vendedor. No se añade un vendedor paralelo.

**I.** Un cambio de listado, contador o estado no cambia el documento que está editándose.
Si deja de estar visible por un filtro, se conserva el contexto del detalle mientras siga
autorizado y se explica el cambio. Si pierde acceso, se retira su contenido privado y se
conserva el trabajo según C01/C04; no se ejecuta automáticamente con otro usuario.

### 2.2 Teclado, foco, tacto y edición

1. Tab/Shift+Tab recorren controles en orden de tarea. El foco es visible y su nombre
   accesible coincide con la etiqueta legible. No hay acciones exclusivas de hover.
2. Abrir un formulario enfoca el primer campo útil, no necesariamente el primero del
   esquema. Abrir un detalle de consulta no despliega innecesariamente el teclado virtual.
3. Enfocar un campo no borra ni selecciona todo su texto automáticamente. El gesto de
   selección explícito y la captura de escáner se tratan por separado.
4. Enter selecciona la sugerencia que tiene foco. No significa simultáneamente añadir
   producto, guardar pedido y cobrar. Un Enter dentro de observaciones conserva su función
   de edición; una acción sensible sólo se activa desde su control inequívoco.
5. Escape cierra primero las sugerencias; después el diálogo o panel que corresponda.
   Cerrar la capa visual no descarta silenciosamente el borrador ni revierte una operación.
6. Al cerrar un selector, vuelve el foco al campo que lo abrió; tras seleccionar, queda
   en la siguiente entrada útil de esa línea. Un error lleva al primer campo inválido
   después de explicar el problema y conserva los demás valores.
7. Resize, tema, teclado virtual, actualización de lista y notificaciones no recrean
   formularios ni pierden selección de texto, scroll o contenido dirty.
8. Escaneo requiere destino explícito y una interpretación por lectura. No concatena el
   código al campo de cliente, contraseña o importe porque ése tenía foco accidentalmente.
   El lector y sus sufijos se verificarán por dispositivo antes de dar ese recorrido por válido.
9. No se asignan aquí F-keys ni combinaciones comerciales. El inventario de atajos reales
   de `theos_pos`/Odoo, conflictos con navegador/OS y equivalencia táctil es B.

### 2.3 Validaciones y mensajes

**D.** Datos obligatorios, precisión, moneda, términos, autorización, existencias, cupo,
mora y saldos proceden de la configuración y reglas existentes. La UI no fija nuevas
fórmulas, reservas ni umbrales universales. Cliente visible e identificador forman una
selección atómica; texto escrito sin entidad resuelta no se presenta como cliente elegido.

**I.** Validación de entrada se muestra junto al campo con corrección posible; rechazos
de negocio muestran documento, causa y siguiente acción autorizada. No se usa sólo color.
No se reduce todo error a «Error de sincronización», «No disponible en este alcance» o
un nombre de estado técnico. Una acción deshabilitada explica su requisito incumplido;
una capacidad ausente no aparece como tarea que el usuario debe arreglar.

### 2.4 Guardado, retorno y resultado

**D.** Guardar borrador, confirmar, cobrar, emitir documento, sincronizar e imprimir son
hechos distintos. La navegación hacia atrás conserva el origen, filtros, selección y
posición permitidos. Una operación completada localmente conserva su hecho empresarial.

**I.** Borradores muestran que están conservados; no se usa un mensaje fugaz como única
evidencia. Descartar es una decisión explícita y sólo afecta al borrador objetivo. Tras
una operación con efectos hay resultado persistente con referencia, estado empresarial,
estado de sincronización y estado fiscal cuando corresponda. El resultado ofrece volver,
continuar e imprimir/compartir sólo cuando esas salidas están disponibles.

Si se pierde la respuesta, el estado expresa qué se conoce y qué debe comprobarse. El
reintento conserva identidad y consulta el resultado por el contrato disponible; no crea
otra operación para conseguir una respuesta verde. Una nueva operación deliberada sobre
el mismo documento no se confunde con el reintento de la anterior.

### 2.5 Accesibilidad comprobable

**D/I.** Mantener objetivos táctiles de al menos 48 px según el sistema visual aprobado,
etiquetas persistentes, errores vinculados a su campo y estados con texto/icono. La
revisión incluye contraste de texto normal 4,5:1 y texto grande 3:1, foco perceptible,
semántica de nombre/rol/valor y reflujo con texto o zoom al 200 %. Estos son criterios de
verificación, no una declaración de conformidad ya obtenida.

Lectores de pantalla anuncian selección y resultado sin repetir el mismo aviso en cada
rebuild. Los mensajes no roban foco ni cubren el campo o acción activa. Movimiento reducido
conserva una transición perceptible sin animación innecesaria; no hay parpadeo de teclado,
campos o estados. Un error o decisión pendiente no desaparece por un temporizador de éxito.

## 3. Acceso Workspace/PIN y cambio de usuario — ACC

**D.** Workspace usa credenciales y reúne permisos efectivos. PIN sólo habilita Ventas,
incluso si la persona también es supervisora. Modalidad y bloqueo dependen de la
parametrización del dispositivo; no hay selector ni listado de operadores recientes.
No se impone bloqueo por PIN a toda sesión ni se crea un plazo de expiración nuevo.

**Recorrido I.** Splash → acceso correspondiente → identidad/contexto visibles → tarea.
Servidor, DB y usuario recordados pertenecen al perfil seleccionado. En un equipo ya
configurado el foco inicial permite completar el dato útil que falta. Guardar contraseña
requiere la elección explícita y el almacén admitido; cambiar perfil no reutiliza la
contraseña de otro perfil. Login incorrecto conserva servidor/DB/usuario y explica cómo
corregir; no mezcla fallo de credencial con ausencia de red.

Cambiar usuario congela el contexto anterior y retira información privada antes de mostrar
el siguiente acceso. Cancelar el cambio sólo retorna al contexto previo si sigue
autorizado. A→B→A recupera los borradores propios y no hace que B herede importes,
formularios, acciones en curso o notificaciones privadas de A. Bloquear, cerrar Workspace
y desautorizar dispositivo son acciones distintas y expresan sus consecuencias.

**B.** Binding de enrolamiento, autorización/revocación, PIN con/sin `hr`, validación
offline, almacenamiento de credenciales por plataforma y reinicio offline web. Un requisito
de producto no acredita que todas esas rutas existan actualmente.

| ID | Dado / acción | Resultado observable |
|---|---|---|
| ACC-1 | Perfil recordado; escribir credencial al aparecer login | Campo responde inmediatamente; no pantalla negra, duplicación de texto ni pérdida de foco |
| ACC-2 | Vendedor-supervisor entra con PIN y después con Workspace | PIN ofrece sólo Ventas; Workspace reúne sus áreas reales sin selector de rol |
| ACC-3 | Cambiar servidor/DB durante una búsqueda tardía del perfil anterior | El resultado antiguo no altera usuario ni credencial del perfil nuevo |
| ACC-4 | A guarda un pedido, cambia a B y retorna a A | B no ve ni modifica el borrador privado de A; A lo recupera íntegro |
| ACC-5 | Sesión expirada o equipo no autorizado, con trabajo local | Se explica la condición y ruta permitida de acceso; no se borra trabajo ni se afirma que falta Internet |

## 4. Ventas de mostrador — VEN-M

**D.** Mostrador puede comenzar con productos si la configuración permite operar antes de
seleccionar cliente. La edición usa `sale.order`, no `pos.order`. Cliente, precio,
descuento, término y confirmación siguen las reglas vigentes. La búsqueda para añadir
productos vive inline en la última/nueva línea, o en la nueva tarjeta editable en portrait.
No se sustituye por la búsqueda externa del listado de documentos.

**Recorrido I.** Identidad del vendedor → buscar/escanear producto → editar cantidad y
condiciones permitidas → resolver cliente/término y requisitos restantes → guardar,
solicitar aprobación o confirmar según el estado real → resultado y próxima venta.
La prioridad de productos no impide acceder antes al cliente ni impone consumidor final.

Al seleccionar producto, nombre/código/unidad e identidad quedan resueltos conjuntamente.
Cantidad admite entrada directa y decimales según unidad; no obliga a pulsar «+» muchas
veces. Una lectura repetida se acumula o crea línea según las condiciones existentes;
nunca se ignora. Se pueden corregir líneas antes de confirmar; el pedido confirmado
permanece bloqueado según Odoo. El resumen conserva total y siguiente acción alcanzables.

Guardar/suspender conserva varias ventas independientes. Volver al catálogo o cambiar
tamaño no crea otra venta. «Nueva venta» abre otra unidad de trabajo; no reutiliza medios
ni asignaciones del documento terminado. Una cotización o referencia/QR sirve para recuperar
el documento autorizado; imprimirla no la confirma. Caja recibe referencia, cliente,
importe debido y estado sin transcripción cuando existe comunicación real.

**B.** Consultas y selección de producto, escáner, reglas de consolidación de líneas,
datos de consumidor final, cambios de precios y candados vigentes; contrato de handoff
entre equipos sin Internet. No se inventa bloqueo universal de stock a partir de una captura.

| ID | Dado / acción | Resultado observable |
|---|---|---|
| VM-1 | Nueva venta; introducir varias líneas desde búsqueda inline | Cada selección afecta su línea; se conserva cliente/contexto y se puede continuar sin abrir ventanas innecesarias |
| VM-2 | Producto con unidad que admite decimal; introducir cantidad válida directamente | Valor y unidad se conservan; el resultado usa precisión/reglas resueltas, sin redondeo impuesto por UI |
| VM-3 | Escanear producto repetido y después uno distinto | Cada lectura tiene efecto visible correcto; no se pierde ni se aplica al cliente o importe |
| VM-4 | Suspender A, trabajar B y recuperar A | Líneas, cliente, condiciones y vendedor siguen separados |
| VM-5 | Guardar/confirmar mientras cambia red o tamaño | No se pierde borrador ni se repite la acción; el resultado comercial y técnico queda visible |

## 5. Venta consultiva y seguimiento — VEN-C

**D.** Comparte modelo y comandos con mostrador. Prioriza cliente y condiciones cuando
determinan precios/crédito. «Mis ventas» es filtro inicial del vendedor; quitarlo muestra
las visibles por ACL, no todo el sistema. Cambiar presentación no duplica el pedido.

**Recorrido I.** Listado con búsqueda/filtros → abrir o crear cotización → seleccionar
cliente → añadir productos inline, secciones/notas y condiciones permitidas → revisar
cambios → guardar/compartir/solicitar aprobación/confirmar según capacidad → seguimiento.
Buscar documentos y buscar productos son controles distintos con alcance visible.

Cambiar cliente, lista o término recalcula por contrato y presenta cambios relevantes.
No se mantienen precios incompatibles ni se sobrescribe silenciosamente un campo dirty.
El rechazo comercial conserva el pedido y explica motivo/siguiente acción. La resolución
de aprobación vuelve al mismo pedido sin confirmar automáticamente ni robar foco.
Imprimir o compartir una propuesta no se rotula como enviada/recibida si el canal no lo
acredita. Volver del detalle conserva filtros y posición del listado.

**B.** Bindings de cliente, condiciones, secciones/notas, solicitud y resolución de
aprobación, cambio de revisión y salidas disponibles. Los importes de una imagen no
constituyen cálculo fiscal ni evidencia de que un descuento esté autorizado.

| ID | Dado / acción | Resultado observable |
|---|---|---|
| VC-1 | «Mis ventas» activo; quitar filtro y abrir un registro | Lista y contador usan el mismo alcance; no aparecen registros fuera de permisos |
| VC-2 | Cliente A seleccionado; escribir/seleccionar B | Nunca se muestra B con el identificador de A; cambios de condiciones se revisan sin perder edición permitida |
| VC-3 | Pedido esperando aprobación; continuar otra tarea y recibir resolución | Aviso recuperable abre el pedido exacto; no confirma por sí solo ni modifica la tarea actual |
| VC-4 | Abrir, filtrar, editar, volver y redimensionar | Consulta, orden, selección y borrador autorizado se conservan |

### 5.1 Cuatro flujos: escenarios comunes a ambas presentaciones

Estos escenarios reproducen D de producto §11; no crean un campo «tipo de venta».
Se prepararán fixtures con términos reales y precondiciones explícitas, sin modificar
precios, permisos o reglas para forzar un resultado favorable.

| ID | Condición de la venta | Resultado a verificar en el recorrido y en su binding |
|---|---|---|
| FL-1 | Crédito puro, aprobación comercial y controles correspondientes | Factura y despacho al confirmar; pedido bloqueado; cupo/mora se respetan |
| FL-2 | Contado puro sin FSC | No se adelantan factura/despacho al confirmar; nacen al cobrar en Caja según proceso vigente |
| FL-3 | Término mixto | Ambas condiciones conviven; factura al confirmar, despacho por su acción y control de lo exigible a la fecha |
| FL-4 | Contado con FSC aprobado | Factura/despacho al aprobar FSC; preparación posible, entrega a cliente requiere el pago completo correspondiente |

Una aprobación comercial o FSC registrada localmente se describe con su estado real y
sincronización separada; no se promete comunicación inmediata con otro equipo desconectado.

## 6. Caja: pendientes, cobro, operaciones y turno — CAJ

**D.** Caja exige Workspace/capacidades y el punto/turno efectivo de la operación.
El cobro reutiliza Caja y los documentos actuales; vendedor, cajera y usuario que ejecuta
no se confunden. El turno de otra persona no pasa a pertenecer a quien inicia sesión.

### 6.1 Encontrar y cobrar

**Precisión incorporada de fuentes Odoo:** [flujo detallado y aceptación CJ-8 a CJ-12](OPERATION_INTERACTION_OFFLINE_MATRIX.md#flujo-de-cobro-contrastado-con-el-wizard-y-panel-odoo).
Abonar añade una línea al wizard; Guardar Abono persiste abonos sin facturar y no
es un borrador; Cobrar procesa el flujo de factura/pagos; Pago Completo cubre el
faltante en efectivo según disponibilidad. No fusionar estas cuatro acciones.
Separar total comercial de importe exigible calculado por Odoo, especialmente en
términos mixtos. Efectivo excedente es vuelto; sobrepago no efectivo sigue el
procedimiento de anticipo. Los métodos existentes no demuestran soporte offline.

**Recorrido I.** Buscar documento/cliente/vendedor en pendientes o cartera → seleccionar
el documento → revisar cliente, importe debido hoy, pagos aplicados y saldo → elegir
medio(s) autorizado(s) → revisar recibido/vuelto cuando aplica → registrar → resultado
persistente → siguiente cliente o comprobante.

El compositor pertenece a la identidad del documento, no al índice de una lista. Muestra
las líneas añadidas y permite editarlas o retirarlas antes de registrar. Importe aplicado,
efectivo recibido y vuelto son conceptos visibles distintos. La moneda y precisión son
las reales; un billete mayor que la deuda no se rechaza como sobrepago si se devuelve vuelto.
Un abono parcial sigue el procedimiento permitido y deja saldo explícito.

El medio inicial puede derivar de configuración pertinente; no se hereda ciegamente del
cliente anterior. Tarjeta, transferencia, cheque y demás medios presentan los campos
que exigen sus modelos/configuración. No se crean diarios desde el compositor ni se pide
información que sólo procede de un dibujo. No se añade un checkbox genérico para que la
cajera certifique el cálculo de lo exigible si la regla existente no lo requiere.

El botón identifica la acción y el importe; cualquier confirmación adicional responde a
una decisión de negocio real. Enter en importe o referencia no dispara un cobro ambiguo.
Error conserva las líneas preparadas. Resultado aceptado separa ese cobro de un nuevo
abono deliberado. Cambiar a otro documento abre su borrador propio o uno vacío.

### 6.2 Resultado, recuperación y operaciones complementarias

**I.** El resultado identifica cliente/documento, importe registrado, saldo, vuelto,
estado comercial/sync/fiscal y salida disponible. «Cobrado en este equipo; pendiente de
enviar» sólo aparece si el hecho quedó guardado. Impresión fallida ofrece reimprimir y
conserva el cobro. Reimprimir nunca consume otro número ni registra un pago nuevo.

| Familia de operación | Interacción y validación requerida |
|---|---|
| Cartera | Reconocer documentos y saldos; seleccionar/aplicar importes según el procedimiento existente; resultado por documento sin asumir acción masiva disponible |
| Retención SRI | Captura → consulta disponible → revisión de datos obtenidos → registro; conservar dato consultado y errores; no editar libremente datos descargados ni inventar estados del backend |
| Anticipo | Cliente y medios de pago en su contexto autorizado; distinguir registrar un anticipo de aplicar uno existente; mostrar disponible/usado según datos reales |
| Nota de crédito | Seleccionar/aplicar el documento permitido y revisar saldo; creación o reversión sólo si el binding vigente lo admite |
| Depósito | Campos y variantes del formulario existente, moneda y sesión según permisos; guardar y contabilizar son efectos distintos cuando así lo dispone el proceso |
| Salida de efectivo | El tipo existente determina campos/documentos; el motivo y aplicación se validan donde corresponda; no introducir selectores de movimiento inventados |
| Cruce de cuentas | Identificar fuentes, destinos, saldos e importes aplicados; resultado explícito; no presentar el cruce como recepción nueva de efectivo |
| Registros del turno | Acceder a órdenes, facturas, pagos, anticipos, cheques, salidas, retenciones y cruces; volver conserva búsqueda, selección y punto/turno |

Cada formulario complementario regresa al origen con su resultado y conserva el cobro
que estaba preparado. Un fallo propio no vacía todos los formularios del Workspace.

### 6.3 Apertura, pausa, recuperación, arqueo y cierre

**I.** Sin turno, apertura nueva, recuperación propia, pausa, punto ocupado, falta de
asignación y fallo de consulta son estados distintos. Error de red no ofrece crear un
turno duplicado. Si hay una única opción autorizada no se exige elegirla repetidamente.
Pausar/bloquear/cambiar usuario no se interpreta automáticamente como cierre contable.

Cerrar es un recorrido dedicado: revisar turno → conteo/arqueo → diferencias e incidencias
→ acción permitida → resultado/comprobante. Contar denominaciones muestra total y comparación
cuando el proceso lo permite; no simula un cero confirmado porque el campo aún no se llenó.
Cerrar un editor de conteo conserva su borrador. Operaciones locales pendientes se consideran
según el proceso existente; la UI no impone conexión ni omite pendientes por iniciativa.

**B de CAJ.** Bindings de cada medio y operación complementaria, sesiones/pausas,
contabilización/reversión, comprobante, resultados inciertos y cierre offline ordenado.
Referenciar el wizard existente no demuestra que todos sus campos estén ya transportados.

| ID | Dado / acción | Resultado observable |
|---|---|---|
| CJ-1 | No hay turno, o falla su consulta | Estado y salida correctos; nunca confundir fallo con ausencia ni crear duplicado automáticamente |
| CJ-2 | Deuda ficticia $18 y recibido $20 en efectivo | Aplicado $18, vuelto $2 y saldo correcto; no rechazar recibido como sobrepago ni exigir cálculo mental |
| CJ-3 | Añadir dos medios; corregir uno; seleccionar otro cliente | Se ven/editan las líneas del primer documento; no aparecen en el segundo |
| CJ-4 | Registrar abono parcial o aplicar anticipo/NC/retención permitida | Resultado y saldo proceden del contrato; no se exige repetir cliente/documento ni inventar dinero recibido |
| CJ-5 | Cobro procesado; respuesta perdida; reinicio y reintento | Se reconoce la misma operación y se recupera resultado; no otro pago ni otra numeración |
| CJ-6 | Cobro guardado localmente; falla impresora | Cobro permanece; reimprimir afecta sólo a salida; siguiente cliente puede trabajar según política |
| CJ-7 | Conteo preparado, cambio de tamaño y salida/retorno al editor | Conteo y turno conservados; revisión distingue sin dato, diferencia y resultado de cierre |

## 7. Bodega e inventario — BOD

**D.** Bodega y Envases son áreas distintas. El recorrido usa documentos/movimientos
reales; no deduce un despacho eligiendo sin contexto el primer ID de una venta. Preparar
y entregar al cliente son acciones distintas. El candado de cobro se aplica al paso que
corresponde, no universalmente a toda preparación o transferencia interna.

**Recorrido I.** Bandeja de tarea → identificar documento/origen/destino/responsable →
revisar líneas/cantidades y requisitos → registrar operación permitida → resolver decisión
de parcial/restante si el backend la solicita → resultado → volver a la misma bandeja.
Recepciones, preparación, entregas, transferencias y conteos tienen contexto reconocible;
no se representan todos con el botón genérico «Validar entrega».

Escáner y entrada directa afectan la línea elegida; cantidades, unidades y lotes/series
se exponen cuando la operación los requiere. Diferencias/faltantes conservan trabajo y
se dirigen al responsable correspondiente. No se crea una reserva o bloqueo de existencia
universal en Flutter. Contar no equivale a aplicar un ajuste; la acción de efecto es explícita.
Cancelar un diálogo de decisión no se envía como una respuesta empresarial contraria.

**B.** Consultas por documento/movimiento real; acciones, unidades, trazabilidad, parciales,
remanentes, recepción/transferencia, ajustes y permisos existentes; provisión offline de
cada tarea. Los nombres internos no se muestran como instrucciones para el bodeguero.

| ID | Dado / acción | Resultado observable |
|---|---|---|
| BD-1 | Pedido con varios movimientos; abrir tarea concreta | Se opera documento/origen/destino correctos, no el primer movimiento sin identificar |
| BD-2 | FSC con condición de pago pendiente | Preparación permitida según flujo; entrega a cliente conserva el candado correspondiente |
| BD-3 | Cantidad parcial que requiere decisión del proceso | Se explican entregado/restante; cancelar diálogo conserva tarea, no cancela silenciosamente el remanente |
| BD-4 | Registrar conteo o faltante y volver | Valores permanecen; ningún ajuste se ejecuta por navegar, escanear o cerrar pantalla |

## 8. Envases — ENV

**D.** Workspace del responsable, sin exigir turno de Caja. Control por producto y varias
líneas/cantidades, no recipiente por recipiente. Separar contenido, recipiente y presentación
con equivalencias configuradas. No limitar a botellas. Los envases propios pueden comprarse
y venderse. Dashboard consolida ubicaciones, clientes/proveedores y tránsito en ambos sentidos.

**Recorridos I.** Dashboard/listado → documento o tarea → líneas → revisión → registro y
resultado. La vista desde factura conserva su referencia y las líneas pertinentes; una
toma física conserva ubicación/custodia, momento y cantidades capturadas. Enviar, recibir,
entregar, devolver, contar y comprar/vender no se confunden por compartir producto.

Agregar línea usa selección de producto/envase y presentación configurada; muestra unidades
y equivalencia para revisar la cantidad sin exigir cálculos manuales. Cambiar presentación
no conserva un total incompatible de manera silenciosa. Parcial, diferencia o deterioro
queda asociado al documento y su procedimiento; no se inventan ajustes de saldo por la UI.

Factura/toma importada o reintentada conserva identidad. Un conteo describe una observación;
no duplica por sí solo entrega, devolución, saldo o movimiento anterior. Compra/venta del
recipiente se vincula con su documento autorizado y no se confunde con venta del contenido.
Volver o cambiar usuario conserva sólo los borradores propios y contexto permitido.

**B.** Modelos/campos, equivalencias, propiedad/custodia, documentos y métodos de cada
operación de Envases; permisos, decisiones sobre diferencias/deterioro y contrato offline.
La aceptación conceptual de esta familia no permite inventar esos bindings.

| ID | Dado / acción | Resultado observable |
|---|---|---|
| EV-1 | Responsable sin turno de Caja; abrir Envases | Accede según permisos de Envases; no recibe requisito genérico de abrir caja |
| EV-2 | Factura con varias líneas de envases/presentaciones; registrar y reintentar | Cantidades por producto/presentación correctas; misma identidad, sin movimientos duplicados |
| EV-3 | Toma física preparada; registrar, revisar diferencia y volver | Observación conservada; no se fabrica entrega/devolución ni ajuste automático por contar |
| EV-4 | Envío/recepción o devolución parcial | Dirección, responsable, recibido/restante y estado visible proceden de la operación configurada |
| EV-5 | Compra/venta adicional de envases | Documento del recipiente diferenciado del contenido; trazabilidad recuperable desde el área |

## 9. Multirrol, aprobaciones y continuidad entre áreas — MUL

**D.** Un Workspace muestra la unión efectiva de áreas sin cambio de perfil. El orden
estable del menú es Ventas, Caja, Bodega, Envases, Aprobaciones y Sistema, omitiendo grupos
sin capacidad. La cabecera conserva identidad/contexto; pie técnico completo en desktop
e iPad horizontal y acceso compacto en vertical/teléfono, según el shell aprobado.

**Recorrido I.** Abrir área → tarea → ir a otra área o seguir aviso → volver al documento
exacto. Navegar de Ventas a Caja no cambia vendedor del pedido ni transfiere turno. Revisar
una aprobación muestra objeto, motivo, consecuencias y responsable; resolverla conserva
auditoría y retorna resultado al solicitante. Un aviso no ejecuta la aprobación al abrirlo.

Los avisos no interrumpen escritura. Abrir notificación revalida contexto/acceso; si pertenece
a otro usuario no expone contenido. Acciones simultáneas conservan su documento y generación
de sesión. Cambiar compañía/servidor/DB retira datos anteriores de la vista sin borrarlos.
La hora de servidor desactualizada se presenta como referencia antigua, no como hora fiscal actual.

**B.** Mapeo de cada destino/acción a capacidades, revalidación, alcance de aprobaciones,
continuación autorizada de colas de usuarios anteriores, notificaciones y hora remota.
No se presupone que una credencial administrativa permita eludir reglas del documento.

| ID | Dado / acción | Resultado observable |
|---|---|---|
| MU-1 | Usuario con Ventas/Caja/Supervisión; recorrer las tres | Mismo Workspace y usuario; tareas/borradores separados sin selector de perfil |
| MU-2 | Aviso de aprobación mientras escribe otro pedido | No cambia foco ni valores; abrirlo lleva al documento autorizado exacto y volver conserva edición |
| MU-3 | A inicia acción, cambia a B, llega respuesta de A | No altera ni revela datos en B; operación conserva autoría y resultado recuperable por contrato |
| MU-4 | Cambiar empresa/base con filtros y formularios abiertos | No se mezclan entidades, preferencias privadas ni permisos; retorno autorizado recupera contexto propio |

## 10. Sincronización, recuperación y soporte — SYN

**D.** Lectura local independiente del cliente remoto. Conexión de red, alcance del
servidor, autenticación, estado empresarial, sincronización y fiscal son dimensiones
distintas. Cada catálogo mantiene progreso/cobertura/error propios. Una página descargada
no significa catálogo completo. No crear presupuestos de stock, crédito o saldo por equipo.

**Recorrido I.** Indicador global → detalle de catálogos/operaciones → incidencia concreta
→ acción permitida → resultado y vuelta a la tarea. El usuario ve qué está disponible,
qué quedó guardado, qué sigue pendiente y cómo continuar. No necesita conocer un cursor,
tabla local o código de excepción. Detalle técnico/exportación saneada queda para soporte.

Reintentar error de catálogo conserva los anteriores correctos y la entrada en curso.
Respuesta financiera incierta y dos operaciones distintas sobre el mismo saldo son casos
separados: la primera se reconcilia por identidad; la segunda sigue la resolución autorizada
sin borrar cobros recibidos ni reasignar autoría. No ofrecer «borrar cola» como recuperación.

Reinicio/actualización y falta de espacio no descartan documentos u operaciones para abrir
la app. Si no se pudo guardar, el mensaje no afirma guardado. Si ya se guardó, se conserva
la identidad y se explica la continuación. El estado del sistema no cambia por apagar
visualmente el indicador de error.

**B.** Provisión/validez offline por operación, restauración web, concurrencia y resolución,
política de retención/espacio, migración, consultas idempotentes y canales entre equipos.
No inventar una duración de credencial ni prometer que dos equipos offline comparten datos.

| ID | Dado / acción | Resultado observable |
|---|---|---|
| SY-1 | Sin servidor, con datos/configuración autorizados | Se consultan datos locales y continúan tareas permitidas; antigüedad y estado se entienden |
| SY-2 | Falla un catálogo tras varias páginas | Cobertura/error de ese catálogo precisos; otros siguen disponibles; reintento no duplica ni borra |
| SY-3 | Operación completada localmente; reiniciar sin red | Mismo hecho, borrador restante, identidad/comprobante y pendientes recuperables |
| SY-4 | Dos operaciones distintas compiten por un saldo | Se preservan ambas evidencias y se indica responsable/procedimiento real; no resolver borrando una |
| SY-5 | Sesión expira con red disponible | Se pide revalidación correspondiente; no se muestra «Sin Internet» como diagnóstico |
| SY-6 | Poco espacio o actualización con pendientes | No falso guardado ni recreación destructiva de base; recuperación explica qué quedó conservado |
| SY-7 | Venta local debe pasar a otro equipo también desconectado | Se muestra disponibilidad real; QR sólo identifica; continuación exige el canal/procedimiento definido |

## 11. Matriz de ejecución y cierre de aceptación

Todos los escenarios anteriores están **pendientes de ejecución**. Preparar este documento
o aprobar una imagen no los marca como pasados. Los bindings B deben completarse en la
fase autorizada para que una prueba de interfaz pueda acreditar además el efecto real.

### 11.1 Plataformas, tamaño y entrada

| Vista | Viewport base de prueba web | Composición exigida | Entrada a recorrer |
|---|---|---|---|
| Desktop | 1440 × 900 | Menú/pie persistentes; rejilla o paneles útiles según familia | Ratón, teclado y trackpad |
| iPad horizontal | 1180 × 820 | Rejilla/paneles sólo si queda ancho útil; pie completo | Tacto, teclado virtual y físico cuando esté disponible |
| iPad vertical | 820 × 1180 | Listas/tarjetas/formulario, sin rejillas UI; contexto compacto | Tacto y teclado virtual; recorrido Tab si hay teclado físico |
| Teléfono | 390 × 844 | Una columna y detalle; sin rejillas UI ni reducción proporcional | Tacto, teclado virtual y navegación de retorno |

Ejecutar claro y oscuro, textos largos, varias líneas y datos suficientes para desplazarse.
En cada familia hacer resize entre las cuatro vistas durante una edición y abrir teclado.
Los tamaños son viewports CSS/lógicos de referencia; emular tamaño en navegador no acredita
teclado, impresora, lector, almacén seguro o comportamiento nativo de un dispositivo real.
No se exige simulador: revisión web responsive y hardware real disponible son evidencias
distintas que deben registrarse como tales.

### 11.2 Estados y fallos por recorrido

| Caso | Dónde aplicarlo | Qué debe conservarse y comprobarse |
|---|---|---|
| Carga inicial/lenta | Todas las familias | Contexto, progreso entendible y recuperación; escritura no bloqueada por un refresco independiente |
| Vacío y filtro sin resultados | Cada listado/selector | Mensajes distintos; limpiar filtro o crear sólo si hay permiso |
| Dato inválido/rechazo empresarial | Formularios y acciones | Entrada conservada, causa localizada y siguiente acción real |
| Sin permiso/módulo/configuración | Rutas y acciones dependientes | Explicación correcta; no simular que un fallo es un resultado vacío |
| Offline con provisión | Tareas offline permitidas de cada familia | Hecho local, identidad, comprobante y dependencias; sin degradar todo a borrador |
| Offline sin dato necesario | Selector/tarea afectada | Explicar dato faltante y ruta disponible; no inventarlo ni presentar catálogo completo |
| Intermitencia/doble pulsación | Guardar, confirmar, cobrar, registrar movimiento | Misma operación/reintento; ninguna duplicación por interacción o recuperación |
| Respuesta perdida tras efecto | Cobro y demás acciones con efecto | Consultar/reconciliar resultado por contrato, recuperar referencia y comprobante |
| Conflicto real entre operaciones | Pedido/saldo/anticipo/documento correspondiente | Versiones/evidencia preservadas y resolución autorizada; no confundir con reintento |
| Impresora/canal falla | Documentos y resultados | Resultado empresarial intacto; estado de salida separado y reintento de transporte |
| Reinicio/actualización/falta de espacio | Acceso, borradores y operaciones offline | Conservación comprobada; nunca falso guardado ni borrado para continuar |
| A→B→A y respuesta tardía | Equipo compartido y multirrol | Autoría, aislamiento, privacidad, continuidad de cola y borradores propios |
| Fuente/texto 200 %, lector de pantalla, movimiento reducido | Acceso y tarea principal de cada familia | Reflujo, semántica, foco y mensajes; sin dependencia exclusiva de color o animación |

### 11.3 Cómo registrar evidencia y superioridad

Por escenario registrar: ID, versión/commit ejecutado, ID visual aprobado y variante,
viewport/tema/entrada, actor/capacidades, datos/precondiciones, pasos, resultado visible,
efecto local/remoto verificado, captura o vídeo, incidencias y estado final. Usar datos
ficticios en prototipo; no incluir secretos en capturas, logs ni diagnósticos.

Estados de evidencia: **no ejecutado**, **bloqueado por binding**, **falló**, **pasó en
prototipo**, **pasó con integración real autorizada**. Un prototipo con fixtures sólo
acredita interacción; no acredita permisos ni exactitud contable. Las pruebas introducen
texto en el campo correcto y comprueban su valor antes de continuar: no vale concatenar
todo en el primer campo ni una ventana inmóvil de «Test starting…».

Para la comparación con `theos_pos`, conservar tareas/datos/equipo equivalentes y medir
pasos, tiempo, errores, corrección y recuperación, además del acabado. Registrar navegación,
búsquedas y recaptura, no sólo clics. No fijar cifras ficticias de rendimiento ni eliminar
un candado para ganar la comparación. La mejora exige evidencia operativa con vendedores
y cajeros reales en las tareas acordadas; una revisión experta no sustituye esa prueba.

### 11.4 Pendientes que no pueden resolverse dibujando

- Mapeo de cada acción al permiso, modelo, método y resultado reales; contratos C01–C07
  no constituyen nombres de nuevos endpoints ni una autorización de cambio backend.
- Inventario de atajos y lectores; transporte de impresión/canales por plataforma.
- Aprovisionamiento, restauración offline web y continuidad A→B sin abandonar la cola de A.
- Resolución de concurrencia, numeración y continuidad entre equipos conforme al proceso
  existente; no repartir stock/cupo ni renumerar documentos ya emitidos desde la UI.
- Bindings completos de Envases y operaciones auxiliares; validez de campos/estados de
  formularios revisados contra sus herencias, sin tomar imágenes como esquema.

El cierre de cada familia exige recorrido principal, fallo y recuperación, retorno,
borrador/cambio de usuario, cuatro vistas y evidencia del binding autorizado. No se
declara terminada por disponer sólo de su listado o su lámina principal.
