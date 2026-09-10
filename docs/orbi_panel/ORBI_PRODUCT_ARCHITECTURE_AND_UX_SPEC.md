# Orbi ERP — arquitectura de producto, acceso compartido y experiencia operativa

Estado: **borrador para aprobación del dueño antes de implementar**  
Fecha: 2026-09-09  
Aplicación: `theos_panel`  
Backend de integración: `l10n_ec_collection_box_pos`

## 1. Motivo de este documento

Este documento consolida en una sola fuente de verdad dos grupos de requisitos que no
deben volver a separarse:

1. la arquitectura funcional y de seguridad para Workspace, PIN, dispositivos
   compartidos y operación offline;
2. la obligación de que la interfaz y la usabilidad de `theos_panel` sean superiores a
   las de `theos_pos` en las tareas equivalentes acordadas.

Una implementación que cumple sólo el backend no está terminada. Una maqueta bonita que
no recorre los modelos, permisos y flujos reales de Odoo tampoco está terminada.

## 2. Hechos verificados en el código

Estos puntos no son propuestas:

- Orbi/Theos trabaja con `sale.order`; no usa `pos.order`.
- `l10n_ec_collection_box_pos` depende de `sale`, no de `point_of_sale`.
- El vendedor de una orden es el campo nativo `sale.order.user_id`.
- `sale.order.sale_created_user_id` ya registra al usuario que procesó o confirmó.
- `sale.order.collection_session_id` relaciona la venta con el turno de Caja.
- `sale.order.collection_user_id` deriva del cajero de ese turno.
- El cobro usa `l10n_ec_collection_box.sale.order.payment` y los wizards existentes.
- La factura y el pago contable siguen usando `account.move` y `account.payment`.
- El despacho continúa sobre `stock.picking` y las ampliaciones custom actuales.
- `collection.config` ya tiene `device_uuid`, `access_token` y cajeros autorizados.
- `l10n_ec_collection_box_pos` ya amplía `res.device` y `res.device.log`.
- El PIN de usuario existe en Odoo por la ampliación del módulo `hr`; Caja y
  `l10n_ec_collection_box_pos` no declaran actualmente una dependencia directa de `hr`.
- `theos_panel` depende de `orbi_runtime`, `theos_pos_core` y `flutter_qweb`; no depende
  de la aplicación ejecutable `theos_pos`.

### 2.1 Campos existentes y significado

| Campo | Significado que se debe conservar |
| --- | --- |
| `sale.order.user_id` | Vendedor de la orden |
| `sale.order.sale_created_user_id` | Usuario que procesó/confirmó la orden |
| `sale.order.collection_session_id` | Sesión de cobro relacionada |
| `sale.order.collection_user_id` | Cajero de esa sesión |
| `collection.session.user_id` | Responsable del turno de Caja |
| `create_uid` / `write_uid` | Auditoría estándar de Odoo |

No se crearán `seller_user_id`, `operator_user_id` ni campos equivalentes que dupliquen
estos significados.

## 3. Objetivo de producto

Construir Orbi ERP como una aplicación offline-first para ventas, Caja, Bodega,
Supervisión y Administración, utilizable en equipos personales y compartidos.

El resultado debe:

- reducir el tiempo necesario para vender y cobrar;
- atribuir cada venta al vendedor real;
- preservar los candados comerciales, contables, fiscales y de entrega;
- permitir continuidad operativa sin servidor;
- mostrar todas las capacidades de un usuario sin obligarlo a cambiar de perfil;
- funcionar con o sin `l10n_ec_collection_panel`;
- superar el acabado, claridad y eficiencia de `theos_pos`.

## 4. Arquitectura técnica

```text
┌─────────────────────────────────────────────────────────┐
│ theos_panel                                             │
│ Material 3, navegación, formularios y workspaces Orbi  │
└──────────────────────────┬──────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────┐
│ orbi_runtime                                           │
│ Sesión, scope, capacidades, conectividad, cola, avisos  │
│ y coordinación de casos de uso                         │
└──────────────────────────┬──────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────┐
│ theos_pos_core                                         │
│ Modelos Odoo, Drift, persistencia y reglas extraídas   │
└──────────────┬───────────────────────────┬──────────────┘
               │                           │
┌──────────────▼────────────┐   ┌──────────▼─────────────┐
│ odoo_sdk                 │   │ flutter_qweb           │
│ JSON-2, errores, sync,   │   │ Documentos QWeb y      │
│ bus y transporte         │   │ render offline         │
└──────────────┬────────────┘   └────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────┐
│ Odoo 19.5 + l10n_ec_collection_box_pos                │
│ sale.order, Caja, facturas, pagos y despachos reales   │
└─────────────────────────────────────────────────────────┘
```

### 4.1 Responsabilidades

| Paquete | Debe poseer | No debe poseer |
| --- | --- | --- |
| `theos_panel` | UI Material, rutas, composición y recursos Orbi | Reglas contables duplicadas, segundo motor de sync |
| `orbi_runtime` | Sesión, scope, credenciales seguras, capacidades y orquestación | Tema, widgets o reglas fiscales copiadas |
| `theos_pos_core` | Modelos, Drift, persistencia y reglas de negocio compartidas | Navegación, Riverpod de pantalla o UI |
| `odoo_sdk` | JSON-2, transporte, retry, eventos y primitivas de cola | Reglas específicas de la venta ecuatoriana |
| `flutter_qweb` | Interpretación y generación de documentos | Cobros, permisos o aprobación comercial |
| `l10n_ec_collection_box_pos` | Contrato entre las apps y los modelos existentes de Odoo | Una contabilidad o POS paralelo |

`theos_pos` puede consultarse y aportar código extraído, pero ambas aplicaciones siguen
siendo independientes. Una modificación de `theos_panel` no debe cambiar el ejecutable ni
la interfaz vigente de `theos_pos`.

## 5. Circuito empresarial real

```text
sale.order
├── sale.order.line
├── aprobación comercial
├── término de pago
├── l10n_ec_collection_box.sale.order.payment
├── wizard existente de cobro
├── account.payment
├── account.move
└── stock.picking
```

No se introduce `pos.order` en ninguna capa.

## 6. Formas de acceso

### 6.1 Workspace

Workspace es el entorno completo de un usuario autenticado con sus credenciales. Está
disponible para vendedores, cajeros, bodegueros, supervisores y administradores.

- La aplicación carga la unión de todos sus grupos efectivos de Odoo.
- No existe un selector de rol o perfil excluyente.
- Los destinos y acciones se filtran por capacidades reales.
- Ocultar una acción en Flutter no sustituye la validación en Odoo.

Ejemplos de prioridad, sin convertirlos en perfiles rígidos:

| Usuario | Funciones esperadas por sus permisos actuales |
| --- | --- |
| Carlos Guajala | Ventas |
| Jacqueline Rizo | Caja y Cobros |
| Miguel | Bodega y Despachos |
| Erik/admin | Unión de Administración, Supervisión, Ventas, Caja y Bodega |

### 6.2 PIN de vendedor

PIN es un acceso rápido exclusivo a Ventas desde un dispositivo autorizado.

- Identifica a un `res.users` vendedor existente.
- Abre directamente la experiencia de Ventas.
- Asigna el vendedor mediante `sale.order.user_id`.
- No activa Caja, Bodega, Administración ni Supervisión.
- No presenta selector ni lista de operadores recientes.
- Cambiar vendedor consiste en bloquear la superficie de venta e introducir otro PIN.
- Un vendedor también puede optar por entrar mediante Workspace.

El mecanismo de entrada impone un techo de capacidades:

```text
PIN       → como máximo, capacidades de vendedor
Workspace → unión de todos los grupos efectivos del usuario
```

Por tanto, un vendedor que también es supervisor:

- con PIN sólo vende;
- con Workspace vende y supervisa.

## 7. Modalidad por dispositivo

La modalidad no es una propiedad global exclusiva de la empresa. Una empresa puede tener
simultáneamente equipos personales y compartidos.

| Modalidad | PIN vendedor | Workspace | Ejemplo |
| --- | ---: | ---: | --- |
| Personal | No es la entrada predeterminada | Sí | Teléfono de vendedor de campo |
| Compartido | Sí | Sí | Computador de mostrador usado por varios vendedores |
| Híbrido | Sí | Sí | iPad o portátil utilizado de ambas maneras |
| Operativo | No | Sí | Caja, Bodega o Administración |

La empresa define una política predeterminada. La ubicación y el dispositivo pueden
ajustarla. La persistencia exacta de esa política debe resolverse ampliando modelos
existentes; este documento no inventa todavía nombres de campos.

## 8. Enrolamiento y confianza del dispositivo

Un administrador enrola el dispositivo una vez. El enrolamiento relaciona de forma
revocable:

- servidor y base de datos;
- empresa y ubicación;
- modalidad de uso;
- identidad del dispositivo;
- vigencia y estado de autorización.

`device_uuid` identifica el equipo, pero no debe ser el único secreto porque es copiable.
La credencial privada debe vivir en Keychain, Keystore o almacén seguro equivalente.

Debe ser posible:

- revocar un dispositivo sin desactivar usuarios;
- revocar un usuario sin borrar el dispositivo;
- trasladar un dispositivo de ubicación de manera autorizada;
- distinguir “bloquear operador”, “cerrar Workspace” y “desautorizar dispositivo”.

## 9. Identidad al ejecutar operaciones

Una credencial técnica de dispositivo no puede quedar como autor de todas las ventas.
Cuando una operación originada por PIN llega al servidor:

1. el servidor valida la autorización del dispositivo;
2. valida el PIN o la prueba de identidad provisionada;
3. confirma que el usuario puede vender en esa empresa/ubicación;
4. limita el contrato disponible al conjunto de acciones de vendedor;
5. procesa la venta bajo el usuario validado;
6. deja que los campos existentes registren vendedor, procesador y auditoría.

No se debe aceptar un `user_id` enviado libremente por Flutter como prueba suficiente de
identidad. Tampoco se debe usar un API key de administrador compartido para atribuir
ventas.

## 10. Offline-first

El modo offline permite continuar trabajando normalmente con la última configuración
válida; no convierte todo en borradores ni exige que Odoo esté disponible para declarar
que una operación local ocurrió.

### 10.1 Datos provisionados

Según la modalidad y permisos del dispositivo, se almacenan de forma segura:

- vendedores autorizados y prueba local de PIN;
- compañía, ubicación y alcance del dispositivo;
- capacidades y versión de la política;
- productos, clientes, precios, impuestos y términos de pago;
- reglas de crédito, mora y aprobación;
- configuración de Caja y secuencias fiscales cuando corresponda.

### 10.2 Estados separados

```text
Estado empresarial:
cotización / confirmada / facturada / cobrada / preparada / entregada

Estado técnico:
local / pendiente / sincronizando / sincronizada / conflicto
```

Una venta o cobro puede estar completado localmente y seguir pendiente de sincronización.
La UI debe mostrar ambos estados sin reinterpretar el hecho empresarial.

### 10.3 Reglas de persistencia

- Operación local y outbox se guardan atómicamente cuando comparten base Drift.
- Cada operación usa UUID/idempotencia y conserva dependencias.
- Cambiar usuario detiene listeners y timers del scope anterior antes de activar el nuevo.
- Una respuesta tardía del usuario anterior no puede alterar la pantalla actual.
- Reiniciar la app conserva borrador, cola, identidad atribuida y contexto permitido.
- Un conflicto se presenta para resolución; no se borra para conseguir una prueba verde.

### 10.4 Fuente de verdad y trabajo offline

Odoo conserva la fuente de verdad de términos, cupo, mora, saldos y procesos de
inventario. Orbi utiliza la última información provisionada mientras no hay conexión y
revalida o concilia con Odoo al recuperarla. No distribuye presupuestos paralelos de
crédito, saldo o stock por dispositivo.

La política de existencias depende de la operación configurada por cada empresa. En venta
de mostrador puede facturarse lo que el cliente presenta físicamente; una diferencia con
la existencia registrada genera la revisión correspondiente por un responsable en Odoo,
sin inventar en Flutter una reserva universal ni un segundo kardex.

### 10.5 Identidad y numeración offline existente

Orbi reutilizará el mecanismo ya implementado por `theos_pos` y sus paquetes compartidos:

- un pedido offline usa UUID, ID local negativo y nombre provisional; Odoo asigna el
  nombre comercial definitivo al sincronizar;
- una factura offline sólo se numera localmente usando el diario de la sesión de Caja
  configurado en Odoo y marcado `numbered_by_client`;
- establecimiento, punto de emisión, ambiente, RUC de la empresa y fecha fiscal proceden
  de la configuración provisionada, no de valores supuestos por Flutter;
- número, fecha, clave de acceso y UUID se guardan atómicamente con la factura y su
  operación pendiente;
- reintentar, reiniciar, mostrar o reimprimir conserva la misma identidad fiscal y nunca
  consume otro secuencial;
- el UUID correlaciona e impide repeticiones, pero no sustituye al número fiscal;
- pagos y anticipos conservan sus mecanismos actuales; no se crea una secuencia o tabla
  paralela de recibos.

`theos_pos` no reserva bloques de secuenciales por dispositivo. El máximo conocido en la
base local evita retroceder dentro de esa instalación, pero no demuestra exclusividad
entre dos equipos desconectados que compartan el mismo punto de emisión. La habilitación,
reemplazo o traslado de un equipo debe verificar en Odoo la propiedad y continuidad del
punto configurado. Una colisión nunca se resuelve renumerando silenciosamente un documento
ya emitido.

## 11. Flujos comerciales invariables

La aprobación comercial ocurre antes de confirmar y confirmar bloquea el pedido. La
clasificación depende del término de pago; `is_cash_sale` no clasifica estos flujos.

| Flujo | Factura | Despacho | Control |
| --- | --- | --- | --- |
| Crédito puro | Al confirmar | Al confirmar | Cupo y mora antes de confirmar |
| Contado puro | Al cobrar | Al cobrar en Caja | Cobro requerido |
| Mixto | Al confirmar | Acción “Generar Despacho” | Lo vencido a la fecha |
| Contado con FSC | Al aprobar FSC | Al aprobar FSC | 100 % pagado para entregar |

FSC adelanta factura y despacho, no autoriza entregar sin cobrar. La preparación de
Bodega puede avanzar; el candado final se aplica al movimiento hacia Customers.

## 12. Calidad visual: `theos_pos` es el piso

`theos_panel` no se acepta sólo porque compile o porque llegue a los modelos correctos.
Para una tarea equivalente debe conservar como mínimo su cobertura funcional y demostrar
una experiencia superior a `theos_pos` en las tareas prioritarias acordadas, considerando:

- cantidad de pasos;
- tiempo para comenzar y completar la tarea;
- jerarquía visual;
- densidad útil de información;
- claridad de la siguiente acción;
- respuesta de teclado, ratón y tacto;
- adaptación al tamaño de ventana;
- recuperación después de error, reinicio u operación offline.

No se copiará cada pantalla porque los públicos y funciones difieren. Antes de construir
cada workspace se inventariarán los patrones equivalentes de `theos_pos`: información
visible, controles persistentes, número de pasos, estados y atajos. Se conserva lo bueno,
se elimina fricción y se mejora el acabado.

### 12.1 Rechazo visual inmediato

Una pantalla se rechaza si:

- parece una maqueta o una galería de componentes;
- deja áreas enormes vacías sin intención operativa;
- presenta tarjetas gigantes para poca información;
- oculta la acción primaria o el contexto del usuario;
- requiere más pasos que `theos_pos` sin una razón de seguridad o negocio;
- sólo se ve bien en un tamaño;
- pierde foco, texto o borrador durante rebuild/resize;
- usa un spinner infinito sin estado ni salida;
- muestra una pantalla negra en arranque o navegación;
- tiene overflow, solapamientos o texto crítico truncado.

## 13. Sistema visual Orbi

- Material 3 oficial; no Fluent UI.
- Logo, nombre e imágenes de Orbi ERP.
- El tema visual de Odoo proporciona el color de acento/semilla.
- Material conserva la generación coherente de superficies claras y oscuras.
- No se tiñen manualmente todas las superficies con el color de la empresa.
- Tokens únicos de color, tipografía, espaciado, radio, elevación y movimiento.
- Escala espacial basada en 4 px.
- Targets táctiles de al menos 48 px.
- Estados semánticos expresados con texto/icono además de color.
- Movimiento breve, útil, interrumpible y compatible con reduced motion.

Los componentes compartidos incluyen como mínimo:

- shell y navegación adaptativa;
- encabezado contextual;
- indicador online/offline/sync;
- botón y bandeja de notificaciones;
- campos y formularios reactivos;
- tablas/listas y lista-detalle;
- barras de acción persistentes;
- estados loading, empty, error, offline y conflict;
- diálogo/panel adaptativo;
- confirmación de acciones destructivas.

## 14. Diseño adaptativo

El layout se decide por el ancho disponible, no por detectar el tipo de dispositivo ni
por orientación.

| Clase | Ancho | Navegación y composición |
| --- | ---: | --- |
| Compacta | `< 600` | Barra inferior, una columna, diálogos fullscreen |
| Media | `600–839` | Rail compacto, dos paneles cuando cada uno conserva ancho útil |
| Expandida | `>= 840` | Navegación completa y composición lista-detalle; un tercer panel sólo si conserva anchos útiles |

Debe soportar retrato, paisaje, ventanas redimensionables y entrada por tacto, ratón,
trackpad y teclado.

Los cortes son orientativos. La composición real usa el ancho y alto disponibles después
de navegación, safe areas, teclado y escala de texto. `>= 840` no obliga a presentar tres
columnas.

Ejemplo para Ventas:

```text
Compacta:  catálogo → pedido → resumen/pago
Media:     catálogo | pedido y resumen
Expandida: catálogo | líneas | cliente, totales y acciones
```

El contenido cambia de composición; no se encoge proporcionalmente toda la pantalla.

## 15. Experiencia por área

### 15.1 Login, PIN y cambio de usuario

- Splash visible y breve, sin pantalla negra.
- Transición suave Splash → Login/PIN.
- Servidor, base y usuario se restauran; contraseña sólo cuando el usuario autorizó
  guardarla en almacén seguro.
- Equipo compartido entra directamente a PIN y ofrece “Entrar al Workspace”.
- Equipo personal entra a Workspace.
- Equipo híbrido ofrece ambas rutas con jerarquía clara.
- El primer campo útil recibe foco y permite escribir inmediatamente.
- Tocar un campo coloca o selecciona correctamente el texto existente.
- Cambiar servidor restaura los datos asociados a ese perfil sin mezclarlos.

### 15.2 Ventas

Prioridades operativas sobre el mismo `sale.order`:

- mostrador permite escanear, buscar y agregar productos primero cuando las reglas
  vigentes no requieren antes el contexto del cliente;
- consultiva prioriza cliente y condiciones cuando determinan precios, crédito o
  seguimiento;
- ninguna prioridad es una secuencia obligatoria: cliente y productos permanecen
  accesibles en ambas presentaciones;
- antes de confirmar, la venta cumple todos los datos, aprobaciones y candados existentes.

Requisitos:

- PIN lleva directamente a una venta lista para operar.
- “Mis ventas” está activo por defecto para vendedor y se puede retirar.
- “Todas” significa todas las visibles por ACL/record rules, no acceso administrativo.
- Cliente, término de pago, vendedor, almacén, totales y próximo bloqueo son visibles en
  el momento oportuno.
- La acción primaria permanece alcanzable sin recorrer una pantalla desproporcionada.
- La cantidad admite entrada directa y decimal según la unidad; vender 24 unidades no
  exige 23 pulsaciones y vender 1,5 no se redondea por la interfaz.
- Repetir un producto acumula o crea otra línea según unidad, precio y condiciones; nunca
  se ignora silenciosamente.
- Cambiar cliente, lista o término recalcula mediante las reglas existentes y muestra los
  cambios relevantes sin conservar precios incompatibles ni borrar ediciones permitidas.
- Un vendedor mantiene varias ventas suspendidas y recuperables. Cambiar PIN no
  transfiere borradores; una transferencia es explícita, autorizada y auditable.
- La aprobación regresa al mismo pedido y muestra resolución y siguiente acción sin
  confirmar automáticamente, robar foco o sobrescribir cambios pendientes.
- La cotización puede verse, imprimirse, compartirse y recuperarse por referencia o QR.
  La referencia identifica el pedido; no concede permisos ni autoriza operaciones.

### 15.3 Caja

Debe priorizar:

- punto y turno efectivo;
- pendientes por cobrar o facturar;
- cliente, documento y total;
- método de pago;
- efectivo entregado y vuelto;
- acción Cobrar.

Cada borrador de cobro pertenece a un documento y una cajera concretos. Cambiar la venta
seleccionada o la usuaria no arrastra importes, anticipos, notas de crédito ni referencias.
Antes de registrar se pueden editar o retirar medios; después se utiliza el procedimiento
existente de reversión o corrección.

El resultado del cobro es persistente y recuperable. Imprimir, compartir o reimprimir un
comprobante nunca vuelve a registrar el pago. Un fallo de impresión es distinto de un
fallo financiero.

La jornada diferencia sin turno, apertura nueva, recuperación propia, turno pausado,
punto ocupado, falta de asignación y error de consulta. Un fallo de red no demuestra que
el turno no exista ni autoriza crear otro automáticamente. El cierre incluye arqueo,
diferencias, incidencias y operaciones locales pendientes según el proceso existente.

Retenciones, anticipos, notas de crédito, salidas y depósitos permanecen disponibles sin
saturar el cobro principal. Los wizards y modelos existentes siguen siendo la fuente de
verdad.

### 15.4 Bodega

Debe priorizar:

- por preparar;
- preparado/listo para entregar;
- bloqueos de pago;
- responsable y ubicación;
- próxima acción permitida.

Preparar no se bloquea por pago. Entregar al cliente sí respeta el candado correspondiente.

### 15.5 Supervisión y administración

Las aprobaciones, excepciones y controles se incorporan a la misma navegación del usuario.
No se exige cambiar de perfil. Una aprobación debe mostrar objeto, motivo, consecuencias y
responsable antes de confirmar.

### 15.6 Mejoras aceptadas de la revisión multidisciplinaria

Estas decisiones forman parte del alcance; no quedan pendientes de aprobación conceptual:

- shell operativo persistente basado en la unión de capacidades, sin selector de rol;
- unidad de trabajo coherente para pedido, cobro, despacho, aprobación y turno;
- cliente visible e identificador real tratados como una sola entidad;
- múltiples borradores aislados por servidor, base, empresa y vendedor;
- handoffs sin transcripción entre Ventas, Caja, Aprobaciones y Bodega cuando existe un
  medio real de comunicación;
- resultado y comprobante persistentes, separados de la impresión;
- listas con cliente, referencia, fecha, vendedor, total, estado y próxima acción para
  reconocer documentos sin abrirlos uno por uno;
- diagnóstico exportable sin secretos, con operación, fase, último resultado y acción
  recomendada;
- política de retención y espacio para equipos compartidos por muchos vendedores;
- validación con personas reales además de revisiones expertas simuladas.

Un cambio entre usuarios conserva autoría y cola originales, pero no obliga a volver a
entrar repetidamente con cada usuario anterior para sincronizar. El coordinador puede
continuar enviando operaciones según su contrato sin reasignarlas ni exponer el trabajo
privado en la pantalla del usuario actual.

## 16. Reactividad y rendimiento

- Riverpod posee estado de pantalla y operación; no el buffer editable del formulario.
- `reactive_forms` posee valores dirty/touched y validación de entrada.
- Drift posee el estado persistido y observable.
- Un refresh remoto no sobrescribe silenciosamente campos dirty.
- No se crean providers, controladores ni `FormGroup` dentro de `build` si ello reinicia
  entrada o foco.
- Providers observan fragmentos pequeños para evitar reconstruir pantallas completas.
- El teclado y la escritura no deben parpadear ni retrasarse durante sincronización.
- Cargas, sync y notificaciones no bloquean navegación o edición.
- Cambiar ancho conserva ruta, pedido, scroll, foco y contenido del formulario.
- La lectura local se compone aunque el cliente remoto no esté disponible; la red habilita
  actualización y sincronización, no el acceso a datos ya provisionados.
- Cada catálogo mantiene cursor, cobertura y error propios; descargar una página no
  equivale a completar el catálogo.
- Una migración nunca recrea ni borra ventas, cobros, borradores, documentos u operaciones
  pendientes para recuperar compatibilidad.

## 17. Integración Odoo autorizable

La integración se implementará en `l10n_ec_collection_box_pos`, reutilizando modelos y
métodos actuales.

Puede requerir, por herencia de modelos existentes:

- enrolamiento/revocación de dispositivo;
- modalidad y alcance del dispositivo;
- consulta de vendedores autorizados;
- validación de PIN;
- entrega de capacidades/políticas para uso offline;
- sincronización de operaciones bajo el vendedor validado.

Antes de añadir cualquier campo se debe demostrar que no existe en Core, Enterprise o
addons custom. No se crea una tabla nueva para ventas, cobros, recibos o dispositivos si
un modelo existente cubre el hecho.

`l10n_ec_collection_panel` puede ampliar el contrato opcionalmente, pero
`l10n_ec_collection_box_pos` no debe depender de Panel.

## 18. Compatibilidad del PIN con y sin `hr`

La aplicación debe ofrecer PIN de vendedor aunque la empresa no instale Recursos Humanos.
Para ello, `l10n_ec_collection_box_pos` ampliará `res.users` y declarará el campo `pin` con
el mismo nombre y tipo base que utiliza Odoo. No se creará una tabla ni un modelo paralelo,
ni se modificará Core.

Odoo 19.5 fusiona las declaraciones homónimas de un campo durante la construcción del
registro ORM. Por eso, instalar `hr` posteriormente no crea un segundo `res.users.pin` ni
elimina el contrato público del campo.

Existe, sin embargo, una transición de almacenamiento que debe tratarse expresamente:

- sin `hr`, el PIN definido por Caja reside en `res.users`;
- con `hr`, la declaración nativa de `res.users.pin` es calculada e inversa y delega el
  valor real en `hr.employee.pin`;
- por tanto, al instalar `hr` no basta con que la columna anterior sobreviva: los PIN ya
  configurados deben trasladarse al empleado vinculado para que el valor visible y
  validado no cambie.

La compatibilidad se resolverá sin dependencia obligatoria de `hr`:

1. el módulo base de Caja aporta `res.users.pin` cuando `hr` no existe;
2. un puente técnico auto-instalable, dependiente de Caja y `hr`, migra de forma
   idempotente los PIN existentes a `hr.employee.pin` cuando ambos están instalados;
3. desde ese momento se reutiliza el comportamiento nativo de `hr` como fuente de verdad;
4. el API de Orbi conserva el mismo contrato y nunca expone ni confía en un `user_id`
   enviado libremente por Flutter.

Antes de implementarlo se verificará el orden real de instalación y actualización con una
prueba de módulo: Caja sin `hr`, PIN configurado, instalación posterior de `hr`, migración
y autenticación con el mismo PIN.

## 19. Estrategia de construcción

### Fase 0 — línea base

- Inventariar flujos y pantallas equivalentes de `theos_pos`.
- Medir pasos y registrar capturas compacta/media/expandida.
- Congelar los criterios comparativos antes de diseñar.

### Fase 1 — sistema visual y acceso

- Tema Orbi, shell, navegación, Splash, Workspace y PIN.
- Prototipo operable con foco, teclado, touch y resize.
- Revisión visual antes de multiplicar pantallas.

### Fase 2 — Ventas vertical completa

- Lista, filtros, edición, confirmación, estados y offline.
- Los cuatro flujos recorridos sobre `sale.order`.
- Comparación directa con `theos_pos`.

### Fase 3 — Caja vertical completa

- Turno, pendientes, cobro y operaciones complementarias.
- Reutilización de wizards/modelos actuales.

### Fase 4 — Bodega, Supervisión y Administración

- Despachos, entrega, aprobaciones, excepciones y navegación combinada.

### Fase 5 — cierre multiplataforma

- Evidencia por plataforma realmente ejecutada.
- Rendimiento profile/release.
- Recuperación offline y sincronización posterior.

La validación completa se paga una vez por fase vertical, no por cada ajuste visual
pequeño.

### 19.1 Proceso obligatorio de diseño y wireframes

Orbi no dependerá de Figma ni de una licencia de diseño. El proceso de producto será
gratuito, reproducible y versionado junto con el código. Antes de implementar cada fase
vertical se producirán estos artefactos:

1. flujo de tarea con actor, objetivo, decisiones, candados y resultado esperado;
2. wireframe anotado con prioridad de contenido, acciones, comportamiento responsive,
   accesibilidad y estados alternos;
3. galería Flutter local con datos ficticios y componentes interactivos;
4. ejecución en Flutter Web para validar tamaños, teclado, ratón y touch;
5. capturas comparables en la matriz visual definida en la sección 20.2;
6. revisión por Arquitectura, UX y los usuarios operativos afectados;
7. aprobación del concepto antes de convertirlo en funcionalidad de producción.

Los prototipos no usarán ERP2 ni escribirán en Odoo. Trabajarán con fixtures que incluyan
datos realistas, textos largos, varias líneas, importes, errores y estados offline. Deben
ser claramente separables de las rutas y servicios productivos y poder descartarse sin
arrastrar lógica falsa a la aplicación.

La fidelidad se elegirá según la decisión que se necesite tomar:

| Nivel | Uso obligatorio |
| --- | --- |
| Flujo o boceto | Comparar alternativas de navegación y secuencia de trabajo |
| Wireframe anotado | Acordar jerarquía, densidad, estados y adaptación por tamaño |
| Prototipo Flutter | Validar interacción, foco, entrada, resize y continuidad de tarea |
| Pantalla terminada | Validar sistema visual, rendimiento, accesibilidad y E2E real |

No se acepta una colección de pantallas aisladas como diseño completo. Cada propuesta
debe cubrir una tarea de principio a fin, incluyendo carga, vacío, datos, error, offline,
sincronización, conflicto, reintento y confirmación persistente cuando correspondan.

### 19.2 Referencias de calidad operativa

`theos_pos` y el Panel de Cobros existente son referencias funcionales y de velocidad,
no plantillas que deban copiarse literalmente. Para escritorio y tablet amplia se debe
conservar o mejorar:

- barra persistente de operaciones frecuentes;
- trabajo con varias órdenes sin perder contexto;
- resumen compacto de cliente, crédito, vencido, disponible, anticipos y vendedor;
- búsqueda de productos con código, existencia, precio y costo según permisos;
- líneas, observaciones, totales y acción principal visibles durante la operación;
- cobro contextual con abonos, múltiples medios, denominaciones rápidas y vuelto;
- densidad suficiente para operar sin abrir ventanas innecesarias.

La referencia observada incluye además comportamientos que deben aparecer expresamente en
los wireframes de Caja:

- listado de pendientes con búsqueda por orden, cliente o vendedor, filtros de alcance y
  acceso directo a nueva orden;
- filas reconocibles sin abrir el documento: orden, cliente, cantidad de ítems, término de
  pago, vendedor, fecha, estado y total;
- acceso visible al turno y a sus acumulados de órdenes, facturas, pagos, anticipos,
  cheques, salidas, retenciones y cruces;
- varias órdenes abiertas como unidades independientes, sin mezclar cliente, líneas,
  pagos ni autoría;
- orden de otro vendedor cobrable pero protegida contra edición cuando corresponda;
- validación de existencia presentada con código, producto, disponible, solicitado y
  faltante cuando el proceso vigente lo exija, conservando el pedido para que el
  responsable resuelva el caso en Odoo;
- diálogo de cobro que mantenga visibles total, pagado, pendiente, entregado y vuelto;
- medios de pago y operaciones relacionadas dentro del mismo contexto: pago, anticipo,
  nota de crédito, retención y cruce de cuentas;
- denominaciones rápidas, registro de uno o varios abonos, eliminación controlada de una
  línea y acciones inequívocas para guardar abono, cobrar o completar pago;
- confirmación persistente del resultado para evitar que cerrar un diálogo deje al cajero
  sin saber si el cobro se registró.

Estos elementos describen capacidades y resultados, no una obligación de copiar tamaños,
colores o distribución del Panel web. Orbi puede reorganizarlos y mejorar legibilidad,
contraste y objetivos táctiles sin ocultar información crítica. Los pasos se evalúan por
tarea: una confirmación justificada puede mejorar seguridad, tiempo total o prevención de
errores. Debe evitarse la fricción innecesaria y demostrarse el beneficio comparativo.

Una captura de bloqueo por existencia demuestra ese caso, no una regla universal que
Flutter deba añadir. Se verificará el comportamiento y configuración vigentes en Odoo,
incluido el caso de mostrador con mercadería física cuya diferencia de inventario resuelve
un responsable. La aplicación no impondrá ni omitirá controles por deducción de una imagen.

En teléfono y tablet compacta esa información se reorganiza por prioridad y por tarea;
no se reduce simplemente el diseño de escritorio hasta volverlo ilegible. La mejora de
Orbi debe demostrarse en rapidez, claridad, recuperación y prevención de errores, sin
eliminar información necesaria ni saltar controles de Odoo.

### 19.3 Skill de diseño específico de Orbi

Antes de iniciar la fase de diseño y desarrollo visual se instalará, adaptará y versionará
en el proyecto el skill `orbi-wireframes`. No se instala durante esta definición para no
confundir una decisión de arquitectura con el inicio de la construcción. Podrá apoyarse
en técnicas genéricas de especificación de wireframes, estrategia de prototipos, diagramas
de flujo, evaluación heurística, crítica de densidad y QA de diseño, pero sus reglas de
dominio prevalecerán.

El skill exigirá como mínimo:

- partir de este documento y del comportamiento verificado en Odoo, `theos_pos` y Panel;
- no inventar modelos, campos, permisos, saldos, cupos, stock ni secuencias;
- diseñar unidades de trabajo completas y no sólo superficies decorativas;
- anotar actor, intención, datos visibles, acción principal, consecuencias y recuperación;
- incluir online, offline, sincronización, conflicto y cambio de usuario cuando aplique;
- generar variantes compacta, media y expandida con contenido equivalente;
- reutilizar Material 3 y los componentes aprobados, sin introducir otro framework visual;
- comparar cada alternativa con las tareas equivalentes existentes;
- someter el resultado a revisión de cajero, vendedor, UX y Arquitectura;
- impedir que una maqueta aprobada se interprete como autorización para cambiar backend o
  desplegar en ERP2.

Penpot o Excalidraw podrán utilizarse opcionalmente para colaboración manual y diagramas.
La fuente verificable para interacción y responsive será la galería Flutter ejecutada en
web. Canva queda reservado para comunicación o infografías, no para validar una interfaz
operativa.

## 20. Pruebas y evidencia

### 20.1 Comandos base Flutter

```bash
cd /Users/elmers/Documents/develop/2026/theos_app/theos_panel
flutter pub get
flutter analyze
flutter test
flutter test integration_test -d chrome
```

Las pruebas E2E deben introducir datos en los campos y recorrer la pantalla real; no se
acepta un harness que escriba todo en el primer campo o permanezca en “Test starting…”.

La validación incluye actualización con datos y outbox pendientes, reinicio offline,
cambio A→B→A en un equipo compartido y continuidad de número/clave fiscal. Los manifests
y permisos se comprueban en builds release por plataforma; un build debug no acredita la
configuración distribuida.

### 20.2 Matriz visual web obligatoria

Cada propuesta estática de pantalla o recorrido debe presentarse en cuatro vistas
identificadas: desktop, iPad horizontal, iPad vertical y teléfono. No basta una tablet
genérica ni se considera revisada una orientación por haber aprobado la otra. La
composición debe adaptarse conservando contexto, acciones y legibilidad, sin encoger
proporcionalmente el escritorio. Esta obligación también aplica a las variantes todavía
no mostradas de pantallas cuyo diseño base ya fue aprobado. Los temas claro y oscuro
siguen formando parte de la revisión.

La matriz siguiente es una base de ejecución; se añade obligatoriamente el viewport de
iPad horizontal de 1180 × 820, además del vertical de 820 × 1180.

| Tamaño | Tema | Entrada |
| --- | --- | --- |
| 390 × 844 | claro y oscuro | touch/teclado |
| 820 × 1180 | claro y oscuro | touch/teclado |
| 1440 × 900 | claro y oscuro | ratón/teclado |

Por cada fase se comprueban además loading, empty, error, offline, syncing y conflict.
Las tareas prioritarias se prueban posteriormente con vendedores y cajeros reales; las
revisiones de agentes o personajes no sustituyen evidencia de uso.

### 20.3 Backend

Las pruebas Odoo se ejecutan sólo cuando exista un cambio backend autorizado, primero en
local y por tarea. ERP2 requiere despliegue/autorización expresa para esa fase. `newerp`
no se toca.

## 21. Criterios de aceptación funcional

- [ ] No existe ninguna operación sobre `pos.order`.
- [ ] Un vendedor puede entrar mediante Workspace.
- [ ] Un vendedor autorizado puede entrar con PIN en un dispositivo compartido.
- [ ] Un vendedor-supervisor con PIN solamente puede vender.
- [ ] El mismo usuario por Workspace obtiene Ventas y Supervisión.
- [ ] `sale.order.user_id` contiene al vendedor correcto.
- [ ] `sale_created_user_id` no queda atribuido a una cuenta técnica por error.
- [ ] Caja y Bodega requieren Workspace.
- [ ] Un administrador ve simultáneamente todos sus destinos autorizados.
- [ ] Cambiar vendedor no requiere reenrolar el dispositivo.
- [ ] La aplicación funciona sin `l10n_ec_collection_panel`.
- [ ] Los cuatro flujos preservan aprobación, cupo, mora, facturación, cobro y entrega.
- [ ] Offline conserva estado empresarial, atribución y outbox después de reiniciar.
- [ ] No se crean tablas o campos que dupliquen hechos existentes.

## 22. Criterios de aceptación de interfaz y usabilidad

- [ ] Cada flujo equivalente conserva la cobertura funcional y los candados de
      `theos_pos`; las tareas prioritarias demuestran mejora en tiempo, errores,
      recuperación y claridad, además de pasos.
- [ ] PIN abre una superficie de Venta inmediatamente operable.
- [ ] La acción siguiente es evidente sin leer documentación.
- [ ] La pantalla aprovecha el espacio sin saturación ni vacío excesivo.
- [ ] Compacta, media y expandida no tienen overflow, solapamiento ni CTA oculta.
- [ ] La escritura mantiene foco y responde sin parpadeo.
- [ ] Touch, ratón, trackpad y teclado completan los flujos principales.
- [ ] Resize, cambio de tema y sync no pierden pedido, formulario, foco ni scroll.
- [ ] Splash, Login/PIN y primera pantalla tienen transición fluida, sin negro.
- [ ] Estados offline/sync/error son visibles, accionables y no bloquean trabajo permitido.
- [ ] Tema claro y oscuro mantienen contraste y superficies Material coherentes.
- [ ] La comparación funcional y visual con datos equivalentes demuestra superioridad en
      las tareas prioritarias acordadas, no sólo una apariencia diferente.

## 23. Límites

### Siempre

- Investigar Core, Enterprise y addons custom antes de diseñar backend.
- Reutilizar contratos, modelos, wizards y campos existentes.
- Implementar por fases verticales utilizables.
- Probar el camino real del usuario y conservar evidencia.
- Mantener `theos_pos` funcional e independiente.

### Requiere autorización específica

- Añadir o cambiar campos/modelos en addons Odoo.
- Cambiar dependencias de manifests, incluida una dependencia de `hr`.
- Trasladar lógica desde Panel hacia Caja/POS.
- Desplegar o actualizar módulos en ERP2.
- Añadir dependencias Flutter compartidas o cambiar esquema Drift.

### Nunca

- Modificar Odoo Core o Enterprise.
- Tocar `newerp` sin aprobación independiente de producción.
- Introducir `pos.order` en este circuito.
- Crear contabilidad, cobros o vendedor paralelos.
- Confiar autorización a botones ocultos en Flutter.
- Guardar contraseñas, PIN, API keys o tokens en código, logs o evidencias.
- Declarar terminado basándose sólo en compilación, HTTP 200 o pruebas parciales.

## 24. Definición de terminado

Orbi se considera terminado cuando la fase acordada:

1. recorre los modelos y métodos reales de Odoo;
2. conserva los invariantes comerciales y de seguridad;
3. funciona online y offline según la política provisionada;
4. atribuye correctamente vendedor, cajero, aprobador y responsable de entrega usando
   los campos existentes;
5. conserva paridad funcional en el alcance equivalente y demuestra una experiencia
   superior en las tareas prioritarias acordadas;
6. supera la revisión visual en los tres tamaños y ambos temas;
7. pasa las pruebas correspondientes y el recorrido E2E real;
8. queda documentada y en un commit reproducible.

## 25. Supuestos explícitos que no deben convertirse en código todavía

- La forma persistente exacta de la modalidad del dispositivo aún debe diseñarse contra
  los campos resueltos de `res.device`, `res.device.log` y `collection.config`.
- La compatibilidad propuesta de `res.users.pin` con `hr` está decidida conceptualmente,
  pero sigue pendiente de la prueba de instalación posterior, migración y autenticación
  descrita en la sección 18.
- La política de expiración del aprovisionamiento offline debe acordarse con el riesgo
  operativo; no se fija aquí un plazo arbitrario.
- No se crearán presupuestos por dispositivo para cupo, mora, saldos o stock. Cualquier
  dato local es la última representación provisionada de Odoo y conserva su fecha/estado.
- Las ampliaciones backend descritas son propuesta de alcance, no autorización para
  modificar o desplegar módulos.

## 26. Requisitos aceptados para calidad enterprise y superioridad operativa

Los siguientes ocho puntos son requisitos aceptados. Sus contratos, métricas y evidencias
deben concretarse por fase; su inclusión no significa que ya estén implementados ni
verificados. El detalle se resolverá contra los procesos existentes, sin inventar reglas
empresariales, campos o circuitos paralelos.

### 26.1 Matriz de cobertura operativa

Se construirá una matriz de tareas equivalentes de `theos_pos` y Panel que incluya vender,
suspender, recuperar, aprobar, cobrar parcialmente, aplicar anticipos, corregir, devolver,
imprimir y cerrar turno. Cada tarea tendrá actor, permisos, precondiciones, recorrido,
modelos/métodos existentes, resultado esperado y evidencia de aceptación. Las diferencias
de público o alcance se justificarán expresamente; no se presume equivalencia entre todas
las pantallas.

### 26.2 Contrato offline por operación

Cada tarea declarará los datos y configuración que necesita provisionados, lo que puede
completar localmente, su comprobante, persistencia, dependencias y continuación al
sincronizar. Debe cubrir reinicio, cambio de usuario y conexión intermitente, manteniendo
separados el hecho empresarial y su estado técnico. Offline permite trabajo real conforme
a la política vigente, no convierte automáticamente todas las operaciones en borradores.

### 26.3 Conflictos y recuperación verificables

Se especificarán los casos de dos equipos cobrando la misma deuda, modificando el mismo
pedido o aplicando un mismo anticipo; cambios de precios o permisos; y respuesta perdida
después de que Odoo procesó una operación. Cada caso tendrá detección, explicación al
usuario, responsable, procedimiento de resolución y conservación de evidencia.

La idempotencia de una operación evita repetirla, pero no resuelve por sí sola dos
operaciones diferentes que compiten sobre el mismo saldo o documento. Ningún conflicto
puede resolverse borrando silenciosamente un hecho local o reasignando su autoría.

Caso obligatorio: Jacqueline registra un cobro, Odoo lo procesa, se pierde la respuesta y
la app se reinicia. La recuperación debe reconocer el resultado y permitir recuperar el
comprobante sin duplicar el pago. El caso de dos equipos desconectados recibiendo dinero
para la misma factura requiere su propio procedimiento empresarial, basado en Odoo.

### 26.4 Continuidad entre dispositivos

Se definirá cómo una venta creada en un equipo llega a Caja cuando falta internet: medio
de comunicación disponible, contenido transferido, identidad del documento, autorización,
confirmación de recepción y prevención de duplicados. Dos bases locales desconectadas no
comparten datos automáticamente. Una referencia o QR que sólo identifica el pedido no
equivale a transferir su contenido. La solución concreta se verificará antes de prometer
ese recorrido como operativo, conservando atribución y candados existentes.

### 26.5 Dirección visual y recorridos aprobados

Antes de multiplicar pantallas se aprobarán tres recorridos completos: venta rápida de
mostrador, venta consultiva y cobro completo. Incluirán datos realistas, ambos temas,
variantes responsive y acceso combinado de usuarios con varios roles.

Los wireframes validarán estructura; después, ejemplos visuales terminados fijarán
densidad, tipografía, tablas, formularios, búsqueda, atajos, diálogos y mensajes. Los agentes
implementarán con esos ejemplos y componentes compartidos como referencia común. Una
galería genérica o un conjunto de pantallas con estilos independientes no satisface esta
compuerta.

### 26.6 Objetivos de rendimiento medibles

Antes de implementar cada fase se fijarán objetivos para arranque, respuesta al escribir
y escanear, búsqueda local, apertura de pedido y registro local del cobro. También se
medirán memoria, almacenamiento y consumo en reposo y durante sincronización.

Los objetivos se basarán en la línea base de `theos_pos`, equipos representativos y
volúmenes reales de catálogos, documentos y operaciones pendientes. Se documentarán
condiciones de medición, distribución de tiempos y valores límite; una demostración con
catálogo vacío o un único tiempo favorable no acredita rendimiento operativo.

### 26.7 Operación, soporte y mensajes útiles

Se diseñarán instalación inicial, aprovisionamiento, actualización con ventas pendientes,
recuperación de equipo, gestión de espacio y diagnóstico exportable. La recuperación
declarará qué información puede recuperarse y desde qué copia disponible, especialmente
cuando existan operaciones que todavía no llegaron al servidor.

Cada incidencia debe permitir entender qué ocurrió, qué quedó guardado y cómo continuar.
Ejemplos: «Cobro guardado en este equipo; pendiente de enviar» y «No se pudo imprimir;
puedes reimprimir». Los mensajes deben corresponder a estados comprobados. «Error de
sincronización» sin contexto ni acción no basta. El detalle técnico queda accesible para
soporte sin exigir al vendedor comprender colas o bases de datos ni exponer secretos.

### 26.8 Comparación y aceptación con usuarios

Las mismas tareas prioritarias se ejecutarán en `theos_pos` y Orbi con datos, equipos y
condiciones comparables. Se medirán tiempo, errores, pasos y recuperación, y se observará
a vendedores y cajeros reales. La superioridad exige resultados en operación y acabado
visual; no se deduce de compilar, cambiar el tema o reducir el número de botones.

El orden de concreción será: matriz operativa y casos offline; tres recorridos visuales
aprobados; objetivos y comparación verificable; implementación por fases verticales.
Cada fase conservará trazabilidad entre requisito, diseño aprobado y evidencia real.

## 27. Menú, contexto global, avisos e integraciones opcionales

La definición transversal se consolida en
[SHELL_AND_INTERACTION_SPEC.md](SHELL_AND_INTERACTION_SPEC.md): orden y subopciones
del menú multirrol, límites PIN, cabecera, pie servidor/BD/fecha-hora del servidor,
avisos dentro/fuera de Orbi, estados, continuidad, teclado, foco y preferencias.
Es parte de esta propuesta, no una implementación ni aprobación automática de imágenes.

[ODOO_OPTIONAL_CAPABILITIES.md](ODOO_OPTIONAL_CAPABILITIES.md) registra las piezas
existentes revisadas y la decisión del dueño: IA, impresión, WhatsApp y Telegram
reutilizan los módulos instalados/configurados y permisos de Odoo. Sin la capacidad
en Odoo no se ofrece en Orbi. Queda descartado un proveedor IA o canal paralelo.

Las ampliaciones visuales SHELL-01, ALERT-01, ALERT-02, CONT-01, OUT-01 y AI-01
constituyen la ronda 03, cuyas seis versiones mostradas fueron aprobadas el
10/09/2026 (APPROVAL_REGISTER.md). Revisiones posteriores requieren aprobación.
No alteran los originales
aprobados de round-02. Consultar VISUAL_COVERAGE.md y APPROVAL_REGISTER.md para
estado vigente; dibujar un flujo no acredita sus bindings ni su ejecución real.

## 28. Expediente de cierre previo a implementación

[DESIGN_HANDOFF.md](DESIGN_HANDOFF.md) consolida las revisiones paralelas visual,
de interacción y de contratos Odoo/offline, sus límites de evidencia y los pendientes
identificados. Las especificaciones nuevas complementan las imágenes aprobadas;
no autorizan modificar la app ni Odoo ni declaran pruebas ejecutadas.
