> Fecha: 13-sep-2026 · HEAD leído: `4d02e3c` (rama `orbi/trabajo-pausado-2026-09-11`, con cambios sin commitear de otra auditoría en router.dart, orbi_runtime.dart y system_notification_presenter.dart).
> Informe de SÓLO LECTURA sobre theos_app y dev_odoo20/addons: no se editó código, no se hicieron commits, no se usó stash y no se tocaron servidores.

Respuesta: NO. theos_pos no tiene hoy funcionando el refresco Odoo→app en tiempo real. Se desenchufó el 5-sep-2026 (commit 44794ac) y lo que queda es el motor huérfano en odoo_sdk. Solo leí código: no edité nada, no hice commits, no usé stash y no toqué servidores.

## Salida LITERAL del comando
```
theos_pos_core/lib/theos_pos_core.dart
theos_pos_core/lib/src/odoo_field_registry.dart
odoo_sdk/lib/src/websocket/websocket_reconnection_manager.dart
odoo_sdk/lib/src/websocket/websocket_event_parser.dart
odoo_sdk/lib/src/websocket/websocket_connection_manager.dart
odoo_sdk/lib/src/websocket/websocket_handler.dart
odoo_sdk/lib/src/websocket/websocket_message_deduplicator.dart
odoo_sdk/lib/src/websocket/websocket_channel_manager.dart
odoo_sdk/lib/src/websocket/odoo_websocket_service.dart
odoo_sdk/lib/src/websocket/websocket_heartbeat_manager.dart
odoo_sdk/lib/src/model/model_registry.dart
```
No sale ningún fichero de theos_pos/lib, orbi_runtime/lib ni theos_panel/lib.

## Evidencia de que está apagado
- `git show --stat --diff-filter=D 44794ac` (5-sep-2026) borró de theos_pos/lib: `core/services/websocket/odoo_websocket_service.dart` (485 líneas), `features/sales/screens/fast_sale/fast_sale_notifier_websocket.dart` (535), los 11 `shared/providers/notification_handlers/notification_handlers_*.dart` (catálogo, sale_order, líneas, caja, tarjeta, finanzas, retenciones, partner/usuario/empresa, actividad, cobranza), además de `websocket_debug_screen.dart` y `websocket_status_widget.dart`. La carpeta `theos_pos/lib/core/services/websocket/` sigue existiendo, pero vacía.
- En odoo_sdk queda vivo y exportado (`odoo_sdk.dart:78-87`): OdooWebSocketService, de 2080 líneas en total.
  - Abre `wss://host/websocket?version=19.0-2` (`websocket_connection_manager.dart:70`).
  - Se suscribe con `{event_name: subscribe, data: {channels, last}}` (`websocket_channel_manager.dart:68`).
  - Parsea `id`/`message.type`/`payload` y guarda `lastNotificationId` (`websocket_event_parser.dart:67-130`). Los tipos se mapean con `WebSocketModelRegistry.registerNotification/registerChannel`, pero **nadie los registra** en ningún paquete: solo aparecen en un comentario de ejemplo. Así que hoy solo se suscribiría a presencia y actividad.
  - Camino a Drift: `ModelRegistry._setupWebSocketHandlers` (`model_registry.dart:370`) → `OdooModelManager.handleWebSocketEvent` (`odoo_model_manager.dart:1005`). En create/write hace `_syncRecordInBackground(id)`, que relee de Odoo y escribe en Drift; en unlink hace `deleteLocal`. De ahí pasa a `watchLocalSearch` (`odoo_model_manager.dart:312`) y a los StreamProvider. **No hay ningún llamador** que alimente ese stream.
  - Los helpers `upsertUomFromWebSocket` (`uom_manager.dart:61`), `upsertSaleOrderLineFromWebSocket` (`sale_order_line_manager.dart:194`) y `updateCompanyConfigFromWebSocket` (`company_manager.dart:36`) no tienen llamadores.
  - `OdooFieldRegistry.syncViaWebSocket/getWebSocketFields` (`odoo_field_registry.dart:52,126`) solo lo usa su test.
- Autenticación del socket nativo: `platform/websocket_connect_io.dart` manda `Authorization: Bearer`. La ruta `/websocket` de Odoo es `auth='public'` y el bus identifica por la sesión (cookie), así que **el Bearer no autentica el bus**. El override `l10n_ec_collection_box_pos/controllers/websocket.py:28` acepta `?session_id=` en la URL. Eso funciona, pero deja el id de sesión en logs y proxies; es justo lo que debe reemplazar la ruta nueva.

## 1. Marco global
| Pieza | theos_pos | Orbi | Diferencia | Qué reutilizar |
|---|---|---|---|---|
| Arranque | `main.dart:130` monta `ProviderScope`; `core/services/app_initializer.dart:96` detecta la versión y abre `DatabaseHelper.initializeForServer` | `theos_panel/lib/app/bootstrap.dart` y `session_composition.dart` (overrides por scope) | Orbi compone por scope con puertos explícitos | Nada de UI; Orbi ya tiene lo suyo |
| Sesión/scope | `core/session/session_scope_activation_coordinator.dart:83` (online/offline, bloqueo, rollback) + `session_teardown_coordinator.dart` + `app_session_scope_driver.dart:89` (compuerta `enableSyncAndReplay`) | `orbi_runtime/lib/src/session/session_runtime.dart:14` (`activate`/`close`) + `RuntimeDatabaseOwner` (el mismo `AppDatabase` de theos_pos_core) | Equivalentes. Orbi además tiene PIN y desbloqueo (`workspace_unlock_store.dart`, `pin_credential_store.dart`); theos_pos no tiene bloqueo ni cambio de usuario | La idea de «apagar sync antes de cerrar Drift» ya está en Orbi vía `stop`/`dispose` |
| Empresa | `shared/providers/company_config_provider.dart:35` (`currentCompany`, se invalida a mano) | En `CapabilitySnapshot.fetch(scope, companyId)` (`bootstrap.dart:402`) | Ninguna de las dos refresca la empresa en vivo | `CompanyManager.updateCompanyConfigFromWebSocket` |
| Conectividad | `ServerHealthService` (`core/services/platform/server_connectivity_service.dart:136`), que se inicia en `shared/screens/main_screen.dart:107` | `ConnectivityMonitor` + `Json2BackendProbe` + `networkSignalProvider` + `AppForegroundSignal` (el último sin commitear) | Orbi separa red de backend | — |
| Estado de sync en pantalla | `SyncInfoBanner`, `ServerStatusWidget`, `offline_queue_section.dart` | `_syncStatusLabel` (`router.dart:653`), `/sync` (`sync_center.dart`) y la pantalla de conflictos | Equivalentes | — |
| Cierre de sesión | `main_screen.dart:120-145` (`runBestEffortSessionCleanup`: orquestador → sync → cola → invalidación) | `ref.onDispose(coordinator.dispose)` (`router.dart:398`) | theos_pos tiene la secuencia ordenada | Copiar ese orden cuando entre el socket: **cerrar el socket primero** |

## 2. App → Odoo
| | theos_pos | Orbi | Diferencia |
|---|---|---|---|
| Escritura local primero | Managers/repos sobre Drift + `offline_queue` | `commitAndEnqueueIfAbsent` (`sale_runtime_adapters.dart:20`) sobre el mismo `OfflineQueueDataSource` | Misma tabla |
| Procesador de cola | `OfflineSyncService` (`features/sync/services/offline_sync_service.dart:120`) envuelve **OfflineQueueProcessor** (`odoo_sdk/lib/src/sync/offline_queue_processor.dart:97`) | `OperationsSyncJob` (`orbi_runtime/lib/src/sync/operations_sync_job.dart:58`) envuelve **el mismo OfflineQueueProcessor** | Mismo motor: dependencias, backoff, `recovery_pending`, `manual_after_ambiguous` |
| Despacho | 6 ficheros `offline_sync_*.dart` (~3.300 líneas: venta, pago, sesión, partner, genéricos, aprobación de crédito) | `OdooOfflineOperationAdapter` (`sale_runtime_adapters.dart:671`), con `reconcile` por `search_read` (l.685-737) | **Orbi tiene reconciliación previa** (¿ya se aplicó?) y theos_pos no. Orbi solo cubre ventas/cobro; theos_pos cubre más tipos |
| Coordinador | `ConnectivitySyncOrchestrator` (`connectivity_sync_orchestrator.dart:38`): al recuperar la red espera 5 s de estabilidad, además hace **sondeo cada 5 min** (l.105), drena la cola y luego `syncCriticalData` | `SyncCoordinatorImpl` (`sync_coordinator_impl.dart:7`): drenado exclusivo, epoch por scope, `operations` primero y después 14 catálogos (`runtime_catalog_composition.dart:90-99`). `SyncAutoResyncTrigger` reacciona a los filos de red y de primer plano (sin commitear) | Orbi no tiene sondeo periódico. theos_pos no reacciona al volver a primer plano |

No hay que unificar: los dos comparten `OfflineQueueProcessor` y `OfflineQueueDataSource`. Lo que difiere es el orquestador de cada app, y eso es correcto porque theos_pos arrastra Riverpod y Fluent.

## 3. Odoo → app (tiempo real)
| | theos_pos | Orbi |
|---|---|---|
| Socket | Borrado el 5-sep. El motor está en odoo_sdk, sin enchufar | No existe |
| Suscripción, parser, dedupe, heartbeat, reconexión | odoo_sdk (sin usar) | — |
| Carga → Drift | `OdooModelManager.handleWebSocketEvent` relee por id (sin usar) | — |
| Pantalla | `watchLocalSearch` → StreamProvider (sí se usa, pero se alimenta de sync/CRUD) | `DriftCatalogStore.watch` / los watch del inbox |

Qué emite Odoo (canal → tipo). Todos van con canal string `"{db}.X"`; el core los guarda como `(db, "{db}.X")` (`bus/models/bus.py:41-47`), igual que lo que suscribe el cliente (`ir_websocket.py:79`), así que **coinciden**.

- **l10n_ec_collection_box**:
  - `{db}.sale.order` → `sale_order_created` (plano: `id`, `name`, `state`, importes, `write_date`, `action`; `models/sale_order.py:154`).
  - `{db}.collection_session` → `session_updated`/`session_deleted` (`collection_session.py:2071,2161,3174`), más el cruzado `{db}.collection_config` → `config_updated`.
  - `{db}.collection_config` → `config_created/updated/deleted` (`collection_config.py:553,609,1024`).
  - También emiten `advance_inherit.py`, `account_move.py`, `account_payment.py`, `cash_out.py`, `collection_session_deposit.py` y `checks_inherit.py` (3-4 `_sendone` cada uno).
- **l10n_ec_collection_box_pos**:
  - `{db}.sale_order_updated` → `sale_order_updated` con `{action, order_id, order_name, x_uuid, values, changed_fields, user_id, timestamp}` (`models/sale_order.py:226-250`).
  - `{db}.tax_updated`, `payment_method_line_updated`, `card_brand_updated`, `card_deadline_updated`, `card_lote_updated`, `product_category_updated`, `stock_quant_updated`, `cash_out_updated`, `product_uom_updated`, `journal_updated`, `sale_order_payment_updated`.
  - `bus_bus.py:11` duplica la presencia y `mail.activity/updated` a `{db}.odoo-presence-res.partner_N` y `{db}.odoo-activity-res.partner_N`.
- ⚠️ **Inconsistencia de carga útil:**
  - La venta llega con dos formas distintas: la base, plana con `id`, y la pos, con `order_id` y `values`.
  - La clave del id cambia por modelo (`order_id`, `tax_id`…), así que hace falta `WebSocketNotificationMapping.idField` por tipo.
  - `_parseActionFromType` deduce la acción por el sufijo del tipo (`_created`/`_deleted`), pero pos manda siempre `*_updated` con `action` dentro de la carga; habría que leer `payload.action`.
  - **No verifiqué** campo por campo que las claves de `values` (`_get_notification_data`) coincidan con `odooName` del registro. Como el manager relee por id, esa coincidencia no es necesaria para que funcione.

## 4. Recuperar lo perdido al reconectar
| | theos_pos | Orbi |
|---|---|---|
| Cambios | Incremental por `write_date > lastSyncDate` con solape (`sync_provider.dart:660-733`, `manager_sync_mixin.dart:68`) | **Recarga completa paginada por offset**: el cursor es el offset y vuelve a null al terminar (`json2_read_adapters.dart:316-339`). No hay `write_date` en el dominio |
| Bajas | `sync.deleted.record.get_deleted_since` (`sync_counts_repository.dart:237`, llamado en `sync_provider.dart:683,843,983`) | **Nada**: un registro borrado en Odoo se queda en local |
| `last` del bus | El parser lo guarda solo en memoria | — |

Odoo registra bajas solo de: product.product, res.partner, product.category, account.tax, uom.uom, product.pricelist, account.payment.term, sale.order, account.move, account.move.line (`sync_tracked_models.py`). No cubre journal, payment.method.line, card_*, collection_*, cash_out ni stock.quant.

## 5. Notificaciones
| theos_pos | Orbi |
|---|---|
| Solo `displayInfoBar` en pantalla (sync_info_banner, supervisor_dashboard, formularios de venta…) y `credit_approval_notification.dart`. **No usa notificaciones del sistema**: sin `flutter_local_notifications`; los handlers de bus que las generaban se borraron | `SystemNotificationPresenter` (`flutter_local_notifications` ^22.3, cancelación por scope) + `RuntimeNotificationInbox` persistente en Drift con `ingest(event)`. Hoy no tiene fuente en vivo |

## Diseño bidireccional para Orbi (sobre lo que ya existe)
**App → Odoo, ya está:** comando → Drift + `offline_queue` en una transacción (`commitAndEnqueueIfAbsent`) → `SyncCoordinatorImpl` → `OperationsSyncJob` → `OfflineQueueProcessor` → `OdooOfflineOperationAdapter.reconcile` (¿ya aplicado?, por `x_uuid`/`search_read`) → `dispatch` → marcar hecho o conflicto → `/sync`. Falta:
- a) sondeo periódico de respaldo, como los 5 min de theos_pos, dentro de `SyncAutoResyncTrigger`;
- b) tras un drenado con éxito, `requestSync` del catálogo afectado.

**Odoo → app, nuevo, reutilizando odoo_sdk:**
1. Pieza `RealtimeSession` en orbi_runtime: pide la sesión a la ruta nueva de `l10n_ec_collection_box_pos` con Bearer JSON-2 y abre `OdooWebSocketService.connect`. En nativo, la cookie en la cabecera; en web, el navegador no deja poner cabeceras, así que va la cookie de la ruta con `SameSite=None; Secure` o, si no queda otra, un token de un solo uso por query, **no el session_id**.
2. Registro de canales y tipos, un mapa `tipo → (modelo, idField, catálogo)` con los ~20 tipos de arriba, en `WebSocketModelRegistry`.
3. `RealtimeEventRouter`: evento → relee por id vía JSON-2 → escribe con el `writeRows` del `DriftCatalogStore` correspondiente (upsert, sin tocar el cursor) → `watch()` refresca la pantalla. Si `action=deleted`, borrado local. Nunca pisa una fila con operación pendiente en la cola (mirar `offline_queue` por `x_uuid`/`record_id`); eso sale a conflicto.
4. Actividad y presencia → `RuntimeNotificationInbox.ingest` → `SystemNotificationPresenter`.

**Al reconectar:**
1. `connect` vuelve a suscribir con `last` persistido por scope (hoy solo vive en memoria; hay que guardarlo en Drift). Si el servidor ya purgó ese `last` (el bus borra con el tiempo), hay que hacer una recuperación completa.
2. `SyncAutoResyncTrigger` online → drena la cola → catálogos incrementales con `write_date > cursor` (hay que cambiar el cursor de offset a `write_date|id`) → `sync.deleted.record.get_deleted_since` por catálogo.
3. El orden lo fija `SyncCoordinatorImpl`: cola primero y el socket se abre después del primer ciclo, para no aplicar eventos sobre una base a medio drenar.

## Qué falta en Odoo
- La **ruta de sesión para el bus** (la que otro agente construye ahora). Cuando exista, hay que retirar o limitar `controllers/websocket.py` (`session_id` por query).
- Unificar la carga útil de venta (base contra pos) o documentar las dos.
- Ampliar `sync_tracked_models.py` a los catálogos que Orbi sincroniza y hoy no registran bajas (account.journal, account.payment.method.line, card brand/deadline/lote, collection.config/session, cash.out).
- Revisar lo que avisa `_sendone` en `bus.py:98`: canales string adivinables. Cualquier sesión válida de la misma base puede suscribirse a `{db}.sale_order_updated` y leer ventas ajenas. Hoy la carga es solo la notificación, pero incluye importes y nombres.
- Nada de esto toca el core; todo cae en módulos propios.

## Frentes en paralelo (ficheros disjuntos)
1. **SDK del socket** (`odoo_sdk/lib/src/websocket/*`):
   - Autenticación por cookie o token en io y web.
   - Acción leída de `payload.action`.
   - `last` inyectable y persistible.
   - Tests en `odoo_sdk/test/websocket_test.dart`.
2. **Cursor incremental y bajas** (`orbi_runtime/lib/src/read/json2_read_adapters.dart`, `local_catalog_adapters.dart`, `catalog_sync.dart`): cursor `write_date|id` y llamada a `get_deleted_since`. Tests en `orbi_runtime/test/sync/`.
3. **Router de tiempo real en runtime** (nuevos: `orbi_runtime/lib/src/realtime/realtime_session.dart`, `realtime_event_router.dart`, `realtime_channel_map.dart`, más el export en `orbi_runtime.dart`). Toma `DriftCatalogStore` por inyección; no edita `runtime_catalog_composition.dart` hasta integrar.
4. **Composición en panel** (`theos_panel/lib/app/router.dart`, bloque propio junto a `scopeSyncCoordinatorProvider`, y `sync_center.dart`): proveedor por scope, cierre ordenado y estado «en vivo» en el pie. ⚠️ `router.dart` y `orbi_runtime.dart` tienen cambios sin commitear de otra auditoría; hay que integrarlos antes.
5. **Notificaciones vivas** (`orbi_runtime/lib/src/notifications/runtime_notification_inbox.dart`, un adaptador nuevo `realtime_notification_source.dart`). ⚠️ `system_notification_presenter.dart` también está modificado sin commitear.
6. **Odoo** (`dev_odoo20/addons/l10n_ec_collection_box_pos`): `sync_tracked_models.py` y la retirada o limitación de `controllers/websocket.py`. No debe pisar `controllers/` mientras el otro agente escribe ahí, así que conviene coordinarlo con él.
7. **Sondeo de respaldo** (`orbi_runtime/lib/src/sync/sync_auto_resync_trigger.dart`, sin commitear): señal periódica opcional.

Dependencias: 3 depende de 1 (API) y de la ruta nueva; 4 depende de 3; 2, 5 (ingest) y 7 son independientes.

¿theos_pos tiene hoy funcionando el refresco Odoo→app en tiempo real? **No.**
