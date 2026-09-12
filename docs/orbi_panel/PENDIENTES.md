# Pendientes vivos de Orbi

Este archivo existe porque las cosas se estaban perdiendo en la conversación. Lo
que no está aquí, no está comprometido con nadie. Se actualiza en cuanto algo
entra o sale, no al final de la sesión.

Última actualización: 2026-09-12, noche. Orbi web en su propio dominio para todos los clientes; arreglos de pantalla en curso.

## Esperan una decisión del dueño

Cuando aparezca una nueva se pone aquí antes de seguir trabajando en lo que dependa de
ella. Hasta el 12-sep-2026 esta sección decía «ninguna» con cinco abiertas, y una ni
siquiera estaba anotada.

- **¿Hay otro cliente que use la conexión en vivo con la sesión en la dirección?** Es la
  mitad del parche del despachador de `l10n_ec_collection_box_pos` (`models/ir_http.py`),
  que **pidió el dueño** en nov-2025 y que no se toca sin él. Revisado el 12-sep-2026: la
  parte de cabeceras es fiel al núcleo que corre en ERP2. La de la conexión en vivo acepta
  el identificador de sesión en la URL, que acaba en los registros, y el propio parche
  escribe parte en el log. Además se salta comprobaciones que el núcleo sí hace al elegir
  sesión y base, y fabrica con el superusuario el token de una sesión que no lo tiene.
  **Ninguna de las dos apps de este repositorio la usa.** Si nadie más la usa, se puede
  quitar.
- **Encender `base.enable_programmatic_api_keys`.** Sin él, cerrar sesión no puede revocar
  en el servidor la clave de quien no es administrador, y cada acceso deja la suya viva
  hasta que caduca. Encenderlo da a cualquier clave del usuario poder de emitir y revocar
  sus propias claves.
- **Las cuatro cuentas de prueba con `12345` y el origen abierto a `*`.** Cambiarlas y
  cerrar la lista de orígenes antes de publicar nada (ver defectos).
- **La bodega de tránsito única de Mepriga con el 49,5 % del inventario** (ver la sección
  de envases).
- **Cambiar la clave de los conectores de Velneo en Mepriga.** Está escrita en su sitio de
  Apache, es muy débil, y esos conectores atacan bases en producción.

## Resueltas, para que no se vuelvan a preguntar

- 🟢 **La pantalla de acceso por PIN ya tiene puerta**: el botón «Modo vendedor (PIN)»
  de la pantalla de acceso la abre (`login-pin-mode-button` en `login_screen.dart`).
  Estaba anotada como inalcanzable.
- 🟢 **Orbi ya no usa Material: es `fluent_ui` entero** (12-sep-2026), por
  decisión del dueño que revocó mi recomendación contraria. Cero importaciones de
  Material en las 94 fuentes, y el tema viejo borrado en vez de dejado por si
  acaso. El marco, el listado y el formulario son ahora piezas compartidas y
  obligatorias, así que ninguna pantalla se fabrica su cabecera. El acento sale
  del color exacto que usa Odoo en esta instalación, leído de su módulo de tema.
  Compuertas en verde: 242 pruebas de runtime, 653 de aplicación, 1.152 de la
  aplicación madura.
  - **Lo que más costó no fue convertir, fue lo que apareció al hacerlo.** En
    pantalla estrecha **no había forma de abrir el menú** y la persona quedaba
    encerrada; el listado compartido **no enseñaba ni una fila**; el botón de
    Excel **no producía ningún fichero**; los once mapeos de catálogo se rompían
    porque Odoo manda `false` en un texto vacío; y avisos se rendía antes de
    tocar la red. Ninguno lo cazó una prueba: todos salieron **abriendo la
    aplicación**.
- 🟢 **Los «5 con error» del pie, explicados y arreglados** (12-sep-2026). No eran
  permisos ni el dominio de origen, que eran mis dos hipótesis, y las dos cayeron con
  medición. Eran **cuatro catálogos pidiendo al servidor cosas que no tiene**, desde el
  único commit que escribió los catorce descriptores de una vez **sin comprobar ninguno
  contra un servidor**.
  - Dos pedían el modelo con el nombre equivocado: les faltaba la palabra «credit».
    Lo que hizo sobrevivir el error once meses es que un tercer modelo hermano,
    los lotes de tarjeta, **sí va sin esa palabra**: el propio addon de Odoo los nombra
    de dos formas distintas.
  - Dos pedían **campos que nunca existieron en ninguna versión**: el símbolo de moneda
    en la sesión de caja, que se resuelve desde la moneda y no es un campo del registro;
    y días y porcentaje en los plazos de tarjeta, cuyo modelo real expresa el plazo en
    **meses**.
  - El redondeo de la unidad de medida sí existió y se retiró en las series nuevas de
    Odoo. El lector local ya traía su propio valor por defecto.
  - **El doble de la prueba devolvía una lista vacía ante un modelo que no reconocía**,
    y por eso daba verde mientras el cliente pedía un modelo inexistente. Ahora falla y
    dice cuál.
  - 🟢 **La vigilancia nueva es lo que más vale**: una prueba recorre los catorce contra
    un Odoo real y falla nombrando el modelo o el campo que el servidor rechaza. Corrida
    contra ERP2: **catorce de catorce**. Se salta sola sin credenciales.
- **D6 — No se construye ninguna ruta propia para listar las bases.** No hace falta:
  medido el 12-sep-2026 desde un origen ajeno de verdad (no localhost), la ruta estándar
  de Odoo ya responde **200 con exactamente una base**, la de esa instancia, y el
  preflight trae las dos cabeceras necesarias, el origen y `X-Odoo-Database`. El acceso
  con usuario y contraseña también funciona desde ese origen y devuelve credencial con
  caducidad. Tres de tres.
  - ⚠️ **Se midió el servidor, no la aplicación.** Fue con peticiones directas, sin
    pasar por ningún build de Flutter. Ayer el cliente web tenía un fallo propio que
    hacía **cero peticiones**, así que «el servidor deja pasar» no es «la aplicación lo
    aprovecha». Falta la comprobación en un navegador real servido desde otro puerto.
  - 🔴 **El origen permitido es `*`, cualquiera.** Sumado a que el listado de bases es
    anónimo y a que las cuatro cuentas de prueba tienen `12345`, ERP2 hoy es una puerta
    abierta. Es aceptable en pruebas y **no** es aceptable al publicar.
  - **En producción esto no va a funcionar igual, y está bien.** Allí el listado de
    bases está apagado a propósito, así que la aplicación caerá a escribir el nombre de
    la base a mano. Esa salida ya existe en el código (`server_manager_dialog.dart`), y
    es lo correcto: enumerar bases sin autenticar no debe normalizarse.
- **D5 — La aplicación web se sirve desde CUALQUIER dominio, incluido localhost.**
  Decisión del dueño, 12-sep-2026. Descarta la opción de atarla al propio dominio del
  Odoo, que era la cómoda. Consecuencia: el origen cruzado deja de ser un rodeo y pasa
  a ser **requisito permanente**, así que el listado de bases y el acceso tienen que
  funcionar desde fuera o la decisión no se cumple. En medición.
- **D7 — No hay buscador global en la cabecera.** Decisión del dueño, 12-sep-2026.
  Cada pantalla conserva el filtro de su propio contenido. Se ahorra la ruta nueva de
  servidor que habría exigido cruzar módulos. Ya está escrito en
  `SHELL_AND_INTERACTION_SPEC.md`.
- **D3 — El despliegue web actual se retira.** Decisión del dueño, 12-sep-2026. Nunca
  pudo hablar con un Odoo, así que no se marca como no funcional: se quita.
- **D2 — Sí a la restricción de unicidad, y va dentro de `l10n_ec_collection_box_pos`.**
  Decisión del dueño, 12-sep-2026. **Escrito el mismo día**, commit `34f03c98e` de
  `dev_odoo20`, rama `master`, sin subir todavía. Índice único parcial sobre
  `(company_id, btrim(l10n_ec_pos_client_op_uuid))`, pre-migración que rechaza la
  actualización nombrando los conflictos, y cinco pruebas nuevas.
  🟢 **Verificado en rojo antes que en verde**, en tres pasadas sobre una base
  desechable: verde con el índice (5 de 5, y la migración corrió sola desde la versión
  anterior); **rojo al borrar el índice por SQL** —exactamente las dos pruebas que
  dependen de él, con `UniqueViolation not raised`, y las otras tres verdes porque no
  dependen de la restricción—; y verde otra vez al recrearlo. El índice existe de verdad
  en la base, confirmado leyendo `pg_indexes`, con las condiciones parciales declaradas.
  🟢 **Subido y desplegado en ERP2** el 12-sep-2026 por orden del dueño. La
  pre-migración corrió y dejó dicho en el registro que no hay operaciones con dos
  facturas vivas; el índice `account_move_pos_client_op_uuid_unique` **existe en la base
  de verdad**, comprobado consultándola; el módulo quedó instalado en `19.1.4`; y el
  servicio volvió a levantar sin un solo error, respondiendo el acceso, el listado de
  bases desde un origen ajeno y la ruta de Orbi.
  - Las dos cosas que lo hacían viable ya existían: el cliente **ya manda** un
    identificador estable, persistido antes de imprimir, así que no hay que tocar la
    aplicación; y el addon ya tenía el patrón de índice y de pre-migración a copiar.
    `account.move` era la única identidad offline sin restricción, justo el documento
    fiscal.
  - **El fallo real no era el que yo pensaba.** No es que el índice no cubriera los
    vacíos: es que **no había índice en absoluto**. La idempotencia era buscar antes de
    crear, sin lock de fila, y bajo READ COMMITTED el reintento no ve la transacción
    original todavía abierta. Cuanto más lento el servidor, más probable el duplicado.
  - Remedido en ERP2 el 12-sep: **cero conflictos** sobre 674 facturas vivas, así que el
    índice se crea sin limpiar nada.
- **D4 — No era una pregunta abierta; estaba cerrada desde el 12-sep y yo la dejé en la
  tabla por error.** `flutter_secure_storage` **ya es** el paquete universal que el
  dueño pedía: una sola interfaz que por debajo usa el llavero en Apple, el gestor de
  credenciales en Windows, el servicio de secretos en Linux, el almacén de claves en
  Android y el navegador en web. El bloqueo de macOS era la firma, no el paquete, y ya
  está arreglado. El envoltorio cifrado que se construyó por el camino se queda sólo
  como respaldo de Linux sin escritorio, que es el único hueco real. Ver
  `decisions/C01-credencial-en-archivo-cifrado.md`.
- **El marco de las 39 láminas está estandarizado** (12-sep-2026,
  `ESTANDAR_LAMINAS_2026_09_12.md`). Se buscaron los choques elemento por elemento y
  salieron **siete**, todos resueltos con mayoría medida, con el contrato ya escrito
  o con una decisión previa del mismo día: teléfono, barra superior, título, anchos,
  logo, vocabulario de acciones y agrupación del menú. **Dos que parecían choques no
  lo eran**: el pie técnico y los colores de estado, donde las láminas resultaron más
  coherentes de lo que se sospechaba. El teléfono deja de ser pregunta del dueño:
  separando pantallas raíz de pantallas empujadas, **catorce de quince raíces ya
  dibujaban barra inferior**, que es justo lo decidido esa mañana. Queda una sola
  pregunta nueva, `D7`.
- **D1 — El listado de bases en ERP2 está encendido** desde el 12-sep-2026. Se
  cambió `list_db` en el archivo propio de esa instancia y se reinició solo su
  servicio. Devuelve una sola base porque el filtro sigue puesto, así que no
  expone las demás instancias del mismo equipo. Ninguna instalación de
  producción comparte ese archivo.
- **D-cert — La renovación automática de certificados NO estaba apagada.** El
  temporizador lleva desde el 3-ago funcionando dos veces al día sin fallar
  una sola vez. La lectura de «apagado» venía de mirar el servicio, que sale
  muerto entre ejecuciones **por diseño**, porque lo dispara un temporizador.
  Premisa falsa, defecto retirado. El de erp2 renueva bien en prueba en seco.
- **Los comentarios del kit sobre el origen cruzado ya dicen la verdad.** Eran
  tres, no uno, y mi propia corrección también estaba incompleta. Lo medido el
  12-sep-2026 por tres vías: Odoo puro **no** abre nada sobre la interfaz de
  datos; un complemento abre el origen; **otro complemento distinto** abre la
  cabecera, y sin ese segundo el navegador rechaza igual aunque el primero
  esté; y **el servidor web de delante no añade nada**, comprobado con un
  preflight que devolvió cero cabeceras. Yo llevaba horas repitiendo que las
  ponía él.
- **Las dos pantallas ausentes y el alta de PIN, cerradas.** Existencias de
  bodega era peor de lo descrito: **no tenía ni ruta**, no se llegaba ni
  escribiendo la dirección. El centro de turno sí la tenía pero ningún menú
  apuntaba a él. Y el alta de PIN ya vive en Configuración, dentro de
  Seguridad, sin subir de capacidades de vendedor. **Lo que más vale de esa
  entrega es la vigilancia nueva**: la prueba existente comprobaba que algún
  permiso abriera cada ruta, nunca que algún menú apuntara a ella. Ahora
  comprueba las dos cosas, verificada en rojo antes que en verde.
- 🟢 **El llavero de macOS funciona, y con él el desbloqueo sin conexión.** La
  causa era que el proyecto no usaba la cuenta de firma que sí existía. Con el
  equipo puesto y el permiso de llavero declarado, el acceso nativo completa y
  el derivado **sobrevive a cerrar y reabrir la aplicación**, medido con dos
  procesos distintos. Se refutaron cuatro hipótesis por el camino, tres mías.
- 🟢 **Se entra desde el navegador con usuario y contraseña**, medido desde un
  dominio ajeno y no desde el fácil. La credencial dura un día exacto y quien
  entra llega al escritorio con pedidos, productos, clientes y facturas
  legibles. Falta solo la comprobación visual en pantalla.
- **El navegador sí guarda credenciales.** Orden del dueño del 11-sep-2026:
  *«yo he dicho que navegador también guarda igual que escritorio»*. Revoca la
  parte de `W02` y `W03` que decía lo contrario. El diseño está encargado y
  quedará escrito en `W04`.

## En construcción ahora mismo

Cuatro agentes abiertos el 12-sep-2026 por la noche, sobre ficheros que no se pisan:

| Frente | Qué hace |
| --- | --- |
| Formularios | Ajustes, cobros, editor de venta y alta de PIN pasan al formulario estándar. El acceso queda fuera a propósito: su presupuesto de alto lo fijan pruebas |
| Acceso, PIN y carga | Quita la franja de 24 px de `ScaffoldPage`, tarjeta opaca de Fluent, pie en `bottomBar`, separa los interruptores y quita el blanco bajo la carga |
| Gestor de servidores | Pasa a `ContentDialog`, título más pequeño, se ajusta al teclado, botón «Listar bases» y usa `/orbi/database` |
| Auditoría Fluent | Sólo lectura: todo lo construido a mano que Fluent ya trae |

Los seis frentes que entregaron antes, el mismo 12-sep-2026, quedaron así, para que nadie
los vuelva a encargar:

| Frente | Dónde quedó |
| --- | --- |
| Desbloqueo sin conexión | Funciona y sobrevive a cerrar y reabrir, medido con dos procesos |
| Ruta de acceso en el conector | Construida, desplegada y medida desde un dominio ajeno |
| Mensajes de acceso | Dieciséis causas distinguidas, copiables y con duración elegible |
| Credencial portable | `decisions/C01-credencial-en-archivo-cifrado.md` |
| Guardado en navegador | `decisions/W04-el-navegador-tambien-guarda.md`, implementado y medido en Chrome |
| Despliegue en navegador | Se entra desde el navegador; falta sólo la comprobación visual en pantalla |

## Defectos conocidos y sin arreglar

- **No existe enrolamiento de dispositivo en ningún sitio del monorepo.** El PIN
  identifica una cuenta, no un equipo autorizado. Sin eso, «equipo compartido»
  es una etiqueta de documento y no algo que el sistema aplique o revoque.
- **Ningún lector de código de barras y ninguna impresión conectada**, aunque el
  paquete de impresión ya viaje en el árbol. Ni rastro de cajón de dinero.
- 🔴 **Las cuatro cuentas de prueba tienen la contraseña `12345`** por petición
  del dueño, para poder entrar a mano. La base está expuesta en internet y la
  ruta de acceso es pública. **Cambiarlas y cerrar la lista de orígenes antes de
  publicar nada.**

Ninguno de estos está encargado a nadie. Están aquí para que no se pierdan.

- **Cada acceso fallido deja una credencial huérfana en el servidor.** El
  retroceso borra la copia local y nunca revoca la remota. Hay cuatro de `admin`
  en ERP2 de esta madrugada, sin revocar.
- **Un fallo de conexión se interpreta como falta de red** sin comprobarlo. El
  paquete de conectividad ya está declarado y sin usar.
- **Los conflictos de sincronización llegan vacíos.** El trabajo que los calcula
  solo guarda cuántos hay y descarta el detalle, así que la pantalla nunca los
  puede mostrar.

- **El certificado de erp1 no se puede renovar.** Vence el 2026-11-04. La
  renovación falla porque el servicio de esa instancia está apagado, y sin
  servicio detrás el proxy devuelve error a todo ese dominio, incluida la
  comprobación que exige la autoridad de certificados. Que esté apagado parece
  deliberado, así que **nadie lo enciende sin decidirlo antes**.

- 🔴 **El servidor de pruebas se edita a mano, y por eso su estado no se puede
  reconstruir desde el repositorio.** Medido el 12-sep-2026 al ir a desplegar:
  **298 ficheros modificados y 145 sin seguimiento**, y su rama local **571 commits por
  detrás** de la publicada. La regla de oro del repositorio dice que nunca se editan
  ficheros directamente en un servidor, y ahí se lleva haciendo tiempo.
  - Por eso el despliegue de hoy **no fue una actualización normal**: traer los 571
    commits sobre un árbol así arriesgaba el trabajo de otros. Se copiaron sólo los
    ficheros de ese módulo, tras comprobar uno por uno que **112 de 118 ya eran
    idénticos** a lo publicado, que los 4 distintos eran exactamente este cambio, y que
    **nada existía sólo en el servidor**. Sin esa comprobación previa no se toca.
  - Mientras siga así, **nadie puede decir qué código corre en ERP2** leyendo el
    repositorio, y una restauración partiría de un estado que no está en ninguna parte.

- 🔴 **La tabla local de plazos de tarjeta se diseñó sobre campos que no existen.**
  Guarda días y porcentaje; el servidor da meses, tipo e interés. Hoy se sincroniza sólo
  el nombre y el plazo queda en cero, que la pantalla oculta, así que **no se inventa un
  dato** — pero tampoco se puede mostrar el plazo. Arreglarlo toca el esquema compartido
  con la aplicación madura y su modelo generado, y **subir la versión del esquema borra
  y recrea todas las tablas** si no se le escribe su rama de migración. Por eso no se
  hizo de paso: necesita decidirse aparte.
- ⚠️ **Que un catálogo responda 200 no prueba que sus campos signifiquen lo que
  creemos.** La vigilancia nueva comprueba que el nombre existe al otro lado, que es lo
  único que una prueba con dobles no puede comprobar. Los diez catálogos que hoy pasan
  limpio **nunca se han contrastado en significado**, y salieron del mismo commit que
  los cuatro rotos.

## Configuración que falta en ERP2, y probablemente en producción

Medido el 11-sep-2026, solo lectura. **No es código, es configuración**, y por eso
es rápido de arreglar y fácil de olvidar.

- **Ningún diario de venta está marcado como numerado por el cliente** (tres de
  tres). Mientras siga así, toda emisión desde el punto de venta cae por el
  camino que el servidor numera, que es justo el desprotegido ante un reintento.
- **Ninguna configuración de caja tiene diario ni identificador de equipo**
  (cinco de cinco vacías). La exclusividad entre dispositivos existe en el
  esquema pero **está sin estrenar**, porque los índices que la garantizan no
  restringen los valores vacíos.
- Colateral: la aplicación vieja **se niega a emitir sin conexión** mientras
  falte esa marca, así que su camino sin conexión ni siquiera arranca en ERP2.

## Orbi web: un solo dominio para todos los clientes

Desde el 12-sep-2026 por la noche, `https://orbi.galapagos.tech` sirve la app compilada
como ficheros estáticos. **Una sola app para todos los clientes**, por orden del dueño: se
abre ahí y en el acceso se elige a qué Odoo conectarse. Cómo está montado y cómo se
despliega: memoria `orbi-galapagos-tech-hosting`.

- **El origen cruzado lo pone el servidor web de cada cliente, no Odoo.** Decisión del
  dueño por la regla «no se toca el core». La ruta de datos del núcleo no declara origen
  cruzado, así que sin eso **se entra pero todo sale vacío**.
  - **ERP2** funcionaba por la pila del punto de venta: `l10n_ec_collection_box` redeclara
    las rutas de datos con origen cruzado, y el parche de `l10n_ec_collection_box_pos`
    añade la cabecera de base. Más un bloque `/json/` en su nginx.
  - **Mepriga** no lleva esa pila. Su Apache contesta ahora el sondeo de `/json/` y pone la
    cabecera de origen en todas sus respuestas, también en los 401. Hubo que encender
    `mod_rewrite`; antes se comprobó que no despertaba reglas dormidas, y después Velneo
    respondía idéntico a la foto previa. Commit `6f6879c` del repositorio `mepriga`.
  - **Un cliente nuevo** necesita lo mismo en su servidor web. Qué exactamente: memoria
    `orbi-web-entre-dominios-por-servidor-web`.
- **`GET /orbi/database`**, en `l10n_ec_orbi_web` y desplegada en ERP2 y Mepriga, devuelve
  sólo la base que atiende el dominio, o 404 sin nombres. Existe porque Mepriga niega el
  listado de bases, que es lo correcto en un servidor público, y la app lo mostraba como
  «no se pudo conectar». La app todavía no la usa: está en construcción.
- **ERP2 ya se actualizó** tras partir el conector y sirve Orbi desde `l10n_ec_orbi_web`.
- **Los grupos de envases de Mepriga sí estaban asignados**: los cinco usuarios activos
  tienen uno, y Gerencia hereda de Usuario.
- **Las tres pruebas de las rutas de Orbi se borraron** por decisión del dueño: quedaron
  rotas en el conector al partir el módulo.
- **El paquete que sirve cada Odoo en `/orbi/` está atrasado** respecto a
  orbi.galapagos.tech. Hay que recompilarlo con `--base-href=/orbi/` cuando entren los
  arreglos de pantalla.
- **La guía de Mepriga decía que su carpeta de módulos es un clon, y no lo es**: `git pull`
  fallaba. Corregida el 12-sep-2026 (commit `37b3c1e` del repositorio `mepriga`, copiada al
  servidor) junto con la trampa de `docker compose run` por SSH. `COMMIT_DE_ORIGEN.txt`
  dice ahora qué commit corre en cada módulo, y marca lo que no se ha comparado.

## Envases: el contrato de Odoo cambió y el mío se quedó corto

Avisado el 12-sep-2026 por la sesión que lleva el lado de Odoo. **El dueño decidió
que los envases sí se ven desde Orbi**, apuntando a una instancia nueva de Odoo 19.5
distinta de ERP2.

- **Mis dos contratos no están equivocados, están callados.**
  `ENVASES_DOMAIN_CONTRACT.md` y `ENVASES_BACKEND_ACCEPTANCE.md` nunca asumieron una
  ubicación de custodia por cliente —tratan propiedad, custodia, ubicación y estado
  como cuatro dimensiones distintas y no nombran ni un modelo—, así que el rediseño
  del 11-sep no los invalida. Verificado con grep, no de memoria.
- **Falta el enganche.** El desglose por tercero ahora vive en un modelo propio,
  `l10n_ec.envases.saldo.tercero`, agrupado por tercero. Mi lado promete ese desglose
  en pantalla y no dice de dónde sale. Hay que escribirlo.
- ⚠️ **El tercero puede venir vacío, y es a propósito**, para que el total cuadre
  contra lo físico. Si el panel no trata esa fila aparte, enseña una fila sin nombre
  que parece un error de datos. Debe decir «sin cliente asignado».
- 🔴 **La empresa nueva tiene una sola bodega de tránsito, sin sentido, y ahí está el
  49,5% de su inventario** (28.774 de 58.162). Los dos contratos exigen tránsito por
  sentido, así que **la mitad del dato no se puede clasificar al conectar**. Es
  decisión del dueño: o se parte esa bodega en dos, o hay que decidir qué dice esa
  columna mientras tanto. Se la traslada la sesión de Odoo, no esta.
- Sin el grupo de permisos de envases dado de alta en esa base, **Orbi no enseña la
  pantalla y no lo dice**: se comporta como si el área no existiera.

## Trabajo grande, pendiente de prioridad

- **Dieciséis pantallas aprobadas sin código.** Dos son imposibles hoy sin
  trabajo de servidor: cobrar contra varias facturas de un cliente, y el conteo
  físico con aprobación de supervisor.
- **Paridad fiscal.** Nueve decisiones propuestas y seis verificaciones que
  exigen una instancia. Es el único bloqueo formal para cerrar el plan.
- **Recepción y transferencia en bodega** siguen sin decisión de producto sobre
  si deben llevar candado, como sí lo lleva la entrega.

## Reglas de este archivo

Se actualiza al vuelo, no al final. Una promesa hecha en la conversación y no
escrita aquí se considera perdida. Cuando algo se cierra, se borra de aquí y su
evidencia queda en `reports/` o en `decisions/`.
