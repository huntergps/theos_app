# Especificación de producto

## Objetivo y alcance

Crear Orbi ERP (`theos_panel`) para vendedores, cajeros y supervisores de empresas
que usan Odoo. El público es general; la legibilidad es calidad del producto, no
una adaptación a una discapacidad del dueño. `theos_pos` puede consultarse y
aportar código extraído; sigue siendo una aplicación independiente y funcional.

El usuario conserva la marca y logo Orbi ERP. La estructura técnica existente
permanece en la raíz del monorepo; no migrar ahora a `apps/` y `packages/` ni
renombrar paquetes para conseguir únicamente una nueva apariencia.

## Requisitos de salida

1. Instalación, navegación y trabajo en las seis plataformas indicadas.
2. Login, cambio de servidor/base/usuario, restauración y desconexión explícita.
3. Catálogos locales reactivos: clientes, productos, impuestos, precios, términos,
   almacenes y configuración de caja/tarjetas/bancos según contrato real.
4. Venta consultiva y mostrador usando los mismos casos de uso y reglas.
5. Cuatro flujos completos, aprobaciones, cobros y documentos trazables.
6. Turno de caja: apertura/recuperación, cobros, anticipos, retenciones, notas de
   crédito, salidas, depósitos, conteo y cierre según permisos/configuración.
7. Trabajo offline operativo, reinicio y reconciliación sin duplicar hechos.
8. Bandeja de notificaciones persistente y avisos del sistema optativos.
9. Uso con y sin `l10n_ec_collection_panel`; conexión contractual por
   `l10n_ec_collection_box_pos` y modelos/métodos existentes.
10. Apariencia propia, adaptable, reactiva y medida en profile/release.

## Flujos comerciales invariables

La aprobación comercial precede a la confirmación; confirmar bloquea el pedido.
La clasificación proviene del término de pago. Contado y crédito pueden coexistir.
No usar `is_cash_sale` heredado ni crear un selector de tipo de venta persistido.

| Flujo | Factura | Nacimiento de despacho | Candado |
| --- | --- | --- | --- |
| Crédito puro: cuotas a plazo | Al confirmar | Al confirmar | Cupo y mora antes de confirmar |
| Contado puro: cuota a 0 días, sin plazo | Al cobrar | Al cobrar en Caja | Cobro requerido por el flujo |
| Mixto: contado y crédito | Al confirmar | Acción «Generar despacho» | Lo vencido a la fecha |
| Contado con Facturar sin Cobro aprobado | Al aprobar FSC | Al aprobar FSC | 100 % pagado para entregar |

FSC adelanta factura y despacho, no autoriza entrega impagada. El control final
está en el movimiento hacia Customers. Preparación y traslado a salida no deben
confundirse con entrega. Mostrar lo ocurrido y la acción pendiente, no solo un
booleano `success`. El backend custom vigente es la referencia de ejecución.

## Roles y filtros

- Vendedor: «Mis ventas» activo por defecto, removible; «Todas» significa todas
  las visibles por sus ACL/reglas, no acceso administrativo.
- Cajero: punto y turno efectivos, pendientes por cobrar/facturar y acciones
  permitidas. No filtrar únicamente por su autoría como vendedor.
- Supervisor: aprobaciones y excepciones explícitamente autorizadas.
- Permisos efectivos y disponibilidad operativa son datos separados de la
  preferencia de presentación. Ocultar un botón no protege el servicio.
- Mostrar motivo accionable si falta configuración, permiso o aprobación.

## Offline-first

Dos estados independientes: operación de negocio local y sincronización remota.
Un cobro local completado puede estar pendiente de sincronizar. Nunca convertir
todo trabajo offline en borrador por conveniencia técnica ni inventar permiso
de aprobación. Aplicar reglas y autorizaciones locales documentadas, provisionadas
y asociadas al usuario/empresa/punto; probar después su conciliación.

Persistir operación y outbox en una transacción cuando pertenecen a la misma BD.
Conservar UUID, dependencias, numeración/fecha fiscal y correlación tras reinicio.
La autorización SRI es un estado externo distinto de la emisión local.
Modo Ruta suspende sincronización automática sin bloquear las operaciones
offline habilitadas ni apagar físicamente Wi-Fi.

La primera instalación requiere aprovisionar identidad, permisos y catálogos.
El reinicio offline de web necesita diseño explícito: su almacenamiento y
credenciales no tienen las mismas garantías que una instalación nativa.

## Límites y decisiones ordinarias

**Siempre:** preservar trabajo del usuario, contratos de Odoo, pruebas de reglas
extraídas y aislamiento de sesiones; usar imports públicos de paquetes; conservar
capacidad offline. Cada cambio compartido identifica sus consumidores afectados.

**Permitido por este encargo de preparación:** definir estructura, contratos,
dependencias propuestas, backlog y criterios. La construcción posterior sigue
las tareas; esta preparación no autoriza por sí sola publicar en tiendas.

**Requiere decisión específica del dueño:** traslados de reglas entre addons,
ampliaciones de permisos de operadores, cambios al contrato backend para web/push,
servicios comerciales/cuentas nuevas, publicación externa.

**Nunca:** modificar Odoo core/Enterprise; tocar `newerp`; duplicar contabilidad
en tablas backend nuevas; guardar secretos en código, encargos o evidencias;
activar WebSocket/push suponiendo que ya están disponibles; borrar colas para
lograr pruebas verdes; declarar seis plataformas probadas tras ejecutar una.

## Pendientes que no se disfrazan de resueltos

- `W01`: login web con usuario/contraseña y restauración offline. El bootstrap
  actual del SDK rechaza web. Investigar contrato viable; si necesita backend,
  presentar propuesta acotada. Login con clave en memoria puede ser un hito
  técnico, pero no certifica la experiencia final de acceso simple/offline web.
- `B01`: contrastar fiscalidad offline, numeración exclusiva, aprobaciones
  locales y replay con backend actual; documentos históricos no certifican.
- `P01`: recepción remota con app cerrada requiere arquitectura push y entrega
  por plataforma; fuera de la primera implementación local de notificaciones.
- `L01`: confirmar licencia Syncfusion existente antes de distribuir componentes.

`W01` y `B01` bloquean afirmar paridad completa, no el catálogo visual ni otras
tareas independientes. No introducir sustitutos inseguros para cerrar esos puntos.
