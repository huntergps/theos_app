# Arquitectura de `theos_pos`

> Documento de orientación del runtime actual. La especificación, el plan y el
> estado verificable viven en `../docs/specs/`; si un ejemplo difiere del
> código o de una prueba, prevalecen el código y la prueba.

## Resumen

`theos_pos` es una aplicación Flutter offline-first para Odoo 19/20. Usa una
única sesión Bearer por scope de usuario, persistencia local Drift, managers
ligados explícitamente al scope activo y sincronización HTTP JSON-2. La app no
abre una sesión del webclient, no usa cookies y no mantiene un WebSocket.

```text
Flutter UI + GoRouter + Riverpod
              │
              ▼
providers / repositories / model managers
        │                       │
        ▼                       ▼
Drift del SessionScope     OdooClient JSON-2
        │                       │
        └──── cola offline ─────┘
                 │
                 ▼
       recovery + polling HTTP
```

## Paquetes y dependencias

```text
theos_pos
  UI, navegación, Riverpod, ciclo de vida y adaptadores de plataforma
       │
       ├──► theos_pos_core
       │      modelos Freezed, tablas Drift, managers y reglas compartidas
       │
       ├──► odoo_sdk
       │      cliente/transport JSON-2, conectividad y primitivas offline
       │
       ├──► odoo_widgets
       │      componentes visuales reutilizables
       │
       └──► flutter_qweb
              interpretación QWeb y documentos
```

Reglas:

- La UI consume providers, repositorios o managers; no construye URLs Odoo.
- `theos_pos_core` no depende de la aplicación Flutter.
- Toda llamada remota de la app usa el único `OdooClient` publicado por
  `odooClientProvider`.
- La lógica de negocio y persistencia no vive dentro de widgets.
- El almacenamiento local se identifica por servidor, base y UID; nunca por
  una clave API.

## Transporte y autenticación

El único transporte de la app es:

```text
POST /json/2/<modelo>/<método>
Authorization: Bearer <api-key>
X-Odoo-Database: <base>
Content-Type: application/json
```

No forman parte de la arquitectura:

- `/web/session/authenticate` o cualquier URL `/web/...`;
- cookies de sesión o `withCredentials`;
- XML-RPC/JSON-RPC del webclient;
- WebSocket como canal de actualización de la aplicación.

Odoo aplica ACL y record rules. El SDK normaliza errores sin exponer headers,
credenciales o cuerpos sensibles. Aunque JSON-2 usa POST para leer y escribir,
el retry de transporte solo se habilita para métodos de lectura expresamente
clasificados; una mutación o método desconocido nunca se reenvía
automáticamente.

## Ciclo de vida de sesión

### Login online

```text
validar Bearer y resolver UID
        │
        ▼
activar SessionScope(server, database, uid)
        │
        ▼
abrir Drift y publicar OdooClient/DatabaseHelper
        │
        ▼
initializeModelManagers(client, db, queueStore)
        │
        ▼
cargar identidad + snapshot atómico de permisos
        │
        ▼
persistir referencia segura y publicar RouteSessionSnapshot
```

La API key no se guarda en preferencias. En plataformas nativas se guarda en
el almacén seguro y la metadata de sesión conserva únicamente una
`credentialRef`. La restauración vuelve a resolver esa referencia, comprueba
el scope committed y repite la misma composición antes de navegar.

En Web el store es efímero: la navegación dentro de la instancia conserva la
sesión, pero un refresh o cierre de la página requiere introducir la clave de
nuevo. No se degrada a LocalStorage ni a una cookie.

### Login offline y restauración

El login offline solo es válido para un scope ya comprometido con identidad y
permisos locales completos. Liga los managers con `client: null`, por lo que
ningún manager puede intentar tráfico remoto. Una restauración con credencial
segura disponible crea el cliente Bearer y liga esos mismos managers con el
cliente activo.

La sesión se publica al router únicamente después de abrir el scope, ligar los
managers y recuperar identidad/permisos. Los guards son default-deny.

### Teardown

Logout, expiración y cambio de servidor/usuario comparten un teardown
serializado e idempotente:

1. cancelar sincronizaciones y orquestadores;
2. invalidar providers que capturan el cliente o la base;
3. ejecutar `resetModelManagersSession()`;
4. cerrar Drift y retirar la sesión del router;
5. borrar la referencia segura cuando la operación sea un logout real.

Cerrar normalmente la ventana nativa no equivale a logout y permite la
restauración posterior.

## Binding de model managers

Los managers concretos son singletons de `theos_pos_core`, pero sus recursos
de sesión no lo son. `initializeModelManagers(...)` recorre todos los managers
y ejecuta `bindSession` con:

- el `OdooClient` del usuario, o `null` en login offline;
- la instancia Drift del `SessionScope` activo;
- un wrapper nuevo sobre la cola offline de ese mismo scope.

Después registra los managers y elimina el wrapper del scope anterior. Esta es
la única entrada de composición de managers para login online, login offline y
cold-start. No se debe crear en paralelo otro `DataContext` para la app: el SDK
ofrece ese contenedor como API genérica, pero el runtime Flutter usa el binding
explícito anterior.

Los providers de managers devuelven esos objetos ya ligados. Agregar un
manager requiere:

1. definir modelo y manager en `theos_pos_core`;
2. incluirlo en `_getAllManagers()`;
3. exponer provider solo cuando una feature lo necesite;
4. cubrir binding, reset y aislamiento de usuario con pruebas.

## Datos locales y UI reactiva

Drift es la fuente inmediata para listas, contadores y formularios offline.
Las lecturas normales siguen este recorrido:

```text
Widget watch
   ▼
Riverpod provider / Drift stream
   ▼
repository o manager
   ▼
tabla del scope activo
```

La sincronización HTTP hace upsert transaccional en Drift. Sus streams
invalidan o actualizan la UI; no se necesita un canal push separado. Una lista
y su contador deben consultar el mismo scope y compartir la misma semántica de
filtros.

## Sincronización HTTP

`ConnectivitySyncOrchestrator` es el coordinador automático de la app. Se
activa dentro de la sesión autenticada y serializa cada ciclo para impedir
trabajo duplicado.

Disparadores:

- una reconciliación inmediata al iniciar el orquestador;
- recuperación de conectividad, después de confirmar estabilidad;
- polling incremental cada cinco minutos;
- acción manual del usuario.

Orden de un ciclo automático:

```text
autenticado + online + no modo offline/ruta
                    │
                    ▼
          drenar cola durable
                    │
            confirmar conexión
                    │
                    ▼
     sincronizar catálogos críticos
                    │
                    ▼
          upsert Drift → streams UI
```

El polling automático es incremental. La sincronización completa es una
acción manual explícita y no compite con otro ciclo en progreso.

## Cola offline

Solo las operaciones declaradas aptas para offline se guardan en la cola Drift
del scope. La cola conserva:

- comando tipado y payload mínimo;
- identidad estable/idempotencia cuando el flujo la admite;
- dependencias entre operaciones;
- estado, intentos y próximo retry con backoff;
- información de conflicto y evidencia de dead-letter.

Al iniciar o recuperar conexión, las operaciones `processing` interrumpidas se
recuperan y el procesador reclama un snapshot listo una sola vez. Si falla un
padre, sus dependientes no se despachan en el mismo ciclo. Antes de repetir una
creación ambigua se consulta el marcador remoto disponible; una operación sin
idempotencia demostrable debe fallar de forma segura y requerir reconciliación.

Los conflictos de `write_date` no se sobrescriben silenciosamente. Se
persisten para resolución autorizada. Eliminar una fila local nunca se trata
como prueba de que Odoo no ejecutó la operación.

## Navegación y permisos

GoRouter y el menú consumen la misma `RouteAccessPolicy`. La sesión publicada
incluye UID y snapshot de permisos; rutas desconocidas o no autorizadas se
deniegan aunque el usuario escriba la URL directamente. Los accesos rápidos
usan nombres de ruta canónicos y no crean navegadores secundarios.

## Verificación de cambios

Antes de integrar cambios de arquitectura:

```bash
flutter analyze
flutter test
```

Además:

- cambios de modelos/tablas requieren regenerar y probar el esquema limpio;
- cambios de sesión requieren pruebas de login, restore, offline, logout y
  cambio de usuario/servidor;
- cambios de sync requieren pruebas de exclusión mutua, queue-first, recovery,
  idempotencia y conflictos;
- ningún fixture, log o snapshot puede incluir una clave real.

**Última actualización:** 2026-08-26

**Versión de arquitectura:** 3.0 (Bearer JSON-2, scope y polling HTTP)
