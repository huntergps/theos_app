# Contratos de integración v1

Estos son contratos de diseño pendientes de materializar en Dart en F01/F04/N01.
Los nombres aquí fijan vocabulario entre equipos. Reutilizar tipos existentes
equivalentes mediante adaptación; no crear una segunda entidad SaleOrder.

## C01 · identidad

`AppScope`: appId, installationId, normalizedServerUrl, database, userId.
`CompanyContext`: companyId, allowedCompanyIds, scopeKey, capabilityRevision.
`scopeKey` es una codificación canónica sin secretos, estable entre reinicios;
no concat simple ambigua. `installationId` se genera una vez y se persiste.
Empresa no cambia `scopeKey`: es una partición de datos/visibilidad dentro de él.
Las claves de notificaciones y cursores añaden una partición de empresa explícita.

`SessionRuntime`: activateOnline, activateOffline, restore, switchCompany, close.
Devuelve sesión activa solo después de instalar BD/cliente/permisos/cola.
`close` es idempotente; distinguir suspender, cerrar proceso y logout explícito.
Un lease/generation identifica cada activación para rechazar respuestas tardías.
La apertura física de BD y la publicación de sesión tienen un único propietario.

## C02 · configuración por capacidades

`CapabilitySnapshot`: scopeKey, companyId, pointId opcional, revision, fetchedAt,
permisos efectivos, políticas de mostrador, operaciones offline provisionadas.
Ausencia del panel no elimina operaciones del contrato base. No inferir permiso
de caja de un color, rol visual, filtro o presencia del módulo panel.
Conservar snapshot para offline con la política de validez acordada; no inventar
TTL que corte ventas de campo ni extender autorizaciones automáticamente.

## C03 · consultas y comandos

Consultas de UI: streams locales paginados/filtrados. `OrderQuery` conserva
companyId, authorFilter opcional, texto, estados y fechas. Lista y contador
consumen el mismo predicado. Paginación estable por ID/orden determinista.

Comandos: `CreateOrder`, `UpdateOrder`, `RequestApproval`, `ConfirmOrder`,
`GenerateDispatch`, `RegisterCollection`, `OpenCashSession`, `CloseCashSession`.
Cada uno recibe `scope`, `commandId` estable, objetivo local/remoto y versión
esperada cuando aplique. Los constructores usan Money/tipos existentes del core.
No inventar fórmulas fiscales ni almacenar claves en estos comandos.

`OperationOutcome`:

- commandId y referencia de entidad (UUID local, ID remoto opcional).
- businessState: estado propio del negocio, incluyendo aprobación requerida,
  operación local completada o rechazo; reutilizar enums de dominio.
- syncState: localOnly/queued/sending/synced/conflict/failed.
- pendingAction opcional: tipo conocido, entidad y contexto validado.
- issues: code, messageKey, args saneados, field opcional, retryable.
- fiscalState independiente cuando aplique: emittedLocal/submitted/authorized/
  rejected; no reducirlo a `synced`.

Un booleano `success` aislado no es suficiente. Reintentar transporte solo donde
la política del SDK lo permite. Un cobro ambiguo se reconcilia por contrato
idempotente del backend; `search` seguido de `create` no demuestra exclusión
atómica frente a concurrencia.

## C04 · edición

`EntityPicker<T>` recibe consulta local asíncrona/observable, selección y callback.
`MoneyField` recibe valor tipado, moneda/precisión, reglas y callback.
`FieldIssue` es dato; su widget decide la representación.
`DraftController` conserva buffer, baseRevision y campos dirty. Cambios externos
durante edición producen aviso/conflicto, no sustitución silenciosa.

Guardado de borrador no equivale a confirmación comercial. Adaptar ambos layouts
(mostrador/consultiva) a los mismos comandos. Cambiar tamaño no recrea borradores.

## C05 · conectividad y sincronización

`NetworkSignal`: tipos de red disponibles, timestamp. Es indicio, no disponibilidad.
`BackendHealth`: unknown/checking/reachable/unreachable, lastCheckedAt.
`AuthStatus`: authenticated/expired/required. Un 401 no es ausencia de Internet.
`SyncSnapshot`: active, queuedCount, failedCount, conflictCount, lastCompletedAt.

`SyncCoordinator`: start(scope), requestSync(reason), pause(reason), stop(scope).
Un coordinador serializa disparadores de red, ciclo de vida, temporizador y manual.
Respeta Modo Ruta, drena dependencias y publica resultado tras commit local.
No crear un temporizador independiente en cada pantalla/contador/notificación.

## C06 · notificaciones

Tipos, persistencia y entrega se fijan en NOTIFICATIONS.md.
`NotificationInbox`: watch(query), ingest(event), markRead(id), markUnread(id),
archive(id), resolve(sourceKey). Cada operación valida el scope.
`NotificationPresenter`: capabilities, requestPermissionFromUserAction,
showOrReplace(delivery), cancel(systemId). No conoce repositorios de venta.
`NotificationNavigator`: open(NotificationTarget). La app revalida sesión,
empresa, entidad y permiso; payload no contiene URL arbitraria ni comando financiero.
`NotificationCursorStore`: leer/avanzar baseline y cursor por scope/partición/origen
en la misma transacción de ingesta, según NOTIFICATIONS.md.

## C07 · marca y documentos

`BrandProfile`: servidor/base/empresa, logo/fondo en caché, colores de marca/acción
como valores neutrales, revisión y fuente. Ningún `AccentColor` Fluent.
Resolver por propiedad: override del usuario en Orbi → configuración Odoo →
predeterminado Orbi. Heredar y personalizar son estados distintos; guardar en Orbi
no escribe Odoo. Véase [PERSONALIZATION_SPEC.md](PERSONALIZATION_SPEC.md).
`ReportRequest`: templateId/revision, entidad y snapshot de datos, formato.
`ReportResult`: bytes, mimeType, nombre seguro, estado fiscal mostrado.
QWeb produce documentos; la emisión/identidad fiscal pertenece al dominio.

## Propiedad y cambios

Integrador: C01/C02/C03/C05 y cambios de esquema. Equipo UI: consumidores C04/C07.
Equipo notificaciones: implementación C06 conforme a contrato.
Cambios de firma compartida deben actualizar primero este archivo y las tareas
dependientes; no resolver conflictos copiando modelos o importando `theos_pos`.
