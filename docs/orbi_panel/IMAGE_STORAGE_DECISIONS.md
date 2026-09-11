# Decisiones de almacenamiento de imágenes Orbi

Estado: decisión arquitectónica para implementar después. No es una API existente,
no modifica Odoo y no autoriza cambios de esquema. Fecha: 2026-09-10.

## Alcance y evidencia

Esta decisión cubre imágenes de producto y avatar de cliente en web, iOS/iPadOS y
otras plataformas Flutter soportadas. La auditoría [OFFLINE_CORE_TECHNICAL_AUDIT](OFFLINE_CORE_TECHNICAL_AUDIT.md)
confirma que hoy no existe puerto de imagen editable, blob durable, upload/remove,
miniatura evictable ni notificación de versión.

Hechos observados:

- `RuntimeDatabaseOwner` abre una base Drift por `AppScope`; `drift_flutter` ofrece
  la misma frontera portable para nativo y web (`orbi_runtime/lib/src/storage/`).
- `AppDatabase` ya contiene `ProductProduct.image128`, `image1920` y
  `ResPartner.avatar128`; son columnas de catálogo existentes, no prueba de que
  sean campos Odoo escribibles ni de que representen todas las variantes.
- `RuntimeMetadataStore` sólo escribe texto JSON en `sync_metadata`, sin transacción
  blob+referencia, hash, cuota ni límite de tamaño. No se usará para imágenes.
- `OfflineQueue` ya tiene `baseWriteDate`, `operationKey`, `replayPolicy` y scope
  de operación; su esquema se comparte con `odoo_offline_core`.
- `ICache`/`ITtlCache` de `odoo_sdk` es caché evictable genérica. Sus valores por
  defecto (1000 entradas y TTL de 5 minutos) no son límites ni política de imágenes.

## Decisión 1 — una fuente durable portable

La propuesta pendiente usará la base Drift del scope activo para guardar el blob
durable y su referencia tipada. El blob y la referencia se comprometen en una sola
transacción del núcleo; sólo después se publica el estado observable. La UI nunca
escribe SQL ni una ruta de archivo.

La referencia durable debe contener, como mínimo: `scopeKey`, `companyId`, modelo,
ID remoto/local del registro, campo binario confirmado, identificador estable del
blob, hash/tamaño/MIME validados, revisión remota conocida, estado de mutación y
`operationKey` si hay intención pendiente. El diseño definitivo de columnas y
versión de Drift corresponde al integrador; esta decisión no crea migración.

No se guardarán rutas absolutas, `File`/`dart:io`, URLs temporales, base64 en
`sync_metadata`, credenciales ni archivos privados en logs. En web el blob debe
sobrevivir recarga según el backend Drift configurado; si la plataforma no puede
garantizarlo, la operación no se presenta como guardada.

Estados mínimos, separados:

`absent` (servidor sin imagen), `notDownloaded`, `loading`, `available`, `error`,
`pendingUpload`, `pendingRemove`, `synced`, `rejected`, `conflict` y `ambiguous`.
Una miniatura disponible y una mutación pendiente no se colapsan en un único
“guardado”. Reinicio, cierre de pantalla y `autoDispose` no eliminan blob ni
intención pendiente.

## Decisión 2 — caché evictable separada

Las miniaturas y descargas de lectura pueden usar una capa evictable separada,
identificada por `(scopeKey, companyId, modelo, registro, campo, versión, tamaño)`.
Su expulsión, TTL, limpieza por presión de disco o logout no puede borrar un blob
durable asociado a `pendingUpload`, `pendingRemove`, conflicto o recuperación.

La caché no concede permisos: antes de leerla se valida scope/empresa/capacidad y
se rechaza una entrada de otra identidad. Una descarga deduplicada sólo actualiza
los consumidores del recurso y conserva la versión; no reconstruye toda la orden.
No se fija aquí una cuota, TTL, formato, resolución ni tamaño de imagen: los
valores existentes de `CacheConstants` no son una configuración aprobada para
imágenes. El contrato real debe suministrar esos límites antes de implementar.

## Decisión 3 — referencia Odoo y permisos efectivos

El recurso visual será tipado por modelo/campo, no por un nombre genérico como
`image_1920`. El binding debe resolver evidencia de la instancia Odoo activa:
modelo, campo binario, lectura, escritura, eliminación, MIME/tamaño y capacidades
de la operación. `unknown` no habilita la función.

La matriz inicial distingue explícitamente:

| Recurso | Registro que manda | Evidencia local observada | Regla |
| --- | --- | --- | --- |
| Producto | el `product.product` seleccionado (variante) | `ProductProduct.image128/image1920`, `productTmplId` | no redirigir a `product.template` sin binding Odoo confirmado |
| Plantilla de producto | sólo si el contrato selecciona `product.template` | relación local únicamente | no asumir que editar plantilla cambia la variante |
| Cliente | `res.partner` seleccionado | `ResPartner.avatar128` | no confundir avatar con una imagen de producto |

Que exista una columna local o un ejemplo SDK con `image_128` sólo acredita lectura
posible en ese código; no acredita escritura ni ACL/record rules. Odoo valida de
nuevo modelo, registro, campo y permiso al ejecutar. La interfaz ofrece ver,
cambiar y quitar como capacidades independientes. No se inventa endpoint, campo,
ACL, extensión de servidor ni permiso derivado del nombre de rol.

## Decisión 4 — mutación durable y cola

Para cambiar/quitar: validar archivo contra límites reales, crear blob durable y
referencia en una transacción, y publicar `pendingUpload`/`pendingRemove`. El
comando de sincronización usa la cola existente y su `operationKey`; no se crea una
segunda cola ni se trata la caché como outbox. Quitar conserva una intención de
eliminación distinta de “sin imagen” o “falló la descarga”.

Sólo se encola offline si el `CapabilitySnapshot.offlineOperations` contiene la
capacidad exacta para esa mutación y el snapshot coincide con `scopeKey`, empresa,
usuario y revisión vigentes. `sync` genérico o `canSynchronize` no bastan. Sin esa
capacidad, el blob puede conservarse como borrador local protegido, pero la UI debe
decir “requiere conexión” y no prometer una mutación offline.

El drenaje respeta lease/epoch, reintentos y reconciliación de
`OperationsSyncJob`. Fallo de disco, validación, autenticación, acceso denegado o
red no producen falso éxito. La limpieza de caché no toca propuestas; una propuesta
inrecuperable se marca error y se conserva la referencia para diagnóstico seguro.

## Decisión 5 — conflicto sin CAS inventado

No se ha acreditado un contrato CAS específico para imágenes. La decisión es exigir
comparación de revisión y escritura en una sola operación atómica del servidor
para sincronizar reemplazos sin sobrescritura silenciosa. Leer `write_date` y luego
hacer `write` en llamadas separadas NO satisface esa condición. Tampoco `fields_get`
prueba permiso efectivo sobre un registro. Si no existe esa acción, el envío automático
queda sin habilitar hasta ampliar el backend con autorización; lectura y preparación
local pueden avanzar. No simular esta garantía con reconciliación posterior.
Resultado incierto o cambio remoto conserva la propuesta como `ambiguous`/`conflict`.

La resolución debe mostrar remoto y propuesta local, permitir conservar una u otra
mediante una nueva intención validada, y registrar el resultado en la cola/conflicto
existente. Nunca se descarta silenciosamente el blob local ni se transforma un
rechazo en `synced`.

## Compuertas de implementación

Antes de código: confirmar con lectura Odoo (sin mutar servidor) campos reales por
`product.product`, `product.template` y `res.partner`; `fields_get`, ACL/record
rules efectivas, capacidades de upload/remove, límites MIME/tamaño/resolución,
revisión y comportamiento de error. Aplicar el método `stack-odoo`: investigar
antes de diseñar, respetar native-first y no tocar `newerp`.

La aceptación debe cubrir reinicio offline, blobs grandes/disco lleno, caché
evictada, doble acción, permiso revocado, respuesta tardía, cambio de empresa o
usuario, rechazo, conflicto y resultado incierto. Hasta contar con esas evidencias,
`OrbiProductImage`/`OrbiCustomerAvatar` siguen siendo nombres contractuales
propuestos, no tipos implementados.
