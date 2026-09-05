# Vendedor y cajero: referencia funcional Odoo 19.5

Fecha: 2026-09-05. Estado: implementación en curso bajo el objetivo ERP2; la paridad
de los recorridos vendedor/cajero todavía no está certificada.

## Objetivo

Extiende PROJECT_COMPLETION_V1.md: facilitar vender y cobrar sin duplicar
contabilidad ni cambiar permisos Odoo. Referencia funcional:
`/Users/elmers/Documents/dev_odoo20/addons/l10n_ec_collection_panel`.
No se exige replicar OWL ni reemplazar los servicios Flutter equivalentes.

## Punto de conexión obligatorio

Decisión del dueño (2026-09-05): `l10n_ec_collection_box_pos` es el punto de
conexión de la app. Los contratos y extensiones backend compartidos que hagan
falta se implementan ahí, reutilizando los modelos y métodos nativos de caja.

`l10n_ec_collection_panel` depende de ese módulo y amplía sus modelos/contratos
mediante herencia Odoo cuando corresponda. Su manifest ya declara la dependencia
y reconoce a `l10n_ec_collection_box_pos` como emisor único de cambios de stock.
La dependencia declarada no demuestra por sí sola que toda la lógica ya esté
extraída o compartida: hay que verificar cada contrato antes de moverlo.

- No convertir `collection.panel` en la API obligatoria de Flutter.
- Si el panel contiene lógica necesaria para ambos clientes, presentar primero
  al dueño un análisis resumido: funcionalidad, origen, destino propuesto
  (`l10n_ec_collection_box` o `l10n_ec_collection_box_pos`), motivo, riesgos y
  pruebas. No trasladarla sin su autorización específica. El panel conservaría
  su extensión de presentación/orquestación y reutilizaría lo compartido.
- Sin dependencia inversa de `l10n_ec_collection_box_pos` hacia el panel, sin
  ciclos, sin duplicar reglas financieras ni emisores de eventos.
- La app debe poder usar los contratos base sin instalar el panel. La presencia
  del panel puede ampliar capacidades, nunca conceder permisos implícitos.
- El panel es referencia para reducir pasos, no un requisito para tener venta
  y cobro sencillos. La aceptación exige ambos escenarios: instalado y ausente.

## Recorridos y aceptación

Ampliación del dueño: verificar los cuatro flujos de venta implementados en
Core, Enterprise y addons custom, además de los casos mostrador/consultiva del
panel. No confundir modalidades del negocio con los cuatro perfiles de uso de
la pantalla. Reducir clics nunca permite omitir aprobación comercial, crédito,
permisos, stock, sesión, condiciones de cobro, facturación ni despacho. La
matriz se debe derivar del código vigente y comprobar por rol; los documentos
históricos no certifican el comportamiento actual.

El dueño confirmó la matriz exacta en `../ODOO_SALES_FLOW_AUDIT.md`: crédito
puro, contado, mixto y Facturar sin Cobro. Aprobación comercial común; pedido
bloqueado al confirmar. Crédito y mixto emiten factura automáticamente al
confirmar; mixto genera despacho por acción explícita. FSC genera factura y
despacho al aprobarse, pero exige 100 % pagado para entregar. El candado final
actúa hacia Customers, no en la preparación ni el traslado a zona de salida.
No usar `is_cash` e `is_credit` como opciones excluyentes.

Rendimiento es también criterio de aceptación: medir arranque, navegación,
búsqueda y trabajo de fondo en modo profile. Las pruebas debug funcionales no
demuestran fluidez. Optimizar cargas y presentación nunca elimina los candados.

| Usuario | Recorrido principal | Límite verificable |
| --- | --- | --- |
| Vendedor sin permisos de caja | Cliente → productos → revisar → confirmar/enviar a aprobación | Sin operaciones manuales de caja; conservar autofacturación del flujo de venta. Un vendedor de campo con permisos adicionales usa las operaciones que tenga autorizadas |
| Cajero | Abrir/recuperar caja → buscar venta pendiente o venta rápida → medios de pago → cobrar/facturar → comprobante | Sesión y permisos válidos; no mostrar éxito remoto por una operación sólo en cola |
| Cajero, durante turno | Consultar cobros, anticipos, cheques, retenciones, notas de crédito, fondos, retiros y depósitos | Mostrar únicamente operaciones autorizadas y configuradas; conservar trazabilidad |
| Cajero, cierre | Revisar documentos y movimientos → contar → revisar diferencia → cerrar | Totales coherentes con Odoo; pendientes de sincronización visibles |

La acción primaria debe corresponder al rol y estado. Los errores deben indicar
qué falta y cómo resolverlo: cliente, productos, autorización, sesión o conexión.
Los escenarios se verificarán con teclado y tacto, sin asumir que ocultar un
botón protege un servicio o un atajo.

## Autoridad del backend y límites

- El grupo `group_collection_panel_user` nace vacío. No asignarlo
  automáticamente ni convertirlo en requisito nuevo para todo vendedor de la app.
  En TecnoSmart el vendedor puede necesitar el flujo Ventas, no el panel.
- Resolver autorización real y contratos de `l10n_ec_collection_box_pos`
  desplegados por servidor. No sustituir todos los RPC existentes sin comparar
  semántica, idempotencia y soporte offline.
- Respetar la configuración efectiva por compañía/punto: edición de precio,
  descuento, teclado táctil, días de pendientes, bloqueo de stock y despacho.
  No activar estas políticas globalmente por conveniencia de interfaz.
- Odoo decide permisos, impuestos, crédito, stock, facturación y despacho.
  El dueño autorizó instalaciones, ajustes y pruebas necesarios en ERP2;
  no se piden confirmaciones repetidas para pasos de ese alcance. Newerp queda
  excluido incluso de lecturas. No ampliar permisos de operadores existentes
  ni trasladar lógica entre módulos sin la decisión específica correspondiente.
- Mantener separación servidor/base/usuario y cola durable. Distinguir el
  estado operativo local del estado de sincronización: un cobro realizado o
  una factura emitida localmente no dejan de existir por carecer de ACK remoto.
  No presentarlos como ya conciliados en Odoo ni autorizados por el SRI si
  esas respuestas externas todavía no se han recibido.

## Contrato offline-first (aclaración del dueño)

Las cajas remotas y los vendedores de campo deben poder continuar su trabajo
sin servidor, no sólo guardar borradores. La app aplica los permisos y reglas
del negocio con la configuración local previamente disponible; estar offline
no equivale a omitir aprobaciones, cupo, mora ni condiciones de entrega.
La implementación de autorizaciones locales y su conciliación debe verificarse,
no sustituirse por una prohibición general de operar sin conexión.

La referencia fiscal original es
`l10n_ec_collection_box_pos/README.md`: emitir e imprimir sin conexión con punto
de emisión exclusivo, conservando número, fecha y clave al sincronizar. Para
diarios numerados por la app, online utiliza el mismo camino con sincronización
inmediata. Modo Ruta permite trabajar horas sin ejecutar sincronización aunque
haya conectividad intermitente.

Aceptación: comprobar venta/cobro/facturación local, reinicio sin pérdida,
reconexión sin duplicados y tratamiento explícito de conflictos. Un estado local
completado y un estado de sincronización pendiente pueden coexistir. Ni el panel
ni una conexión activa son requisitos implícitos para estas operaciones.

Corrección fiscal local en curso: replicar los datos del método nativo
`account.move._l10n_ec_set_authorization_number` (RUC emisor, ambiente de empresa,
fecha fiscal, serie y secuencial). La fecha original debe sobrevivir a reintentos
y regeneración. No cambiar Core ni Enterprise. La paridad del algoritmo no
certifica por sí sola asignación del diario, cobro ni los cuatro flujos completos.

Evidencia local (5 de septiembre): seis vectores calculados ejecutando los
métodos nativos sin modificarlos coinciden exactamente con Dart, incluidos los
dígitos verificadores 0, 1 y 9 y ambos ambientes. Tres pruebas del repositorio
comprueban RUC emisor/fecha/ambiente, ausencia de configuración y regeneración
con fecha histórica. La regresión ejecutó 1092 pruebas sin fallos, incluyendo
esos casos (`/tmp/theos_offline_fiscal_regression_20260905.log`). No equivale a
una validación fiscal de punta a punta contra ERP2.

Correcciones locales posteriores: sesión → punto → diario por identificador
exacto, validando empresa y configuración; sincronización de establecimiento y
punto de emisión sin reiniciar la secuencia local; factura, secuencia y cola
en una transacción. Estado pagado/parcial/no pagado derivado del importe
aplicado y retenciones locales. Pasaron 15 pruebas fiscales de app y dos de
sincronización del diario en core; estas correcciones son posteriores a la
regresión de 1092 pruebas indicada arriba.

Hallazgos aún abiertos: falta la política local de numeración exclusiva y su
aprovisionamiento. El replay actual no envía fecha/secuencial al wizard, y
encontrar una factura por pedido no acredita que el cobro esté completado.
La extensión propuesta del flujo custom Caja/POS está documentada en
`dev_odoo20/docs/especificaciones/theos-offline-fiscal/CONTRATO.md`; no se ha
desplegado ni certificado en ERP2.

## Evidencia y pendientes

1. La app ya dispone de venta rápida, cobros y pantallas de caja. Ausencia de
   llamadas a `collection.panel` demuestra falta de integración directa, no
   ausencia de todas sus funciones ni obliga a reescribirlas.
2. Corregido el handler compartido de Cobrar/F6: comprueba rol, sesión propia
   abierta y revalida después de esperas; conserva la excepción nativa de
   supervisor de caja/administrador sin sesión. No permite entrar al cobro de
   ventas pendientes/rechazadas/canceladas. Una pestaña Pagos restaurada tampoco
   muestra el contenido de caja al vendedor. La protección del servidor sigue
   siendo necesaria; estas guardas no sustituyen las ACL.
3. Contrastar `panel_bootstrap`, `panel_pendientes`, `panel_abrir` y los métodos
   de cobro con servicios existentes para identificar contratos compartidos que
   deben vivir en `l10n_ec_collection_box_pos`, no conectar Flutter directamente
   al panel. Preservar las acciones intermedias de aprobación que devuelva Odoo.
4. Lectura/persistencia de `advance_line_ids` implementada: detalle tras reinicio,
   snapshot completo atómico, IDs locales independientes y vínculo al padre tras
   replay. La actualización local v10/v11 → v12 conserva datos y cola existente
   e incorpora el caché de capacidades del punto.
5. Verificar por host configuración de stock/precios y contratos desplegados.
   ERP2 JSON-2 ahora devuelve HTTP 200 y 36130 contactos; también pasó la prueba
   real del SDK. No se ha demostrado la causa del anterior 401. `newerp` es
   producción y queda excluido incluso de consultas; los demás son de pruebas.
6. Implementado localmente `collection.config.pos_app_capabilities` en
   `l10n_ec_collection_box_pos`, con extensión por herencia desde el panel y
   resolución punto → compañía mediante el resolver existente. Incluye 13
   políticas booleanas y días de pendientes. Flutter valida y persiste el
   contrato en ambos caminos de sincronización, con nueve pruebas focales.
   ERP2 ya expone el contrato base (commit `e714324a4`, despliegue autorizado);
   JSON-2 verificó tres puntos. El panel está desinstalado y no existe en su
   árbol runtime: la respuesta base `counter_policies=null` es la esperada.
   Su instalación fue autorizada posteriormente, pero no es necesaria para
   habilitar la app. La suite completa del candidato opcional ejecutó 202
   pruebas con 26 errores; no se instaló ni se declara validado ese escenario.
   Pruebas backend: 2/2 base en una BD temporal desde `template0`, con panel
   `uninstalled`; 2/2 de la extensión con panel instalado. El harness habitual
   clona una plantilla que incluye el panel, por lo que no demuestra aislamiento.
   La BD temporal y su filestore se limpiaron tras la prueba.
   Implementado: consumo reactivo de visibilidad de Cobrar/F6, Anticipo y Salida de
   dinero para el punto propio del cajero, incluyendo rechazo de caché con
   compañía incorrecta. Todavía faltan los demás consumidores de políticas;
   no imponer las restricciones de mostrador al vendedor en modo Ventas.
   La comprobación F6 mantiene una suscripción durante la espera, de modo que
   también funciona sin el panel de acciones montado. No se eliminan operaciones
   históricas ni se concede ningún permiso por estas políticas de presentación.
7. E2E nativo en curso: almacenes de credenciales/preferencias aislados y SQLite
   temporal, sin borrar datos del operador. La restauración verifica un nuevo
   contenedor de aplicación, no reinicio del proceso ni persistencia del Keychain.
   El primer intento aislado encontró un formulario de acceso inválido antes
   del RPC. Se añadió espera de frame y comprobaciones de destino/clave sin
   imprimir secretos. Otro intento agotó la espera y mostró desbordamiento de
   un mensaje largo; no se ha demostrado una causa única de ese rechazo.
   Los mensajes largos ahora son desplazables (dos pruebas de ventana).
   La ejecución posterior pasó: **1 E2E nativo, 19 segundos**, acceso real ERP2,
   restauración de contenedor, navegación de menús/acciones permitidas y
   redirección de ruta protegida. Evidencia:
   `/tmp/theos_erp2_readonly_e2e_error_capture.log`.
   No prueba permisos de vendedor/cajero reales, operaciones contables, ni
   cierre de turno: se usó la credencial administrativa suministrada.
   Repetido después del despliegue base en ERP2: 1/1 pasado en 16 segundos,
   `/tmp/theos_erp2_post_deploy_e2e.log`. Regresión de la app actual: 1057/1057.

## Plan y estructura

1. Aplicar esta especificación con las decisiones del dueño sobre el módulo
   de conexión y el objetivo explícito de dejar funcionando y probar contra ERP2.
2. Cerrar guardas comunes de cobro y sus pruebas negativas.
3. Centralizar los contratos compartidos en `l10n_ec_collection_box_pos` y
   extenderlos desde el panel por herencia cuando corresponda. Mapearlos a
   `features/sales` y `features/collection` mediante adaptadores Flutter.
4. Simplificar recorridos sobre las pantallas existentes; no poner reglas
   financieras en widgets. Usar providers/repositorios existentes y conservar
   estilo Flutter del repositorio.
5. Cerrar anticipos y validar turno completo con perfiles vendedor/cajero.

Orden de cierre autorizado por el dueño el 5 de septiembre: **Aprobaciones →
Turno de cajero → Cuatro flujos completos en ERP2 → Con y sin panel → Rendimiento**.
Hasta tres agentes Luna en paralelo, con tareas delimitadas y resultados breves;
pueden preparar fases posteriores, no declararlas cerradas anticipadamente.
El agente principal decide contratos y escribe/revisa cambios financieros.
Sin delegación recursiva ni secretos en encargos.

### Contrato de salida: aprobaciones

- `action_pos_confirm` recorre `set_approved` y `confirm_approved_order` nativos;
  no escribe directamente la aprobación comercial ni activa bypass de crédito.
- `skip_credit_check` se conserva por compatibilidad del cliente, pero no concede
  autorización: la decisión y revalidación corresponden al flujo nativo.
- Una acción de aprobación pendiente devuelve `success=false`,
  `approval_required=true`, `action`, identidad y estado real del pedido.
  No se descarta el wizard ni se presenta la orden como confirmada.
- Éxito exige estado real de venta y bloqueo nativo. La reanudación desde
  `waiting` conserva el control de solicitudes pendientes y aprobación vigente.
- Un error controlado revierte la operación compuesta mediante savepoint;
  no quedan aprobación, firma ni asientos parciales del intento fallido.
- La app conserva y presenta la aprobación pendiente; las pruebas incluyen
  rechazo, acción pendiente, reintento y éxito con pedido bloqueado.
- La solicitud offline guarda estado local y comando de sincronización en una
  sola transacción: si falla la cola, no deja un pedido esperando una solicitud
  inexistente. Sin cola disponible devuelve fallo, no un ID de éxito ficticio.
  Tres pruebas del productor cubren fallo de escritura, cola ausente y éxito
  local; los dos defectos fueron observados en rojo antes de la corrección.

## Perfiles reales de pruebas ERP2

El dueño autorizó crear claves para `sebastian.rodriguez` (uid 43) y
`jacqueline.rizo` (uid 23). Generadas con alcance RPC y vencimiento de 12 horas,
guardadas únicamente en el llavero macOS; no se copiaron al repositorio ni se
modificaron grupos. JSON-2 `context_get` confirmó ambas identidades. Sebastián
no pertenece al grupo de caja; Jacqueline sí. La sesión abierta existente de
Jacqueline (id 13, punto 5) se conserva, no es una sesión desechable del test.
El harness admite `THEOS_E2E_EXPECTED_UID` y comprueba identidad tras acceso y
restauración para evitar un verde accidental usando al administrador.
Ambos recorridos nativos pasaron tras corregir la consulta administrativa de
grupos y adaptar el harness a la pantalla de operador: Sebastián 14 s y
Jacqueline 12 s. Regresión actual 1072/1072 y analyzer sin incidencias.
Auditoría detallada y límites: `../ODOO_SALES_FLOW_AUDIT.md`.

## Comandos y pruebas

- `make analyze` desde la raíz.
- `flutter test test/core/navigation/route_access_policy_test.dart` en theos_pos.
- Pruebas focales de cobro, permisos, cola y sesión según archivos modificados;
  suite completa de paquetes afectados al cerrar la implementación.
- Pruebas negativas: vendedor con F6; cajero sin sesión; cambio de usuario;
  doble pulsación; desconexión/reintento; aprobación rechazada; stock bloqueado.
- Backend: verificar contratos base con el panel ausente y extensiones con el
  panel instalado; mismas guardas y sin duplicar cobros ni eventos.
- E2E autorizado por servidor: venta → cobro mixto → comprobante → movimiento
  de caja → conteo/cierre; cotejar IDs y totales reales, no sólo HTTP exitoso.

No declarar terminada esta especificación por pruebas unitarias de contratos:
requiere revisar los recorridos y contrastarlos con Odoo autenticado.
