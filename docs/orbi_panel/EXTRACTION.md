# Inventario de extracción

Lectura de código 2026-09-06. Las rutas son relativas a la raíz. Candidato no
significa verificado financieramente ni movido. No repetir auditorías amplias:
leer los orígenes que corresponden a la tarea y sus dependencias directas.

| Origen comprobado | Destino propuesto | Trabajo previo |
| --- | --- | --- |
| `theos_pos_core/lib/src/services/sales/` y `services/taxes/`, `services/prices/` | Mantener core | Consumir API pública y trasladar pruebas si se amplía |
| `theos_pos/lib/core/session/session_scope.dart` | Identidad neutral en core; adaptador runtime | Parametrizar app/instalación; evitar prefijo theos_pos fijo |
| `theos_pos/lib/core/session/session_scope_activation_coordinator.dart` y teardown/cleanup | Coordinación independiente en runtime/core según imports | Inyectar driver y probar orden, rollback y cierre |
| `theos_pos/lib/core/session/app_session_scope_driver.dart` | Runtime | Inyectar almacenamiento y ciclo de sync |
| `theos_pos/lib/core/security/platform_credential_store.dart` y variantes | Runtime | Namespaces por app; web efímero actual no resuelve W01 |
| `odoo_sdk/lib/src/auth/native_auth_bootstrap_web.dart` | SDK como frontera actual | Documentar unsupported; no sustituir con cookies web sin contrato |
| `theos_pos/lib/core/database/database_helper.dart` y `theos_pos_core/lib/src/database/database_helper.dart` | Apertura runtime, operaciones core | Definir una conexión dueña; evitar duplicar helpers estáticos |
| `theos_pos/lib/core/managers/manager_providers.dart` | Runtime | Un registro/binding por scope; no capturar DB anterior |
| `theos_pos/lib/core/services/platform/server_connectivity_service.dart` | Runtime sobre ServerHealthService SDK | Extraer adaptador connectivity_plus; no duplicar health/polling |
| `theos_pos/lib/features/sync/services/connectivity_sync_orchestrator.dart` | Runtime | Separar providers y manejar lease de sesión |
| `theos_pos/lib/features/sync/services/offline_sync_service.dart` y sus parts | Handlers negocio core; ejecución genérica SDK; composición runtime | Sustituir helper de app y managers globales por dependencias |
| `theos_pos/lib/features/sales/services/payment_service.dart` y subservicios | Core | Separar OdooService/provider de transporte y repositorios |
| `theos_pos/lib/features/sales/services/payment_wizard_contract.dart` y `sale_confirmation_contract.dart` | Core | Conservar validación de contrato real, no nuevas firmas inventadas |
| `theos_pos/lib/features/collection/services/session_service.dart` | Core | Eliminar dependencia del helper app; confirmar lifecycle de turno |
| `theos_pos/lib/features/authentication/services/branding_service.dart` | Descarga/datos neutrales; caché runtime; conversión visual app | Quitar Fluent de datos y separar colores de superficies |
| `theos_pos/lib/features/reports/repositories/qweb_template_repository.dart` | Core/runtime según dependencias | Reusar Drift, revisión de plantilla y assets offline |
| `odoo_widgets/lib/src/base/odoo_field_base.dart` y config | Referencia para componentes Orbi | Streams/value/callback reutilizables; widget Fluent no se importa |
| `theos_pos/lib/shared/providers/notification_provider.dart` | Fuente funcional para inbox | Son contadores; no asumir persistencia ni añadir timer paralelo |
| `theos_pos/lib/shared/widgets/credit_approval_notification.dart` | Productor de eventos + UI Orbi | Deduplicación persistente y destino autorizado |

## Método de traslado

1. Identificar API pública, consumidores y pruebas actuales de la unidad elegida.
2. Definir dueño y dependencias explícitas; mover regla sin rediseñarla a la vez.
3. Adaptar cliente actual con fachada/reexport público si hace falta.
4. Migrar pruebas que demuestran comportamiento; añadir solo casos de la nueva
   frontera (scope, error, reinicio, dependencias), no duplicar suites enteras.
5. Integrador revisa diff, contrato y consumidores antes de desbloquear tareas.

No combinar extracción de pagos con cambio de semántica contable en un mismo
encargo. Si se detecta un defecto, registrar evidencia y tarea correctiva separada.
No hacer una búsqueda/creación remota pasar por garantía única sin respaldo backend.

## Alertas para no heredar accidentalmente

- Estado mutable global de managers/DatabaseHelper/SyncNotifier: independiente
  entre procesos, pero delicado para cambio de sesión y varias ventanas internas.
- Documentación histórica de auth difiere del bootstrap nativo permitido en
  AGENTS.md; comprobar código y respetar aclaraciones actuales del dueño.
- Los tests existentes no acreditan por sí solos numeración fiscal, turno entero
  ni las seis plataformas; ver VALIDATION.md.
- Las partes `part of` de OfflineSyncService comparten estado; mover un archivo
  suelto sin entender el conjunto no crea un servicio independiente.
- El tamaño de un archivo no es medición de rendimiento. Medir consultas,
  paginación, rebuilds, memoria y tiempo de frame antes de atribuir causas.
