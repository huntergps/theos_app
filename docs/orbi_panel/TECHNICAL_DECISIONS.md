# Resolución técnica previa a implementación

Estado: decisiones de arquitectura, no cambios ejecutados en app, esquema o servidor.
Complementa y concreta las propuestas anteriores. No acredita pruebas no realizadas.

## Decisiones tomadas

| Punto | Resolución |
|---|---|
| Reactividad | La fuente observable es el almacenamiento del núcleo; los adaptadores UI se suscriben a sus commits. No añadir refresh periódico por widget ni mantener streams desconectados de la base. |
| Borrador | Un único buffer durable por scope, empresa y documento, en Drift; SharedPreferences deja de ser autoridad de edición. Migración explícita no destructiva. |
| Propiedad del estado | Núcleo: datos durables, operaciones y revisiones. Controlador de formulario: edición y validación. Widget: foco/cursor/composición. Adaptador: conexión y ciclo de vida. |
| Formularios | Mantener `reactive_forms` y Riverpod ya declarados; no agregar otro framework de formularios. Un bridge evita dos buffers editables independientes. |
| Identidad | Reutilizar AppScope/CompanyContext y lease existentes. ID local y remoto deben ser distinguibles por modelo; jamás por índice de fila. |
| Persistir vs enviar | Aplicar un campo guarda el borrador según su contrato. No encola ni confirma automáticamente una operación comercial. Sólo una acción de negocio explícita crea el comando correspondiente. |
| Estados | Resultado empresarial, persistencia local, transporte, conflicto y fiscalidad son dimensiones separadas; no mapear cualquier error a aprobación requerida. |
| Rejillas | Syncfusion es la elección fijada; no se reabre selección. Adaptador común para wide y controlador compartido con lista/tarjetas compactas. Licencia y compatibilidad son comprobaciones, no decisiones visuales. |
| Archivos | Entrada por handle/stream de bytes portable, no path obligatorio. Propuesta de imagen pendiente durable y protegida; miniaturas cacheadas pueden limpiarse sin borrar propuestas. |
| Odoo | Fachadas/acciones existentes mediante el SDK, con parámetros y resultados tipados. No copiar reglas fiscales al widget ni crear escrituras directas equivalentes. |
| Cobro | Cuatro intenciones distintas: Abonar, Guardar Abono, Cobrar y Pago Completo. Reutilizar wizard y guardas; edición local de medios no es abono registrado. |
| UI | Composición sobre Flutter/Syncfusion, tema centralizado y contratos pequeños. No modificar las bibliotecas ni crear un formulario universal para dinero/inventario. |

Detalle de persistencia y observables: [resolución local](LOCAL_STATE_DECISIONS.md).
Detalle de recursos y permisos: [resolución de imágenes](IMAGE_STORAGE_DECISIONS.md).

## Transporte y límite transaccional

No fijar una nueva ruta HTTP por comodidad. Cada adaptador usa el transporte que el
SDK y la instalación soporten y la acción pública de la fachada identificada en
[bindings](ODOO_ACTION_BINDINGS.md). Invocación de un método privado queda excluida.

Crear un wizard, escribir líneas y ejecutar su botón pueden ser varias llamadas;
su existencia no demuestra atomicidad de la secuencia completa. Conservar identidad
del proceso, resultado y estado de incertidumbre. No ejecutar el mismo cobro otra vez
por timeout. Si la fachada no ofrece consulta/dedupe atómica suficiente, esa acción
remota espera ampliación backend autorizada; el borrador puede seguir operativo.

Las capacidades offline provisionadas permiten sólo sus acciones declaradas. Un
contrato todavía incompleto no autoriza envío automático al reconectar. La falta de
red tampoco convierte toda operación en prohibida: se aplica la matriz por operación.

## Prueba de aceptación elegida

El primer recorrido usa web local y navegador real, en 1440×900, 1180×820, 820×1180
y 390×844. Se introducen datos campo por campo, comprobando foco y valor, sin simular
login por API. No usar simuladores. Ensayo con backend ficticio sólo acredita UI;
persistencia necesita reinicio real, y efectos Odoo requieren entorno aislado autorizado.

No existe configuración Playwright localizada en el inventario de archivos de este
checkout. La ruta `.spec.ts` del plan es propuesta, no evidencia de runner disponible.
Antes de QA01, verificar la herramienta de navegador disponible y fijar el runner
reproducible; no instalarlo como efecto incidental de esta documentación.

## Puertas que no se pueden cerrar sólo escribiendo

| Puerta | Evidencia necesaria | Trabajo independiente que no se detiene |
|---|---|---|
| Compilación de interfaces | Tipos/imports implementados y análisis/tests | Contratos y descomposición de tareas |
| Migración | Fixtures de borradores viejos, fallo inducido y recuperación | Diseño de campos/selección |
| Licencia Syncfusion | Licencia aplicable confirmada por titular; versión compatible comprobada | Controladores y presentación compacta |
| Permisos Odoo | Grupos, reglas y compañía del usuario en base segura | Adaptadores tipados y lectura local |
| Conflicto de imagen remoto | Acción con comparación de revisión atómica o mecanismo equivalente probado | Caché y preparación local de propuesta |
| Dedupe cobro | Reintento concurrente y timeout posterior al commit sin doble efecto | Borrador de venta y compositor |
| Envases | Entrega externa probada, no sólo cimiento/documento | Restantes áreas |

Estas puertas son verificaciones de implementación o condiciones externas, no
decisiones de arquitectura dejadas abiertas. No afirmar «todo resuelto» mientras
carezcan de evidencia.
