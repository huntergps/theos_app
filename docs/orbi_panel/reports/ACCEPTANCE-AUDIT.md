# Auditoría QA de aceptación U02–U10

Auditoría de código productivo (2026-09-07). No se usaron los reportes como evidencia.
`PASS` significa que hay camino productivo comprobable; `PARTIAL` que sólo una parte
está conectada; `FAIL` que el criterio principal no tiene implementación productiva.

## Resultado por tarea

- **U02 — PASS (código; restore corregido).** Bootstrap hace exactamente un restore
  online y un fallback offline (`app/bootstrap.dart:83-93`, `features/auth/auth_controller.dart:17-30`),
  y el router aplica una política única
  (`app/router.dart:158-188`). Pero no hay llamada productiva a
  `AuthNotifier.restore` al arranque (`rg` sólo encuentra su declaración en
  `features/auth/auth_controller.dart:135-145`); restore/offline queda en una API no
  ejercida. Web sí devuelve estado explícito en `auth_controller.dart:177-180`.
  Tests de auth usan `FakeAuthService` (`test/features/auth/auth_flow_test.dart:9-89`).
- **U03 — PARTIAL.** Controller y repositorio tienen paginación, epochs, streams y
  listas inmutables (`features/clients/catalog_contracts.dart:15-155`), y la ruta
  crea controllers scope-bound (`app/router.dart:82-108`). La persistencia durable
  depende de que el coordinador haya sincronizado; pantallas aceptan un repository
  inyectado y no prueban la ruta real (`clients_screen.dart:6-25`,
  `test/features/catalogs/catalog_features_test.dart`).
- **U04 — PASS (persistencia de filtro corregida).** Mis ventas/Todas y scope están cableados
  (`features/orders/orders_contracts.dart:56-87`); lista y contador usan el mismo
  `RuntimeLocalOrderReader` (`orbi_runtime/lib/src/read/runtime_order_reader.dart:17-60`).
  El filtro ahora se restaura por scope y vuelve a validar permisos
  (`features/orders/orders_contracts.dart:91-170`, `features/orders/orders_screen.dart:6-35`).
  El mapping productivo ahora deriva cobro de `amount_unpaid/payment_state` y
  facturación de `amount_to_invoice/invoice_status/has_queued_invoice`
  (`app/order_scope_repository.dart:74-111`); el lector local comparte el OR con
  count y el lector JSON-2 conserva caja sin filtro vendedor
  (`orbi_runtime/lib/src/read/runtime_order_reader.dart:17-63`,
  `orbi_runtime/lib/src/read/json2_read_adapters.dart:298-348`).
- **U05 — PARTIAL.** Counter/consultive comparten controller/ruta y el comando F07
  (`app/router.dart:213-247`, `features/sales/sale_editor.dart:144-180`). Sin scope
  usa `LocalSaleEditorPort` explícitamente no configurado (`router.dart:127-134`,
  `sale_editor.dart:262-275`); por tanto no hay éxito falso, pero tampoco operación
  productiva sin composición. Tests principales usan puertos fake/runtime aislados
  (`test/features/sales/sale_editor_test.dart:78-226`).
- **U06 — FAIL.** `scopeCollectionPendingProvider` devuelve siempre `const []`
  (`app/collection_scope_composition.dart:121-133`) y turno/diarios leen sólo
  metadata sin productor (`:40-119`). Sólo cobro/turno están implementados en
  `runtime_collection_actions.dart:12-81`; anticipo, retención, nota de crédito,
  salida y depósito se renderizan “No disponible” (`features/collection/collection_screen.dart:179-190`).
- **U07 — PARTIAL.** Adapter real valida lease/capacidad y llama RPCs exactos
  (`features/approvals/approval_runtime_adapter.dart:73-104,121-165,243-335`), sin
  bypass de entrega. Sin embargo la resolución offline devuelve `accepted: true`
  tras encolar (`:256-268`), sin evidencia de reconciliación productiva del queue;
  tests cubren fake RPC/puerto (`test/features/approvals/approvals_test.dart:8-30`).
- **U08 — PARTIAL.** Actividad y attachment tienen productores JSON-2 y lease
  (`app/u08_scope_adapters.dart:173-253`). Resume ahora navega sólo a una ruta
  incluida en el item y validada por `RouteAccessPolicy`
  (`ui/home_page.dart:83-104`, `features/home/home_center.dart:49-96`); el puerto
  sigue sin ejecutar lógica de negocio por sí mismo (`u08_scope_adapters.dart:63-69`).
  Documentos sólo cachean `ir.attachment.datas`; no existe endpoint PDF/QWeb, por lo
  que el criterio PDF offline no está satisfecho (`:230-253,269-301`).
- **U09 — PASS (operaciones integradas).** Ruta activa crea coordinador con jobs reales de la composición
  (`app/router.dart:58-80`, `orbi_runtime/lib/src/read/runtime_catalog_composition.dart:84-107`)
  y UI muestra fallos/conflictos/reintento (`features/sync/sync_center.dart:119-163`).
  `OperationsSyncJob` ahora expone cola pendiente/backoff/dead-letter/conflicto desde
  el mismo `OfflineQueueDataSource`, y `CoordinatorSyncCenterPort` lo publica como
  catálogo `operations` (`features/sync/sync_center.dart:55-105`,
  `orbi_runtime/lib/src/sync/operations_sync_job.dart:68-88`). El provider default
  vacío sólo aplica sin sesión; la ruta activa pasa el job real (`app/router.dart:350-367`).
- **U10 — PARTIAL.** Preferencias se persisten por scope y Modo Ruta llama
  pause/resume cuando existe coordinator (`app/preferences/app_preferences.dart:129-227`,
  `app/router.dart:310-327`). El permiso SO está detrás de gesto y distingue denied
  (`settings_screen.dart:119-145`). No hay test productivo que confirme que cambiar
  preferencias nunca altera capacidades; provider de SharedPreferences lanza
  `UnimplementedError` fuera de bootstrap (`app/preferences/app_preferences.dart:230-232`).

## Bloqueos priorizados

1. **P0 U06:** pendientes/turnos sin productor y cinco operaciones aceptadas sólo como
   “No disponible”; no puede aceptarse caja completa.
2. **P1 U08:** falta contrato productivo PDF/QWeb; no declarar PDF offline.
3. **P2 U03/U05/U07/U09/U10:** pruebas predominan ports/fakes y no ejercen composición
   real; revisar antes de cerrar aceptación, aunque no se observó éxito falso en U05.

## Auditoría independiente focalizada (2026-09-07)

Se ejecutó `flutter analyze` sobre todo `theos_panel` (limpio) y, en serie para
evitar la carrera de activos nativos de Flutter, la batería focalizada:

| Tarea | Evidencia ejecutada | Resultado | Bloqueo / límite |
|---|---|---|---|
| F07 | `flutter test test/app/business_composition_factory_test.dart`; suite de ventas, aprobaciones y sync; `orbi_runtime` tests documentados en `reports/F07.md` | PASS en wiring productivo: lease/scope, cola durable, replay/reconciliación y job `operations` | No se certifica backend ERP2 real ni web W01; queda `F06`/`B01` fuera de este recorrido |
| U03 | `flutter test test/features/catalogs`; `runtime_scope_catalog_test` + selección/borrador/responsive | PASS focal: repositorios scope-bound, paginación, estados, respuesta tardía y durable local | Falta medición independiente de catálogo representativo en esta auditoría; la cifra de 5000 (<500 ms) proviene del reporte U03 |
| U04 | `flutter test test/features/orders`; router auth | PASS focal: Mis ventas/Todas, permisos, contador/lista, pendientes de cajero, scope y resize | No se hizo recorrido contra ERP2 conectado |
| U05 | `flutter test test/features/sales`; integración de borrador/cola y dos rutas | PASS focal: counter/consultive comparten draft/command, doble submit, aprobación pendiente y scope stale | El editor wide a text scale 2.0 no tiene test de overflow; ver UI-A11Y residual |
| U07 | `flutter test test/features/approvals`; composición física y replay offline | PASS focal: IDs de solicitud/venta separados, autoridad stale, FSC contado y replay | No equivale a autorización online con actores reales; no marcar V01 |
| U09 | `flutter test test/features/sync`; ruta inyecta coordinator/jobs reales | PASS focal: progreso, retry coordinado, offline conserva cola, conflictos sin resolución falsa | Conflictos abren sólo detalle informativo; falta flujo de resolución productivo |
| U10 | `flutter test test/features/settings` pasa; preferencias scope/theme/route-mode y permiso por gesto inspeccionados | PARTIAL | `flutter test` completo falla en `test/app/preferences/app_preferences_test.dart`: guarda 1.8 y espera 1.3, contradiciendo soporte explícito hasta 2.0. No se modificó el test para ocultar el bloqueo |

La ejecución focalizada consolidada (`catalogs`, `sales`, `orders`, `approvals`,
`sync`, `auth`, `router_auth`) terminó **46 pruebas OK**. La suite completa terminó
**79 pruebas ejecutadas, 1 fallo** (la aserción de escala anterior). Los intentos
paralelos iniciales de Flutter produjeron además un error no determinista de
`native_assets.json`; no se reproduce al ejecutar en serie y no se considera fallo
de producto.
