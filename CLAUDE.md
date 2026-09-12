# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Monorepo Flutter/Dart de siete paquetes, sin framework de workspace: todo se orquesta
desde el `Makefile` de la raíz. Flutter **3.47.1 / Dart 3.13.1**, pinneado y obligatorio
(coincide con CI).

## Comandos

```bash
make deps        # pub get en los 7 paquetes (los de Orbi se saltan si no existen)
make generate    # build_runner en theos_pos_core y theos_pos
make analyze     # los 5 paquetes clásicos
make test        # los 5 paquetes clásicos
make analyze-orbi / make test-orbi   # orbi_runtime + theos_panel
make verify      # check-secrets + generated-check + analyze + test  ← la compuerta de CI
```

**Una sesión limpia necesita `make deps && make generate` antes de que `theos_pos`
compile.** Sin generar, `flutter analyze` y `flutter test` fallan porque faltan
`providers.g.dart`, `*.freezed.dart`, etc.

Un solo archivo de test, y un solo test dentro del archivo:

```bash
cd theos_pos      && flutter test test/features/sales/algo_test.dart --plain-name "nombre exacto"
cd theos_pos_core && dart test    test/managers/algo_test.dart      --plain-name "nombre exacto"
```

`odoo_sdk` y `theos_pos_core` son **Dart puro** (`dart test`, `dart analyze`). Los otros
cinco son paquetes Flutter (`flutter test`, `flutter analyze`). El `Makefile` ya usa el
comando correcto por paquete; al invocar a mano hay que respetarlo.

### Arrancar una de las dos apps — el nombre del objetivo dice cuál

🔴 **`run-macos` y `run-web` arrancan `theos_pos`, NO Orbi.** El nombre no lo dice y eso
ya hizo perder tiempo: quien creía estar probando Orbi estaba mirando la app vieja de
Fluent. Los objetivos de Orbi llevan `orbi` en el nombre, sin excepción.

| Objetivo | Qué arranca | Credencial |
|---|---|---|
| `make run-macos` | `theos_pos` (Fluent) en macOS | inyecta `THEOS_ERP2_API_KEY` vía `scripts/run_flutter_with_erp2.sh` |
| `make run-web` | `theos_pos` (Fluent) en Chrome | ninguna; se entra desde la app |
| `make run-orbi-macos` | `theos_panel` (Orbi) en macOS: **compila y abre el paquete** | **ninguna**; se entra por la pantalla de acceso |
| `make run-orbi-web` | `theos_panel` (Orbi): **compila, sirve en `127.0.0.1:8099` y abre el navegador** | **ninguna**; se entra por la pantalla de acceso |
| `make stop-orbi-web` | detiene el servidor que levantó `run-orbi-web` | — |
| `make dev-orbi-macos` | sesión interactiva de Orbi en macOS, con recarga en caliente | **ninguna** |
| `make dev-orbi-web` | sesión interactiva de Orbi en Chrome, con recarga en caliente | **ninguna** |

🔴 **`run-*` compila y abre; `dev-*` abre sesión interactiva y EXIGE una terminal de
verdad.** Medido el 12-sep-2026: `flutter run` sin TTY **se queda esperando para siempre
sin imprimir una sola línea**, así que desde cualquier invocador no interactivo —el
prefijo de admiración de Claude Code, un guion, CI— parece un comando roto. Por eso los
objetivos `run-orbi-*` **no** llaman a `flutter run`: compilan y abren el resultado, y no
pueden colgarse. Si quieres recarga en caliente, `dev-orbi-*`, tecleado en tu terminal.

La primera compilación tarda **minutos** (unos 2,5 min la web, algo menos macOS en
incremental). Los objetivos lo avisan antes de empezar, porque un comando mudo durante
minutos parece colgado aunque esté trabajando.

**Orbi no recibe credencial inyectada en ningún destino, tampoco en escritorio.**
`theos_panel` no tiene ni un `String.fromEnvironment` para una clave: el único
`fromEnvironment` del paquete es el arnés E2E (`lib/erp2_harness.dart`), que lee
`Platform.environment` en tiempo de prueba. Inyectarla sería peso muerto, y además
taparía justo la pantalla de acceso que se quiere probar.

`scripts/run_flutter_with_erp2.sh` es **sólo de `theos_pos`**: hace `cd theos_pos` y
rechaza los destinos web y las compilaciones que no sean debug nativo. Hay una prueba de
arquitectura que lo vigila (`theos_pos/test/architecture/platform_security_config_test.dart`),
así que no se toca sin mirarla.

## Las dos aplicaciones

El repo contiene **dos apps que coexisten**, no una migración:

- **`theos_pos`** — la app madura y probada. Fluent UI. Es la que despliega
  `deploy-web.yml` y la que cubren las specs de `docs/specs/PROJECT_COMPLETION_V1*.md`.
- **`theos_panel`** (proyecto «Orbi») — app nueva **independiente**, Material, con su
  propio runtime. No depende de `theos_pos` ni lo reemplaza. Está parcialmente
  implementada (login, gestión de servidores, shell operativo, editor de ventas,
  envases) y **pausada**, sin certificación contra un Odoo real.

```text
theos_pos  (Fluent UI)          theos_panel  (Material, Orbi)
    │                                │
    │                                └── orbi_runtime   sesión, storage, auth, sync — SIN UI
    ├── theos_pos_core   dominio + Drift + servicios   ← compartido por ambas apps
    ├── odoo_sdk         cliente JSON-2, capabilities, cola offline
    ├── odoo_widgets     campos Fluent UI reutilizables
    └── flutter_qweb     intérprete QWeb → PDF
```

⚠️ `docs/orbi_panel/README.md` dice que la app Orbi «está pendiente». Está
desactualizado. El estado real vive en el handoff más reciente,
`docs/orbi_panel/COORDINATOR_HANDOFF_<AAAA_MM_DD>.md`.

## Fronteras que el código respeta de facto

- Los widgets **no** construyen URLs de Odoo, no abren `AppDatabase` y no guardan su
  propio `OdooClient`. Todo RPC pasa por los managers singleton de `odoo_sdk`.
- Impuestos y totales viven en `theos_pos_core/lib/src/services/sales/` y
  `services/taxes/`, inyectados por provider. Nunca en la vista.
- La sincronización tiene un coordinador único, `ConnectivitySyncOrchestrator`: un ciclo
  a la vez, y drena la cola durable antes de sincronizar catálogos.
- `orbi_runtime` no importa temas, diálogos ni rutas, ni ninguna de las dos apps
  (`docs/orbi_panel/ARCHITECTURE.md`, ADR-01).
- `odoo_widgets` es agnóstico del gestor de estado y no depende de `odoo_sdk`: se
  conecta por `Stream` genérico.

## Odoo 19 frente a Odoo 20

No hay adapters por versión ni feature flags de configuración. El aislamiento son tres
archivos en `odoo_sdk/lib/src/api/`:

| Archivo | Papel |
|---|---|
| `odoo_version.dart` | Parsea la versión del servidor y deriva flags de campos y modelos |
| `odoo_capabilities.dart` | Matriz por área con estado `supported / unsupported / unknown` |
| `odoo_capabilities_detector.dart` | Construye la matriz; **la evidencia gana al hint de versión** |

Dos decisiones que no se deben «simplificar»:

- Cuando la versión es `unknown`, todos los flags legacy asumen **19.1**, la versión más
  vieja. Es deliberado: es preferible fallar pidiendo un campo inexistente que dejar de
  pedir uno que sí existe.
- `unknown` **no** es `unsupported`. Ninguna función se habilita mientras el estado sea
  `unknown`.

Cuidado con el nombre: hay un segundo sistema llamado «capabilities» en
`theos_pos_core/lib/src/services/operations/capability_provisioner.dart`, y ese es de
**permisos de usuario** (vendedor, cajero, aprobador), no de versión de servidor.

## Autenticación y transporte

El runtime es siempre **Bearer token JSON-2** sobre `/json/2/<modelo>/<método>`. No hay
sesiones por cookie: `odoo_sdk/lib/src/api/session/session.dart` y `auth/auth.dart` son
archivos vacíos a propósito. El login interactivo por usuario y contraseña vive aparte,
en `src/auth/native_auth_bootstrap_io.dart`, y solo usa una cookie efímera para fabricar
un API key que luego descarta.

`OdooClient.call(args: ...)` está **deprecado**: el dispatcher JSON-2 no trata `args`
como posicionales, llega como un kwarg literal llamado `args` y falla. Usa `kwargs` con
los nombres reales del método Python.

## Persistencia offline-first

`theos_pos_core/lib/src/database/database.dart` define unas 45 tablas Drift,
`schemaVersion` 14. La escritura va **primero a Drift**, luego intenta sincronizar, y si
no puede encola en la tabla `offline_queue`. La UI se refresca sola porque los
`watchLocalSearch()` de Drift alimentan `StreamProvider` de Riverpod. No hay WebSocket.

🔴 **La estrategia de migración borra y recrea todas las tablas** para cualquier salto de
esquema que no tenga una rama explícita en `MigrationStrategy`. Subir `schemaVersion` sin
añadir su rama pierde los datos locales sin aviso.

La cola offline distingue `retry_safe` de `manual_after_ambiguous`, y este último es el
predeterminado seguro para documentos financieros, precisamente para no duplicarlos. Las
operaciones que quedan en `processing` tras un cierre abrupto pasan a `recovery_pending`
al abrir la base.

## Código generado — la asimetría importa

| Paquete | `.g.dart` / `.freezed.dart` en git |
|---|---|
| `theos_pos_core` | **sí, 67 archivos** (no tiene `.gitignore` propio) |
| `odoo_sdk` | sí, 6 archivos |
| `theos_pos` y el resto | no, ignorados |

Si tocas un modelo `@freezed` o una tabla Drift de `theos_pos_core`, tienes que correr
`build_runner` **y commitear** el generado. Si tocas un provider de `theos_pos`, corres
`build_runner` y no commiteas nada. El gate `make generated-check` regenera y falla si el
árbol trackeado cambia, así que solo puede romperse por `theos_pos_core`.

`make generate` **no** cubre `odoo_sdk`, aunque tenga `build_runner`. Regenéralo a mano
si cambias algo que lo requiera.

## Tests

`mocktail`, nunca `mockito`. Los mocks compartidos de `odoo_sdk` están en
`odoo_sdk/test/mocks/`. No hay golden tests en ningún paquete.

Los tests que golpean un Odoo real se saltan solos cuando faltan sus variables de
entorno, y nunca las registran en el log: `ODOO19_*` y `ODOO20_*` para la matriz de
versiones, `THEOS_AUTH_SMOKE` para el bootstrap de autenticación, `ORBI_ERP2_*` para los
de `theos_panel`.

## CI

`quality` corre en Ubuntu y es la compuerta: secretos, generado, `git diff --check`,
análisis y tests de los siete paquetes. Si falla, no corre ningún build. **Los paquetes
de Orbi no son opcionales ni tolerantes**: se activan solos por la presencia de
`theos_panel/pubspec.yaml`, y si su análisis o sus tests fallan, se cae también el build
de `theos_pos`.

Los builds cubren web, Android App Bundle, iOS, macOS, Windows y Linux. El de Android
usa `build apk --config-only` seguido de `build appbundle --no-pub` como rodeo a un bug
conocido de Flutter 3.47.1 con `integration_test`.

## Reglas de proceso del repositorio

- **No actualices lockfiles** como parte de un cambio ajeno. Se resolvieron con Flutter
  3.47.1 y solo se regeneran con ese SDK.
- **ERP2 es un entorno de pruebas; producción es intocable.** Escribir en ERP2 no
  requiere autorización caso por caso. `scripts/verify_orbi_erp2.py` rechaza
  cualquier host que contenga `newerp`, y las escrituras de prueba exigen
  `--allow-test-writes` más el host exacto — ese freno es una protección contra
  escribir por accidente, no una puerta de permiso que ya no existe. Producción
  (`newerp`) no se toca, sin excepción. Firmar builds, publicar en tiendas y
  cambiar esquemas o módulos de Odoo en producción sí requieren autorización aparte.
- **Nada de secretos en el árbol.** `scripts/check_secrets.sh` corre en CI y busca
  archivos `.env`, claves PEM, tokens y URLs con credenciales embebidas.
- Las evidencias de Orbi van a `docs/orbi_panel/reports/evidence/<AAAA-MM-DD>/`, y los
  informes de tarea siguen `docs/orbi_panel/REPORT_TEMPLATE.md`. Solo el integrador marca
  una tarea como `done`.
- `docs/orbi_panel/tasks.json` se valida con `python3 scripts/check_orbi_plan.py`, que
  solo comprueba la estructura del plan. No es evidencia de que la app funcione.
- Mensajes de commit: `tipo(ámbito): descripción en inglés en imperativo`, con ámbitos
  como `orbi`, `panel`, `pos`.

## Documentos que NO son fuente de la verdad

`theos_pos/AUDIT.md` y `theos_pos/VERIFICATION_RESULTS.md` están archivados y ellos
mismos lo declaran. La fuente vigente es `docs/specs/PROJECT_COMPLETION_V1*.md`,
`theos_pos/ARCHITECTURE.md` y el CI. `theos_panel/README.md` sigue siendo el boilerplate
de `flutter create`.

## Trampa: código aspiracional que parece vigente

`theos_pos_core/lib/src/services/operations/operation_commands.dart` y la familia
`sale_operation_*` definen un patrón de comandos tipados que **no está enchufado al flujo
real**: solo aparecen en su propio archivo y en sus tests. El mecanismo vivo es
`SalesRepository` junto al enum `OfflineLocalCommand` de
`odoo_sdk/lib/src/sync/offline_queue_types.dart`.
