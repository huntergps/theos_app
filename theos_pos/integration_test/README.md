# E2E read-only

El recorrido real es explícitamente opt-in y sólo se ejecuta en un target
nativo debug. No inicia sincronización de catálogos ni procesadores de colas
offline; los indicadores pueden realizar health checks autenticados de solo
lectura. Recorre únicamente login/restauración, pantallas de consulta,
navegación y redirecciones de rutas protegidas.

La clave se lee del entorno del proceso y nunca se guarda en este repositorio:

```bash
THEOS_E2E_ENABLED=true \
THEOS_E2E_READ_ONLY=true \
THEOS_E2E_API_KEY='clave-de-pruebas' \
flutter test integration_test/read_only_session_navigation_test.dart -d macos
```

Opcionalmente se aceptan `THEOS_E2E_SERVER_URL` y `THEOS_E2E_DATABASE`. Sus
valores por defecto son el servidor ERP2 de pruebas. También pueden entregarse
como `--dart-define`, aunque para la clave se recomienda el entorno nativo para
evitar incluirla en los argumentos del proceso.

El test rechaza modo release, Web, HTTP no-loopback y cualquier ejecución sin
`THEOS_E2E_READ_ONLY=true`. Para CI sin credenciales, use el harness
determinista de `test/integration/session_navigation_harness_test.dart`.
