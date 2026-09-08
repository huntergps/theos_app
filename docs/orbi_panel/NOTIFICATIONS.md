# Sistema de notificaciones de Orbi ERP

## Objetivo

Conservar avisos relevantes entre reinicios, dirigir al trabajo correspondiente
y mostrarlos opcionalmente fuera de la aplicación. Tres conceptos separados:
evento de origen, entrada en la bandeja y entrega al sistema operativo.
Una notificación no es una nueva venta, pago o aprobación ni su evidencia contable.

## Orígenes y presentación predeterminada

| Evento | Bandeja | Aviso SO | Condición |
| --- | --- | --- | --- |
| Actividad asignada/vencimiento | Sí | Según preferencia | Usuario destinatario y revisión nueva |
| Aprobación requerida para supervisor | Sí | Sí, optativo | Permiso efectivo y entidad visible |
| Aprobación resuelta para solicitante | Sí | Sí, optativo | Resultado observado por sync, no inferido del envío |
| Conflicto/cola que necesita intervención | Sí | Uno agrupado | Error persistente; no por cada retry |
| Trabajo largo solicitado terminado | Sí, si útil | Optativo | No avisar por cada producto importado |
| Cobro realizado por el propio usuario | Feedback inmediato | No por defecto | Estado operativo explícito |
| Pérdida/recuperación breve de red | Indicador de conexión | No | Evitar spam y dos indicadores contradictorios |
| Recordatorio de cierre/actividad local | Sí | Programado si soportado | Fecha, zona horaria y usuario definidos |

Avisos de la sesión todavía no identificada son transitorios; no persistirlos
bajo usuario inventado. No cargar automáticamente todo el historial como avisos
nuevos en la primera sincronización: fijar watermark/baseline y mostrar pendientes
actuales sin ráfaga al SO. Preferencias por app/scope/categoría; modo silencioso.

## Modelo local propuesto

N01 crea tipos e interfaces; N02 incorpora tablas y migración en el core con
propiedad exclusiva del esquema. No se crea ningún modelo backend para esto.

`NotificationEntry`:

- `id`: UUID local; `scopeKey`; `companyId` opcional para avisos de sesión general.
- `partitionKey`: no nula, `company:<id>` o `global`; global solo para avisos que
  no revelen datos de una empresa. Validar correspondencia con companyId.
- `sourceKey`: identidad semántica estable del hecho (actividad/solicitud/cola).
- `revision`: revisión canónica del evento; no `DateTime.now()` en cada polling.
- `kind`: activity/approval/sync/system; `severity`: info/attention/error.
- `titleKey`, `bodyKey`, argumentos limitados y saneados; texto fallback opcional.
- `occurredAt`, `createdAt`, `updatedAt` UTC; `readAt`, `archivedAt`, `resolvedAt`.
- `target`: tipo permitido y referencia UUID/ID; nunca un método RPC ejecutable.
- `origin`: local/poll/futurePush; `expiresAt` opcional.

Restricción única `(scopeKey, partitionKey, sourceKey)`; revisión evita procesar de nuevo el
mismo evento. Nueva revisión relevante actualiza entrada y puede restablecer
lectura según categoría. Repetición de la misma revisión conserva read/archive.
No almacenar claves, cuerpos de RPC, datos completos del cliente ni comprobantes.

`NotificationDelivery`:

- entryId, scopeKey, revision, channel, deliveryState, attempts, nextAttemptAt.
- systemId: entero estable asignado por un registro local único por app/instalación,
  compartido por scopes y protegido frente a asignación concurrente. Mapeo
  `(scopeKey, entryId, channel) → systemId`; las revisiones conservan el mismo ID.
  No usar un contador distinto por BD de usuario ni truncar un hash sin resolver
  colisiones. Cancelar solo IDs del scope obtenidos de este registro.
- state: pending/claimed/shown/denied/unsupported/failed/cancelled.
- leaseExpiresAt para recuperar entrega interrumpida; error saneado.
- Único `(scopeKey, entryId, revision, channel)`.

`NotificationCursor`: scopeKey, partitionKey, source, cursorValue,
baselineComplete, updatedAt. Único `(scopeKey, partitionKey, source)`.
Si el origen usa write_date, conservar también desempate por ID y solapamiento
con dedupe, para no perder cambios con igual timestamp. Avanzar cursor y upsert
de entradas/entregas atómicamente. Baseline incorpora pendientes relevantes a la
bandeja pero no crea entregas SO masivas. Cursor fallido no se marca completado.

Una transacción persiste entrada y entrega. Si el origen viene de un commit de
negocio en la misma BD, insertar el evento/entrada en esa transacción o usar
outbox durable; no depender de un callback volátil después del commit. Para
polling externo, upsert con la revisión remota conocida.

## Entrega y deduplicación

1. El productor identifica evento, destinatario y revisión.
2. Persistencia idempotente de bandeja e intención de entrega.
3. Worker de sesión reclama una intención; consulta permiso/capacidades/preferencias.
4. `showOrReplace(systemId)` presenta solo si sigue siendo el scope activo.
5. Persiste resultado y conserva la bandeja aunque el SO deniegue el permiso.

La confirmación de entrega compara lease, scope y revisión: una respuesta tardía
no puede marcar como entregada una revisión nueva. Cambio de compañía filtra
bandeja y destino; avisos empresariales usan preferencias/permisos de esa compañía.

BD y SO no comparten transacción: caída después de mostrar puede causar
reentrega. El ID estable permite reemplazar donde la plataforma lo soporte.
No prometer exactamente una vez en todos los sistemas. Repetidos por polling
o rebuild sí deben quedar deduplicados persistentemente.

No contar intents pending como notificaciones entregadas. `shown` significa
petición aceptada por la API, no que una persona la haya visto/leído.

## Leer, resolver, archivar y retener

- Leer no resuelve una actividad ni aprueba una venta.
- Resolver refleja el estado del origen; archivar es preferencia de bandeja.
- Marcar leído es local a la instalación inicialmente. Sincronizar lectura entre
  dispositivos queda fuera del contrato inicial, para no inventar un modelo Odoo.
- Retener avisos sin resolver y entregas pendientes. Limpiar entradas resueltas
  y leídas de más de 90 días; aplicar límite configurable a ese subconjunto.
- Mantener watermark/cursor de origen tras limpieza para evitar reingestión del
  historial. Al rehacer catálogos, no volver a notificar todas las revisiones.
- En logout cancelar avisos y recordatorios del scope activo, detener listeners
  y reclamar/reprogramar correctamente entregas interrumpidas. No borrar datos
  operativos ni todas las notificaciones de otros scopes de la instalación.

## Pulsación y navegación

Payload mínimo: versión, identificador opaco de entrada y scope; validar formato.
Después de abrir app: restaurar sesión, comparar scope y empresa, revalidar
permiso y resolver objetivo mediante rutas internas permitidas. Si cambió usuario,
pedir acceso correspondiente sin revelar contenido previo. Si fue borrada la
entidad, mostrar aviso útil. Referencias locales se resuelven a ID remoto al sync.
Los botones iniciales son «Abrir»/«Ver detalle». No ejecutar cobrar, aprobar,
cancelar ni cerrar caja directamente desde payload/notificación del SO.

## Plataforma y segundo plano

Base investigada: `flutter_local_notifications 22.3.0`; revalidar versión resuelta.

| Plataforma | Contrato inicial |
| --- | --- |
| Android | Mostrar/programar con permisos y configuración de plataforma; restricciones de batería; no requerir alarmas exactas para avisos ordinarios |
| iOS/macOS | Permisos y opciones de presentación; programar cantidad acotada; no mantener Dart vivo para esperar novedades |
| Linux | Mostrar según servidor de notificaciones; scheduling no soportado por el plugin |
| Windows | Mostrar; verificar MSIX/package identity para cancelación/consulta; no usar periodicidad no soportada |
| Web | Permiso desde gesto del usuario, contexto seguro/setup correspondiente; scheduling/repetición no soportados |

`NotificationCapabilities` refleja show/schedule/actions/cancel/launchHandling
según plataforma/configuración, no un booleano universal. Si un SO no soporta una
función, la bandeja sigue funcionando; recordatorio se evalúa al reabrir sin
prometer puntualidad con app cerrada.

El plugin no recibe novedades de Odoo con la app cerrada. Primera etapa: eventos
que la app conoce por trabajo local o sincronización, y recordatorios previamente
programados donde se admitan. P01 debe definir backend de push, transporte por
plataforma y deduplicación compartida antes de prometer entrega remota cerrada.
No instalar Firebase ni crear cuentas/servicios por suposición.

## Verificación mínima

Mismo evento dos veces, revisión nueva, reinicio conservando lectura, recuperación
de delivery claimed, permiso denegado, scope cambiado durante show, objetivo sin
permiso/borrado, baseline sin ráfaga, cancelación aislada y capacidades no soportadas.
Pruebas reales del adaptador al menos en cada plataforma disponible; lo restante
queda explícitamente pendiente. Mock del plugin no prueba aviso visible del SO.

Fuente: https://pub.dev/packages/flutter_local_notifications (consulta 2026-09-06).
