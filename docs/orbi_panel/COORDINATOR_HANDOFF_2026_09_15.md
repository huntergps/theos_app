# Traspaso al siguiente coordinador — Orbi (15-sep-2026)

Este documento reemplaza a `COORDINATOR_HANDOFF_2026_09_14.md` como fuente vigente
del estado de Orbi, según manda `CLAUDE.md`. Lee el anterior sólo como historia; para
trabajar, este es el que manda.

## Prompt para iniciar

Actúa como coordinador de Orbi ERP en `/Users/elmers/Documents/develop/2026/theos_app`.
Continúa desde este documento, no desde cero. Aplica `docs/orbi_panel/AGENTS.md`
expresamente a tus encargos de implementación, además de los AGENTS de cada ruta.
Reparte en agentes `sonnet` lo que se produce con criterio medio sobre terreno ya
fijado, y en `haiku` lo que se comprueba sin criterio: contar, cotejar, correr un
comando y traer la salida. Nunca `haiku` para juzgar, y nunca `fable`. Sin
subdelegación: ningún subagente relanza otro agente por su cuenta. Cierra cada
agente en cuanto entregue — nunca más de 10 vivos a la vez, y máximo 3 con Flutter
en simultáneo. Tú resuelves arquitectura, permisos, contratos y revisión final.

Primero identifica el estado del worktree (`git log --oneline -1` debe dar `f9f7f9c`
en `orbi/trabajo-pausado-2026-09-11`) y revisa `tasks.json` completo, no sólo
`python3 scripts/check_orbi_plan.py --ready`. Contrasta `tasks.json` con código y
evidencia; no confíes en etiquetas `done` como prueba de calidad. Lee primero este
documento entero antes de asignar trabajo nuevo.

Orden sugerido de los pendientes: **B, C, A**; después revisar D con el dueño (trae
decisiones de producto que no son mías). Aplica las lecciones de la sección final,
sobre todo la de pedir salida literal y la de láminas aprobadas completas.

## Estado verificable

- Rama `orbi/trabajo-pausado-2026-09-11` en `f9f7f9c` («rebuild the home screen
  after the approved operational home layout»), subida a `origin`.
- Publicado en `https://orbi.galapagos.tech`: `f9f7f9c`, confirmado con
  `curl -s https://orbi.galapagos.tech/orbi-commit.txt` → `f9f7f9c`.
- Compuertas:
  - `f9f7f9c`: `orbi_runtime` +569 pruebas verdes, `theos_panel` +1052 ~13 verdes,
    `analyze-orbi` limpio, `check-secrets` limpio.
  - `71f7007`: paquetes clásicos verdes (`theos_pos` +1155, `theos_pos_core`
    +1842 ~21, `odoo_sdk` +622, `odoo_widgets` +218, `flutter_qweb` +102,
    `generated-check` limpio).
  - Anomalía sin causa conocida: una corrida de `orbi_runtime` salió con `rc=144`
    y el reintento fue verde (probable competencia de Flutter, no un fallo real).
- Publicaciones del día: `cb8e4c1`, `71f7007`, `f9f7f9c` (todas verificadas con
  `git cat-file -t` y `git log -1 --format=%s`).
- La app de ESCRITORIO del dueño (`theos_panel/build/macos/Build/Products/Debug/Orbi
  ERP.app`, compilada a las 07:42) es ANTERIOR a lo integrado hoy: hay que
  recompilar con `make run-orbi-macos` antes de usarla para revisar algo de esta
  lista.
- No hay agentes de este encargo trabajando ahora. No reanudar tareas antiguas sin
  nuevo encargo concreto.

## Lo integrado hoy (`git log --oneline b0645cd..f9f7f9c`)

1. **`b0f0963`** — campo de fecha de envases con borde de `TextBox`; cifra
   «Enviados» en `bodyStrong`.
2. **`b1e1eb8` + `cb8e4c1`** — «Estado de envases» según lámina ENV-01 en las 4
   vistas: filtros Producto/Presentación/Ubicación, chip «propios» con el par de
   `InfoBadge`, `Expander`, rejilla de 3 columnas o filas, Clientes/Proveedores,
   foto de `product.product.image_128` con sonda guardada por servidor, gancho
   `cardBuilder` en `OrbiListing`, título compacto en `OrbiPage`.
3. **`9b44729` + `1442f17` + `71f7007`** — barra inferior en ventana vertical de
   ancho ≤ 1024 (láminas SHELL-01/ENV-01): logo `orbi_logo.svg` a 32 px teñido
   como `theos_pos`, botón «+» por ruta (hoy Envases → Enviar), «Actividades»
   agrupada en «Más», franja de estado.
4. **`3c55ef8` + `f464b5a`** — PIN según lámina ACC-02: `Button`, `FilledButton`
   «Entrar», puntos visibles, `Divider`, `InfoBar`; se arregló el estado real
   «PIN inválido» con rueda de carga que antes se quedaba mal.
5. **`f9f7f9c`** — Inicio según lámina ACC-03: «Inicio operativo», cifras sólo con
   datos existentes, `TabView` de Fluent, tabla o tarjetas con chips, tarjetas por
   módulo. Fuera por falta de datos de Odoo: Despachos, Aprobaciones,
   minigráficos.

Los nueve SHA anteriores (`b0f0963`, `b1e1eb8`, `cb8e4c1`, `9b44729`, `1442f17`,
`71f7007`, `3c55ef8`, `f464b5a`, `f9f7f9c`) se verificaron uno por uno con
`git cat-file -t` y `git log -1 --format=%s` y el rango coincide exactamente con
`git log --oneline b0645cd..f9f7f9c`.

## Pendientes

Ramas `wip/*` verificadas con `git ls-remote --heads origin 'wip/*'` — existen en
`origin`, **ninguna revisada ni integrada**:

```
595ef6f1b61e2d567e159637ced47b1b5f4088aa	refs/heads/wip/bloqueo-sobrevive-recarga
3a7b8d393be309e62a46bbfb99091c0700deb1c1	refs/heads/wip/inicio-acc03-correcciones
f9f7f9cdd77897db1daf58d28847e792f53d0593	refs/heads/wip/preferencias-usuario-al-entrar
```

### A. `wip/inicio-acc03-correcciones` (`3a7b8d3`)

Está encima de `837cc94` sobre `4c84c69` (`4c84c69` es el mismo contenido de
`f9f7f9c` pero rebasado — mismo mensaje de commit, «rebuild the home screen after
the approved operational home layout»). Al integrar: **cherry-pick sólo `837cc94`
y `3a7b8d3`**, no la rama completa.

- **`837cc94`, hecho:** cifras con miles en una línea (`home_dashboard_view.dart:24-37`),
  fechas en filas (`u08_scope_adapters.dart:231,269,311,356`), tarjeta compacta de
  teléfono (`home_center.dart` `_documentCard`), tarjetas por módulo junto a la
  tabla.
- **`3a7b8d3`, SIN PROBAR, a medias:**
  - Contraste de chips en oscuro (`home_resume_status.dart:83-89`); la prueba (j)
    de `home_center_test.dart` estaba en rojo porque el umbral
    `luminancia > 0.5` falla para «Error». Arreglo ya decidido: elegir el color
    de mayor contraste real entre negro y blanco, en vez de ese umbral fijo.
  - `showFilterBox: false` en `envases_saldo_terceros_screen.dart:204-211` (evita
    la doble caja de filtro); falta su prueba.
- **Sin hacer, decisión pendiente:** píldoras y ocultar «Columnas» en teléfono,
  porque `clients_screen_composition_test.dart:158-161` exige NO ocultarlos en
  ningún listado. Antes de tocarlo hay que resolver esa contradicción, no
  saltársela.

### B. `wip/bloqueo-sobrevive-recarga` (`595ef6f`)

Falla en web con Mepriga: con «Guardar clave» ACTIVADO, la sesión se bloqueó por
inactividad y al recargar salió la pantalla de acceso, sin llave guardada y con
«Guardar clave» apagado.

- Prueba de control `theos_panel/test/app/workspace_lock_survives_reload_test.dart`:
  PASA en `f9f7f9c` (la recarga sola, sin bloqueo, conserva todo).
- Causa candidata sin confirmar: el bloqueo es sólo visual y la sincronización de
  fondo sigue corriendo. Un 401 → `handleSessionExpired`
  (`auth_controller.dart:814-837`, escuchado en `router.dart:2832-2840`) →
  `closeExpired()` (`native_auth_service.dart:1415-1440`), que borra la llave
  (línea 1431) y la bandera de recordada (línea 1435). Posible 401 por
  vencimiento de la llave sin renovación (`renewApiKeyIfNeeded`,
  `native_auth_service.dart:1494-1598`, flag `base.enable_programmatic_api_keys`).
- **Decidido y SIN hacer:**
  1. Prueba «401 estando bloqueado → recargar → acceso» que falle en `f9f7f9c`
     (reproduce el bug antes de tocar código).
  2. Pausar `scopeSyncCoordinatorProvider` mientras `workspaceLockProvider` sea
     verdadero (mismo patrón que `scopeRouteModePauseProvider`,
     `router.dart:846-867`) y reanudar con `requestSync` al desbloquear, sin
     tocar `closeExpired`.
  3. Revisar en Mepriga, en SÓLO LECTURA, el vencimiento de llaves y si el
     servidor permite renovar.

### C. `wip/preferencias-usuario-al-entrar` (= `f9f7f9c`, sin código todavía)

Falla en escritorio con ERP2: «Mis preferencias» dice «Tu usuario todavía no se
sincronizó en este dispositivo».

- El diálogo lee `res_users` local (`user_preferences_dialog.dart:153-160`;
  `orbi_runtime/lib/src/account/user_preferences.dart:211-214`).
- Causa: el trabajo `catalog:currentUser` corre casi al final del primer ciclo
  (`runtime_catalog_composition.dart:127-206`; `sync_coordinator_impl.dart:187-220`),
  que contra ERP2 ronda 25-35 s (17 catálogos medidos en 21,6 s).
- Orden del dueño: al entrar deben cargarse TODAS las preferencias para trabajar
  sin conexión, y la foto del usuario debe verse en el avatar.
- Diseño decidido: un disparador enganchado a `scopeCatalogCompositionProvider`
  (`router.dart:624-638`) que llame `composition.sync('currentUser')` y
  `('currentUserPartner')` (`runtime_catalog_composition.dart:218-226`), con el
  provider en un archivo nuevo. `_UserAvatarMenu` muestra la foto.
- **Fallo real encontrado, hay que corregirlo primero:** JSON-2 devuelve binarios
  como `{"content": base64, "size": N}` y `local_catalog_adapters.dart:624` los
  guarda con `toStringOrNull`, lo que corrompe la foto
  (`user_preferences_dialog.dart:379` hace `base64Decode` sobre ese dato ya
  corrupto). Hay que desenvolver el `content` y tratar el SVG generado como «sin
  foto». Probablemente el mismo fallo está en `readImages` de
  `orbi_runtime/lib/src/envases/envases_existencias_reader.dart` (fotos de
  producto) — revisarlo también. En ERP2, `res.users` tiene `avatar_128` e
  `image_128`.

### D. Auditoría de envases contra láminas (capturas temporales, scratchpad de sesión)

Marca cada punto como «requiere dato de Odoo» o «requiere decisión del dueño»
antes de asignarlo — no es trabajo de implementación directa todavía.

- **Por recibir:** faltan las pestañas «Entregas/Devoluciones/Tránsitos/Clientes/
  Proveedores/Tomas» (hoy son destinos del menú, no pestañas), el título
  «Pendientes de envases» y el panel lateral con «Custodia del cliente» y
  «Conversión de presentación» (`envases_por_recibir_screen.dart:140-155,230-263`).
  Coincide en tablet (834) y teléfono (390).
- **Detalle del traslado:** faltan el chip de estado junto al título
  (`envases_traslado_detalle.dart:57-65`), «Custodia del cliente», «Conversión»,
  el breadcrumb y las acciones «Cerrar/Imprimir/Marcar como entregado» (hoy dice
  «Registrar recepción/Dar por perdido», `:229-247`).
- **Recibir (ENV-06):** faltan breadcrumb, campos «Devolución/Entrega origen/
  Cliente/Responsable/Fecha recepción», «Motivo», «Observaciones», botón
  «Revisar» y fila de totales; el chip dice «En tránsito» y la lámina dice «En
  recepción» (`envases_recibir_form.dart:257-267,296,299-314`).
- **Enviar:** sin lámina específica todavía — no hay contra qué comparar.
- **Movimientos (ENV-02):** faltan «Tipo» y «Estado» (Odoo no los entrega hoy,
  `envases_movimientos_screen.dart:20-24` — esto es dato del servidor, no un
  bug de Orbi), «+ Nuevo movimiento» y panel lateral de detalle.
- **Saldo de terceros:** doble caja de filtro (ver punto A arriba); faltan las
  cifras «Entregados/Devueltos/Pendientes» y las acciones «Registrar devolución/
  Preparar facturación» (hoy es de sólo lectura por diseño — confirmar con el
  dueño si eso sigue así).

### E. Del traspaso anterior

Siguen sin empezar la ola 3 (tablas y tiempo real de dinero y pedidos) y el resto
de la ola 4.

## Lecciones

Cada una tiene su archivo en
`/Users/elmers/.claude/projects/-Users-elmers-Documents-develop-2026-theos-app/memory/`:

- Los subagentes con Flutter necesitan el parámetro Bash `timeout: 600000` y
  envolver el comando con `perl -e 'alarm 580; exec @ARGV'`
  (`gotcha-agente-flutter-test-colgado-pasa-a-segundo-plano.md`).
- Máximo 3 agentes a la vez corriendo Flutter.
- Capturas legibles: `FontLoader('packages/fluent_ui/FluentIcons')`, Arial del
  sistema y `fontFamily` explícito en el constructor de `FluentThemeData`.
- Una lámina aprobada se aplica completa en sus 4 vistas, no se recorta sin
  preguntar (`orbi-laminas-aprobadas-se-aplican-completas.md`).
- No decir «listo» sin probar contra un Odoo real, y decir en qué app y en qué
  commit quedó (`orbi-listo-solo-con-prueba-real-y-destino-claro.md`).
- En un puente Riverpod → Stream, construir el disparador ANTES del
  `ref.listen(fireImmediately: true)`, o arranca «sin red» para siempre
  (`gotcha-broadcast-pierde-valor-de-fireimmediately.md`).
- Publicar por partes lo que ya está revisado, no esperar a tener todo junto.
- Coordinar con pocos tokens: «cerrar» significa terminar, encargos cortos, una
  sola ronda de correcciones, pocas capturas
  (`orbi-coordinar-con-pocos-tokens.md`).

No tomar este traspaso como autorización para lanzar trabajo mientras el dueño
mantenga la pausa. El nuevo coordinador debe recibir el encargo de continuar antes
de asignar nada.
