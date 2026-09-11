# Orbi ERP — contratos de interfaces de componentes

Estado: **propuesta tipada, no implementada**. Este documento fija fronteras entre
componentes Flutter, `orbi_runtime` y el núcleo offline. Los fragmentos son
pseudocódigo Dart; no son imports, clases ni APIs disponibles hoy.

## 1. Alcance y separación de APIs

`CONTRACTS.md` fija el vocabulario compartido (por ejemplo `AppScope`,
`CapabilitySnapshot`, `EntityPicker<T>`, `OperationOutcome`, `DraftController` y
`C04`). `REACTIVE_COMPONENTS_SPEC.md` fija las decisiones de reactividad,
persistencia durable y composición. `KEYBOARD_AND_INPUT_CONTRACT.md` fija el
significado contextual de Enter/Escape, el retorno al llamador y las cuatro vistas.
Este archivo concreta interfaces de componentes para que esos contratos puedan
materializarse posteriormente.

No se debe interpretar ningún tipo de este archivo como una API ya existente. En
particular, la presencia de `EntityPicker<T>` o `MoneyField` en `CONTRACTS.md` no
autoriza importar una implementación de `theos_pos` ni crear una segunda entidad
de negocio. Cuando exista un tipo equivalente en el core, el adaptador lo consume;
la firma definitiva y sus imports públicos los integra F01.

La dirección permitida es:

```text
Flutter component → ControllerBridge → use case/repository offline
                  ← typed state stream ← durable local commit/outbox
```

Los componentes no ejecutan SQL, conocen tablas, llaman Odoo, contienen reglas
fiscales, administran credenciales ni deciden permisos por nombre de rol. El núcleo
posee identidad, transacciones, outbox, versiones y autorización efectiva; el
componente sólo presenta estado y emite intención tipada.

## 2. Primitivas compartidas propuestas

```dart
sealed class EntityId {
  final String model;             // modelo contractual, p.ej. sale.order.
  final String key;               // UUID local o clave remota, no índice de lista.
  const EntityId(this.model, this.key);
}
final class LocalEntityId extends EntityId {
  const LocalEntityId(super.model, super.key); // UUID generado localmente.
}
final class RemoteEntityId extends EntityId {
  const RemoteEntityId(super.model, super.key); // ID opaco del backend.
}
typedef RequestId = String;      // estable para deduplicar/rechazar respuestas tardías.
typedef Revision = String;

final class ScopeRef {
  final String scopeKey;
  final String companyId;
  final String userId;
  final String? pointId;
  final int capabilityRevision;
}

final class CancelHandle {
  bool get isCancelled;
  void cancel();                 // idempotente; no revierte un commit durable.
}

final class FocusAnchor {
  final EntityId? entityId;
  final String controlId;         // semántico, no posición ni GlobalKey efímera.
  final int? caretOffset;
  final int? selectionExtent;
}

abstract interface class ControllerBridge<S, I, R> {
  Stream<S> watch();
  S get current;
  Future<R> dispatch(I intent);
  void retainFocus(FocusAnchor anchor);
  void dispose();
}
```

Todo stream debe tener el `ScopeRef` y el identificador de consulta/documento en
su estado o en su canal de creación. Una respuesta debe descartarse si ya no
coincide con `RequestId`, scope, entidad, revisión de edición o consulta vigente.
`dispose` libera listeners y recursos del ámbito, pero nunca elimina un borrador,
blob pendiente ni operación de outbox.

Los controladores de edición y foco se crean fuera de `build` y sobreviven a
rebuilds por cambio de tema, tamaño, stream o Riverpod. Un provider puede componer
el bridge; no es obligatorio que el widget sea `ConsumerWidget`, ni se debe duplicar
el mismo buffer mutable entre `FormGroup`, provider y controlador.

## 3. FieldBinding: valor, edición y comandos

### 3.1 Tipos y ownership

El binding representa un campo de un borrador o formulario, no una columna SQL.
El `DraftController` es dueño del buffer editable y de `baseRevision`; el binding
es una vista tipada de un solo campo. El repositorio/núcleo es dueño del valor
persistido. El widget posee exclusivamente cursor, composición y foco.

```dart
sealed class FieldValue<T> {
  const FieldValue();
}
final class FieldEmpty<T> extends FieldValue<T> {}
final class FieldPresent<T> extends FieldValue<T> {
  final T value;
}

sealed class FieldStatus {
  const FieldStatus();
}
final class FieldPristine extends FieldStatus {}
final class FieldDirty extends FieldStatus {}
final class FieldApplying extends FieldStatus { final RequestId requestId; }
final class FieldApplied extends FieldStatus { final Revision revision; }
final class FieldReverted extends FieldStatus {}
final class FieldConflict extends FieldStatus {
  final Revision baseRevision;
  final Object localValue;
  final Object remoteValue;
}
final class FieldRejected extends FieldStatus {
  final List<FieldIssue> issues;
}

final class FieldState<T> {
  final FieldValue<T> persisted;
  final FieldValue<T> draft;
  final String? editingText;      // representación incompleta, si aplica.
  final FieldStatus status;
  final List<FieldIssue> issues;
  final bool editable;
}

abstract interface class FieldBinding<T> {
  Stream<FieldState<T>> watch();
  FieldState<T> get current;
  void edit(FieldEdit<T> edit);   // sólo cambia buffer; no implica persistencia.
  Future<FieldApplyResult> validateAndApply({String reason});
  void revert();                  // vuelve al último valor persistido/base segura.
  void dispose();
}

sealed class FieldEdit<T> {
  final FocusAnchor origin;
}
final class SetTypedValue<T> extends FieldEdit<T> { final FieldValue<T> value; }
final class SetEditingText<T> extends FieldEdit<T> { final String text; }
final class ClearValue<T> extends FieldEdit<T> {}

final class FieldIssue {
  final String code;
  final String messageKey;
  final Map<String, Object?> safeArgs;
  final String? fieldId;
  final bool retryable;
}
```

`editingText` permite distinguir vacío de cero y texto numérico incompleto de un
importe válido. Precisión, moneda, unidad y formato local se proporcionan como
política tipada del campo; no se comparten automáticamente entre cantidad y dinero.
La validación de campo es previa y explicativa, pero no sustituye reglas de
documento ni autorización del servidor.

### 3.2 Eventos y resultados

```dart
sealed class FieldApplyResult {}
final class FieldAppliedResult extends FieldApplyResult {
  final OperationOutcome outcome;
  final FocusAnchor restoreFocus;
}
final class FieldValidationFailed extends FieldApplyResult {
  final List<FieldIssue> issues;
  final FocusAnchor firstInvalid;
}
final class FieldApplyConflict extends FieldApplyResult {
  final Revision localBase;
  final Revision remoteRevision;
  final Object localValue;
  final Object remoteValue;
}

sealed class FieldIntent {}
final class EditField extends FieldIntent { final FieldEdit<Object?> edit; }
final class ApplyField extends FieldIntent { final String reason; }
final class RevertField extends FieldIntent {}
```

`edit` puede actualizar la UI inmediatamente y marcar dirty, pero sólo
`validateAndApply` entrega un comando al bridge. Aplicar significa validar y
persistir el nuevo estado local/draft según el contrato del formulario; **no implica
encolar envío remoto automáticamente**. Sólo un comando de sincronización o envío
explícito, permitido por la operación y su política offline, crea/actualiza outbox.
Si operación y outbox deben ser atómicos, el caso de uso del núcleo lo hace en una
transacción; el widget nunca lo decide. Un resultado remoto conserva por separado `businessState`, `syncState`, `fiscalState`
e `issues` según `OperationOutcome`; no se reduce a `success == true`.

El widget puede aplicar al salir del campo si el formulario lo declara, o exigir un
botón explícito. Nunca escribe un importe incompleto por cada tecla por defecto.
Enter/Tab sólo ejecutan la intención del editor; no confirman globalmente el
documento. Escape restaura la capa de edición indicada por el contrato y no borra
la orden. Una respuesta o validación tardía no mueve el foco a otra entidad.

## 4. EntitySelector<T>: consulta, selección y cancelación

```dart
final class EntityOption<T> {
  final EntityId id;
  final T value;
  final String label;
  final String? supportingLabel;
  final bool selectable;
}

final class EntityQuery {
  final String text;
  final int pageSize;
  final String? cursor;
  final String orderKey;          // orden determinista del repositorio.
  final ScopeRef scope;
  final RequestId requestId;
}

sealed class EntityPage<T> {}
final class EntityPageData<T> extends EntityPage<T> {
  final List<EntityOption<T>> items;
  final String? nextCursor;
  final bool isRefreshing;
}
final class EntityPageError<T> extends EntityPage<T> {
  final Object error;
  final bool retryable;
}

abstract interface class EntityQuerySource<T> {
  Stream<EntityPage<T>> watch(EntityQuery query, CancelHandle cancel);
}

abstract interface class EntitySelector<T> {
  Stream<EntitySelectorState<T>> watch();
  void open({required FocusAnchor caller});
  void search(String text);       // conserva cursor y selección mientras carga.
  void loadNextPage();
  void select(EntityId id);       // ID y etiqueta se actualizan juntos.
  void accept();                  // acepta sólo la opción activa actual.
  void cancel();                  // no modifica selección previa.
  void dispose();
}
```

El selector cancela la consulta anterior al iniciar otra y deduplica por
`(scope, requestId)`. La paginación usa cursor/ID y orden determinista, nunca el
índice de la página para identificar la entidad. Si llega una página tardía no
reemplaza la búsqueda nueva. `accept` sin opción activa no se propaga al formulario
ni confirma el documento. Al aceptar o cancelar se devuelve el `FocusAnchor` del
llamador; si ya no existe, se elige su sustituto semántico y se anuncia el cambio.

## 5. List/Grid: mismos datos, presentaciones distintas

El controlador de consulta y selección se comparte; la vista compone lista/tarjetas
o un adaptador Orbi sobre Syncfusion DataGrid. Syncfusion es el motor mandatorio de
rejilla para las vistas que usan rejilla; su licencia, versión y compatibilidad real
quedan pendientes de verificación antes de distribuir. No se hereda una rejilla
externa ni se crea un motor paralelo.

```dart
final class ListQuery {
  final ScopeRef scope;
  final String text;
  final Map<String, Object?> filters;
  final String? cursor;
  final String orderKey;
  final RequestId requestId;
}

final class RowModel<T> {
  final EntityId id;
  final T entity;
  final Revision revision;
  final bool selectable;
  final bool editable;
}

abstract interface class ObservableListController<T, I> {
  Stream<CollectionState<T>> watch();
  void setFilters(Map<String, Object?> filters);
  void setSearch(String text);
  void loadNextPage();
  void select(EntityId id, {bool extend = false});
  Future<OperationOutcome> applyRowEdit(EntityId id, I intent);
  void clearSelection();
  void retainView({required EntityId? anchorId, required int scrollOffset});
  void dispose();
}

abstract interface class GridAdapter<T, I> {
  final ObservableListController<T, I> controller;
  final List<ColumnSpec<T>> columns; // IDs y extractores tipados, no strings SQL.
  final FocusAnchor? initialFocus;
}
```

`CollectionState` debe distinguir carga inicial, refresh incremental, error,
selección y páginas disponibles. Lista y contador consumen el mismo predicado del
repositorio; filtros de UI no amplían ACL. Las filas se reconcilian por `RowModel.id`
y `revision`, no por índice. Edición concurrente produce conflicto y conserva el
borrador local. Cambiar filtro, ordenar, paginar o cambiar layout conserva el ID
ancla permitido, foco, texto en composición y scroll; si el ID deja de ser visible,
se anuncia el retorno determinista sin enfocar accidentalmente otra fila.

La rejilla puede exponer columnas, selección y edición en desktop/iPad horizontal.
En iPad vertical y teléfono, el mismo controller se representa como lista/tarjetas y
detalle; no se comprime una rejilla ni se duplican permisos o comandos. El producto
se busca dentro del editor de línea cuando así lo exige el flujo, no mediante una
búsqueda externa que pierda su línea llamadora.

## 6. Imagen: lectura, ampliación, cambio y retirada

Ver/ampliar y cambiar/quitar son capacidades separadas. El blob pendiente debe ser
durable y estar ligado al scope; caché evictable no es almacenamiento de una
intención.

```dart
enum ImageReadState { absent, notDownloaded, loading, ready, failed }
enum ImageMutation { replace, remove }

final class ImageRef {
  final String resourceId;
  final EntityId ownerId;
  final String fieldId;
  final Revision revision;
  final String? mimeType;
}

final class ImageState {
  final ScopeRef scope;
  final ImageRef? remote;
  final String? durableLocalBlobId;
  final ImageReadState readState;
  final ImageMutation? pendingMutation;
  final bool canRead;
  final bool canChange;
  final bool canRemove;
  final List<FieldIssue> issues;
}

abstract interface class ImageBinding {
  Stream<ImageState> watch();
  Future<ImageState> readThumbnail();
  Future<ImageState> readFull();
  Future<void> openViewer();
  Future<void> chooseReplacement(ImageInput input);
  Future<void> requestRemove();       // confirmación pertenece a la UI.
  Future<OperationOutcome> apply();
  void revertPending();
  void dispose();
}

final class ImageInput {
  final Object selectionHandle;    // referencia opaca del picker/cámara de plataforma.
  final Stream<List<int>> bytes;   // lectura portable; no presupone path ni File.
  final String declaredMimeType;
  final int declaredByteLength;
}
```

El núcleo valida tipo/tamaño/resolución contra el contrato real del modelo; esta
interfaz no inventa una lista universal de formatos ni presume `image_1920`. Antes
de mostrar «guardado», debe escribir el blob y su referencia recuperable. La UI
publica `pendingMutation: replace/remove` y muestra estado local/sync separado.
Limpieza de caché no puede eliminar un blob pendiente; fallo de disco no puede
producir éxito falso; reintentos conservan una identidad estable.

Si cambia la revisión remota mientras existe una propuesta local, el estado pasa a
conflicto y conserva ambas referencias para una resolución autorizada. Un permiso
revocado bloquea la acción y no elimina la propuesta local silenciosamente. La caché
no concede acceso: toda lectura, ampliación o mutación vuelve a validarse contra
`ScopeRef` y capacidades efectivas. No se registran blobs privados ni credenciales.

Una actualización de imagen sólo notifica a consumidores del `resourceId` y
`ownerId`; no reconstruye la orden completa ni roba el foco del editor activo.

## 7. Composición, foco y cuatro vistas

Los contratos son agnósticos a widgets concretos. Un componente visual se compone
con controles Flutter/Material y, para rejillas, el adaptador mandatorio de
Syncfusion sujeto a licencia/versionado verificados. Recibe bindings,
callbacks y tema por propiedades. No hay herencia pesada de widgets ni dependencia
de `BuildContext`/`WidgetRef` en objetos del núcleo.

La misma sesión de controller, consulta, permisos y comandos debe alimentar estas
cuatro composiciones de aceptación:

| Vista | Composición prevista | Requisito de continuidad |
|---|---|---|
| Desktop 1440×900 | Rejilla/paneles cuando ayudan | Editor por entidad, foco y retorno al origen permanecen estables. |
| iPad horizontal 1180×820 | Paneles o rejilla sólo si cabe | Teclado abierto no oculta campo/acción; selector vuelve a la línea. |
| iPad vertical 820×1180 | Lista, tarjetas y formulario | Volver conserva filtro, posición, selección y borrador. |
| Teléfono 390×844 | Una columna con detalle | Operar no depende de F-keys, hover ni columnas fuera de pantalla. |

En las cuatro vistas: cambio de tema/tamaño, refresh, sync, respuesta tardía o
actualización de imagen no recrea controllers, no sobrescribe dirty, no cambia
selección por índice y no mueve foco sin intención. Un aviso no roba foco. Al cambiar
usuario/empresa/BD se detienen listeners del scope anterior antes de aceptar entrada;
los borradores y operaciones conservan su autor y no se muestran al nuevo scope.

## 8. Invariantes verificables por implementaciones futuras

- Un ID estable identifica entidad, fila, selector, blob y ancla; nunca se usa el
  índice como identidad.
- `edit`, `select`, `search`, `apply` y `revert` son intenciones distintas y
  observables; Enter no confirma un documento por propagación accidental.
- Paginación y búsquedas cancelan trabajo obsoleto y no pisan texto, cursor o foco.
- Aplicar localmente es durable y separado de sincronizar, rechazar, conflictuar o
  emitir fiscalmente; repetir una intención no duplica efectos.
- La UI no declara permiso: muestra capacidades recibidas y el núcleo vuelve a
  validarlas al ejecutar.
- Lista y rejilla comparten consulta, filtros, selección, edición y permisos; sólo
  cambia la composición visual.
- Las pruebas futuras deben cubrir RC01–RC12 y KI-03/KI-04/KI-08/KI-14/KI-18 en las
  cuatro vistas, incluyendo reinicio offline, resize durante edición y conflicto
  remoto. Este documento no afirma que esas pruebas estén ejecutadas.

## Referencias

- [CONTRACTS.md](CONTRACTS.md)
- [REACTIVE_COMPONENTS_SPEC.md](REACTIVE_COMPONENTS_SPEC.md)
- [KEYBOARD_AND_INPUT_CONTRACT.md](KEYBOARD_AND_INPUT_CONTRACT.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
