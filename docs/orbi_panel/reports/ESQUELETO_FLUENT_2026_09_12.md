# El esqueleto de Fluent, pieza por pieza, y qué tiene Orbi en su lugar

Fecha: 2026-09-12 · Autor: `mensajes-acceso` · Para: `pantallas-ausentes` (implementa)

**Análisis, no código.** Leído del paquete instalado
(`~/.pub-cache/hosted/pub.dev/fluent_ui-4.16.1/lib/src/`), no de documentación, y
contrastado con el uso real en `theos_pos`, que lleva años con él.

---

## Las dos respuestas, primero

### 1. ¿La lámina está dibujada sobre el esqueleto de Fluent? — **SÍ, en escritorio y tableta. En teléfono, NO.**

La prueba que lo cierra no es el parecido general, es un detalle que no se le
ocurre a nadie por casualidad: en `SHELL-01.png`, **el buscador global es una
caja de texto en escritorio y se convierte en un ICONO DE LUPA en iPad
vertical**. Eso es exactamente, y con ese nombre, un par de propiedades
hermanas de `NavigationPane`:

```dart
this.autoSuggestBox,
this.autoSuggestBoxReplacement,   // pane.dart:88-89
```

`autoSuggestBoxReplacement` existe para una sola cosa: qué se pinta en lugar
del buscador cuando el panel está estrecho. Quien dibujó la lámina tenía el
panel de Fluent delante.

A eso se suman los demás huecos, uno a uno: cabecera del panel con el logo
(`header`), elementos desplegables con `>` (`PaneItemExpander`), acciones al
pie, título con subtítulo sobre la tabla (`PageHeader`), fila de acciones con
`···` (`CommandBar` + su desbordamiento).

**Pero la lámina NO es Fluent entera, y conviene decirlo:**

- 🔴 **El teléfono usa una barra inferior de navegación** (Inicio · Órdenes ·
  Clientes · Más). Fluent **no tiene** esa pieza: su respuesta a poco espacio
  es `PaneDisplayMode.minimal` (hamburguesa) o `.top`. Esa barra es un patrón
  Material puro. `theos_pos` no usa ninguna.
- 🔴 **El pie de estado de una línea tampoco es una pieza de Fluent.** En
  `theos_pos` es un widget a medida (`ServerInfoBar`), montado FUERA del
  `NavigationView`. No hay nada que traducir: hay que construirlo.

Y un tercer matiz, medido: **la lámina no sigue los umbrales de Fluent.**
`PaneDisplayMode.auto` decide con `width <= 640 → minimal`, `>= 1008 →
expanded` (`view.dart:541-543`). La lámina dibuja el iPad horizontal a **1366
px con el panel colapsado en hamburguesa**, y a 1366 Fluent lo abriría. O sea
que quien la dibujó tomó el catálogo de piezas de Fluent pero **eligió sus
propios cortes**, más conservadores. Al traducir, los umbrales hay que sacarlos
de la lámina, no del paquete.

Así que la traducción es hueco por hueco **para nueve de once piezas**; dos hay
que inventarlas, y una de ellas (la barra inferior) ya es Material de nacimiento.

### 2. ¿Cuántas piezas del esqueleto le faltan a Orbi? — **Nueve de once.**

Orbi tiene hoy **dos**: la navegación lateral (con encabezados de grupo) y el
pie de estado. Le faltan las otras nueve. Detalle en la tabla grande.

---

## La tabla

Ordenada de más externo a más interno. «Orbi hoy» sale de leer
`theos_panel/lib/ui/layouts/operational_shell.dart` (324 líneas, el esqueleto
entero).

| # | Pieza de Fluent | Hueco de la lámina que cubre | Orbi hoy | Equivalente Material |
|---|---|---|---|---|
| 1 | **`NavigationView`** + `PaneDisplayMode` (`pane.dart:13`) | El armazón: panel que se abre/colapsa según el ancho | `Scaffold` con `Row` a mano: barra fija de 256 px si «desktop», si no `Drawer`. **Dos modos, no cinco** | `NavigationRail` (`extended: true/false`) + `NavigationDrawer` + `NavigationBar`, elegidos por ancho |
| 2 | **`NavigationPane.header`** (`pane.dart:85`) | Logo ORBI ERP sobre el menú | **No existe**: el logo vive en el `AppBar` | `NavigationRail.leading` |
| 3 | **`NavigationPane.autoSuggestBox` + `autoSuggestBoxReplacement`** (`pane.dart:88-89`), o **`TitleBar.content`** | Buscador global «Buscar en ORBI…», que **se vuelve lupa** al estrechar | **No existe**, ni caja ni icono | `SearchAnchor.bar()` en ancho; `IconButton` que abre `showSearch` en estrecho |
| 3b | **`PaneItem.infoBadge`** (`pane_items.dart:93`) | Contador sobre una entrada del menú | **No existe** | `Badge` envolviendo el icono del destino |
| 4 | **`PaneItemHeader`** (`pane_items.dart:600`) | Encabezados de grupo del menú | ✅ **Lo tiene** (`Text` con `labelLarge` por grupo) | ya resuelto. ⚠️ Fluent **los oculta en modo compacto**; si el rail colapsado de Orbi los deja, quedarán textos sueltos entre iconos |
| 5 | **`PaneItemExpander`** (`pane_items.dart:707`) | «Ventas ⌄» con hijos: Órdenes, Mostrador, Clientes, Productos | **No existe**: el menú es plano. Los hijos de Ventas están al mismo nivel que todo | `ExpansionTile` dentro del `NavigationDrawer`; en `NavigationRail` no hay anidamiento nativo — ver «Lo que NO traería» |
| 6 | **`PaneItemSeparator`** (`pane_items.dart:552`) | Líneas entre bloques del menú | **No existe** | `Divider` |
| 7 | **`NavigationPane.footerItems`** (`pane_items.dart` vía `:87`) | Zona baja del menú, separada de la navegación | **No existe**: cerrar sesión está en el `AppBar` | hijos al final del `NavigationDrawer`, tras un `Spacer` |
| 8 | **`TitleBar`** (`title_bar.dart:24-37`): `leftHeader` · `icon` · `title` · `subtitle` · **`content`** · `endHeader` · `captionControls` | Toda la franja superior. `content` es el buscador global; `endHeader` es empresa ⌄, ubicación ⌄, campana ③, avatar y `···` | `AppBar` con logo + empresa **como texto plano** y tres iconos sueltos. **Sin selector de empresa, sin ubicación, sin campana, sin avatar** | `AppBar` con `title` (logo) y `actions`: `SearchAnchor.bar()`, dos `MenuAnchor`, `Badge` sobre `IconButton`, `CircleAvatar` con `PopupMenuButton` |
| 9 | **`ScaffoldPage`** (`layout/page.dart:39-42`): `header` · `content` · `bottomBar` | Que cada pantalla tenga su cabecera propia y su barra inferior | **No existe**: cada pantalla se pinta libre dentro del `Expanded` | un widget propio con los mismos tres huecos |
| 10 | **`PageHeader`** (`layout/page.dart:219-221`): `leading` · `title` · `commandBar` | «Órdenes y cotizaciones» + «Gestiona y da seguimiento al ciclo comercial.» | **No existe**: ni título de página ni subtítulo | `SliverAppBar.large`, o un encabezado propio con los mismos tres huecos |
| 11 | **`CommandBar`** + `CommandBarOverflowBehavior` (`surfaces/commandbar.dart:67`) | Fila «Filtros · Columnas · + Nueva orden» y el `···` de la barra superior | **No existe** | `OverflowBar` / `Wrap` + `MenuAnchor`. 🔴 El valor por omisión de Fluent es **`dynamicOverflow`**: lo que no cabe se va solo a un menú `···`. Material **no hace eso solo** — hay que construirlo, o los botones se recortan |
| — | **`BreadcrumbBar`** (`breadcrumb_bar.dart:108`) | **Ningún hueco.** La lámina no tiene migas | no existe | no hace falta — ver abajo |
| — | **`InfoBar` / `displayInfoBar`** (`surfaces/info_bar.dart:31`) | Avisos | ✅ **Lo tiene y mejor**: `CopyableMessagePanel` / `showCopyableMessage`, con botón de copiar y duración configurable | ya resuelto |
| — | **Pie de estado** | Servidor · BD · hora · ● Conectado · 🔔 3 pendientes | ✅ **Lo tiene** (`_contextFooter`), y en compacto lo pliega en una hoja modal | ya resuelto. **No es pieza de Fluent** |

---

## Lo que dice el uso real de `theos_pos`

Ocho años de aplicación con Fluent delante. Lo que **usa** y lo que **nunca
necesitó** vale más que la lista de lo que el paquete ofrece:

| Pieza | ¿La usa `theos_pos`? |
|---|---|
| `NavigationView`, `NavigationPane` (`header`, `footerItems`, `displayMode`) | **Sí** — un solo sitio, `main_screen.dart` |
| `ScaffoldPage` | **Sí, 15 ficheros** — es su unidad de pantalla |
| `PageHeader` | **Sí, 14 ficheros** |
| `CommandBar` + `CommandBarButton` | **Sí, 9 ficheros**, siempre como `PageHeader.commandBar` |
| `InfoBar` | **Sí, 44 ficheros** |
| `PaneItemExpander` | **No. Nunca.** |
| `PaneItemHeader`, `PaneItemSeparator` | **No. Nunca.** |
| `NavigationAppBar` | **No** — usa una barra de título propia |
| `BreadcrumbBar` | **No. Nunca.** |
| `CommandBarOverflowBehavior` | **No** — nunca configuró el desbordamiento |
| Barra inferior de navegación | **No existe** |

Dos lecturas de esto, y las dos importan:

1. **El trío `ScaffoldPage` + `PageHeader` + `CommandBar` es lo que de verdad
   estructura una pantalla**, y es justo lo que Orbi no tiene. Si hay que
   elegir por dónde empezar después del menú, es por ahí: 15, 14 y 9 ficheros
   no mienten.
2. **La lámina pide cosas que `theos_pos` nunca usó** — los desplegables del
   menú, sobre todo. O sea que la lámina **no es un calco de la app vieja**: es
   un diseño nuevo hecho sobre el catálogo de Fluent. Eso responde de otra
   manera a la pregunta del encargo, y refuerza el sí.

---

## Lo que NO traería, y por qué

**1. `BreadcrumbBar` — no traerlo.** La lámina no lo pide, `theos_pos` nunca lo
usó en ocho años, y la navegación de Orbi es plana de dos niveles: un área y
una pantalla. Unas migas de dos escalones son adorno. Material ni siquiera
tiene equivalente propio.

**2. `PaneItemExpander` dentro de un `NavigationRail` — no traerlo tal cual.**
Aquí la costumbre de Material se impone. Un rail colapsado muestra iconos de
~56 px: un submenú desplegable dentro de esa columna es incómodo con ratón y
casi imposible con el dedo. Fluent lo resuelve porque su panel abierto es ancho
y está pensado para ratón en Windows.

La traducción honesta es **partir el comportamiento en dos**:
- en el **cajón** (móvil/tableta), `ExpansionTile` — es exactamente el gesto;
- en el **rail** (escritorio), *no* anidar: que «Ventas» lleve a su pantalla y
  los hijos vivan como pestañas en la cabecera de esa pantalla, que es justo
  donde la lámina ya dibuja «Todas · Mis ventas · Hoy».

🔴 **Y hay una consecuencia que hay que decidir antes de implementar:** en
`SHELL-01` los hijos de Ventas se ven **desplegados en el menú lateral**. Si en
escritorio no se anidan, la lámina y la implementación se separan ahí. No es un
detalle que se pueda resolver a mitad de código: o se acepta la diferencia con
su razón escrita, o se lleva la lámina de vuelta al dueño. **Esto lo decide él,
no nosotros.**

**3. `PaneDisplayMode` configurable por el usuario — no traerlo.** `theos_pos`
deja elegir el modo del panel y lo persiste (`config_service.dart`). Es un
ajuste que en Material no existe como idea, y añade un eje de variación que
multiplica lo que hay que probar. Que el ancho decida.

**4. `InfoBar` — no traerlo, ya está superado.** Orbi ya tiene avisos con botón
de copiar, duración configurable por gravedad y errores que no caducan. `InfoBar`
sería un paso atrás.

---

## Lo que Orbi tiene y conviene no perder al reconstruir

Va aquí porque un rehacer del esqueleto puede llevárselo por delante sin querer:

1. **Encabezados de grupo en el menú.** Ya agrupa por `OperationalDestination.group`
   (Ventas, Caja, Bodega, Envases, Aprobaciones, Sistema), que son las seis áreas
   de `NAVIGATION_CAPABILITY_MATRIX.md`, en orden estable.
2. **El pie se pliega en compacto** en vez de desaparecer: se convierte en un
   botón que abre una hoja modal con lo mismo. La lámina hace igual.
3. **El esqueleto no conoce el router ni los proveedores.** Recibe destinos y
   avisa de navegación. Esa frontera es lo que hace que se pueda probar sin
   montar media aplicación.
4. **Etiquetas de accesibilidad ya puestas**: «Navegación principal»,
   «Información de conexión», y cada destino con su `Semantics`.

---

## Dos datos que nadie pidió y cambian el trabajo

**El menú oculta lo que no corresponde** (`NAVIGATION_CAPABILITY_MATRIX.md`,
regla 1: «Se omiten grupos sin capacidad visible»). Un vendedor no verá Caja.
Al hacer el menú siempre visible en escritorio, eso sigue mandando.

🔴 **Y el caso que se va a ver todos los días: mientras las capacidades no han
llegado, `RouteAccessPolicy` cierra todo menos `/` y `/settings`.** Con un menú
siempre visible, durante ese instante se pintará **vacío o a medias** — y un
menú vacío parece una aplicación rota. Es el mismo problema que ya está resuelto
en el texto (`route_access_messages.dart` distingue «todavía no sé» de «no te
toca») y merece el mismo trato en el esqueleto: un estado de carga explícito,
no la ausencia de entradas.

---

## Por dónde empezaría

1. **Barra superior** (#8) — es lo que el dueño llama «se ve fea»: cuatro huecos
   vacíos donde la lámina tiene empresa, ubicación, campana y avatar.
2. **`ScaffoldPage` + `PageHeader`** (#9, #10) — da a cada pantalla título,
   subtítulo y sitio para sus acciones. Es lo más usado en `theos_pos`.
3. **Buscador global con su reemplazo** (#3) — poco trabajo y es de lo primero
   que se nota.
4. **`footerItems` y separadores** (#6, #7) — pequeños.
5. **Desplegables** (#5) — **sólo después de que el dueño decida** lo del punto
   anterior.

---

# Parte II — El marco frente al formulario: quién pone qué

> «es decir todo el marco sobre el que se muestran los formularios y la app»

Esta parte contesta la pregunta que de verdad decide. Medido leyendo **seis
pantallas distintas** de `theos_pos` y **las quince** de Orbi.

## 🔴 La hipótesis de partida era razonable y es FALSA

La sospecha era: *«en Fluent el marco pone bastante más de lo que uno esperaría,
y por eso todas las pantallas de la app vieja se parecen sin que nadie las
coordine»*.

**No se parecen por el marco. Se parecen por disciplina de copiar y pegar.**

En `theos_pos` **no existe ningún widget propio que encapsule
`ScaffoldPage` + `PageHeader` + `CommandBar`**. No hay `TheosPage`, ni `AppPage`,
ni `BaseScreen`, ni `PageScaffold`: el `grep` de `class .*Page extends` en
`lib/shared/` devuelve **cero**. Las quince pantallas escriben el andamiaje a
mano, una por una.

Y como es disciplina y no marco, **tiene grietas visibles**: `settings_screen`
no lleva `commandBar` en absoluto, y el scroll se reparte 2 contra 4 (dos
pantallas usan `ScaffoldPage.scrollable`, cuatro se lo montan a mano).

Esto importa mucho para Orbi, porque cambia la conclusión: **copiar el reparto
de Fluent no basta. Hay que hacer lo que `theos_pos` nunca hizo.**

## Qué pone el marco de Fluent de verdad

De las seis preguntas, el marco sólo contesta dos por sí mismo:

| Pregunta | ¿Quién? | Evidencia |
|---|---|---|
| Título de pantalla | **la pantalla** | cada una escribe `PageHeader(title: Text(...))` |
| Subtítulo | **nadie** | `PageHeader` **no tiene** esa propiedad. Cuando hay texto secundario es un `Text` suelto en el contenido, con formato distinto en cada pantalla |
| Botones de acción | **la pantalla los declara**, el marco decide dónde caben | van en `PageHeader(commandBar:)`, y `CommandBar` los pliega solo a un `···` (`dynamicOverflow` por omisión) |
| Barra inferior | **nadie** | `ScaffoldPage.bottomBar` existe y **ninguna de las seis lo usa** |
| **Desplazamiento** | **EL MARCO** ✅ | la cabecera queda fija fuera del área que rueda, lo use `.scrollable` o no. Es efecto de `ScaffoldPage`, no algo que cada pantalla resuelva |
| **Dónde va un aviso** | **la pantalla**, con helpers compartidos | y ahí sí hay convención: `CopyableInfoBar` (flotante) y `TheosInfoBars` (inline) |
| Migas de pan | **no existen** | ninguna de las seis, ni casera |

Lo que el marco pone es **menos de lo que parece**: la cabecera fija, el padding
y el plegado de los botones. Todo lo demás es convención repetida.

**Y el dato que más enseña:** donde `theos_pos` sí construyó marco compartido fue
en los **avisos**, no en el esqueleto — `CopyableInfoBar` lo usan 4 de 6
pantallas. Justamente la pieza que en Orbi ya está resuelta y mejor.

## Orbi: tiene marco de página, y va MEJOR que la app vieja

Orbi tiene algo que `theos_pos` no tiene en ocho años: **`OrbiPageShell`**
(`lib/ui/components/orbi_components.dart:7`), un widget compartido que pone
título, acciones, botón de inicio, ancho máximo de 1440, padding y semántica de
ruta (`scopesRoute`, `namesRoute`).

**Lo usan 9 de 15 pantallas.** Eso es marco de verdad, no copiar y pegar.

## 🔴 Pero hay dos AppBar apiladas en doce de quince pantallas

Y aquí está, probablemente, el «se ve fea».

Todas las rutas viven dentro del `ShellRoute` (`router.dart:643-1230`,
comprobado contando paréntesis, no a ojo). Ese shell ya pinta
`Scaffold(appBar: ...)` con logo y empresa. Y encima:

- **9 pantallas** usan `OrbiPageShell`, que crea **otro** `Scaffold` con **otra**
  `AppBar`;
- **3 más** (`approvals_screen`, `settings_screen`,
  `sync_conflict_resolution_screen`) crean su propio `Scaffold` + `AppBar` a
  mano.

**Doce de quince pantallas se dibujan con dos barras de título, una encima de
otra.** La lámina tiene **una**, y el título de pantalla va **dentro del
contenido**, no en una segunda barra.

Las **tres restantes** (`home_center`, `activity_center`, `sync_center`) no
ponen ninguna: **no tienen título**. Así que hoy conviven tres tratamientos
distintos en la misma aplicación.

## El reparto en Orbi, hoy

| Pregunta | Fluent | Orbi hoy | Lo que debería ser |
|---|---|---|---|
| Título | pantalla | **9 por `OrbiPageShell`, 3 con `AppBar` propia, 3 sin título** | el marco, un solo camino |
| Subtítulo | nadie | **nadie**, y la lámina lo pide | el marco |
| Acciones | pantalla declara, marco pliega | `OrbiPageShell.actions` las recibe, **pero nadie las pliega**: no hay desbordamiento | el marco decide dónde caben |
| Barra inferior | nadie | pie de conexión, **del marco** ✅ | ya está bien |
| Desplazamiento | **marco** | **11 de 16 se lo montan ellas** | el marco |
| Avisos | pantalla + helpers | **mezcla**: `CopyableMessagePanel` (bueno) y **6 `showSnackBar` sueltos** | el marco |
| Migas | no hay | no hay | no hacen falta |

## 🔴 Y un defecto que encontré de paso, del mismo tipo que los de esta noche

Los avisos sueltos no sólo se saltan el componente compartido: **muestran
nombres de enum en crudo a quien está en el mostrador.**

```dart
// collection_screen.dart:512
.showSnackBar(SnackBar(content: Text('Resultado: ${result.name}')));
// collection_screen.dart:603
.showSnackBar(SnackBar(content: Text('Cobro: ${result.name}')));
// collection_screen.dart:126
label: 'Turno ${_currentShift.state.name}',
```

Eso produce **«Resultado: queued»**, **«Cobro: synced»**, **«Turno: open»**. Hay
**19 interpolaciones de `.name`** en `lib/features/`, de las cuales unas diez
acaban en pantalla.

Es exactamente el defecto que el dueño reportó del acceso —volcar lo interno en
vez de explicar— vivo en Caja y en Ventas. Y además esos seis avisos **no se
pueden copiar** y **ignoran la duración configurada**, porque no pasan por
`showCopyableMessage`.

## Qué significa esto para el encargo

**Arreglar la lámina del esqueleto no basta.** Si cada pantalla sigue poniendo
su título, su scroll y sus errores donde puede, quedan quince pantallas que no
se parecen y quince sitios donde arreglar lo mismo — que es justo lo que pasó
esta noche con los mensajes que fallaban en silencio en cuatro sitios distintos.

El orden que propongo, y el primero no es visual:

1. **Una sola barra.** Decidir si el título de pantalla vive en la barra del
   shell o dentro del contenido (la lámina dice: dentro del contenido) y quitar
   la segunda `AppBar`. **Esto solo ya cambia doce pantallas.**
2. **Que `OrbiPageShell` sea obligatorio y crezca**: subtítulo, acciones con
   desbordamiento, y que posea el scroll. Las seis que no lo usan, que lo usen.
3. **Cerrar los seis avisos sueltos** y las diez interpolaciones de `.name`.
4. Y sólo entonces, las piezas que faltan de la Parte I.

---

# Parte III — ¿Comprar o construir?

> «¿hay algún paquete, solución, etc. que haga lo mismo que `fluent_ui`?
> Búscalo para no hacer todo desde cero.»

## 1. Lo que ya está en el árbol: nada aprovechable, y nada olvidado

`theos_panel/pubspec.yaml` declara diez dependencias y **las diez se usan**.
Ninguna es de marco ni de navegación: la más cercana es `go_router`, que enruta
pero no dibuja. No hay aquí un paquete olvidado como el de impresión.

## 2. 🔴 Lo que Material ya trae de fábrica — y cambia la cuenta de nueve a dos

Esta es la parte que nadie había mirado, y es la que más ahorra. Leído del SDK
instalado (Flutter **3.47.1**,
`packages/flutter/lib/src/material/`), no de documentación.

**De las nueve piezas que faltaban, Material da seis de fábrica o casi.**

| Pieza que «faltaba» | ¿Material lo trae? | Qué es exactamente |
|---|---|---|
| Cabecera del panel | ✅ **Sí** | `NavigationRail.leading` y **`NavigationDrawer.header`** |
| Elementos de pie del menú | ✅ **Sí** | **`NavigationDrawer.footer`**, y `NavigationRail.trailing` + `groupAlignment` |
| Separadores | ✅ **Sí** | `Divider` como hijo suelto: `NavigationDrawer.children` acepta cualquier widget |
| Desplegables | ✅ **Sí** | `ExpansionTile` |
| Buscador global + su reemplazo | ✅ **Sí** (las piezas) | `SearchAnchor.bar()` y un `IconButton`; el intercambio hay que escribirlo |
| Barra superior con sus huecos | ✅ **Sí** | `AppBar` + `MenuAnchor` (selectores), `Badge` (contador), `CircleAvatar` |
| Cabecera de página | ✅ **Casi** | `SliverAppBar.large` / `.medium`: título grande que se encoge al rodar |
| **Los cinco modos de panel** | ⚠️ **Las piezas sí, el director NO** | Existen `NavigationRail` (con `extended`), `NavigationDrawer` y `NavigationBar`. **No existe nada en el SDK que elija entre ellos según el ancho**: `grep` de `Breakpoint`, `AdaptiveScaffold` y `AdaptiveLayout` en todo `lib/src/` devuelve **cero** |
| **Barra de acciones que pliega a un `···`** | ❌ **NO** | `OverflowBar` existe, pero su propia documentación dice que apila los hijos **en columna** cuando no caben — no los mueve a un menú. **Material no tiene el `dynamicOverflow` de Fluent** |

**O sea: el inventario de la Parte I contaba nueve ausencias, y de verdad sólo
faltan dos cosas.** Las otras siete son piezas de Material que nadie ha
enchufado todavía.

Y las dos que faltan **no son widgets, son comportamiento**:

1. **El director que elige rail / cajón / barra inferior según el ancho.** Los
   tres actores están; falta quien decida. Son pocas líneas y ya hay que
   escribirlas de todos modos, porque **los umbrales tienen que salir de la
   lámina**, que no coincide con los de Fluent (Parte I).
2. **El plegado de las acciones que no caben.** Esto sí es trabajo real de
   medir anchos y mover botones a un `MenuAnchor`, y es exactamente donde un
   paquete podría ganarse el sitio.

### 🔴 Y el dato que remata: Orbi no usa NINGUNA de esas piezas

Conté los usos en `theos_panel/lib/`:

| Widget de Material | Ficheros que lo usan |
|---|---|
| `NavigationRail` | **0** |
| `NavigationDrawer` | **0** |
| `NavigationBar` | **0** |
| `SearchAnchor` | **0** |
| `MenuAnchor` | **0** |
| `SliverAppBar` | **0** |
| `OverflowBar` | **0** |
| `Badge` | 1 |
| `ExpansionTile` | 2 |

La barra lateral de Orbi es un `ListView` de `ListTile` escrito a mano, y su
cajón es un `Drawer` genérico — **no** el `NavigationDrawer` de Material, que
es el que trae `header` y `footer` ya resueltos.

**El problema no es que falten piezas. Es que las piezas existen, están
instaladas, y se reimplementaron a mano peor.** Eso cambia la pregunta «comprar
o construir» por una tercera respuesta: **usar lo que ya está pagado.**

### Un aviso para quien escriba el director de modos: hay TRES cortes distintos

| Quién | Cortes |
|---|---|
| **Fluent** | `≤640 → minimal`, `≥1008 → expanded` (`view.dart:541-543`) |
| **Orbi hoy** | un solo corte: `≥840` **y** más ancho que alto → barra fija; si no, cajón (`operational_shell.dart:103-105`) |
| **Material 3** | `<600` compacto · `600–840` medio · `>840` expandido — y Orbi **ya tiene** esas constantes (`OrbiTheme.compactBreakpoint/mediumBreakpoint`) |
| **La lámina** | iPad horizontal **1366 px con hamburguesa** |

Los tres primeros darían panel abierto a 1366. **La lámina lo cierra.** Ni
Fluent ni Orbi ni Material coinciden con ella, así que **los umbrales hay que
sacarlos de la lámina** — y ése es otro motivo por el que un paquete que traiga
sus propios cortes estorba en vez de ayudar.

Nota aparte: la condición `maxWidth >= maxHeight` que Orbi usa hoy hace que un
**iPad en vertical (1024×1366)** caiga en «no escritorio» aunque tenga 1024 px
de ancho. Es deliberado y coincide con la lámina, que ahí dibuja hamburguesa.
Conviene no perderlo al reescribir.

## 3. Los paquetes: lo que hay, con las cifras de hoy (12-sep-2026)

Consultado en pub.dev en vivo, no de memoria.

| Paquete | Publicador | Última versión | Descargas/mes | Likes | Qué cubre |
|---|---|---|---|---|---|
| **`flutter_adaptive_scaffold`** | **flutter.dev** (oficial) | hace **16 meses** | 6,2k | **952** | navegación adaptable |
| `forui` | duobase.io ✅ | hace **19 días** | 26,5k | 436 | scaffold + header + sidebar + bottom nav |
| `sidebarx` | frezycode.com ✅ | hace 13 meses | 9,5k | 782 | sólo barra lateral |
| `custom_adaptive_scaffold` | hanskokx.com ✅ | hace 52 días | 1,1k | 29 | navegación adaptable |
| `overflow_view` | romainrastel.com ✅ | hace 15 meses | **77,1k** | 227 | primitivo de desbordamiento |
| `toolbar_m3e` | bruckcode.de ✅ | hace 10 meses | 897 | **5** | cabecera + **acciones con desbordamiento a menú** |
| `flutter_admin_scaffold` | keyber.jp ✅ | hace 20 meses | 752 | 208 | sidebar + appBar |
| `adaptive_scaffold_plus` | sin verificar | hace 25 días | 342 | 3 | navegación adaptable |
| `canonical_adaptive_scaffold` | sin verificar | hace 14 meses | — | 2 | fork del oficial |
| `macos_ui` | macosui.dev ✅ | hace 10 meses | 32,6k | 1,07k | marco completo, **estética macOS** |
| `shadcn_ui` | mariuti.com ✅ | hace 8 días | 66k | 956 | navegación **pendiente en su propia hoja de ruta** |

Descartados por muertos: `adaptive_scaffold` (6 años, incompatible con Dart 3),
`flutter_adaptive_navigation` (3 años), `adapto_scaffold` y `auto_scaffold`
(sin tracción).

### 🔴 El dato que decide: el paquete oficial está DISCONTINUADO

`flutter_adaptive_scaffold` lo publica **`flutter.dev`**, tiene **952 likes** —
más que ningún otro candidato — y pub.dev lo marca **`discontinued`**: «This
project has been discontinued, and will not receive further updates». Última
versión hace **16 meses**.

Su fork declarado «para continuar el desarrollo» (`canonical_adaptive_scaffold`)
lleva **14 meses parado**: la continuación también se estancó. Y los relevos
vivos tienen 29 y 3 likes.

**Si el propio equipo de Flutter abandonó su marco adaptable, atarse a uno de
terceros con 3 likes es peor apuesta que escribir sesenta líneas.**

### Y ninguno cubre el marco entero

Ni uno solo junta navegación adaptable + cabecera de página + desbordamiento de
acciones. Lo más cerca sería **combinar dos** (`custom_adaptive_scaffold` +
`toolbar_m3e`) — y entonces ya se está ensamblando el marco a mano, sólo que
con dos dependencias ajenas dentro.

`toolbar_m3e` merece una mención porque **hace exactamente lo que Material no
hace**: acciones que se van solas a un `PopupMenuButton` al pasar de
`maxInlineActions`. Pero tiene **5 likes y 10 meses sin publicar**. No se ata
una aplicación de negocio a eso. **Su idea sí es copiable**, y es poco código.

`forui` es el más vivo de todos (19 días, 436 likes) y sí trae piezas de marco,
pero es **otro lenguaje visual**: adoptarlo significaría rehacer `OrbiTheme`,
que ya tiene su color de marca y su escala. Cambiar el marco entero de la
aplicación para ahorrarse dos comportamientos no sale a cuenta.

---

## 🔴 Recomendación: ESCRIBIRLO — pero escribir muy poco

**No comprar.** Seis razones, la última es la que de verdad decide:

1. **Siete de las nueve ausencias son Material sin enchufar.** No se compra lo
   que ya está instalado y pagado.
2. **Ningún paquete cubre el marco entero**, así que en el mejor caso serían dos
   dependencias y seguir ensamblando a mano.
3. **El único oficial está discontinuado**, y su fork también. El aval de
   `flutter.dev` no protege de nada: el proyecto está muerto igual.
4. **El único que hace lo que Material no hace tiene 5 likes.** Su idea vale;
   su mantenimiento, no.
5. **Los umbrales tienen que salir de la lámina**, que no coincide con Fluent,
   ni con Material 3, ni con lo que Orbi hace hoy. Un paquete que traiga sus
   propios cortes es un estorbo, no un ahorro.
6. **Un marco de terceros es de lo más invasivo que hay, y Orbi tiene
   justamente lo que rompería.** El `ShellRoute` con 18 rutas, la
   `RouteAccessPolicy` que decide qué se puede ver, y un menú que se construye
   desde las capacidades del servidor. Eso es lo primero que un paquete de
   marco quiere gobernar él.

### Y el argumento que zanja

**El problema de Orbi no es que falten piezas: es que las que hay no se usan
igual en todas las pantallas.** Dos barras apiladas en doce pantallas, tres sin
título, once de dieciséis con su propio scroll, seis avisos sueltos.

**Ningún paquete arregla eso.** Lo arregla que `OrbiPageShell` sea obligatorio y
crezca. Comprar un marco nuevo mientras el propio no se usa en seis de quince
pantallas sería cambiar el problema de sitio y pagar una dependencia por ello.

### Lo que hay que escribir, y es poco

| Qué | Cuánto |
|---|---|
| El director que elige `NavigationRail` / `NavigationDrawer` / `NavigationBar` por ancho, con los umbrales **de la lámina** | ~40 líneas, y **hay que escribirlo igual** aunque se compre |
| El plegado de acciones a un `MenuAnchor` cuando no caben | ~60 líneas. Es lo único con dificultad real |
| Cambiar el `ListView` de `ListTile` a mano por `NavigationDrawer`/`NavigationRail` | **borra ~76 líneas** de `operational_shell.dart` |

O sea: el saldo es **cien líneas nuevas y setenta y seis borradas**, sin ninguna
dependencia nueva, y con `header`, `footer`, separadores, desplegables,
buscador, contadores y cabecera de página resueltos por Material.

**Y una copia que sí recomiendo, sin dependencia:** el `maxInlineActions` de
`toolbar_m3e` — decidir cuántas acciones caben inline y mandar el resto a un
menú — es la idea correcta y se escribe en una tarde.

---

# Parte IV — Los dos paquetes que la arquitectura nombró, y la pregunta de Fluent

## 🔴 El titular, corregido: NO estamos en la peor de tres opciones

La sospecha era que estamos «sin el paquete Material que la arquitectura mandó
instalar y sin el marco escrito a mano», o sea en la peor casilla. **La mitad es
cierta y la otra mitad no**, y la diferencia importa:

**`material_ui` ES `package:flutter/material.dart`.** No es un sistema de
componentes de terceros: es el Material del propio SDK **extraído del framework
y republicado en pub.dev** por `flutter.dev`, parte del desacoplamiento
Material/Cupertino anunciado el 13-ago-2026. Los mismos `Scaffold`, `AppBar`,
`NavigationRail`, `NavigationDrawer` de siempre, sólo que versionables aparte.

| | |
|---|---|
| Publicador | **`flutter.dev`**, verificado |
| Última versión | **1.2.0, hace 3 días** (y la 1.1.1 que cita el ADR existe, de hace 9 días) |
| Descargas | **822 000 al mes** · 261 likes · **160/160** pub points |

**Orbi ya usa esos widgets**, vía `flutter/material.dart`. Instalar el paquete
sería cambiar de dónde vienen los mismos widgets, no ganar ninguno. Así que la
«deuda» de no haberlo instalado **no es deuda**: es una migración de empaquetado
pendiente, sin efecto visual.

**Lo que sí falta es el marco. Sólo eso.** No estamos en la peor casilla, sino
en la que tiene una sola cosa que hacer.

### `material_3_expressive`

| | |
|---|---|
| Publicador | **no verificado**, individuo |
| Última versión | 1.1.2, hace 2 días |
| Descargas | 1 580 al mes · **40 likes** |

Trae 45 widgets `M3E*` con física de muelle y morfeo de formas. Tiene
`M3ENavigationRail`/`Drawer`/`Bar` y `M3EButtonGroup` con estrategias de
desbordamiento, **pero no conmuta solo por ancho ni trae cabecera de página**.
El ADR ya lo marcaba como «evaluación selectiva, no contrato obligatorio», y esa
cautela sigue siendo la correcta: 40 likes y un publicador sin verificar no
sostienen el marco de una aplicación de negocio.

### Ninguno de los dos trae marco

Confirmado contra la lista de once piezas: **ni conmutación automática, ni
cabecera título+subtítulo, ni desbordamiento de acciones a un menú.** Ambos dan
piezas sueltas para ensamblar. Lo cual es coherente con la Parte III: el marco
hay que escribirlo, y es poco.

## La pregunta incómoda: ¿por qué no `fluent_ui` directamente?

Fui a buscar la razón escrita antes de opinar. **Existe, está dispersa en cuatro
documentos, y es buena.** La reconstruyo:

**1. La decisión está tomada y es explícita.**
`ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md:358`: «Material 3 oficial; no Fluent
UI.» Y `DESIGN_HANDOFF.md` registra una **decisión del dueño del 11-09-2026**:
componentes reutilizables dentro de `theos_panel/lib/ui/`, **«sin crear otro
paquete»**. En la jerarquía de ese mismo documento, las decisiones explícitas del
dueño son la fuente de precedencia número 1.

**2. Y hay una razón técnica de verdad, no sólo gusto.** En el mismo apartado:

> «El tema visual de Odoo proporciona el color de acento/semilla. Material
> conserva la generación coherente de superficies claras y oscuras.»

Eso es `ColorScheme.fromSeed`: **cada empresa de Odoo trae su color y Material
deriva de él todo el esquema, claro y oscuro, con contrastes coherentes.**
Fluent no hace eso — su `AccentColor` es otra cosa, y `CONTRACTS.md:105` lo
prohíbe expresamente («Ningún `AccentColor` Fluent»). Con Fluent habría que
teñir superficies a mano, que es justo lo que el spec prohíbe dos líneas más
abajo.

**3. Y una razón que nadie escribió pero que este informe mide:** la lámina
aprobada incluye **teléfono con barra inferior de navegación**, y **Fluent no
tiene esa pieza** (Parte I). Con Fluent, el teléfono de la lámina no se puede
construir sin salirse del paquete. `theos_pos` no la tiene precisamente porque
es una aplicación de escritorio Windows; Orbi es de mostrador, con tableta y
teléfono.

### Las dos caras, honestamente

**A favor de Fluent:** ocho años probado en esta casa, y hace de fábrica las dos
cosas que a Material le faltan — el plegado de acciones y la conmutación por
ancho. Adoptarlo ahorraría las cien líneas de la Parte III.

**En contra, y pesa más:** perdería la generación de esquema desde la semilla de
Odoo —que es un requisito de producto, no una preferencia—, no puede dibujar el
teléfono de la lámina, contradice una decisión del dueño de hace un día, y
obligaría a reescribir las quince pantallas y `OrbiTheme` entero. **Cien líneas
contra reescribir la aplicación.**

Y el argumento que zanja: **lo que hace de `theos_pos` una app uniforme no es
Fluent.** La Parte II lo midió — no existe widget compartido, las quince
pantallas repiten el andamiaje a mano, y tiene grietas. Adoptar Fluent traería
sus piezas, no su uniformidad, porque **su uniformidad no existe en el paquete:
está en la disciplina de quien lo usó.**

**Conclusión: la decisión de Material fue correcta y está bien razonada.** Lo
que faltó no fue el paquete: fue escribir el marco que ningún paquete da.
