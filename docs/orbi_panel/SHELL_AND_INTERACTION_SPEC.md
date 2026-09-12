# Orbi ERP: especificación de shell e interacción

Fecha: 2026-09-10, con el estándar del marco resuelto el 2026-09-12.
Estado: propuesta de producto y contrato visual. No declara implementación terminada,
ni inventa modelos, campos, ACL o endpoints. Las vinculaciones reales quedan pendientes.

## Principios

- El menú es la unión de las capacidades visibles para empresa, usuario, punto y
  configuración efectiva. No cambia de perfil para cambiar de área: un usuario
  multirrol conserva identidad y permisos de Odoo.
- El servidor valida cada lectura y acción. Ocultar un botón nunca sustituye una ACL,
  regla, aprobación, compañía, documento o destinatario válidos.
- La interfaz reutiliza los casos de uso y documentos de Odoo; no duplica contabilidad,
  numeración fiscal, proveedores de IA, canales ni colas.
- PIN queda limitado a capacidades de ventas. No concede Caja, Bodega, aprobaciones,
  configuración ni funciones de supervisor.

## Shell y navegación

La cabecera muestra marca Orbi, empresa, ubicación/almacén y usuario activo. En Caja
añade punto y sesión efectivos. Cambiar empresa, base, servidor o usuario invalida
el acceso visual al contexto anterior y vuelve a cargar sus capacidades. **No borra
borradores, documentos, caché persistida ni operaciones pendientes:** quedan aislados
por servidor/BD/empresa/usuario y conservan autoría. Sólo se retiran de la vista los
datos privados que no corresponden al nuevo contexto. La sincronización de operaciones
anteriores sigue el contrato autorizado, sin atribuirlas al nuevo usuario.

El menú de unión contiene:

- **Ventas:** órdenes/cotizaciones, mostrador, clientes y productos.
- **Caja:** pendientes, cartera, registros (facturas, pagos, anticipos, cheques,
  retenciones, depósitos, salidas y cruces), operaciones existentes y Mi turno.
- **Bodega:** existencias, recepciones, preparación, entregas, transferencias y conteos.
- **Envases:** dashboard, movimientos, entregas/devoluciones, tránsitos y tomas desde
  factura o toma física.
- **Aprobaciones:** pendientes e historial.
- **Sistema:** actividades, sincronización, cola/conflictos y configuración.

Éste es también el orden estable de grupos. No mostrar grupos vacíos. En escritorio
se usa barra lateral expandible; tablet horizontal puede colapsarla manteniendo
acceso a etiquetas; en vertical/teléfono, menú accesible con grupos y subopciones,
sin comprimir todas las áreas en una barra de iconos. Volver conserva el listado,
filtros, selección y posición cuando el contexto siga autorizado.

| Grupo | Regla de acceso propuesta (no nombre de ACL inventado) |
|---|---|
| Ventas | Capacidad de consultar/vender; edición, descuentos y confirmación se validan separadamente |
| Caja | Credenciales Workspace y permisos de Caja; turno/punto se comprueba por operación |
| Bodega | Permisos de inventario/despacho de Odoo; no requiere ser cajero |
| Envases | Permisos del módulo de envases y del responsable; no exige sesión de Caja |
| Aprobaciones | Sólo solicitudes y acciones que Odoo permite resolver al usuario |
| Sistema | Operación propia y preferencias; diagnóstico y administración según privilegios |

La capacidad exacta de cada subopción debe vincularse a permisos reales antes de
implementar. Administrador no significa eludir reglas comerciales. La modalidad PIN
limita las acciones aunque la persona tenga otros grupos en Workspace.

Cada entrada puede ocultarse por ausencia de capacidad, pero el estado debe distinguir
ausente, no autorizado, no configurado y temporalmente no disponible. La navegación
preserva filtros permitidos (por ejemplo, «Mis ventas»), nunca amplía el universo ACL.
El filtro «Todas» significa todas las visibles para el usuario, no acceso administrativo.

## Cabecera, pie y responsive

La cabecera persistente conserva título, contexto de empresa/ubicación e identidad.
El pie técnico es **persistente en escritorio y tablet horizontal**, no sólo diagnóstico:
servidor, BD, fecha/hora del servidor, zona horaria, conexión y sincronización separadas.
En tablet vertical/teléfono conserva un indicador compacto que abre esos mismos datos.
La última referencia recibida se identifica junto a la hora. Si está obsoleta u offline,
debe decirlo explícitamente; no presentar la hora local como fiscal ni una referencia
vieja como confirmación remota.

Formato propuesto: `Servidor: erp.demo.local | BD: orbi_demo | Hora servidor:
10/09/2026 14:32:10 UTC-05 | Conectado | 3 pendientes`. Ejemplo offline:
`Última hora recibida: 14:30:00 · Sin conexión · Referencia desactualizada`.
Si aún no se obtuvo hora, mostrar «Hora del servidor no disponible». Una estimación
que avance localmente debe rotularse como estimación; no es fecha fiscal autoritativa.
La fuente/método de hora y tolerancia de antigüedad quedan por verificar en el backend.
No exponer estos datos del servidor/BD en notificaciones del sistema o pantalla bloqueada.

La composición es wide por defecto, portrait compacto y detalle. En wide se permiten
rejillas y paneles; en portrait se usan listas, tarjetas y formularios de una columna.
No comprimir una rejilla desktop dentro de teléfono. El detalle puede abrirse como
panel o pantalla y siempre conserva volver, contexto y autoría.

## Estados y continuidad

Todo listado, tarjeta, detalle y acción contempla: `loading`, `empty`, `error`,
`forbidden` y `offline`, con texto accionable y reintento seguro cuando corresponda.
Los borradores, pestañas, dependencias, autor y empresa/punto se conservan tras
reinicio. Nunca convertir automáticamente un hecho offline completado en borrador.
Un cobro local puede estar pendiente de sincronización sin dejar de ser un cobro local.

Mostrar estado comercial y estado de sincronización por separado. Un conflicto ofrece
comparar y resolver; no borra trabajo ni crea otro documento. Después de cambiar usuario,
empresa o base, no continuar una respuesta de IA ni una acción pendiente bajo la sesión
anterior.

## Interacciones

- Teclado: orden de foco lógico, foco visible, Escape para cerrar modal y atajos sólo
  cuando no roban entradas del formulario. La búsqueda debe tener foco explícito.
- Tablas anchas Syncfusion: filtros de documentos separados de la búsqueda para añadir
  productos. **Añadir productos se busca inline en la última/nueva línea**, nunca en
  una barra exterior. En portrait, buscar dentro de la nueva tarjeta/línea editable.
  La búsqueda de un listado de documentos sí está en la cabecera del listado.
  Los campos inválidos se marcan junto a su causa.
- Cards: cada acción identifica documento, estado, actor y siguiente acción; no usar
  un booleano genérico `success` para ocultar fallos parciales.
- Scanner/resultado de impresión o reimpresión no confirma ventas ni repite pagos.
  Reintentar un envío de resultado incierto primero consulta su estado disponible.

No seleccionar/reemplazar texto automáticamente sólo por enfocarlo: edición y captura
por escáner se distinguen. Tab/Shift+Tab avanzan/retroceden; Escape cierra sugerencias
antes que el formulario; Enter selecciona una sugerencia sólo si ésta tiene foco.
Nunca confirmar un cobro por un Enter ambiguo. Atajos comerciales se inventariarán
contra theos_pos/Odoo antes de asignarlos, evitando conflictos con navegador/OS.
Guardar anchos, columnas, orden y filtros por usuario/contexto/vista; no heredar
preferencias privadas de otro usuario. Resize no pierde foco ni edición dirty.

| Estado | Comportamiento |
|---|---|
| Carga inicial | Progreso o esqueleto, mensaje si tarda y recuperación; no spinner infinito |
| Vacío | Distinguir catálogo vacío de filtro sin resultados; crear sólo con permiso |
| Error | Qué falló, qué se conservó, acción segura y detalle técnico opcional |
| Sin permiso | Volver o solicitar revisión; no CTA que el usuario no pueda ejecutar |
| Offline | Datos locales utilizables con antigüedad y límites visibles |
| Conflicto | Preservar ambas versiones y permitir sólo resoluciones autorizadas |

## Avisos y privacidad

Clasificar cada aviso como: transient (éxito breve), inline banner (contexto del
registro), modal (decisión/bloqueo) o notification center persistente (seguimiento).
| Tipo | Presentación y permanencia | Sistema operativo |
|---|---|---|
| Guardado correcto | Mensaje breve sin robar foco; no es la única evidencia del guardado | No |
| Error de campo | Texto junto al campo, persiste hasta corregir | No |
| Sin conexión/sesión expirada | Banda persistente con acción, conexión distinta de autenticación | No por defecto |
| Aprobación/pedido listo | Centro de notificaciones persistente y acceso al documento | Opcional y autorizado |
| Fallo/conflicto | Registro persistente y acción de recuperación | Según preferencia e importancia |
| Decisión necesaria | Diálogo sólo cuando requiere elección explícita; no confirmaciones repetidas | No sustituye diálogo |

En escritorio/tablet horizontal la campana abre panel lateral; vertical/teléfono
abre pantalla de actividades. Los mensajes breves no cubren el teclado ni acciones
primarias; se ubican sobre el área segura inferior o esquina libre. Se agrupan eventos
repetidos, se conserva lectura/no lectura y no se vuelve a avisar por cada rebuild.
Tiempo de mensajes informativos propuesto: 5 segundos; avisos que exigen acción no
dependen de ese plazo. Debe pausarse la desaparición durante interacción/accesibilidad.

El sistema operativo sólo recibe avisos con consentimiento del usuario. La pantalla
de bloqueo no muestra secretos, importes sensibles, tokens ni contenido privado.

Offline no promete entrega al sistema operativo cuando la app está cerrada. Cambiar
usuario es una acción segura: limpia contexto privado, conserva datos autorizados y
requiere revalidación. Un aviso local de conexión no se confunde con un mensaje externo
entregado.

Al pulsar un aviso externo: abrir Orbi, autenticar si corresponde, revalidar acceso
y abrir el documento exacto. Si pertenece a otro usuario no revelar su contenido.
Texto externo genérico predeterminado: «Tienes una actividad pendiente». Permiso OS
denegado no bloquea avisos internos. No confundir notificación local de una app activa
con push remoto: soporte web/escritorio/móvil y recepción con app cerrada se validan
por separado; no prometer un mismo mecanismo en todas las plataformas.

## Capacidades Odoo opcionales

La UI consulta capacidades efectivas después de autenticación y cambio de contexto:
instalación, configuración, autorización, documento, destinatario y transporte son
dimensiones separadas. La capacidad se revalida al ejecutar y tras cambios de módulos o
configuración. No se ofrecen sustitutos si el módulo no está instalado.

- **IA:** sólo agentes, herramientas y proveedores instalados/configurados en Odoo y
  autorizados para ese usuario. No proveedor propio, SDK, secreto ni catálogo paralelo.
- **Plantillas y canales:** reutilizar los mecanismos de Odoo para WhatsApp y Telegram.
  Telegram actualmente es texto; no anunciar PDF/adjuntos como enviados sin ampliación
  aprobada del backend.
- **Avisos externos de Odoo:** reutilizar `l10n_ec.notification.dispatcher` y sus
  resultados/candados. Los mensajes locales de formulario/guardado/conexión son UI,
  no necesitan llamar al dispatcher ni generar mensajes externos.
- **Salidas e impresión:** reutilizar la resolución por caja/compañía/informe, su orden
  y fallos. Odoo genera el trabajo; el cliente ejecuta sólo transportes compatibles.
  Distinguir generado, enviado al transporte, entregado y fallo.

Asistente: botón de cabecera sólo si la capacidad Odoo está instalada/configurada y
autorizada. Panel lateral ancho, pantalla propia vertical. Mostrar documento y empresa
consultados; contexto mínimo sin PIN, contraseña ni acceso indiscriminado a la BD.
Separar consultar, proponer y ejecutar; una propuesta no factura/cobra/confirma. La
acción sensible identifica cambios, documentos e importes antes de confirmar según
el contrato Odoo. Auditoría conserva actor, origen IA y resultado. Cambiar de usuario
retira contexto privado, respuestas tardías y permisos anteriores. Sin Odoo disponible
no hay proveedor alternativo. Configuración, costes y proveedor se gestionan en Odoo.

Véase [capacidades Odoo verificadas en fuente](ODOO_OPTIONAL_CAPABILITIES.md), que
prevalece sobre ideas anteriores de proveedores propios o envío de PDFs por Telegram.

## Referencias visuales nuevas

Ronda 03, seis versiones mostradas aprobadas el 10/09/2026:
SHELL-01 (menú/pie), ALERT-01 (avisos internos), ALERT-02 (avisos OS), CONT-01
(continuidad/interacciones), OUT-01 (salidas Odoo), AI-01 (asistente opcional).
Las imágenes de round-02 conservan su aprobación; estas láminas las complementan.
Las revisiones posteriores no heredan aprobación. Véase APPROVAL_REGISTER.md.

## Estándar resuelto del marco (12-09-2026)

Esta sección cierra las diferencias entre las 39 láminas aprobadas (33 de round-02 y 6
de round-03). El análisis y la evidencia lámina por lámina están en
`ESTANDAR_LAMINAS_2026_09_12.md`; aquí queda sólo lo que manda. **Donde una lámina
dibuje otra cosa, manda esta sección.**

| Elemento | Estándar |
| --- | --- |
| Teléfono, pantallas raíz | Barra inferior: Inicio más hasta cuatro de los seis grupos, y «Más» abre el resto. Sin hamburguesa además de la barra: son dos rutas al mismo sitio |
| Teléfono, pantallas empujadas | Sin barra inferior. Vuelta atrás, como cualquier detalle abierto desde una lista |
| Cabecera | Marca, empresa, ubicación, usuario activo y campana. En Caja se añaden punto y sesión efectivos. Nada más es obligatorio |
| Sesión | «Bloquear» y «Cambiar usuario» viven dentro del menú del avatar, no sueltos en la cabecera |
| Título | Dentro del contenido, bajo la cabecera, nunca dentro de ella. Con subtítulo de una línea. **El código de pantalla no se muestra**: es control de calidad de las láminas, no producto |
| Barra de acciones | El secundario con contorno a la izquierda, el primario relleno con el color de acento a la derecha |
| Anchos | Los del código (`OrbiTheme.compactBreakpoint` 600, `mediumBreakpoint` 840, y 1440 para el modo expandido). Los píxeles impresos en las láminas son ilustración, no especificación |
| Pie | El formato ya fijado más arriba en este mismo documento, persistente en escritorio y tableta horizontal, compacto en vertical y teléfono |
| Menú lateral | Los seis grupos de este documento —Ventas, Caja, Bodega, Envases, Aprobaciones, Sistema—, todos de primer nivel. Envases **no** cuelga de Inventario. Nada de grupos genéricos de ERP que ninguna lámina tenía por qué inventar |
| Marca | «ORBI ERP» en mayúsculas con el anillo teal |

### Color por significado

La forma del distintivo es libre: **no tiene que ser redondo** (decisión del dueño,
12-09-2026). Lo que no es libre es el color:

| Significado | Color |
| --- | --- |
| Confirmado o correcto | Verde |
| Pendiente | Ámbar |
| Error, rechazado o diferente | Rojo |
| Borrador | Gris |
| En proceso o en tránsito | Azul |

### Lo que sigue abierto

Queda uno solo.

- ~~Buscador global en la cabecera.~~ **Decidido el 12-09-2026: no lo hay.** Cada
  pantalla usa el filtro de su propio contenido. Las láminas que lo dibujan no mandan
  sobre este punto.
- **Vocabulario de los botones.** Cinco pares distintos conviven hoy sólo en Caja para
  lo que en el fondo es confirmar o cancelar. Es un glosario de textos por tipo de
  operación, no una regla de marco, y se resuelve aparte.

### Cómo se hace cumplir

Un documento se puede no leer. Lo único que vuelve esto un hecho es que la cabecera,
el pie, el título y la barra de acciones vivan en un widget de marco compartido que
toda pantalla esté obligada a usar, sin poder fabricarse el suyo. Mientras eso no esté
implementado, esta sección y la lámina correctiva `VIS01` son el mejor sustituto
disponible, y no hay que confundirlas con la solución.

## Contratos pendientes de enlazar

Antes de implementar hay que mapear cada pantalla y acción a modelos/métodos públicos
resueltos del backend, permisos efectivos, compañía/punto/sesión y estados de error.
El adaptador debe documentar qué consultas son lectura y qué acciones producen efectos;
no llamar métodos privados desde la UI. Deben verificarse los cuatro flujos comerciales,
FSC, entrega pagada, numeración, aprobaciones y replay offline según los contratos reales.

También queda pendiente definir el contrato de capacidades, invalidación de caché,
deduplicación de cola e impresión local por plataforma. La recepción con app cerrada,
push y login web/offline requieren decisiones específicas; esta especificación no los
da por resueltos.

## Criterios de aceptación

1. El menú sólo muestra la unión de permisos/capacidades efectivas y no cambia de perfil.
2. PIN nunca expone acciones fuera de ventas.
3. Wide, portrait y detalle mantienen contexto, foco, estados y siguiente acción legible.
4. Todos los estados (`loading`, `empty`, `error`, `forbidden`, `offline`) tienen salida.
5. Reinicio, cambio de sesión y conflictos preservan autoría, dependencias y hechos sin
   duplicar documentos o cobros.
6. Impresión, WhatsApp, Telegram e IA respetan configuración, permisos y módulos Odoo;
   no hay proveedor, canal, cola ni ACL paralelos.
7. Ninguna vista afirma entrega externa, aprobación o sincronización sin evidencia del
   resultado real del backend.
8. Cada binding pendiente queda trazado a un modelo/método/permiso real antes de
   considerarse implementado; la propuesta visual por sí sola no certifica paridad.
