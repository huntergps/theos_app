# Decisiones de estado local y contratos de runtime

Fecha: 2026-09-10. Alcance: prerequisito RT01 y migración RT02.
Este documento fija decisiones para implementación posterior; no afirma pruebas
ejecutadas ni modifica esquema, app o ERP2.

## Decisiones cerradas

1. **Una fuente durable para el editor.** El buffer editable de venta será un
   único store Drift, segregado por `(scopeKey, companyId, draftId)`; `draftId`
   será estable e independiente de los comandos. Un comando identifica una intención
   concreta/reintento, no todas las ediciones sucesivas del documento. El store tendrá snapshot completo, `baseRevision`,
   dirty/revisión local y estado de sincronización. Riverpod, controllers y
   `SharedPreferences` no serán copias editables.
2. **Separación de responsabilidades.** El draft se guarda localmente sin
   confirmar ni crear outbox. La confirmación seguirá pasando por el caso de uso
   existente, que puede agrupar entidad + outbox en transacción. `dispose` sólo
   cierra listeners; no borra draft ni operación pendiente.
3. **Identidad/empresa.** `AppScope.scopeKey` no contiene empresa
   (`orbi_runtime/lib/src/contracts.dart:22-31`); por eso `companyId` es columna y
   parte obligatoria de toda clave/consulta del draft. Nunca se elegirá empresa
   por último valor, perfil ambiguo o primera empresa permitida.
4. **Migración conservadora.** Se leerán sólo claves conocidas y payloads válidos.
   Un draft antiguo con `scopeKey` pero sin `companyId` no se asigna a ninguna
   empresa: queda en migración pendiente/recuperación manual y no se muestra.
   Payload inválido, empresa ausente, líneas incompletas o campos no serializados
   se conservan intactos como legado aislado; no se "completan" ni se descartan.
   No se migrará `discount`/`tax` faltante adivinando cero. La migración debe
   reportar qué campos no pueden recuperarse y conservar una copia raw antes de
   retirar la lectura antigua. No borrar claves SharedPreferences en RT02.
5. **Campos completos.** El formato durable debe preservar, como mínimo, todos
   los campos de `SaleDraftSnapshot` y `SaleDraftLine`: identidad, cliente,
   nota, términos/cuotas, cantidad, precio, descuento, impuesto, total/UoM/taxes,
   `baseRevision`, `expectedVersion`, aprobación y acción pendiente. El decode
   debe validar tipos y enumeraciones, sin `as` no controlados.
6. **Observables existentes vs nuevos.** Se reutiliza
   `LocalCatalogStore.watch(AppScope)` existente: `DriftCatalogStore.commit` ya
   escribe filas+cursor en una transacción y publica después. Se debe conectar a
   él los repositorios UI; no crear otro stream de catálogo. `NotificationInboxStore.watch`
   existente también se conserva. Para órdenes, drafts y conteos de cola se
   requieren observables nuevos en el core o adaptadores scope-bound; los
   `StreamController` manuales de UI no son fuente de verdad.
7. **Cancelación y lease.** Toda consulta nueva cancela la anterior; el resultado
   se publica sólo si coinciden scope, compañía, requestId y lease vigente.
   `SessionLease` existente (`RuntimeDatabaseOwner`, `SessionRuntime`) es la
   autoridad. Cancelar no revierte un commit durable. Cambio de scope/empresa
   debe cerrar la suscripción previa antes de aceptar la nueva.
8. **Paginación.** Órdenes conservan orden determinista
   (`date_order DESC, odoo_id DESC`); el cursor debe transportar ambos valores,
   no asumir que `afterId` solo describe un orden por fecha. No aumentar límite interpolando input
   UI; validar límites en el puerto. Catálogos no deben seguir offset como
   identidad: se necesita cursor estable por ID/orden, gate de contrato del backend
   si no existe. Lista y contador comparten predicado.
9. **Conteos/outcomes.** `OperationOutcome` conserva business/sync/fiscal/pending
   e issues; ningún error se presenta como “Aprobación comercial pendiente”. El
   snapshot de sync debe distinguir ready/scheduled/processing/failed/conflict/
   dead-letter. `queuedCount` no será número de jobs: debe salir de filas de
   `offline_queue` filtradas por scope/partición cuando el esquema lo permita.

## Firmas verificadas y propuestas

Existentes (no recrear):

```dart
abstract interface class SaleDraftRepository {
  Future<int> save(SaleDraftRecord draft);
}
abstract interface class SaleDraftStore {
  Future<SaleDraftSnapshot?> load(String scopeKey);
  Future<void> save(SaleDraftSnapshot draft);
}
abstract interface class LocalCatalogStore<T> {
  Stream<CatalogState<T>> watch(AppScope scope);
  Future<CatalogState<T>> read(AppScope scope);
  Future<void> commit(AppScope scope, CatalogBatch<T> batch);
  Future<void> recordError(AppScope scope, Object error);
}
abstract interface class SyncCoordinator {
  Future<void> start(AppScope scope);
  Future<void> requestSync(SyncReason reason);
  Future<void> pause(PauseReason reason);
  Future<void> stop(AppScope scope);
}
```

Nuevas propuestas (marcadas, no APIs disponibles):

```dart
abstract interface class DurableSaleDraftStore {
  Stream<SaleDraftState> watch(SaleDraftKey key, CancelHandle cancel);
  Future<SaleDraftState?> read(SaleDraftKey key);
  Future<SaleDraftState> upsert(SaleDraftState draft, {required SessionLease lease});
  Future<void> remove(SaleDraftKey key, {required SessionLease lease});
}
abstract interface class RuntimeOrderObservable {
  Stream<OrderSnapshot> watch(OrderQuery query, CancelHandle cancel);
}
abstract interface class OfflineQueueMetrics {
  Stream<QueueCounts> watch(AppScope scope, {required SessionLease lease});
  Future<QueueCounts> read(AppScope scope, {required SessionLease lease});
}
```

`SaleDraftKey` deberá contener `scopeKey`, `companyId` y `draftId`; `SaleDraftState`
deberá contener snapshot, `baseRevision`, revisión local, dirty y outcome.
Los tipos se integran en el contrato compartido antes de implementación.

## Evidencia real y gates RT01/RT02

- Store/DB actual: `theos_pos_core/lib/src/database/database.dart` exporta
  `AppDatabase`; tablas relevantes son `sale_order`, `sale_order_line`,
  `offline_queue` y `sync_metadata`. `SaleOrder` tiene `companyId`, pero no existe
  tabla de draft editable segregada por empresa.
- Persistencia de confirmación: `orbi_runtime/lib/src/sales/sale_draft_repository.dart`
  (`DriftSaleDraftRepository.save`) atomiza cabecera, líneas y outbox, pero sólo
  recibe `SaleDraftRecord` y devuelve `Future<int>`; no carga/observa drafts.
- Buffer actual: `theos_panel/lib/features/sales/sale_editor.dart`,
  `SharedPreferencesSaleDraftStore` y `SaleDraftController`; la clave sólo usa
  scope y el serializer no incluye `discount` ni `tax`.
- Composición: `theos_panel/lib/app/router.dart:229-273` inyecta el store de
  preferencias y opcionalmente el repositorio Drift; esto debe converger a un
  único store durable.
- Cola: `theos_pos_core/lib/src/database/datasources/offline_queue_datasource.dart`
  ya ofrece `getPendingCount`, `getRetryStats`, estados y filtros; falta puente
  observable scope-bound. `SyncCoordinatorImpl` publica `_jobs.length`, no filas.
- Lease/cierre: `orbi_runtime/lib/src/storage/runtime_database_owner.dart` y
  `orbi_runtime/lib/src/session/session_runtime.dart` son propietarios de BD y
  lease; no añadir un lease paralelo.

RT01 no depende de la migración de drafts: conectar el observable de catálogos
existente puede avanzar independientemente. El observable nuevo de órdenes requiere
firma/cursor integrados. RT02 implementará una tabla de buffer editable separada de
hechos comerciales en la BD scope existente, con clave compuesta indicada arriba,
versión de payload y revisión local. La migración de esquema la posee el integrador.
Fixtures de legado válido, empresa desconocida, campo perdido y JSON inválido, así
como rollback/reinicio, son criterios de aceptación de implementación, no otra
decisión de producto. No se garantiza recuperación sólo por inspección estática.
