# Traspaso al siguiente coordinador — Orbi (14-sep-2026)

El dueño pidió detener este trabajo y dejarlo preparado para otro coordinador con
agentes económicos. No hay autorización para declarar el proyecto terminado. Este
documento reemplaza a `COORDINATOR_HANDOFF_2026_09_11.md` como fuente vigente del
estado de Orbi, según manda `CLAUDE.md`.

## Prompt para iniciar

Actúa como coordinador de Orbi ERP en `/Users/elmers/Documents/develop/2026/theos_app`.
Continúa desde este documento, no desde cero. Aplica `docs/orbi_panel/AGENTS.md`
expresamente a tus encargos de implementación, además de los AGENTS de cada ruta.
Reparte en agentes `sonnet` lo que se produce con criterio medio sobre terreno ya
fijado, y en `haiku` lo que se comprueba sin criterio: contar, cotejar, correr un
comando y traer la salida. Nunca `haiku` para juzgar, y nunca `fable`. Sin
subdelegación: ningún subagente relanza otro agente por su cuenta. Cierra cada
agente en cuanto entregue. Tú resuelves arquitectura, permisos, contratos y revisión
final.

Primero identifica el estado del worktree (`git log --oneline -1` debe dar
`05eeb83`) y revisa `tasks.json` completo, no sólo
`python3 scripts/check_orbi_plan.py --ready`. Contrasta `tasks.json` con código y
evidencia; no confíes en etiquetas `done` como prueba de calidad. Lee primero este
documento entero antes de asignar trabajo nuevo.

## Estado verificable al detener

- Último commit integrado en `orbi/trabajo-pausado-2026-09-11`: `05eeb83`, «subscribe
  sync triggers before replaying the current network signal».
  Verificado con `git log --oneline bdee4f5..9b2089f`: además de `bdee4f5` se
  integraron, en orden, `d99e818` (conteo SRI cada 5 min), `7907b05` (este
  traspaso), `f40736b`, `47d5480`, `8733955`, `39ace0f` (detección de base de
  Odoo reinstalada) y `9b2089f` (prueba de SRI adaptada a esa huella). Después
  de `9b2089f`, verificado con `git log --oneline 9b2089f..05eeb83`, se
  integraron `3015964` (este traspaso), `afc9ae7` (navegación de envases sin
  historial), `92a8a79` y `6c0ed87` (drenar la cola al encolar en línea; la
  segunda cambia la señal de conteo a inserciones) y `05eeb83` (los
  disparadores de sync se suscriben antes de recibir la señal de red actual).
- **Publicado en `https://orbi.galapagos.tech` durante el día:** se publicaron
  varias versiones a lo largo de la jornada. La que quedó al final de la tarde
  fue `90a37dc` («take the user timezone offset from Odoo», hora del servidor).
  «Guardar clave» corresponde al rango `40f47e8..faa7de8` (`40f47e8` «keep a
  single stable GoRouter across auth changes», `faa7de8` «cover router
  stability and login preference contract»); la sesión que sobrevive a cerrar
  la pestaña es `6becdca` («keep the session open across tab and app
  restarts»). Confirmado con `git cat-file -t` y `git log -1 --format=%s` sobre
  cada sha. Con el traspaso de `9b2089f` se publicó ese commit, confirmado
  entonces en `orbi.galapagos.tech/orbi-commit.txt`. Con este traspaso se
  publicó `05eeb83`, confirmado igual con `curl` sobre
  `orbi.galapagos.tech/orbi-commit.txt`.
- Cifras de la compuerta sobre `05eeb83`: `make verify` en `6c0ed87` «+1155: All
  tests passed!» (`05eeb83` sólo toca `theos_panel`); `orbi_runtime` «+564: All
  tests passed!»; `theos_panel` «+1010 ~13: All tests passed!»; `analyze-orbi`
  «No issues found!».
- No hay agentes de este encargo trabajando ahora. No reanudar tareas antiguas sin
  nuevo encargo concreto.

## Lo integrado hoy (hasta `05eeb83`)

1. **Acceso y sesión.**
   - Router GoRouter único y estable (`40f47e8`); «Guardar clave» sin guardado a
     medio escribir (`bc196a7`, cubierto por `faa7de8`).
   - Sesión que sobrevive a cerrar la pestaña (`6becdca`): marca no secreta
     `orbi/auth/open_session` con servidor, base y userId. Bandera «recordada»
     separada `orbi/auth/remembered`, con migración de instalaciones previas
     (`c89defd`, ampliado y probado en `68e928b` y `f8d7215`).
   - Volver a la última pantalla por usuario (`e31b564`). Aviso visible si el
     navegador guarda datos locales sólo en memoria (`9f558c0`).
2. **Envases.**
   - Borradores durables de envío y recepción: no reviven tras registrar, guardan
     al salir y reintentan un conflicto de revisión (`97a426e`, `a853d93`).
   - Formularios y listas rehechos según las láminas
     `visual_baselines/approved/round-02/ENV-01.png`, `ENV-02.png`, `ENV-03.png`,
     `ENV-06.png` y `visual_baselines/approved/BODEGA-ENVASES-v1.png`
     (`4149b6c`, `ed473f8`), y pulidos tras revisar capturas 1920x1080 y 390x844
     contra esos aprobados (`bdee4f5`): acciones bajo el contenido con
     «Cancelar», un solo buscador (`showFilterBox`), panel de detalle con título.
     Fechas en español fijando `orbiAppLocale` en
     `theos_panel/lib/app/orbi_app.dart`, que nunca traía `locale:` (`548684e`).
   - Errores de carga de bodega con «Reintentar» en vez de lista vacía (`b31b3b9`).
3. **Hora del servidor:** `ClientPolicyService`/`ClientPolicySyncTrigger` leen
   `app.sync.client.policy.client_policy()` (`6809e3e`), toman el desfase de zona
   horaria real del usuario en vez de una tabla fija de UTC por nombre de zona
   (`90a37dc`), arrancan el temporizador y persisten la marca de reloj atrasado
   (`c6d572f`). Sincroniza al entrar, al volver al frente y cada 15 min.
4. **Límite sin conexión:** 3 días por omisión, parametrizable en Odoo vía el
   mismo `client_policy()`. `OfflineAllowanceStore` decide antes de restaurar;
   `AuthServiceStatus.offlineExpired` bloquea el armazón (sin cerrar la sesión)
   si el límite vence estando abierta (`fff9a45`).
5. **Bloqueo por inactividad:** 15 min desde `inactivity_lock_minutes` de Odoo,
   temporizador propio en `orbi_runtime` (`1ca8e3c`); desbloqueo con PIN
   conservando permisos, sin tocar `AuthNotifier` ni el snapshot de capacidades
   (`180a03b`); arranque bloqueado sólo al restaurar una sesión ya vencida, nunca
   justo tras un ingreso interactivo (`fe6f1c2`).
6. **PIN:** retención de la llave por PIN vía `orbi/auth/pin_retained`,
   independiente de «Guardar clave» (`647e586`); selector de usuarios PIN de la
   misma base (`a034495`); PIN sin conexión dentro del límite de 3 días
   (`33c1061`); migración de PIN existentes de instalaciones previas, por
   servidor y con reintento si falla (`1613324`).
7. **Universal:** `ServerFeatureStore` sondea con `fields_get` (evidencia gana,
   `unknown` nunca es indisponible) `sale.order`, `collection.session`,
   `approval.request` y `l10n_ec.envases.operacion`, persistido por servidor y
   base. El menú exige permiso Y módulo disponible; una denegación por módulo
   ausente lo dice explícitamente en vez de apuntar a un supervisor.
   `SessionApprovalPort` se salta el RPC de `approval.request` cuando la sonda
   ya confirmó que no existe (`556c3a7`).
8. **Ventas estándar sin `l10n_ec_collection_box_pos`:** `SaleServerProfileResolver`
   sondea con `fields_get` si `sale.order`/`sale.order.line` tienen `x_uuid`; sin
   la extensión, `create` omite `x_uuid`, un create ambiguo nunca es
   `retry_safe` (queda en revisión manual) y la confirmación usa `action_confirm`
   tanto en la cola como en línea (`9c1176a`). Un fallo de sonda antes de
   confirmar se reporta como `server_profile_unknown` — «no se envió nada» — en
   vez de ambigüedad genérica (`6e4ab34`).
9. **Señales del armazón:** ambiente pruebas/producción guardado explícitamente
   por servidor (nunca adivinado del nombre), nombre de equipo editable
   (hostname nativo o user-agent en web), pastilla de caja abierta reusando el
   provider existente, y pastilla de pendientes del SRI leyendo el campo
   genérico `account.move.edi_state` con `hasField` (`38cff49`).
10. **SDK:** el sondeo de conectividad ahora reprograma sólo tras terminar el
    anterior, cancela con `CancelToken` al detener y descarta resultados tardíos
    con un contador de generación (`e973311`) — corrige un test que fallaba
    siempre en aislamiento y de forma intermitente en `make verify`.
11. **Detección de base de Odoo reinstalada:** huella de `res.users.create_date`
    guardada en `sync_metadata` y comprobada en cada activación EN LÍNEA
    (`SessionRuntime.activate` con cliente). Se trata como base reinstalada
    cuando la huella guardada no coincide con la del servidor, o, si todavía
    no había huella guardada, cuando hay datos de escritura local más viejos
    que el alta de ese usuario en Odoo menos una hora. En ese caso se vacían
    las tablas locales y se muestra un aviso en el
    armazón que queda visible hasta que la persona lo cierra, en vez de
    desaparecer solo (`f40736b` vacía datos locales al detectar el reemplazo,
    `47d5480` corrige el criterio a «dato local más viejo que el usuario de
    Odoo», `8733955` mantiene el aviso hasta que se reconoce, `39ace0f` corrige
    el parseo de fechas de Odoo a UTC al comparar, `9b2089f` adapta la prueba
    de pendientes del SRI a esta huella). Un fallo de red al leer la huella en
    el arranque **no cierra la sesión**: `restoreOnce` en
    `theos_panel/lib/features/auth/auth_controller.dart:166-179` distingue un
    rechazo explícito de credencial (ahí sí exige volver a entrar) de
    cualquier otro error — sin red, timeout, DNS — que cae al respaldo offline
    igual que antes.
12. **Navegación de envases (`afc9ae7`):** `/envases/enviar` se abre desde el
    menú lateral con `go()` y Orbi restaura la última ubicación con `go()`, así
    que `context.pop()` lanzaba «There is nothing to pop»; ahora
    `volverOEnvases` usa `pop()` si hay historial y si no navega a `/envases` o
    `/envases/por-recibir`. `onCompleted` salió del `try` del registro, así que
    un fallo de navegación ya no se muestra como «No se pudo registrar…».
    Texto del aviso: «Guardado en este equipo. Se envía a Odoo en cuanto haya
    conexión.».
13. **Cola offline (`92a8a79`, `6c0ed87`):** `DurableEnvasesOperations` siempre
    encola, y nadie pedía drenar estando en línea (el disparador de reconexión
    sólo actúa en el paso a conectado, y el respaldo de 5 min se apaga con
    tiempo real vivo). `SyncQueuedOperationTrigger` escucha
    `OfflineQueueDataSource.watchQueuedInserts()` (inserciones en
    `offline_queue`, no el conteo, que se anula si en la misma transacción sale
    una operación y entra otra) y pide `requestSync` sólo del trabajo
    `operations` con debounce de 300 ms.
14. **Orden del puente de red (`05eeb83`):** `StreamController.broadcast()`
    descarta lo emitido sin oyentes y `ref.listen(..., fireImmediately: true)`
    emite de forma síncrona; en `router.dart` los disparadores se construían
    DESPUÉS, así que con la red ya presente arrancaban «sin red». Afectaba al
    disparador de la cola y al respaldo de 5 min. Ahora se construyen antes.

## En curso al redactar (queda pendiente, sin commit)

- Refresco del contador de pendientes del SRI cada 5 min (hoy sólo se lee al
  cargar el armazón, según `38cff49`).

## Servidores (reportado por el coordinador; repositorio `dev_odoo20`, no
verificable desde este worktree)

- `l10n_ec_app_sync` 19.1.6 (fusión `bd4392db6` en `origin/master`) desplegado en
  Mepriga y en ERP2. En ERP2 va junto con `l10n_ec_collection_box_pos` 19.1.11:
  se suben juntos porque la 1.4 mudó `mobile_set_im_status`.
- newerp sigue en 19.1.4. Procedimiento documentado y sin ejecutar en
  `dev_odoo20/docs/DESPLIEGUE_APP_SYNC_COLLECTION_BOX_POS_NEWERP_14SEP2026.md`:
  requiere autorización del dueño antes de tocar producción.
- Mepriga: prueba real de envases desde Orbi con soledad.jinez (envío de 24
  Pilsener; recepción de 22 buenas + 1 dañada, 1 pendiente, sin duplicados). La
  base `envases` se está reinstalando esa misma noche, con los mismos ids de
  usuario y posiblemente otros ids de productos y ubicaciones — de ahí que la
  detección de base reinstalada (arriba) sea bloqueante antes de volver a abrir
  sesión ahí.

## Decisiones del dueño del día

- La sesión web sobrevive a cerrar la pestaña.
- PIN con tope de vendedor y selector de usuarios.
- Bloqueo por inactividad a los 15 min, desbloqueo con PIN que conserva la
  sesión y sus permisos.
- 3 días sin conexión, parametrizable desde Odoo.
- El ambiente (pruebas/producción) lo dice el dueño por servidor: ERP2 y Mepriga
  son pruebas, newerp es producción.
- Orbi debe ser universal: Mepriga no tiene ventas y aun así debe funcionar.
- Ventas estándar sin el módulo POS de cobros.
- No tocar la clave guardada de carlos.guajala.
- El envase pendiente y la operación con error en Mepriga «da igual, son
  pruebas» — no ameritan corrección urgente.

## Pendientes y riesgos conocidos

- **No abrir Orbi con Soledad en Mepriga** hasta publicar la detección de base
  reinstalada (arriba, «en curso»): la base `envases` cambia de ids esta noche.
- El campo de fecha de envases tiene poco borde visual y la cifra de «Enviados»
  se ve algo más pequeña que el resto — pendiente de ajuste visual menor, no
  bloqueante.
- Las capturas de esta jornada se hicieron con pruebas de widgets, no con
  capturas de navegador real: la extensión Claude in Chrome dejó de responder.
  No hay carpeta `reports/evidence/2026-09-14/` — no inventar que sí la hay.
- La ola 3 (tablas y tiempo real de dinero y pedidos) y el resto de la ola 4
  siguen sin empezar.

## Lecciones de proceso

- Los agentes que dejan `flutter test` corriendo en segundo plano terminan sin
  entregar: pedirlo con Bash en primer plano y `timeout: 600000`.
- No borrar el worktree de un agente antes de que se cierre formalmente (ver
  `gotcha-agente-cerrado-sigue-escribiendo.md`: `ListAgents`/`TaskStop` antes de
  reasignar su fichero).
- Dejar temporales sueltos en el árbol principal tumba la compuerta (ver
  `gotcha-git-diff-check-en-copia-limpia-no-revisa-nada.md`: `git diff --check`
  sobre una copia limpia no revisa nada; en compuertas hay que comparar entre
  commits).
- Leer los logs de la compuerta antes de creer un «verde» reportado por un
  agente — un agente barato puede haber corrido el comando equivocado.
- Un subagente puede relanzar otro agente si no se le prohíbe explícitamente en
  el encargo: prohibirlo siempre por escrito.
- Los agentes de navegador comparten la sesión real del dueño en
  `orbi.galapagos.tech`: cuidado con qué se hace ahí en su nombre.

## Referencias de lectura dirigida

`ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md` (offline_max_days, inactivity_lock_minutes),
`ARCHITECTURE.md`, `SPEC.md`, `UI_COHERENCE_RULES.md`, `NAVIGATION_CAPABILITY_MATRIX.md`,
`ENVASES_DOMAIN_CONTRACT.md`, `ESTANDAR_LAMINAS_2026_09_12.md`,
`visual_baselines/approved/round-02/` (ENV-01/02/03/06) y
`visual_baselines/approved/BODEGA-ENVASES-v1.png`, `AGENTS.md`. Leer sólo lo
aplicable a cada subtarea; no releer todo antes de cada encargo pequeño.

No tomar este traspaso como autorización para lanzar trabajo mientras el dueño
mantenga la pausa. El nuevo coordinador debe recibir el encargo de continuar.

## En curso al cerrar

No queda nada en ramas de agentes. Los dos arreglos que quedaron pendientes en
el traspaso anterior (navegación de envases sin historial y drenar la cola
offline al encolar en línea) ya están integrados en `orbi/trabajo-pausado-2026-09-11`
(`afc9ae7`, `92a8a79`, `6c0ed87`) y publicados en `orbi.galapagos.tech` como
parte de `05eeb83` (ver «Estado verificable al detener» y el punto 14 de «Lo
integrado hoy» sobre el orden del puente de red, que también corregía el
disparador de esta misma cola).
