# Tareas: Theos App — versión productiva de venta y caja

> **Política vigente:** la aplicación nunca ha estado en producción. Cada
> instalación crea el esquema Drift vigente y scopes aislados por
> servidor/base/usuario. Runtime fijado: Flutter global 3.47.1 / Dart 3.13.1.

## Estado

- Especificación: `PROJECT_COMPLETION_V1.md`
- Plan aprobado para implementación: `PROJECT_COMPLETION_V1_PLAN.md`
- Fase activa: F8 — recorridos E2E y cierre de la matriz externa
- Implementación funcional completada: F2–F7; F0/F1 conservan sus verificaciones
  externas documentadas y F9 permanece pendiente
- Pendiente externo: F0.5 requiere la primera ejecución de GitHub Actions,
  especialmente su build en Windows.
- El E2E nativo read-only contra ERP2 está cerrado: validó dos arranques con
  restauración segura, permisos, todos los módulos permitidos y sus loaders,
  los cuatro accesos rápidos, layouts compactos y guard de ruta. Los
  smoke C1 de la matriz Odoo 19/20 siguen habilitándose con
  `ODOO19_*`/`ODOO20_*` y quedan omitidos sin credenciales.
- Regresión global local posterior a F3–F7: cerrada con todos los analyzers
  limpios y 3615 pruebas aprobadas; el SDK registra además 14 pruebas omitidas
  de forma explícita. Conteo por paquete: SDK 1787, core 559, widgets 188,
  QWeb 102 y app 979.
- Regla: cada tarea modifica aproximadamente cinco archivos manuales como
  máximo; lockfiles y fuentes generadas se consideran salidas verificables.

## F0 — Baseline reproducible

- [x] **F0.1 — Resolver dependencias con el SDK fijado.**
  - Aceptación: Flutter 3.47.1/Dart 3.13.1 resuelve los cinco paquetes y los
    lockfiles quedan versionables.
  - Verificar: `make deps` con Flutter 3.47.1.
  - Archivos: `.gitignore`, `*/pubspec.lock`.

- [x] **F0.2 — Exponer comandos raíz.**
  - Aceptación: dependencias, generación, análisis, pruebas y cinco builds se
    invocan desde la raíz sin una herramienta de workspace adicional.
  - Verificar: `make help` y `make verify`.
  - Archivos: `Makefile`.

- [x] **F0.3 — Añadir guardia básica de secretos.**
  - Aceptación: CI rechaza llaves privadas, archivos de credenciales, tokens
    conocidos y URLs con credenciales sin imprimir el valor detectado.
  - Verificar: `make check-secrets`.
  - Archivos: `scripts/check_secrets.sh`, `.github/workflows/ci.yml`.

- [x] **F0.4 — Documentar el monorepo y archivar el estado histórico.**
  - Aceptación: instalación, arquitectura, plataformas, límites y fuentes de
    verdad actuales están visibles desde la raíz; informes previos se declaran
    históricos.
  - Verificar: revisión de enlaces y comandos del `README.md`.
  - Archivos: `README.md`, este documento.

- [x] **F0.5 — Crear gates CI de calidad y builds.**
  - Aceptación: CI analiza y prueba los cinco paquetes, valida generación y
    secretos, y construye iOS sin firma, Android App Bundle, macOS, Windows y
    web con Flutter 3.47.1.
  - Verificar: sintaxis del workflow y ejecución de `make verify`; los builds
    específicos de OS terminan de validarse en sus runners.
  - Archivos: `.github/workflows/ci.yml`.
  - Estado: workflow implementado con gates de calidad antes de los builds,
    cancelación de ejecuciones obsoletas, límites de tiempo y artefactos
    retenidos siete días. Análisis, pruebas, generación, escaneo de secretos,
    formato y builds web, iOS sin firma, macOS y Android están verdes
    localmente. La ejecución en GitHub Actions queda como verificación externa
    del runner Windows y no requiere secretos reales.

## F1 — Contrato JSON-2 y capacidades

- [x] **F1.1 — Congelar el contrato HTTP JSON-2 con fixtures.**
  - Aceptación: pruebas distinguen `ids`, `kwargs` y `context` para CRUD,
    método de modelo y método de recordset.
  - Verificar: `cd odoo_sdk && dart test test/api/json2_transport_test.dart`.
  - Archivos: transporte/cliente JSON-2 y hasta tres fixtures/tests del SDK.
  - Estado: el contrato cubre métodos de modelo, métodos de recordset, CRUD,
    mezcla explícita de contexto y la única compatibilidad de `args`.
    La suite completa del SDK permanece verde con Dart 3.13.1.

- [x] **F1.2 — Exponer `OdooTransport` mediante `OdooClient`.**
  - Aceptación: la fachada conserva compatibilidad y ninguna feature nueva
    construye URLs `/json/2`.
  - Verificar: `cd odoo_sdk && dart analyze && dart test`.
  - Archivos: contrato, implementación JSON-2, fachada y exports del SDK.
  - Estado: `Json2Transport` implementa el contrato estable y
    `OdooClient.transport` lo expone sin retirar `crud` ni la fachada actual.

- [x] **F1.3 — Detectar versión y capacidades críticas.**
  - Aceptación: 19.x y 20.x producen una matriz tipada de bancos, UoM, stock,
    caja, cobro/factura, reportes y sincronización HTTP.
  - Verificar: pruebas unitarias con fixtures 19/20 y smoke read-only opt-in.
  - Archivos: versión, capacidades, detector y sus pruebas.
  - Estado: matriz tipada implementada con evidencia prioritaria sobre hints de
    versión; estados no comprobados permanecen `unknown`.

- [x] **F1.4 — Normalizar errores y sanear integración.**
  - Aceptación: acceso, validación, desconexión, método/campo ausente y sesión
    expirada se convierten en excepciones tipadas sin datos sensibles.
  - Verificar: suite de errores, interceptores y sanitización del SDK.
  - Archivos: excepciones, mapper/interceptor y pruebas.
  - Estado: respuestas JSON-2 y fallos de transporte se mapean a errores
    tipados; incluye
    `SessionExpiredException` HTTP 403/code 100, cancelación, timeouts y
    saneado recursivo de credenciales antes de exponer excepciones.

- [x] **F1.5 — Corregir call sites inválidos descubiertos por el contrato.**
  - Aceptación: métodos de recordset usan `ids:` y los argumentos funcionales
    permanecen en `kwargs`; no se cambian aún operaciones financieras sin una
    prueba del backend.
  - Verificar: búsquedas estáticas, pruebas afectadas y analyzer del paquete.
  - Archivos: lotes de hasta cuatro call sites más su prueba.
  - Estado: seis call sites seguros migrados en dos lotes. Catorce llamadas
    financieras/custom permanecen inventariadas para F4 porque requieren una
    prueba controlada del backend; `mail.activity.action_cancel` y
    `account.advance.action_return` no existen con esos nombres en Odoo 20.

## F2 — Sesión, permisos y aislamiento

- [x] **F2.1 — Política de rutas y permisos default-deny.**
  - Aceptación: una sola matriz cubre vendedor, cajero, supervisor y admin;
    reconoce rutas parametrizadas y aliases; toda ruta desconocida se deniega.
  - Verificar: `cd theos_pos && flutter test test/core/navigation/route_access_policy_test.dart && flutter analyze`.
  - Archivos: grupos, política de rutas, menú y prueba.
  - Estado: la matriz central cubre roles, rutas literales y parametrizadas;
    menú y comprobación directa comparten una política default-deny. Las 13
    pruebas focalizadas y el analyzer pasan con Flutter 3.47.1.

- [x] **F2.2 — Snapshot atómico de grupos/permisos.**
  - Aceptación: todos los grupos se consultan antes de publicar; cero grupos
    limpia permisos anteriores y un fallo parcial no mezcla usuarios.
  - Verificar: `cd theos_pos && flutter test test/features/authentication/permission_sync_test.dart && flutter analyze`.
  - Archivos: matriz de grupos, repositorios/provider y prueba.
  - Dependencia: F2.1.
  - Estado: se resuelven los siete grupos antes de una escritura única; cero
    grupos revoca el estado anterior y fallos parciales no publican. Una
    generación en el provider descarta respuestas tardías de otro usuario.

- [x] **F2.3 — Persistencia segura para clean-install.**
  - Aceptación: SharedPreferences no conserva API key/session/token; nativo
    restaura mediante una referencia al store seguro y web usa sesión efímera.
  - Verificar: prueba de secure session store, analyzer y escaneo de secretos.
  - Archivos: dependencia, store, server service y prueba.
  - Estado: las credenciales usan el store seguro nativo o el store efímero
    web; las claves planas se ignoran.
  - `flutter_secure_storage ^11.0.0` está resuelto junto con `file_picker 12`,
    `share_plus 13` y Syncfusion 34, sin overrides de resolución.

  - [x] **F2.3a — Store efímero web.**
    - Aceptación: una nueva instancia no restaura secretos y ninguna ruta usa
      LocalStorage/sessionStorage.
  - [x] **F2.3b — Adapter y selector de store seguro.**
    - Aceptación: native delega en `flutter_secure_storage`; web selecciona el
      store efímero sin invocar el backend web del plugin.
    - Archivos: dependencia, adapter/selector, export y prueba.
  - [x] **F2.3c — Escritura directa en almacenamiento seguro.**
    - Aceptación: las claves planas no se leen; los secretos nuevos se escriben
      directamente en el store seguro.
  - [x] **F2.3d — Integrar perfiles seguros en servidor/sesión.**
    - Aceptación: `saved_servers`, `current_session`, `stored_credentials` y
      `last_used_api_key` dejan de escribirse con secretos; logout tras cold
      restart elimina las claves conocidas del scope.
    - Archivos: server service, initializer, login y pruebas.
    - Dependencia: F2.3b–c y F2.4a/c.
    - Estado: `ServerService` sólo restaura API keys desde
      `SecureCredentialStore` mediante `credentialRef`. Las claves planas no se
      restauran; login offline espera la restauración segura antes de buscar.
  - [x] **F2.3e — Configuración nativa y matriz por dispositivo.**
    - Aceptación: Keychain Apple, backup Android y build Windows quedan
      configurados; web exige nuevo login tras refresh.
    - Dependencia: F2.3b.

- [x] **F2.4 — Scope de sesión y aislamiento Drift por usuario.**
  - Aceptación: servidor/base/usuario forman el scope sin secretos y dos
    usuarios no comparten catálogo, órdenes ni cola.
  - Verificar: pruebas de server database y multiserver.
  - Archivos: scope, database service, initializer y pruebas.
  - Estado: `SessionScope`, nombres Drift scoped, journal de activación,
    adapters y apertura ordenada están implementados y probados.
  - Política: cada servidor/base/UID activa exclusivamente su propio scope.

  - [x] **F2.4a — Value object no secreto de scope.**
    - Aceptación: URL normalizada, base y UID generan identidad e identificador
      estable, acotado y seguro para filesystem; usuarios quedan separados.
    - Verificar: `flutter test test/core/session/session_scope_test.dart`.
  - [x] **F2.4b — Inicialización del scope.**
    - Aceptación: crea y compromete el scope actual antes de exponer Drift.
  - [x] **F2.4c — Nombre Drift derivado de `SessionScope`.**
    - Aceptación: el nombre scoped separa usuarios dentro de la instalación.
    - Archivos: scope, server database service y sus pruebas.
    - Estado: API scoped implementada y activa.
  - [x] **F2.4d — Inicialización multiplataforma del scope actual.**
    - Aceptación: cada plataforma crea y abre el almacenamiento scoped de la
      instalación actual usando los adapters soportados.
  - [x] **F2.4f — Activación ordenada del scope.**
    - Aceptación: UID precede a Drift y no hay sync/replay antes de activarlo.
    - Archivos: login, initializer, splash, database helper y prueba.
    - Dependencia: F2.3 y F2.4b–d.
    - Estado: UID y manifest committed preceden a Drift, sync y replay; scopes
      ambiguos quedan bloqueados sin fallback de usuario.
  - [x] **F2.4g — Aislamiento, rollback y cleanup protegido.**
    - Aceptación: los scopes se mantienen aislados y cleanup es seguro.
    - Dependencia: F2.4c–d.
    - Estado: aislamiento y cleanup están cubiertos por pruebas independientes.

- [x] **F2.5 — Coordinador único e idempotente de teardown.**
  - Aceptación: logout/expiración detienen servicios, invalidan providers,
    retiran clientes/contextos y cierran Drift una sola vez.
  - Verificar: prueba del lifecycle controller y analyzer.
  - Archivos: controller, servicio Odoo, auth guard, main screen y prueba.
  - Dependencia: F2.3 y F2.4.
  - Estado: logout, expiración y cambio de servidor comparten teardown
    serializado e idempotente.

- [x] **F2.6 — Activación/restauración atómica de sesión.**
  - Aceptación: estados explícitos; Drift y managers quedan ligados al scope
    antes de publicar usuario/permisos; un fallo revierte y cambiar servidor
    termina primero el scope anterior.
  - Verificar: prueba de activación y analyzer.
  - Archivos: lifecycle, login, splash, initializer y prueba.
  - Dependencia: F2.2–F2.5.
  - Estado: login online, login offline y cold-start llaman al mismo
    `initializeModelManagers` con base/cola scoped y cliente Bearer cuando está
    disponible. El rebinding limpia recursos del usuario anterior; teardown
    ejecuta `resetModelManagersSession` antes de cerrar Drift.

- [x] **F2.7 — Router Riverpod con guards reactivos.**
  - Aceptación: router observa sesión/permisos; acceso por URL queda protegido;
    rutas desconocidas no cargan contenido autenticado.
  - Verificar: prueba de router guard y analyzer.
  - Archivos: router, rutas, main, menú y prueba.
  - Dependencia: F2.1 y F2.6.
  - Estado: guards default-deny observan sesión y permisos; URLs autenticadas
    no cargan contenido sin scope válido.

- [x] **F2.8 — Matriz C2 de ciclo e aislamiento.**
  - Aceptación: dos scopes recorren login, restauración, switch, expiración y
    logout sin mezclar usuario, catálogo, órdenes, cola ni credenciales.
  - Verificar: integración de lifecycle, analyzer y suite completa.
  - Archivos: integración, fixtures y pruebas multiserver.
  - Dependencia: F2.1–F2.7.
  - Estado: matriz parametrizada cubre login online, restauración offline,
    logout, expiración, cambio de servidor y errores de activación; verifica
    teardown, rollback y nombres de Drift distintos para cada scope.

## F6 — Adaptación multiplataforma (paralela)

- [x] **F6.1 — Harness tipado de layout e interacción.**
  - Aceptación: breakpoints y políticas cubren Android phone/tablet, iPad en
    ambas orientaciones, desktop y web sin entrar al dominio.
  - Verificar: prueba focalizada de adaptive layout policy y analyzer.
  - Archivos: constantes/tamaños, policy, export y prueba.
  - Estado: size classes compact/medium/expanded y capacidades de entrada
    producen políticas tipadas de navegación, diálogo, columnas, densidad,
    hover, teclado y barcode. Las ocho pruebas focalizadas están verdes.

- [x] **F6.2 — Shell adaptativo de Venta Rápida.**
  - Aceptación: compact muestra un panel, medium dos y expanded tres; el grid
    responde al ancho local y touch/teclado pueden coexistir sin inferir OS.
  - Verificar: tamaños 390×844, 768×1024, 1024×768 y 1440×900; resize conserva
    estado, no hay overflow y el analyzer queda limpio.
  - Archivos: pantalla fast sale, FAB táctil, favoritos y prueba adaptativa.
  - Dependencia: F6.1.
  - Estado: el shell usa constraints locales con una/dos/tres columnas, touch
    y teclado coexisten y favoritos calcula 1–4 columnas por su panel. Ocho
    pruebas de tamaños, capacidades y resize están verdes.

- [x] **F6.3 — Cobro adaptativo dentro del panel.**
  - Aceptación: métricas, campos y acciones refluyen por constraints; el
    diálogo es full-screen en compact y modal en tamaños mayores; targets
    respetan 48 px touch y 32 px pointer sin alterar cálculos financieros.
  - Verificar: pruebas a 390, 768 y 1024 px, callbacks y analyzer.
  - Archivos: payment tab, diálogo de pago, quick amount y prueba.
  - Dependencia: F6.1.
  - Estado: métricas/acciones refluyen, los pares de campos se apilan, la
    superficie compact es full-screen y los targets respetan la policy. Cuatro
    pruebas pasan sin modificar cálculos ni callbacks financieros.

- [x] **F6.4 — Conteo y validación de caja adaptativos.**
  - Aceptación: denominaciones, contadores, información y acciones refluyen;
    rotar/redimensionar conserva conteos, total y notas sin cambiar llamadas
    Odoo ni DTOs.
  - Verificar: pruebas a 390×844, 768×1024 y 1024×768, más analyzer.
  - Archivos: cash count, campo reactivo, validación de sesión y prueba.
  - Dependencia: F6.1 y F1.5.
  - Estado: conteos, resumen, información y acciones refluyen; compact usa
    fullscreen y el estado/notas sobreviven al resize. Cuatro pruebas pasan y
    se preservan DTOs, cálculos, providers y llamadas Odoo. El ancho decide el
    reflow y las capacidades explícitas deciden independientemente targets
    touch/híbrido/puntero de 48/44/32 px.

- [x] **F6.5 — Shell de sesión de caja en landscape corto.**
  - Aceptación: command bar y tabs no dependen de una resta fija de altura ni
    producen scroll anidado; los controles siguen alcanzables.
  - Verificar: fixture de providers, landscape corto y analyzer.
  - Estado: shell adaptativo implementado; en landscape corto elimina la
    resta fija de altura, usa el viewport restante para las tabs y evita el
    scroll anidado del cuerpo principal. Los controles de sesión y tabs siguen
    siendo alcanzables sin modificar providers, DTOs ni llamadas Odoo.

## F3 — Vertical de vendedor

- [x] **F3.1 — Unificar scope de lista, contadores y filtros de ventas.**
  - Aceptación: administrador consulta el scope global permitido y vendedor su
    scope personal; lista, chips y contadores aplican la misma identidad.
  - Estado: filtros, orden descendente, paginación y búsqueda remota incremental
    comparten el contrato y ya no muestran vacío con contadores positivos.

- [x] **F3.2 — Persistir edición de orden y líneas.**
  - Aceptación: encabezado, campos visibles, líneas modificadas y estado sucio
    sobreviven al flujo de edición y quedan marcados para sincronización.
  - Estado: repositorios de lectura/escritura y Fast Sale conservan cambios
    locales sin que una actualización concurrente los sobrescriba.

- [x] **F3.3 — Crear y confirmar sin duplicados.**
  - Aceptación: una orden nueva conserva un UUID idempotente y su confirmación
    distingue éxito, aprobación y fallo; un reintento offline no crea otra
    orden.
  - Estado: creación, reconciliación del ID y confirmaciones implementadas con
    claves estables y manejo explícito de resultados.

- [x] **F3.4 — Cerrar pruebas focales del vendedor.**
  - Aceptación: providers, repositorios, formulario, Fast Sale y layouts
    adaptativos pasan sus pruebas y analyzer focal.
  - Estado: verificación focal completada e incluida en la regresión global
    local cerrada en F8.

## F4 — Vertical de cajero

- [x] **F4.1 — Completar ciclo JSON-2 de sesión de caja.**
  - Aceptación: abrir, pausar, reanudar y cerrar usan métodos de recordset y no
    aceptan como actual una respuesta remota obsoleta.
  - Estado: ciclo de sesión y rechazo de estado stale cubiertos por pruebas
    focales.

- [x] **F4.2 — Tipar cobro y creación de factura.**
  - Aceptación: el wizard separa `ids` y `kwargs`, aplica las líneas de pago y
    solo publica éxito cuando el backend devuelve un resultado financiero
    final.
  - Estado: contratos de pago/factura y resultados intermedios implementados.

- [x] **F4.3 — Resolver anticipos y resultados que requieren acción.**
  - Aceptación: anticipo, devolución o aprobación requerida se representan de
    forma explícita y no se confunden con factura pagada.
  - Estado: manejo de estados financieros alternos integrado en el flujo.

- [x] **F4.4 — Persistir factura y relación con el cobro.**
  - Aceptación: factura, pagos, sesión y orden conservan una relación local
    consultable para documento y cierre.
  - Estado: implementación focal completada e incluida en la regresión global
    local cerrada en F8.

## F5 — Offline, idempotencia y recuperación

- [x] **F5.1 — Sustituir métodos sintéticos por comandos tipados.**
  - Aceptación: cada entrada de cola tiene tipo, versión, payload validado y un
    handler explícito hacia JSON-2.
  - Estado: productores críticos usan el contrato tipado y versionado.

- [x] **F5.2 — Encadenar dependencias e idempotencia.**
  - Aceptación: cabecera, líneas, confirmación y operaciones financieras no se
    ejecutan antes de su padre y conservan claves idempotentes estables.
  - Estado: dependencias y bloqueo padre/línea implementados.

- [x] **F5.3 — Recuperar interrupciones y fallos permanentes.**
  - Aceptación: reinicio recupera `processing`; resultados ambiguos pasan por
    `recovery_pending`; reintentos respetan backoff y el agotamiento termina en
    dead-letter sin borrar evidencia.
  - Estado: recuperación, DLQ y reintento manual implementados.

- [x] **F5.4 — Persistir y resolver conflictos.**
  - Aceptación: el conflicto conserva contexto saneado, permite resolución y
    vuelve a consultar dependencias remotas antes de continuar.
  - Estado: persistencia y resolución implementadas.

- [x] **F5.5 — Apagar sync antes de cerrar la sesión local.**
  - Aceptación: no queda un writer activo cuando se invalida el scope o se
    cierra Drift.
  - Estado: shutdown ordenado integrado e incluido en la regresión global
    local cerrada en F8.

- [x] **F5.6 — Reconciliación HTTP queue-first.**
  - Aceptación: la app no depende de WebSocket; inicio, recuperación y polling
    serializan ciclos que drenan primero la cola y luego sincronizan catálogos
    críticos. El sync completo permanece manual.
  - Estado: `ConnectivitySyncOrchestrator` ejecuta un poll inmediato, escucha
    recuperación de conectividad y repite el ciclo incremental cada cinco
    minutos. Los upserts Drift actualizan la UI mediante streams.

## F7 — Documentos, impresión y cierre

- [x] **F7.1 — Persistir documento y estados de factura.**
  - Aceptación: borrador, publicada, pagada y estado fiscal se consultan desde
    el almacenamiento local sin inventar un estado exitoso.
  - Estado: persistencia Drift y contratos focales completados.

- [x] **F7.2 — Separar render y salida de plataforma.**
  - Aceptación: la preparación del documento no depende directamente del
    plugin usado para abrir, compartir o imprimir.
  - Estado: integración funcional completada; matriz por plataforma en F8.

- [x] **F7.3 — Enlazar documento con el cierre operativo.**
  - Aceptación: el cajero puede partir del resultado de cobro/factura para
    consultar el documento y continuar al cierre sin perder la relación.
  - Estado: recorrido focal completado e incluido en la regresión global local
    cerrada en F8.

## F8 — Regresión global, builds y E2E directo

- [x] **F8.1 — Ejecutar analyzer y suites de los cinco paquetes.**
  - Aceptación: todos los analyzers y suites terminan en verde en el mismo
    árbol de trabajo posterior a F3–F7.
  - Estado: completada localmente con Flutter 3.47.1/Dart 3.13.1. Los cinco
    analyzers terminaron sin incidencias. Pruebas aprobadas: SDK 1787 (más 14
    omitidas), core 559, widgets 188, QWeb 102 y app 979; total: 3615
    aprobadas y 14 omitidas.

- [x] **F8.2 — Validar clean-install y seguridad.**
  - Aceptación: Drift crea el esquema actual desde cero; credenciales quedan
    fuera de Git/logs; web usa Bearer JSON-2 sin cookies ni
    `withCredentials`.
  - Estado: completada localmente. Las pruebas cubren creación del esquema
    actual desde instalación limpia y almacenamiento de credenciales por
    plataforma; Web usa Bearer JSON-2 sin cookies. El escaneo de secretos y
    `git diff --check` terminan en verde sin exponer valores sensibles.

- [ ] **F8.3 — Construir artefactos por plataforma.**
  - Aceptación: web, macOS, Android e iOS sin firma construyen local/CI según
    el host; Windows construye en su runner CI.
  - Estado: el 2026-08-26 se construyeron localmente con Flutter 3.47.1 el APK
    y AAB Android, iOS release sin firma, macOS release y Web release (incluido
    el dry run WASM). El runner Windows continúa como verificación externa;
    firma, notarización y distribución no forman parte de estos builds
    reproducibles. Por ello la tarea permanece abierta.

- [ ] **F8.4 — Ejecutar recorridos directos controlados.**
  - Aceptación: login/restauración, navegación, venta, caja, documento y
    recuperación offline se prueban en targets disponibles sin escribir en
    `erp2` salvo autorización explícita.
  - Estado: el recorrido macOS read-only real pasó con `exit 0`: dos arranques
    restauraron la sesión, cargaron 11 grupos/permisos, navegaron a
    Actividades y Ventas y comprobaron el redirect de una ruta protegida. La
    cola permaneció vacía y no hubo escrituras en ERP2. Siguen pendientes los
    recorridos controlados de escritura para venta, caja, documento y
    recuperación offline, junto con su ejecución contra Odoo 20.

- [ ] **F8.5 — Cerrar documentación y gates de release.**
  - Aceptación: especificación, plan, tareas, README y runbooks reflejan los
    resultados finales reproducibles, sin estados históricos contradictorios.
  - Estado: README y runbooks de instalación/configuración, release y soporte
    offline están creados; los informes históricos contradictorios quedaron
    archivados. La evidencia externa de CI/Windows, los E2E controlados, la
    firma/notarización/distribución y el piloto siguen pendientes.

## F9 — Piloto externo y cierre

- [ ] **F9.1 — Ejecutar piloto con vendedor y cajero.**
  - Aceptación: ambos completan los recorridos acordados en una empresa y
    diario controlados sin usar el backend web.
  - Estado: pendiente de C8 y de coordinación externa.

- [ ] **F9.2 — Certificar matriz y distribución.**
  - Aceptación: defectos críticos/altos quedan cerrados, se congela la matriz
    comprobada y cualquier distribución firmada cuenta con autorización.
  - Estado: pendiente.
