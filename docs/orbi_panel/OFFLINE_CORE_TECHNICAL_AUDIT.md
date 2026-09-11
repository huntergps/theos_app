# Auditoría técnica del núcleo offline Orbi

Fecha: 2026-09-10  
Alcance: `orbi_runtime/lib/src/**` y adaptadores de `theos_panel/lib/app/**`.  
Método: inspección estática de firmas, consultas, transacciones, ciclo de vida y
puentes Riverpod. No se ejecutaron servidores, ERP2 ni suites pesadas.

## Dictamen

La fuente contiene mecanismos offline para órdenes, catálogos, borradores de venta,
operaciones de caja y documentos cacheados. También contiene validaciones de
identidad/empresa, leases de sesión y outbox Drift. Esto es cobertura estática de
los mecanismos presentes, no una demostración de funcionamiento, aislamiento ni
idempotencia: en esta auditoría no se ejecutaron sus pruebas.

No existe todavía una capa reactiva completa: varias consultas UI son lecturas
puntuales disparadas por `refresh`/`FutureProvider`, y los repositorios mantienen
`StreamController` sin cerrar ni emitir cambios de Drift. El borrador visible se
guarda además en `SharedPreferences`, separado del borrador comercial duradero.
No existe contrato de archivo/imagen editable (ni `OrbiProductImage`, ni
`OrbiCustomerAvatar`, ni selector/upload/remove). Los documentos sí tienen caché
durable, pero no flujo de mutación ni notificación de actualización. Por tanto,
RC01, RC02, RC04, RC06–RC11 y RC12 sólo están parcialmente cubiertos.

## Conexión widgets → puertos reales → persistencia → notificación

| Consumidor UI (ruta/archivo) | Puerto/firma existente | Persistencia real | Notificación/observabilidad actual |
|---|---|---|---|
| `OrdersScreen` `/sales`, `WarehouseScreen` `/warehouse` (`router.dart:311-470`) | `OrderRepository.watch(OrderQuery)` → `ScopeOrderRepository`; `RuntimeLocalOrderReader.read/refreshOnline` | Tabla Drift `sale_order`; refresh remoto actualiza sólo filas `is_synced=1` en transacción (`runtime_order_reader.dart:90-151`) | `StreamController` propio sólo emite al cargar/refrescar; no `watch` Drift ni cierre del controller (`order_scope_repository.dart:18-47`) |
| Selectores de clientes/productos `/clients`, `/products` y editor de venta | `CatalogRepository.watch/refresh/loadNext`; `RuntimeScopeCatalogRepository`, `RuntimeProductCatalogRepository`, `RuntimePartnerCatalogRepository` | Tablas core mediante `LocalCatalogStore`; `DriftCatalogStore.commit` agrupa filas+cursor en transacción (`local_catalog_adapters.dart:315-376`) | El store Drift sí emite tras commit, pero los adaptadores de app leen `store.read` y mantienen streams manuales; no reciben esa emisión ni cierran controllers (`scope_catalog_repository.dart:15-151`) |
| `SaleEditorScreen` `/sales/counter` y `/sales/consultive` | `SaleDraftController`; `SaleEditorPort.submit`; `RuntimeSaleEditorPort.submit`; `RuntimeSaleCommandPort.confirm` | Buffer en `SharedPreferencesSaleDraftStore`; al submit, `DriftSaleDraftRepository.save` inserta cabecera/líneas/outbox en una transacción (`sale_draft_repository.dart:9-107`); confirmar usa `DriftSaleCommandStore.commitAndEnqueueIfAbsent` (`sale_runtime_adapters.dart:20-106`) | `SaleDraftController.changes` manual; `update` hace `unawaited(store.save)`; provider sí llama `dispose`, pero no hay coordinación de escrituras tardías (`router.dart:258-273`, `sale_editor.dart:313+`) |
| Caja `/collection` y sus wizards | `scopeCollection*FutureProvider`; `RuntimeCollectionOperationPort.advance/withholding/creditNote/cashOut/deposit`; `DurableCollectionProducer` | Turno/pendientes: tablas `collection_session`/órdenes, con metadata como fallback. Cash-out, depósito, anticipo, retención y líneas de cobro se encolan con transacciones y claves idempotentes (`durable_collection_producers.dart:17-648`) | `FutureProvider` se recalcula por invalidación; no stream de cambios de tablas. `_inFlight` evita doble acción sólo mientras vive el puerto (`collection_operation_port.dart:51-76`) |
| Aprobaciones `/approvals` | `ApprovalPort`/`SessionApprovalPort`; `DriftApprovalOfflineQueue.enqueue` | `offline_queue` para aprobación; sync la procesa como `OfflineOperation` | No hay inbox específico de cambios de aprobación; depende de sync/manual refresh |
| Centro de notificaciones | `NotificationInboxPort` → `SessionNotificationInboxPort` → `RuntimeNotificationInbox.watch/ingest/markRead/...` | Tablas de notificaciones del core; cursor/baseline se delegan al store, con validación de scope/partición | `watch` del store Drift se transforma en stream; el adaptador acumula entradas y recalcula unread (`notification_scope_adapter.dart:34-88`). Presenter del sistema es puerto separado; no se dispara desde build |
| Documentos `/reports/:documentId` | `DocumentRenderPort.loadCached`; `ScopeDocumentRenderPort.loadCached`; sincronización adicional `syncDocument` | `RuntimeMetadataStore` escribe JSON/base64 en `sync_metadata` bajo `ui/documents/<scope>/<id>`; generación QWeb guarda PDF `localOnly` | No hay stream/versionado: `DocumentView` hace `FutureBuilder` una vez (`document_view.dart:128+`). `syncDocument` no ingesta evento ni avisa a consumidores |
| Sync global (shell/centro sync) | `SyncCoordinator.start/requestSync/pause/stop`; `SyncCoordinatorImpl.snapshots`; `OperationsSyncJob.run` | `offline_queue`, catálogos y metadatos; processor conserva conflictos/dead-letter | Stream `snapshots` serializa drenajes; `SyncCoordinatorImpl` evita drains paralelos y usa epoch. El `queuedCount` publicado es aproximación por número de jobs, no filas reales (`sync_coordinator_impl.dart:73-165`) |
| Imagen de producto/avatar | **Sin puerto o firma encontrada** en runtime/app; sólo logo estático de splash | **Sin tabla/blob/archivo durable** para imágenes editables | **Sin notificación** de versión, carga, error o cambio |

## Hallazgos por contrato

### Consultas observables y Riverpod

- `AppScope`, `CompanyContext`, `SessionLease`, `SyncSnapshot` y las firmas de
  `SyncCoordinator` existen en `orbi_runtime/lib/src/contracts.dart`; validan IDs,
  scope y contadores positivos/no negativos.
- `RuntimeLocalOrderReader.read` usa variables SQL para filtros y hace que lista y
  contador compartan el predicado. La página usa `ORDER BY date_order DESC,
  odoo_id DESC`; esto satisface una paginación determinista básica. `limit` se
  interpola después de venir del core, pero no hay validación local de límite.
- Los catálogos filtran mapas completos (`r.value.values.any`) y usan cursor por
  offset. Es una lectura puntual con offset, no una consulta observable ni
  paginación estable por ID; una modificación de catálogo puede desplazar páginas.
- En app se usa `ref.watch` para scope/capacidades y `ref.onDispose` para varios
  controllers (`router.dart:190-224,258-273`). No se usa `select`; es posible que
  pantallas completas reconstruyan por cualquier cambio de snapshot.
- `FutureProvider` de caja y `FutureBuilder` de documentos representan snapshots,
  no cambios continuos. La guía Riverpod recomienda separar repositorio del estado
  y limitar suscripciones; aquí el repositorio existe, pero sus streams manuales no
  están conectados a la fuente de verdad.
- `ScopeOrderRepository`, los tres repositorios de catálogo y
  `ScopeHomeResumePort`/`ScopeActivityPort` crean controllers sin `onCancel`,
  `dispose` o `close`. Un provider puede desmontarse y dejar listeners/streams
  vivos; además un cambio de sesión no emite una invalidación explícita a esos
  consumidores.

### Borradores, comandos y transacciones

- El borrador de edición (`SaleDraftSnapshot`) tiene `scopeKey`, `commandId`,
  `baseRevision` y `expectedVersion`, pero `copyWith` no incrementa revisión ni
  marca campos dirty. `SaleDraftLine` expone `discount` y `tax`
  (`sale_editor.dart:17-40`), pero el mapa que escribe
  `SharedPreferencesSaleDraftStore.save` sólo incluye `taxIds` y no esos dos
  campos (`sale_editor.dart:274-285`); es una pérdida de fidelidad al reiniciar.
- `SaleDraftController.update` persiste cada cambio sin esperar el resultado. El
  repositorio Drift sólo se invoca en `submit`, por lo que el buffer editable y la
  entidad/outbox no son la misma copia durable. Esto contradice el objetivo de
  recuperar una edición incompleta desde el núcleo.
- `DriftSaleDraftRepository.save` contiene una transacción para cabecera, líneas y
  outbox, rechaza líneas vacías y usa UUID/clave de operación. `DriftSaleCommandStore`
  contiene verificaciones de versión/colisión y encola confirmación en la misma
  transacción. Son mecanismos observados en fuente, no garantías ejecutadas aquí.
- Los productores de caja también agrupan hechos y operaciones en transacciones,
  y `RuntimeCollectionOperationPort._inFlight` protege reentrancia en memoria. La
  deduplicación después de reinicio se intenta mediante `operationKey`/outbox; no
  se afirma aquí que sea correcta sin ejecutar pruebas de reinicio/concurrencia.
- `OperationOutcome` separa `businessState`, `syncState`, `fiscalState`, acción
  pendiente e incidencias tipadas. Sin embargo `RuntimeSaleEditorPort` convierte
  cualquier incidencia en el texto “Aprobación comercial pendiente”; puede ocultar
  conflicto, rechazo o error de transporte al widget.

### Archivos, imágenes y documentos

- `CachedDocumentCodec` valida título, MIME, estados y base64 no vacío; el caché
  persiste bytes en SQLite y sobrevive reinicio. `syncDocument` valida la respuesta
  de `ir.attachment` antes de escribir (`u08_scope_adapters.dart:438-482`).
- `RuntimeMetadataStore.write` es una escritura SQLite individual, no una
  transacción que agrupe blob + referencia + versión. Tampoco impone límite de
  tamaño, nombre seguro, hash, expiración o cuota. Es durable como metadata, pero
  no ofrece la semántica de archivo recuperable requerida para una propuesta de
  imagen pendiente.
- No hay selector/cámara, validación de formato/tamaño/resolución, upload/remove,
  estado `loading/error/notDownloaded`, caché de miniaturas, deduplicación ni
  protección específica de archivos privados. No debe inventarse `image_1920`:
  falta contrato del modelo Odoo y capacidades efectivas.
- `generateOffline` permite inyectar cualquier `fiscalState`; técnicamente conserva
  el estado separado, pero la autorización fiscal debe venir del dominio y no del
  formulario.

### Sync, identidad y lifecycle

- `RuntimeDatabaseOwner` garantiza una conexión Drift por scope, abre/migra antes
  de publicar y cierra la anterior; nombre de BD deriva de SHA-256 del scope.
  `SessionRuntime` añade epoch y `SessionLease` para rechazar respuestas tardías.
- `OperationsSyncJob` reconcilia operaciones ambiguas antes de reintentar,
  comprueba scope durante dispatch y conserva conflictos. `SyncCoordinatorImpl`
  serializa triggers, pausa y stop; no crea un timer por pantalla.
- La implementación concreta está en `orbi_runtime/lib/src/read/local_catalog_adapters.dart`:
  `DriftCatalogStore<T>.commit` valida el scope, llama `writeRows`, escribe el
  cursor en `sync_metadata` dentro de `runtime.database.transaction` y sólo
  después emite al controller (`:315-376`). El adaptador UI no consume ese stream,
  por lo que la atomicidad de persistencia no implica reactividad de pantalla.
- La cola queda durable; `_inFlight`, streams y controllers son caché/estado de
  presentación y desaparecen al cerrar composición. `OrbiBusinessCompositionFactory`
  cierra graphs anteriores, aunque `composeSync` lo hace `unawaited`, dejando una
  ventana de recursos concurrentes.
- Metadata de UI y documentos se particiona por `scopeKey`; notificaciones además
  validan partición global/empresa. Los queries de órdenes sí filtran empresa y,
  salvo cola de cajero, autor. La clave del borrador es sólo
  `orbi.sale_draft.<scope>` (`sale_editor.dart:220-227`) y `AppScope.scopeKey`
  contiene app/instalación/servidor/BD/usuario, no empresa (`contracts.dart:22-31`);
  `SaleDraftSnapshot` tampoco tiene `companyId` (`sale_editor.dart:88-101`). Por
  ello un mismo usuario que cambia de empresa puede reutilizar ese buffer, aunque
  las tablas de hechos sí llevan `company_id`: requiere contrato explícito o clave
  compuesta antes de afirmar aislamiento entre empresas.

## Faltantes priorizados y tareas pequeñas

| ID | Archivo(s) concretos | Cambio propuesto | Aceptación/evidencia |
|---|---|---|---|
| AUD-01 | `theos_panel/lib/app/order_scope_repository.dart`, `theos_panel/lib/app/scope_catalog_repository.dart` | Añadir lifecycle explícito y conectar `watch` a cambios de Drift/commit; cancelar consultas al cambiar lease. | Test: commit/refresh local emite una sola actualización; dispose cierra controllers; cambio de scope no publica respuesta tardía. |
| AUD-02 | `theos_panel/lib/features/sales/sale_editor.dart`, `orbi_runtime/lib/src/sales/sale_draft_repository.dart` | Elegir una fuente durable para el buffer; persistir dirty/baseRevision y todos los campos (`discount`, `tax`), con validación de decode. | Reinicio offline conserva texto/líneas/impuestos/descuento; cabecera+l líneas+outbox siguen atómicos; evidencia de rollback inducido. |
| AUD-03 | `theos_panel/lib/features/sales/sale_editor.dart`, `orbi_runtime/lib/src/sales/sale_command_port.dart` | Mapear `OperationOutcome` a estados visibles distintos (queued, rejected, conflict, ambiguous) sin colapsarlos a aprobación pendiente. | Fixtures de cada estado producen copy/estado distinto y no muestran “guardado” para rechazo/conflicto. |
| AUD-04 | `orbi_runtime/lib/src/sync/catalog_sync.dart`, `orbi_runtime/lib/src/read/local_catalog_adapters.dart` | Verificar/cubrir `DriftCatalogStore.commit`: registros+cursor y publicación observable en una sola transacción. | Prueba de fallo entre registro y cursor deja ambos sin cambiar; listener recibe sólo estado post-commit. |
| AUD-05 | Nuevo contrato y adaptadores bajo `orbi_runtime/lib/src/` + `theos_panel/lib/app/` (requiere decisión de modelo Odoo) | Definir recurso tipado de imagen, blob durable/ref, versión, capacidad, límites y operación upload/remove; separar caché evictable de propuesta pendiente. | RC06–RC11: miniatura offline, reinicio sin red, disco lleno/archivo inválido, permiso revocado y conflicto remoto sin pérdida. |
| AUD-06 | `theos_panel/lib/app/u08_scope_adapters.dart`, `theos_panel/lib/features/reports/document_view.dart` | Añadir identidad/versionado y stream o invalidación de documento; agrupar bytes+referencia en una operación durable y limitar tamaño. | Sync actualiza sólo el documento afectado; documento corrupto no reemplaza caché válido; UI reacciona sin reconstruir toda la orden. |
| AUD-07 | `orbi_runtime/lib/src/sync/sync_coordinator_impl.dart`, `theos_panel/lib/app/business_composition_factory.dart` | Publicar conteos reales de cola/conflicto por scope y hacer cierre de composiciones awaitable/observable. | Cambiar sesión durante sync no muta snapshot nuevo; conteos coinciden con filas ready/scheduled/dead-letter/conflict. |

## Conclusión de aceptación

La base existente contiene aislamiento por lease, outbox durable y claves de
deduplicación para venta/caja/sync como mecanismos de fuente; esta auditoría no
demuestra su comportamiento en ejecución. No debe declararse cumplimiento pleno de
la especificación reactiva ni de imágenes: faltan observables conectados a la base,
un único borrador durable con revisión/conflicto y un contrato de recursos binarios.
Las tareas AUD-01–AUD-07 son cambios acotados; cada una exige evidencia específica
antes de cerrar RC01–RC12.
