# Orbi ERP — contrato de teclado, foco y entrada

Fecha: 2026-09-10. Inventario **I01**. Sólo documentación: no modifica código,
configuración de equipos, Odoo ni asignaciones de teclas. No acredita pruebas ejecutadas.

## 1. Alcance y estados

Completa el inventario solicitado por
[INTERACTION_ACCEPTANCE_SPEC.md](INTERACTION_ACCEPTANCE_SPEC.md), especialmente §2.2,
sin sustituir sus recorridos ni las reglas de
[producto](ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md),
[shell](SHELL_AND_INTERACTION_SPEC.md) y [contratos](CONTRACTS.md).
Las aprobaciones visuales se consultan en [APPROVAL_REGISTER.md](APPROVAL_REGISTER.md).

- **E — existente, inspeccionado:** encontrado en las fuentes locales indicadas.
  No significa probado en pantalla ni necesariamente adecuado para copiar.
- **I — interacción especificada:** requisito observable para el nuevo panel;
  no implica aprobación de implementación o asignación de un nuevo atajo.
- **B — pendiente:** requiere decisión, binding o comprobación por plataforma/dispositivo.

El inventario cubre Venta Rápida, edición de líneas, búsqueda, login, entrada de lector
y persistencia de preferencias en ambas apps. No afirma inventariar todos los atajos
del cliente web Odoo, de cada plugin o de todas las ventanas de `theos_pos`.
La ausencia de un handler propio no implica que los controles nativos carezcan de
teclado: esas conductas deben probarse en su widget y plataforma reales.

## 2. Atajos existentes de Venta Rápida en theos_pos — E

Fuentes: [POSKeyboardShortcuts](../../theos_pos/lib/features/sales/utils/keyboard_shortcuts.dart)
(`functionKeyMap`, `getAction`, ayuda) y
[FastSaleScreen](../../theos_pos/lib/features/sales/screens/fast_sale/fast_sale_screen.dart)
(`_handleKeyEvent`). La acción efectiva del segundo prevalece sobre el nombre del enum,
tooltip o comentario del primero.

| Entrada actual | Comportamiento del handler de pantalla | Límite que debe conservar el inventario |
|---|---|---|
| F1 | Abre ayuda de atajos | Lo procesa la pantalla fuera del mapa principal |
| F2 | Pasa a búsqueda de producto y solicita foco de búsqueda | No confirma una venta |
| F3 | Ejecuta `toggleCustomerPanel()` | No equivale por sí solo a cliente seleccionado |
| F4 | Añade nueva pestaña/orden | No reasigna la venta anterior |
| F5 | Ejecuta inicialización con `force: true` | No demostrar conservación de edición sólo por el nombre «Actualizar» |
| F6 | Invoca `goToPaymentsWithAutoConfirm` | Puede confirmar un borrador antes de ir a cobro; no es sólo navegación |
| F8 | Ejecuta también `toggleCustomerPanel()` | Aunque el enum dice `togglePaymentMode`, comparte destino con F3 |
| F9 | Invoca `confirmOrderWithCreditCheck` | Es el camino con controles de confirmación, no una confirmación alternativa |
| F10 | Guarda la orden activa | Guardar no es confirmar, cobrar ni imprimir |
| F12 | Abre la orden guardada y avisa que está lista para imprimir | Sin ID guardado pide guardar; no envía directamente a impresora |
| Escape | En modo búsqueda limpia teclado y vuelve a cantidad | Fuera de búsqueda consume la tecla sin cancelar la venta |
| Arriba/Abajo | Selecciona línea anterior/siguiente fuera de modo búsqueda | Los editores y selectores pueden tener manejo propio |
| `+`/`−`, equivalentes numéricos | Incrementa/reduce cantidad fuera de modo búsqueda | No es un permiso para modificar un documento bloqueado |
| Delete | Quita línea seleccionada y ofrece Deshacer durante 5 segundos | Este comportamiento pertenece a la línea de venta, no al borrado de documentos |
| Enter/Enter numérico | El helper devuelve `confirm`, pero el handler lo ignora | Su significado real queda al contexto hijo; no confirma globalmente |

No hay asignación F7/F11 en este mapa. No se completa la secuencia por intuición.

El mismo helper acepta **Control o Meta** más N, S, P, F y R para nueva orden,
guardar, abrir para imprimir, buscar producto y actualizar, respectivamente.
No es un mapa distinto por sistema operativo. Tampoco exige ausencia de Shift/Alt
adicionales; las teclas F se reconocen antes de evaluar modificadores. Por tanto,
«Ctrl+N» en la ayuda no describe todo lo que el código puede capturar.

La pantalla activa el handler según `hardwareKeyboard`. El
[provider de capacidades](../../theos_pos/lib/features/sales/screens/fast_sale/widgets/touch_actions_fab.dart)
usa como fallback `touch`, `precisePointer` y `hardwareKeyboard` verdaderos; no prueba
que se haya detectado un teclado conectado. Sus comentarios de equivalencia táctil
no reemplazan el handler real —por ejemplo, llamar a F8 «Cobrar» no acredita ese efecto.

**I.** La nueva app debe tener una sola intención por acción y conservar los mismos
candados desde botón, teclado o lector. Este inventario no autoriza trasladar F6/F9 ni
ninguna otra tecla al panel. **B:** mapa final por plataforma, modificadores exactos,
capacidad activa, etiquetado visible y pruebas de colisión.

## 3. Foco y edición existentes — E

### 3.1 Líneas y búsquedas de theos_pos

| Fuente | Hecho observado | Implicación para el nuevo contrato |
|---|---|---|
| [EditableTextCell](../../theos_pos/lib/features/sales/widgets/editable_text_cell.dart) | Al ganar foco selecciona todo el texto; al perderlo intenta enviar el valor. Enter y Tab pueden resolver código y navegar a cantidad. Escape restaura el valor inicial y avisa al padre | Selección automática y validación al blur son comportamiento heredado, no aprobación para copiarlo |
| [SalesOrderLinesDataSource](../../theos_pos/lib/features/sales/widgets/lines/sales_order_lines_data_source.dart) | Registra foco por identidad de línea y tipo de celda. Código resuelto usa callback a cantidad; cantidad → descuento → código de la siguiente línea. Shift+Tab invierte el recorrido; flechas recorren la misma columna | La navegación debe referir la entidad estable, nunca el índice de una lista que puede reordenarse |
| Misma fuente, celda cantidad | Enter avanza como Tab; Escape vuelve a código o solicita tratamiento de línea vacía. `+` y `−` modifican cantidad | No convertir el avance de celda en confirmación del documento. La precisión/unidad no se redefine aquí |
| [GridFocusController](../../theos_pos/lib/features/sales/widgets/lines/grid_focus_controller.dart) | Define otro registro y recorrido de celdas | No se encontró instanciación en `theos_pos/lib` fuera de su definición/ejemplo. No usar su existencia como prueba de integración; la fuente anterior contiene el manejo activo inspeccionado |
| [BaseSearchDialog](../../theos_pos/lib/shared/widgets/dialogs/base_search_dialog.dart) | Consulta inicial seleccionada; flechas cambian selección de resultados; Enter devuelve el elemento seleccionado | Resultado y foco deben corresponder a la misma entidad; no seleccionar sólo por posición después de actualizar la lista |
| [PosCustomerKeypadPanel](../../theos_pos/lib/features/sales/screens/fast_sale/widgets/pos_customer_keypad_panel.dart) | Enter en búsqueda intenta buscar/añadir producto; en modo numérico aplica el valor y limpia. Éxito de búsqueda limpia/refocaliza; no encontrado selecciona texto | El modo visible determina el significado de la entrada. No existe un Enter único para toda la pantalla |

`EditableTextCell` usa guardas de envío y callbacks en más de una ruta de edición;
la lectura no sustituye una prueba de envío único con teclado físico. La propagación
entre editor, listener de lector y pantalla también requiere ejecución real.

### 3.2 Estado inspeccionado de theos_panel

- [LoginScreen](../../theos_panel/lib/features/auth/login_screen.dart) tiene FocusNode
  por servidor, DB, usuario y credencial. Los tres primeros usan `next`; la credencial
  usa `done` y llama a envío. Servidor solicita autofocus incluso con datos recordados.
  No selecciona explícitamente todo el contenido de esos campos al enfocarlos.
- [EntityPicker](../../theos_panel/lib/features/clients/entity_picker.dart) busca mediante
  `onChanged`, permite elegir resultados con tap y tiene carga adicional. No se observó
  un mapa propio de flechas/Enter equivalente al selector anterior.
- [SaleEditor](../../theos_panel/lib/features/sales/sale_editor.dart) y
  [CollectionScreen](../../theos_panel/lib/features/collection/collection_screen.dart)
  no incorporan el mapa de Venta Rápida. El campo de importe inspeccionado no define
  un `onSubmitted` que cobre.
- La búsqueda en `theos_panel/lib` de `LogicalKeyboardKey`, `SingleActivator`,
  `CharacterActivator`, `CallbackShortcuts`, `Shortcuts`, `KeyboardListener`,
  `HardwareKeyboard` y `onKeyEvent` no encontró un mapa explícito de app.
  No se encontró el listener HID de Venta Rápida en ese árbol.

Estas observaciones son de código. No declaran que la nueva interfaz esté lista para
uso sólo con teclado, lector o tecnología de asistencia.

## 4. Contrato de foco, reemplazo y retorno — I

1. **Al entrar:** enfocar el primer dato útil que falta. Si servidor, DB y usuario ya
   están recordados correctamente, no obligar a recorrerlos para llegar a la credencial.
   Si se está consultando un documento, no abrir el teclado virtual sin intención de editar.
2. **Al editar:** clic/tap/foco no equivale a reemplazar. El cursor y la selección obedecen
   al gesto del usuario. Reemplazar requiere selección explícita, acción de limpiar o
   entrada de escáner en su destino declarado. No cambiar texto después mediante una
   restauración de perfil, respuesta tardía o reconstrucción de pantalla.
3. **Selección explícita:** respetar acciones de edición de la plataforma, incluida
   Seleccionar todo y pegar; no capturarlas como acciones empresariales. Las pruebas
   que reemplazan servidor/DB/usuario deben enfocar cada campo, seleccionar o limpiar,
   introducir el valor y verificar ese campo antes de continuar al siguiente.
4. **Al buscar:** el campo conserva consulta y cursor mientras llegan resultados. La
   opción activa se identifica de forma estable. Enter sólo acepta la opción activa de
   ese selector; si no existe, no confirma un documento por propagación al padre.
5. **Al elegir:** texto visible e ID se actualizan juntos. No queda el nombre de un
   cliente con el ID del anterior. El foco pasa al siguiente dato útil de esa tarea,
   no a un control aleatorio creado por el nuevo layout.
6. **Al volver/cancelar selector:** restaurar el control llamador. Si ya no existe por
   cambio legítimo de estado, ir a su sustituto lógico y anunciar el contexto; no enfocar
   otro registro que ahora ocupa el mismo índice. Cancelar no modifica la selección previa.
7. **Al cerrar detalle:** volver al origen con filtro, selección, búsqueda y posición
   conservados mientras sigan permitidos. Cerrar una capa no descarta un borrador ni
   revierte un cobro completado.
8. **Al validar:** conservar los demás valores y señalar el primer dato corregible. No
   forzar un ciclo de refoco continuo. La validación asincrónica obsoleta no actúa sobre
   una nueva línea, documento o usuario.
9. **Durante sync/resize:** conservar formulario, foco, selección, composición de texto
   y scroll. Un aviso no roba foco. El indicador de progreso no reemplaza todo el formulario.
10. **Al cambiar usuario/contexto:** retirar foco, destinos de escáner y handlers del
    ámbito anterior antes de aceptar nueva entrada. Conservar borradores y operaciones
    con su autor; no exponerlos al siguiente usuario ni ejecutar callbacks tardíos bajo él.

La restauración tras reinicio y la persistencia de borradores siguen C01/C04/C05;
no se inventa aquí otra cola ni almacén de credenciales.

## 5. Enter, Escape y activación sin ambigüedad — I

| Contexto con foco | Enter o equivalente de teclado virtual | Escape / retorno de capa |
|---|---|---|
| Campo de texto de una línea | Acción de edición anunciada, como siguiente o buscar | Cierra primero sugerencias si existen; no descarta el documento |
| Observaciones multilínea | Inserta salto de línea | No convierte edición en cancelación empresarial |
| Resultado activo de selector | Elige esa entidad una sola vez | Cierra sugerencias/selector conservando la selección anterior si no se eligió otra |
| Código/cantidad/descuento de una línea | Resuelve o aplica esa entrada y avanza según recorrido visible | Sale de edición según contexto; eliminar línea requiere intención identificable |
| Campo importe/recibido/referencia de Caja | Valida/aplica ese campo o avanza; nunca cobra por handler global | Conserva compositor y documento; no elimina medios ya introducidos |
| Botón explícito de acción con foco | Activa sólo esa acción por semántica estándar del control | No cambia el resultado de una operación que ya empezó |
| Credencial/PIN con acción de acceso | Envía sólo el formulario de acceso activo | No activa handlers de la sesión anterior |
| Sufijo de lectura del escáner | Termina únicamente la lectura de su destino declarado | Cancela captura incompleta, no cancela el pedido |

Tab/Shift+Tab siguen orden lógico; no se interceptan dentro de un editor si destruyen
la navegación asistida. Cada evento tiene un único propietario: editor/selector activo
antes que acciones generales. Enter y Enter numérico tienen el mismo efecto contextual.

En Caja, el foco inicial **no se coloca en Cobrar** al terminar de introducir un importe
ni al recibir un evento de red. Activar `Cobrar <importe>` desde su control explícito sí
es una intención inequívoca; no se agrega un modal universal de confirmación. Mientras
se registra o comprueba una operación, repetición de tecla/doble pulsación no crea otra
identidad de cobro. Resultado persistente e impresión siguen separados.

No equiparar Enter con «confirmar» de manera global. No reutilizar la etiqueta de
`POSShortcutAction.confirm` para decidir un comportamiento financiero nuevo.

## 6. Lectores y escaneo — E / I / B

### 6.1 Heurística actual de theos_pos — E

[BarcodeListenerWidget](../../theos_pos/lib/features/sales/screens/fast_sale/widgets/barcode_listener_widget.dart)
está alrededor de Venta Rápida. Observa KeyDown y usa una heurística HID de velocidad:
intervalo de 100 ms, duración de 500 ms, mínimo de 6 caracteres y conjunto
`[a-zA-Z0-9\-*]`. Ignora Ctrl/Meta/Alt y F1–F12. Enter/Enter numérico pueden completar
lectura; Escape, Backspace, Delete y otras teclas no textuales limpian el buffer.

Hay dos rutas distintas: al recibir Enter comprueba longitud, duración y orden activa;
por temporizador copia y procesa texto con longitud suficiente sin repetir todas esas
comprobaciones. No atribuir a ambas rutas la misma garantía por compartir constantes.
La bandera de procesamiento evita superposición, pero no demuestra cola sin pérdida
para lecturas rápidas consecutivas.

Un producto encontrado se añade/incrementa; ausencia lleva el código a búsqueda;
varios resultados abren selector. El listener confía en la propagación de eventos desde
los hijos, sin declarar un destino de escaneo por campo. El comentario sobre no interferir
con TextBox no prueba aislamiento. La velocidad de escritura no identifica un lector.
Tampoco el término QR en un comentario acredita cámara, todas las simbologías o contenido
fuera del conjunto de caracteres admitido.

### 6.2 Contrato del panel — I

- El contexto muestra qué se está leyendo: producto, documento u otro destino autorizado.
  El código no se concatena a contraseña, nombre de cliente o importe por foco accidental.
- El destino se vincula a documento/línea/contexto estables. Cambiar usuario, empresa,
  tarea o diálogo cancela una captura incompleta y no la entrega al nuevo contexto.
- Una lectura produce una interpretación. Su sufijo no añade una segunda línea, pulsa
  Cobrar ni confirma una venta. Repetir deliberadamente un código después de completar
  la lectura anterior sigue el caso de uso real; no se suprime como duplicado por texto.
- No encontrado y coincidencias múltiples conservan código y ofrecen resolución visible.
  Resolver producto, unidad/presentación, lote u otra entidad depende de bindings reales;
  no se inventan conversiones ni se supone que todo código identifica un producto único.
- Entrada manual y búsqueda táctil siguen disponibles cuando no hay lector. Un lector
  configurado no justifica suprimir controles accesibles ni exigir teclado físico.
- Captura ocupada/fallida debe informar de forma recuperable; no perder una lectura en
  silencio. No registrar credenciales ni contenido sensible de campos como diagnóstico HID.

**B.** Tipo de lector, prefijos/sufijos, simbologías, distribución de teclado, terminación
por Enter/Tab/temporizador, foco nativo/web y política de lecturas mientras se procesa otra.
Las constantes heredadas no son parámetros aprobados del nuevo producto. Verificar cada
configuración real; redimensionar Chrome no prueba cámara ni lector físico de iPad.

## 7. Preferencias de listados y columnas — E / I

### 7.1 Persistencia actual inspeccionada — E

| Fuente | Qué guarda | Alcance observado |
|---|---|---|
| [TheosDataGrid](../../theos_pos/lib/shared/widgets/grid/theos_data_grid.dart) | Anchos en `datagrid_columns_<storageKey>` y ordenamiento en `datagrid_sorting_<storageKey>`; debounce de resize de 350 ms | Depende de `storageKey`; el componente no añade usuario/empresa por sí mismo |
| [SalesOrderLinesGrid](../../theos_pos/lib/features/sales/widgets/lines/sales_order_lines_grid.dart) | Visibilidad en `<storageKey>_visibility` y anchos en `<storageKey>_widths`; reset de anchos | Configuración por clave de la rejilla, no prueba de aislamiento por operador |
| [ListFilterPersistenceService](../../theos_pos/lib/shared/services/list_filter_persistence_service.dart) | Consulta y facetas en `list_filters_<storageKey>` | El servicio recibe la clave; no añade ámbito de usuario implícitamente |
| [OrdersContracts del panel](../../theos_panel/lib/features/orders/orders_contracts.dart) | Filtro de órdenes en `orbi.orders.filter.<scope>` | `scope` suministrado; consulta de texto en memoria. No contiene contrato de anchos/visibilidad/orden físico de columnas |

En [listado de ventas](../../theos_pos/lib/features/sales/screens/sale_orders_list_screen.dart)
y su [variante desktop](../../theos_pos/lib/features/sales/screens/sale_order_list/sale_orders_list_desktop.dart)
se pasa la clave literal `sale_orders`; en
[líneas del formulario](../../theos_pos/lib/features/sales/screens/sale_order_form/form_lines.dart),
`sale_order_form_lines`. No confundir ordenamiento de registros con orden físico de
columnas. No se encontró persistencia de arrastre/reordenamiento de columnas en las
fuentes de rejilla inspeccionadas; no se afirma soporte de esa función.

### 7.2 Comportamiento requerido — I

1. Preferencias por contexto autorizado y vista: servidor, DB, empresa y usuario,
   diferenciando presentación wide y compacta cuando corresponda. No reutilizar la
   preferencia privada de A como si perteneciera a B en el equipo compartido.
2. Conservar filtros permitidos, búsqueda, selección y posición al volver al listado.
   Preferencias restauradas no amplían ACL ni convierten «Todas» en acceso administrativo.
3. Columnas configurables sólo donde hay rejilla aprobada. En vertical/teléfono se
   mantienen ordenamiento/filtros y contexto, no se dibujan columnas estrechas ni se
   eliminan importes/identidad porque estuvieran fuera del ancho desktop.
4. Ancho/visibilidad no pueden hacer inaccesible un dato obligatorio para reconocer el
   documento y su acción. Un filtro u ordenamiento activo sigue siendo visible aunque
   la columna relacionada no se muestre. El restablecimiento restaura preferencias,
   nunca borra documentos, cola, credenciales o borradores.
5. Si cambia el esquema disponible, ignorar preferencias de campos ausentes de forma
   segura y conservar las válidas. No pedir al cajero reparar claves técnicas.

**B.** Binding definitivo del ámbito y catálogo de columnas configurables por listado.
No se aprueba arrastre de columnas ni menú nuevo sólo porque otra rejilla lo permita.

## 8. Cuatro vistas y modalidades de entrada — I

Son tamaños de aceptación, no detección de hardware. Un iPad puede tener teclado físico;
una ventana desktop puede recibir tacto. Mantener controles equivalentes en pantalla.

| Vista de prueba | Composición | Foco, entrada y retorno exigidos |
|---|---|---|
| Desktop 1440 × 900 | Rejilla/paneles cuando ayudan; shell persistente | Teclado, ratón y trackpad; foco en tarea activa, editor por línea y retorno al origen sin perder posición |
| iPad horizontal 1180 × 820 | Paneles/rejilla sólo con espacio útil | Tacto y teclado virtual; físico si existe. Abrir teclado no oculta campo ni acción; selector devuelve foco a la línea |
| iPad vertical 820 × 1180 | Lista, tarjetas y formulario; sin rejilla UI | Detalle legible; entrada y acción visibles con teclado abierto; volver recupera lista y posición, no un formulario nuevo |
| Teléfono 390 × 844 | Una columna con detalle; sin rejilla UI | Tacto, teclado virtual y retorno predecible; buscar/editar/cobrar no depende de F-keys, hover o columna fuera de pantalla |

En las cuatro: tema claro/oscuro, foco perceptible, nombre/rol/valor accesibles,
objetivos táctiles de 48 px, texto/zoom al 200 % y movimiento reducido conforme al
contrato general. Cambiar ancho durante edición no ejecuta ninguna acción, cierra
sesión ni reenvía la operación. Si un diálogo se convierte en pantalla, conserva su
resultado pendiente y el destino de retorno; no duplica capas ni borra texto.

Las pantallas de mostrador, consultiva, Caja, Bodega y Envases pueden tener distinto
orden de captura, pero comparten este contrato. No imponer recorrido de celda desktop
a una tarjeta vertical. El recorrido específico sigue INTERACTION_ACCEPTANCE_SPEC.

## 9. Colisiones de navegador y sistema — E externo / B

La documentación oficial confirma que muchas teclas heredadas ya pertenecen al host.
No basta con que un handler Dart las enumere: el navegador/OS puede procesarlas primero.

| Host | Colisiones con el inventario heredado |
|---|---|
| Chrome, Windows/Linux | Ctrl+N/S/P/F/R: ventana, guardar página, imprimir, buscar y recargar. F3/F5/F6/F10/F12: búsqueda, recarga, foco de barras y herramientas |
| Chrome, macOS | Cmd+N/S/P/F: ventana, guardar, imprimir y buscar. Las combinaciones del navegador no son atajos empresariales |
| macOS nativo | La fila superior puede controlar funciones del equipo; Fn/Globo permite enviar teclas F estándar según configuración |

Fuentes: [atajos oficiales de Chrome](https://support.google.com/chrome/answer/157179?hl=en)
y [atajos y teclas de función de Apple](https://support.apple.com/en-us/102650),
consultadas el 10/09/2026. Son referencias del host, no prueba de captura en Orbi.

**B.** Probar Chrome y el host nativo macOS/Windows usados para aceptación. La app no
debe asumir que Meta es Control en Windows ni que Control equivale a Command en macOS.
No se reasignan aquí alternativas. Registrar combinación exacta, modificadores extra,
layout de teclado, foco, acción del host y resultado de Orbi antes de aprobar un mapa.

Conservar edición y navegación estándar del sistema. No secuestrar combinaciones para
que una etiqueta heredada parezca funcionar. Si una acción no tiene atajo seguro en
un host, sigue disponible con control visible y semántica de teclado; la ayuda sólo
anuncia combinaciones realmente soportadas. No exigir que el usuario desactive
accesibilidad o cambie preferencias del sistema para completar una tarea normal.

## 10. Matriz verificable de aceptación — I, aún no ejecutada

Ejecutar escenarios en las cuatro vistas cuando la entrada exista; las pruebas de
periféricos se registran aparte con dispositivo real. Usar datos de prueba sin secretos
en capturas. No validar rellenando controllers o autenticando por API cuando se pretende
acreditar entrada visual. Una captura sola no prueba secuencia de teclado.

| ID | Acción y condición | Resultado observable |
|---|---|---|
| KI-01 | Abrir login recordado y escribir credencial | Campo útil disponible inmediatamente; servidor/DB/usuario no cambian ni reciben la contraseña |
| KI-02 | Reemplazar datos de tres campos existentes, uno por uno | Foco identificado, selección/limpieza explícita y valor exacto comprobado en cada campo; no texto concatenado |
| KI-03 | Tab y Shift+Tab por formulario; Escape desde sugerencias | Orden lógico, foco visible, cierre sólo de la capa superior y retorno al llamador |
| KI-04 | Escribir mientras llega respuesta tardía de búsqueda/perfil | Consulta, cursor y entidad activa no son reemplazados por respuesta obsoleta |
| KI-05 | Elegir cliente, volver y cambiarlo | Nombre e ID se mantienen unidos; cancelar selector deja cliente anterior intacto |
| KI-06 | Editar línea; cambiar tema/ancho con teclado abierto | Misma línea, cantidad, selección, cursor y borrador; sin reenvío ni salto a otra orden |
| KI-07 | Enter en código, cantidad, observación y referencia de Caja | Sólo efecto contextual; observación conserva edición y ningún campo dispara Cobrar |
| KI-08 | Activar explícitamente Cobrar; pulsar otra vez durante respuesta lenta | Una operación estable y resultado recuperable; no doble cobro ni foco automático en una segunda acción |
| KI-09 | Usar botón y futuro atajo aprobado para confirmar/ir a cobro | Mismo documento, autor, validaciones y candados; la ayuda describe el efecto real |
| KI-10 | Escanear con destino producto; sufijo Enter; repetir deliberadamente | Una interpretación por lectura; repetición no perdida ni confundida con reintento de cobro |
| KI-11 | Escanear con credencial/importe enfocado o al cambiar usuario | No contaminar campo sensible ni usar destino anterior; respuesta visible según configuración |
| KI-12 | Código desconocido/múltiple; cancelar y reintentar | Código conservado, elección explícita y retorno a tarea; no producto elegido por índice obsoleto |
| KI-13 | Dos lecturas rápidas mientras la primera sigue procesándose | Tratamiento observable, sin pérdidas silenciosas ni interpretación doble por temporizador/sufijo |
| KI-14 | Ajustar listado, abrir documento y volver; alternar A → B → A | Preferencias/contexto permitidos de A recuperados; B no ve datos privados ni recibe borradores de A |
| KI-15 | Restaurar columnas con campo retirado; pasar a vista vertical | Preferencias válidas conservadas, fallback legible, sin rejilla vertical ni pérdida de identidad/importes |
| KI-16 | Probar mapa candidato con campo/celda/selector/diálogo activos y modificadores extra | No captura ambigua; acción del host registrada; ninguna combinación se declara soportada sin evidencia |
| KI-17 | Cobro offline, corte de respuesta, retorno y reimpresión | Entrada no se bloquea por falta de red; resultado y autor persisten; reimprimir no registra otro cobro |
| KI-18 | Completar tarea con teclado y lector de pantalla; zoom 200 % | Foco/nombre/rol/valor y errores comprensibles; sin trampas de foco ni acciones sólo por color/hover |

Registrar por ejecución: revisión de código, escenario, vista y host, modalidad de
entrada, contexto no sensible, secuencia real, resultado esperado/obtenido y evidencia.
Los fallos se mantienen abiertos; un test de widget o un mapa definido no sustituyen
la prueba visual de login, edición, cobro y retorno.

## 11. Qué queda por decidir o enlazar — B

- Mapa final de atajos por plataforma y contexto, con modificadores exactos, colisiones,
  disponibilidad y alternativas táctiles. No hay teclas comerciales nuevas aprobadas aquí.
- Binding de búsqueda/lectura por tipo de documento y de cada acción a su caso de uso
  real. No se inventan métodos Odoo, precisión, unidades, secuencias ni reglas de cupo/stock.
- Configuración/protocolo de lector y verificación en hardware admitido; la heurística
  temporal heredada no basta como garantía.
- Alcance definitivo de preferencias de columnas y migración de claves, si se implementa.
- Evidencia E2E en web y nativo cuando corresponda. I01 documenta lo encontrado y el
  contrato de aceptación; no cierra por sí solo los bindings ni las pruebas de interacción.
