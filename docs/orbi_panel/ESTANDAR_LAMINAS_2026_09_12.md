# Estándar del marco entre las 39 láminas aprobadas

Fecha: 2026-09-12 · Autor: `pantallas-ausentes` · Encargo del dueño, relayado por el
coordinador: **«hay que estandarizar las láminas»**, antes de implementar cualquier
pantalla. **Análisis, no código.**

## 0. Método

Se revisaron las **39 láminas vigentes** (33 de round-02 + 6 de round-03; las 7
históricas quedaron fuera por estar superadas). Cuatro se abrieron y compararon
personalmente con detalle (`SHELL-01`, `ACC-03`, `CAJ-05-v2`, `ENV-01`, elegidas por
ser la lámina de marco global, la de inicio/identidad, y las dos que el coordinador
señaló como «las que más controles raros suelen tener»: Caja y Envases). Las 35
restantes se repartieron en cuatro barridos independientes, cada uno con el mismo
cuestionario de 7 puntos (navegación de teléfono, barra superior, título, barra de
acciones, anchos declarados, pie, estados/colores), para que la comparación fuera
uniforme y no dependiera de qué mirase primero. Se contrastó todo contra
`SHELL_AND_INTERACTION_SPEC.md` (que ya es un contrato escrito, aunque disperso y sin
seguimiento) y `ROUND_02_REVIEW.md`/`APPROVAL_REGISTER.md` para fechas y alcance real
de aprobación.

**Aviso importante antes de las tablas:** no todo lo que parece un choque lo es. Dos
elementos que a primera vista contradicen (pie técnico, colores de estado) resultaron,
al mirar las 39, ser **consistentes** una vez se entiende la razón de la aparente
diferencia. Se reportan igual, con la explicación, en vez de forzarlos a la lista de
contradicciones.

---

## 1. El teléfono — navegación

| Patrón | Cuántas láminas | Ejemplos |
|---|---:|---|
| Barra inferior de iconos (root) | 10 | ACC-03, VEN-01, VEN-05, ALERT-02, CAJ-11, CAJ-09-v2, BOD-01, BOD-02, SYN-01, SYN-02 |
| Barra inferior + botón central «+» (FAB) | 4 | ENV-01, ENV-02, CFG-01, NOT-01 |
| Barra inferior **y** hamburguesa a la vez | 1 | SHELL-01 |
| Pestañas superiores **y** barra inferior a la vez | 1 | ENV-03 |
| Sólo hamburguesa, sin barra inferior (pantalla empujada/formulario) | 15 | VEN-03, CAJ-03, CAJ-05-v2, CAJ-04/06/07/08-v2, BOD-03/04, ENV-06/07, SUP-01, SYN-03, OPS-01, OUT-01 |
| Flecha atrás / breadcrumb, sin tabs ni hamburguesa | 3 | CAJ-02, ALERT-01, CONT-01 |
| Ningún mecanismo de navegación visible | 1 | CAJ-10 |
| Panel modal a pantalla completa | 1 | AI-01 |
| No aplica (acceso/PIN, previo a autenticación) | 2 | ACC-01, ACC-02 |

A simple vista parecen 16 láminas «con barra inferior» contra 18 «sin ella» — un
empate que confirmaría que esto lo tiene que decidir el dueño, como sospechaba el
coordinador. **Pero la mayoría de las que no la tienen son pantallas empujadas** (un
formulario o un detalle abierto desde una lista), no pantallas raíz: ahí no cabe
ninguna barra, con o sin Fluent, con o sin bottom-bar — es lo mismo que pasa al abrir
un documento en cualquier app. Separando por tipo de pantalla:

- **De las ~15 pantallas que SÍ son raíz de un listado** (ACC-03, VEN-01, VEN-05,
  BOD-01, BOD-02, ENV-01, ENV-02, SYN-01, SYN-02, ALERT-02, CAJ-11, CAJ-09-v2,
  CFG-01, NOT-01, SUP-01), **14 de 15 usan barra inferior en alguna forma.** Sólo
  `SUP-01` (Aprobaciones) no la dibuja.

Con esto, el «empate» desaparece: **no es 50/50, es una mayoría clara una vez se
separan las pantallas raíz de las pantallas empujadas.**

**Y esto ya se decidió hoy mismo.** La Parte VII de `ESQUELETO_FLUENT_2026_09_12.md`
(12-09-2026) ya resolvió que el teléfono lleva una barra inferior escrita a mano,
razonada por alcance del pulgar y por que Orbi tiene 7 áreas de primer nivel (más de
las 5 que Fluent recomienda para su modo `top`). No hay nada que reabrir aquí: esta
tabla simplemente confirma con las 39 láminas que esa decisión coincide con lo que la
mayoría ya dibujaba por su cuenta.

**Lo que sí decido aquí, porque la Parte VII no lo cubrió:**

- **El conjunto de destinos dentro de la barra es puro caos** — ninguna de las 10+4
  láminas con barra inferior coincide con otra en qué 4-5 opciones incluir (`VEN-01`:
  Inicio/Clientes/Órdenes/Reportes/Más; `VEN-05`: Inicio/Ventas/Inventario/
  Notificaciones/Más; `CAJ-11`: Inicio/Ventas/Caja/Reportes/Más; `ACC-03`: seis grupos
  completos; etc.). **Estándar: Inicio + hasta 4 de los 6 grupos del menú de unión ya
  aprobado en `SHELL_AND_INTERACTION_SPEC.md` (Ventas, Caja, Bodega, Envases,
  Aprobaciones, Sistema), y «Más» abre el resto** — no una lista distinta inventada
  por pantalla.
- **La hamburguesa redundante de `SHELL-01`** (barra inferior y hamburguesa juntas)
  se elimina: el botón «Más» de la barra inferior ya cumple la función de abrir el
  menú completo agrupado que pide el spec («menú accesible con grupos y
  subopciones, sin comprimir todas las áreas en una barra de iconos»); mantener las
  dos rutas es redundante, no una capa adicional deliberada.
- **El botón central «+» (FAB)** de `ENV-01`/`ENV-02`/`CFG-01`/`NOT-01` es minoritario
  (4 de 39) y no está pedido en ningún documento — no entra al estándar base. Queda
  como nota de posible mejora futura, no como parte del marco.

## 2. La barra superior

Ninguna de las 39 láminas coincide con otra en su composición exacta. Lista de
controles observados y en cuántas láminas aparece cada uno (aproximado, sobre 39):

| Control | Aparece en | Nota |
|---|---:|---|
| Avatar / identidad de usuario | 39/39 | Universal, sin excepción |
| Campana de notificaciones | ≈29/39 | Mayoría clara |
| Empresa (nombre, bajo 5 campos distintos: Empresa/Sucursal/Planta/Sede/Ambiente) | ≈26/39 | Mayoría, pero sin nombre de campo único |
| Buscador global con caja de texto | ≈17/39 | Minoría-a-la-mitad, no mayoría |
| Ayuda «?» | ≈5/39 | Minoritario |
| Engranaje de configuración inline | 1/39 (`CAJ-11`) | Único caso, se descarta |
| «Periodo» como filtro en la barra superior | 3/39 | Minoritario, y redundante con filtros ya repetidos dentro del contenido (`VEN-01` tiene «Periodo» arriba Y pestañas «Todas/Hoy» abajo) |
| Botones «Bloquear»/«Cambiar usuario» visibles siempre (no dentro del menú del avatar) | 1/39 (`ACC-03`) | Único caso, pero es la lámina cuyo propio título declara el tema («Workspace multirrol... menú Bloquear y Cambiar usuario») |
| Punto de cobro/sesión de Caja en línea | presente en toda lámina de Caja que muestra sesión activa | Consistente dentro de Caja |

**Estándar que propongo, y por qué no invento nada:** `SHELL_AND_INTERACTION_SPEC.md`
ya dicta esto por escrito, sólo que nadie lo había cruzado contra las láminas hasta
ahora: *«La cabecera muestra marca Orbi, empresa, ubicación/almacén y usuario activo.
En Caja añade punto y sesión efectivos.»* Sumado a la campana (mandatada aparte, en la
sección de avisos del mismo spec) y a la mayoría medida arriba, el marco obligatorio
queda: **marca · empresa · ubicación · usuario activo · campana** (+ punto/sesión en
Caja). Buscador global, ayuda, engranaje inline y «Periodo» en la barra **quedan
fuera del marco obligatorio** — ninguno lo pide el spec y ninguno pasa de mitad de
las láminas; una pantalla puntual puede añadir alguno si aporta, pero no forman parte
del marco que se repite en todas.

Los botones «Bloquear»/«Cambiar usuario» de `ACC-03` se adoptan como estándar del
**menú del avatar** (no como botones sueltos permanentes) porque `ACC-03` es la
lámina cuyo tema declarado es precisamente la identidad/sesión — la misma regla de
precedencia que ya está escrita en el inventario (la lámina más reciente manda sólo
sobre su propio tema declarado) aplica igual aquí aunque no sea la más reciente: es
la única que lo declara como su asunto.

**Lo único que dejo para el dueño en este punto:** el buscador global. Está en la
mitad de las láminas mostradas, no lo pide el spec, y no hay una lámina «autoridad»
sobre el tema que lo zanje. Además tiene un costo real detrás si se implementa en
serio (buscar por número/cliente/producto/documento a través de módulos exige un
endpoint de búsqueda cruzada en el backend, no sólo un campo de texto). Ver la
pregunta en la sección 5.

## 3. El título de pantalla

- **Dónde vive: unánime.** Las 39 láminas, sin excepción, ponen el título dentro del
  área de contenido, debajo de la barra superior — nunca dentro de la barra misma.
  No hay nada que decidir aquí.
- **Subtítulo:** mayoría clara lo lleva (descripción breve de una línea bajo el
  título). Se adopta como estándar.
- **Código de pantalla delante del título (ej. «VEN-01»):** en la **mayoría** de las
  láminas el código NO aparece dentro del UI simulado — sólo en el rótulo externo del
  tablero, fuera del frame del dispositivo. Cuando sí aparece, lo hace en **tres
  formatos distintos**: fusionado en el texto («BOD-04 · Conteo físico»), como
  etiqueta pequeña junto al título (`BOD-03`, `ENV-03`, `ENV-06`), o precediendo con
  espacio (`VEN-03`, `CAJ-09-v2`). **Estándar: no se muestra el código de pantalla
  dentro de la aplicación real** — es un artefacto de control de calidad de las
  láminas, no un elemento de producto. Las dos láminas que definen el marco global
  (`SHELL-01`, `ACC-03`) tampoco lo muestran, lo que confirma la mayoría.

## 4. La barra de acciones

- **Orden y estilo: consistente, no es un choque.** En las 39 láminas, cuando hay un
  par cancelar/confirmar, el secundario (outline) va siempre a la izquierda y el
  primario (relleno, color de acento) va siempre a la derecha. Se adopta tal cual.
- **Vocabulario: inconsistente, pero no es un problema de marco.** Sólo dentro de
  Caja aparecen cinco pares distintos para lo que en el fondo es «confirmar/cancelar
  un formulario»: Cancelar/Aceptar (`CAJ-07-v2`), Cancelar/Confirmar (`CAJ-08-v2`),
  Cancelar/Guardar/Revisar cierre (`CAJ-10`), Volver/Guardar/Contabilizar/Ver asiento
  (`CAJ-06-v2`), Cambiar clave/Registrar/Cerrar (`CAJ-04-v2`). **Esto no lo resuelvo
  aquí**: es una cuestión de redacción por tipo de operación, legítimamente distinta
  entre un depósito bancario y una retención SRI, no una regla del marco visual. Lo
  dejo anotado para un glosario de textos aparte, no para este documento.
- **Overflow «⋮»/«más» por fila:** se usa cuando hay más de 2-3 acciones por
  registro; no hay una regla fija de cuántas caben antes de agruparse, pero tampoco
  hay contradicción real — es una decisión de densidad por pantalla, no de marco.

## 5. Los cortes de ancho

Round-02 usa mayoritariamente Desktop 1920×1080 / iPad horizontal 1366×1024 / iPad
vertical 768×1024 / teléfono ~390×844 — con excepciones concretas: `CAJ-03` usa
1366×768 en Desktop, `OPS-01` usa un set completo distinto (1440×900/1024×768/
768×1024/390×844), `ENV-01` no imprime números en absoluto, y `SHELL-01` (round-03)
usa 1024×1366 para el iPad vertical en vez de 768×1024 — que además, a diferencia de
los demás, sí es geométricamente la misma tableta que su horizontal (1366×1024)
simplemente girada; el 768×1024 que usa el resto de láminas es un modelo de tableta
distinto y más antiguo.

**Esto no lo mando al dueño.** Los números impresos en una lámina son parte de la
ilustración generativa, no una especificación de implementación: esta sesión ya
midió y fijó los cortes reales contra los que se construye (`OrbiTheme.
compactBreakpoint = 600`, `mediumBreakpoint = 840`, y el corte de 1440 documentado
para el modo expandido), anclados a los mismos dispositivos de las láminas pero
verificados contra el código, no contra la etiqueta de una imagen. **Estándar: se
descartan los píxeles impresos en las láminas; se usan los breakpoints ya medidos y
vigentes en el código.**

## 6. El pie (footer)

**Esto parecía un choque y no lo es.** De las 39 láminas, sólo dos lo dibujan dentro
del chrome de la app: `SHELL-01` («Menú y contexto global») y `OUT-01` («Salidas de
documentos de Odoo», donde el servidor/entorno forma parte de la procedencia del
documento que se está mostrando). Las otras 37 lo omiten por completo — pero **ambas
excepciones son, precisamente, las dos únicas láminas cuyo tema declarado incluye el
pie**, exactamente lo que predice la regla de precedencia que ya está escrita en el
inventario (`INVENTARIO_2026_09_12.md`, §6): una lámina manda sobre su propio tema
declarado, no sobre todo lo que dibuja. Las 37 restantes no "contradicen" el pie —
simplemente no era su asunto, tal como el propio `ROUND_02_REVIEW.md` ya advierte
(«una lámina de un recorrido no prueba todos sus estados ni cada pestaña»).

**Estándar: el que ya dicta el spec escrito**, sin cambios — persistente en escritorio
y tablet horizontal, indicador compacto en vertical/teléfono, con el formato ya
fijado en `SHELL_AND_INTERACTION_SPEC.md` («Servidor: ... | BD: ... | Hora servidor:
... | Conectado | N pendientes»).

## 7. Estados y colores

**Esto tampoco es un choque real.** Sin que ningún prompt de generación lo pidiera
explícitamente, las 39 láminas convergieron solas en el mismo código de color:

| Significado | Color | Ejemplos |
|---|---|---|
| Confirmado / éxito | Verde | `SHELL-01`, `ACC-03`, `VEN-01`, `CAJ-05-v2`, `AI-01`, `OUT-01` |
| Pendiente | Ámbar/naranja | `CAJ-02`, `BOD-02/03/04`, `SUP-01`, `SYN-02`, `OPS-01` |
| Error / rechazado / diferente | Rojo | `SHELL-01` (sync), `SUP-01`, `SYN-02/03`, `OUT-01` |
| Borrador | Gris | `VEN-01`, `CAJ-08-v2`, `AI-01` |
| En proceso / en tránsito | Azul | `VEN-01`, `ACC-03`, `ENV-03`, `SYN-01` |

El dueño ya resolvió la única variable que sí divergía (la forma del chip: *«que no
sea redondo da igual»*). **Estándar: se escribe la tabla de arriba tal cual, como la
única convención de color por significado — no hay que inventar una, ya existe y ya
es consistente.**

## 8. Agrupación del menú lateral — ya resuelto antes de hoy

Varias láminas (`ACC-03`, `CAJ-05-v2`, `ENV-01`, y otras) dibujan grupos genéricos de
ERP que no están en el alcance aprobado: Compras, Inventario, Proveedores, Reportes,
Configuración, Administración, Comercial, Operaciones — y en `ENV-01` Envases aparece
anidado dentro de Inventario en vez de ser un grupo de primer nivel. **Esto no es un
hallazgo nuevo de hoy**: el propio `ROUND_02_REVIEW.md` ya lo señaló en su QA inicial
(«el generador agregó menús; no constituyen ampliación de alcance») y
`SHELL_AND_INTERACTION_SPEC.md` ya fija los seis grupos válidos, en este orden:
**Ventas, Caja, Bodega, Envases, Aprobaciones, Sistema**, cada uno de primer nivel,
sin grupos vacíos. Lo repito aquí sólo para que quede en el mismo sitio que el resto
del marco, no porque haga falta decidir nada de nuevo.

## 9. Una nota menor: el logo

`ORBI ERP` en mayúsculas con el anillo teal aparece en 34+ de 39 láminas, incluida
`SHELL-01` (la lámina de marco global). Sólo `CONT-01`, `OUT-01` y `AI-01` (las tres
últimas de round-03) usan una variante «Orbi ERP» con otro ícono. Mayoría clara,
incluida la lámina de mayor autoridad sobre el chrome — se estandariza en
`ORBI ERP` mayúsculas con el anillo teal.

---

## Lo que decido yo, y por qué (resumen)

| # | Elemento | Decisión | Base |
|---|---|---|---|
| 1 | Teléfono — mecanismo | Barra inferior en pantallas raíz; sin hamburguesa redundante | Mayoría real (14/15 raíces) + ya decidido en Parte VII de hoy |
| 1b | Teléfono — destinos | Inicio + 4 grupos + «Más» | Menú de unión ya aprobado en el spec |
| 2 | Barra superior | Marca, empresa, ubicación, usuario, campana (+punto/sesión en Caja); Bloquear/Cambiar usuario en el menú del avatar | Spec escrito + mayoría + precedencia de `ACC-03` |
| 3 | Título | Sin código de pantalla dentro del UI; con subtítulo | Mayoría abrumadora, confirmada por las dos láminas de marco |
| 4 | Barra de acciones | Secundario outline-izquierda, primario relleno-derecha | Ya consistente en las 39 |
| 5 | Anchos | Se usan los breakpoints ya medidos en código (600/840/1440), no los píxeles de las láminas | Los números de láminas son ilustrativos, no especificación |
| 6 | Pie | Persistente en escritorio/tablet horizontal, compacto en vertical/teléfono, formato ya fijado en el spec | No era un choque; precedencia de tema ya lo explica |
| 7 | Estados/colores | Verde/ámbar/rojo/gris/azul por significado; forma libre (ya resuelto por el dueño) | Convergencia espontánea en las 39 + decisión previa del dueño |
| 8 | Menú lateral | Los 6 grupos del spec, sin añadidos genéricos, Envases de primer nivel | Ya resuelto en QA previa + spec |
| 9 | Logo | «ORBI ERP» mayúsculas, anillo teal | Mayoría, incluida la lámina de marco |

## Lo que le toca decidir al dueño

**Buscador global en la barra superior — sí o no.** Está dibujado en poco más de la
mitad de las láminas (17/39), no lo exige el spec escrito, y no hay una lámina cuyo
tema declarado sea «la búsqueda» que zanje el empate por precedencia.

- **Si sí:** hay que construir una búsqueda que cruce módulos (ventas, caja, bodega,
  envases, clientes) desde un único campo — eso es un endpoint de backend nuevo, no
  sólo un campo de texto en la UI. Coste real, no cosmético.
- **Si no:** cada pantalla conserva su propio buscador de contenido (el que ya usan
  `VEN-01`, `CAJ-11`, etc. para filtrar su propia tabla), y el marco se queda sin
  buscador global. Coste cero adicional, pero pierde el atajo que la mitad de las
  láminas ya sugiere.

Sobre el punto que se señaló inicialmente como «del dueño» —bottom bar contra
hamburguesa en el teléfono—: con las 39 láminas miradas, la evidencia y la decisión
ya tomada hoy en la Parte VII lo dejan resuelto (ver sección 1). Lo ratifico aquí en
vez de reabrirlo; si se prefiere que lo decida el dueño de todas formas, avísenme y
lo presento como pregunta abierta.

## Dónde debe vivir el estándar, mi criterio

Ninguna capa sola basta:

1. **Texto que ya existe y ya tiene autoridad:** `SHELL_AND_INTERACTION_SPEC.md`.
   No hace falta un documento nuevo que compita con él — recomiendo que, una vez el
   dueño confirme lo de esta nota, las decisiones de este documento se fundan ahí
   como una sección nueva («Estándar resuelto, 12-09-2026»), no que queden sueltas en
   un tercer archivo que nadie vuelve a abrir.
2. **Una lámina correctiva, ya pedida y sin hacer.** `DESIGN_HANDOFF.md` ya tiene
   pendiente exactamente esto desde antes de hoy: la tarea **VIS01**, «Normalizar
   menú, pie y marca entre rondas — lámina de componentes globales con logo real,
   seis áreas y pie en cuatro formatos». Este documento le da a esa tarea, ya
   planeada, el contenido exacto que le faltaba para ejecutarse. Recomiendo generarla
   ahora que hay una decisión escrita que dibujar, en vez de seguir postergándola.
3. **El código, cuando se implemente.** Esta es la única capa que de verdad
   «hace imposible saltárselo», que es el criterio que se pidió. Un documento se
   puede no leer y una lámina se puede generar distinta la próxima vez; un widget de
   marco compartido (la cabecera, el pie, el título, la barra de acciones) que
   TODA pantalla esté obligada a usar —sin poder construir su propio chrome a mano—
   es lo único que convierte esta decisión en un hecho en vez de en una sugerencia.
   Mientras no se implemente, las capas 1 y 2 son el mejor sustituto disponible, pero
   no hay que confundirlas con la solución definitiva.

## Las dos respuestas directas

**¿Cuántos choques reales hay? — Siete**, uno por elemento del marco (barra
superior, teléfono, título, vocabulario de acciones, anchos declarados, logo,
agrupación de menú — este último ya señalado antes de hoy). **Dos hallazgos que
parecían choques no lo fueron** (el pie técnico y los colores de estado): en ambos
casos las 39 láminas resultaron más coherentes de lo que se sospechaba, por razones
que quedan explicadas en las secciones 6 y 7.

**¿Cuántos decido yo y cuántos son del dueño? — Los siete los decido yo**, citando en
cada uno mayoría medida, el spec ya escrito, una decisión previa de hoy mismo (Parte
VII), o la regla de precedencia por tema declarado ya establecida en el inventario.
**Al dueño le dejo una pregunta nueva** que surgió al resolver la barra superior (el
buscador global, por su costo real de backend) y **le ratifico, sin reabrirla**, la
pregunta del teléfono que él mismo había anticipado — porque ya tiene una decisión de
hoy que la resuelve y la evidencia de las 39 láminas coincide con ella.
