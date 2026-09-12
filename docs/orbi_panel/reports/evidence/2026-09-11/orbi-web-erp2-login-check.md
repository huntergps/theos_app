# Orbi (theos_panel) en navegador contra ERP2 — medido, no asumido

Build local, `flutter run -d web-server --web-port=8791`, servido en
`http://127.0.0.1:8791`. Sin `--dart-define`, sin script de credenciales: nada
de esto llegó al navegador por compilación. Chrome real (extensión
claude-in-chrome), consola y red monitoreadas con `read_console_messages` /
`read_network_requests`.

## 1. Desplegable de bases de datos — NO se llena solo

Servidor nuevo: `https://erp2.tecnosmart.com.ec`. A los ~500ms del debounce de
`_onUrlChanged`, el campo "Base de datos" NO se convierte en desplegable.
Aparece el aviso:

> "Desde esta plataforma no se puede consultar la lista de bases. Escribe el
> nombre manualmente."

Captura: `login-db-discovery-unsupported-web.jpg`.

**Punto exacto:** `odoo_sdk/lib/src/auth/database_discovery_web.dart` — la
implementación web de `OdooDatabaseDiscovery.listDatabases()` lanza
`DatabaseDiscoveryException(unsupportedPlatform)` de forma incondicional,
ANTES de intentar cualquier red. `read_network_requests` confirma cero
peticiones a `erp2.tecnosmart.com.ec` durante todo el intento.

**Causa documentada en el propio código:** el comentario del archivo dice que
`/web/database/list` de Odoo "no declara política CORS" (a diferencia de la
interfaz JSON-2, que sí declara `cors: '*'`), así que un build web sería
bloqueado por el navegador antes de llegar al servidor — y el código evita esa
petición inútil directamente. Esto es DISTINTO de lo habilitado hoy en el
servidor (`list_db = True`): ese cambio no tiene ningún efecto visible desde
un build web de Orbi, porque el cliente nunca intenta la llamada.

## 2. Acceso con usuario y contraseña — falla, pero en SILENCIO (sin red, sin mensaje)

Con el servidor "ERP2 pruebas" seleccionado, usuario y una contraseña de
prueba escritos, clic en "Iniciar sesión":

- `read_network_requests` tras el clic: **0 peticiones** a
  `erp2.tecnosmart.com.ec` (ni siquiera un intento bloqueado por CORS).
- `read_console_messages`: sin errores, sin excepciones.
- La UI: el campo contraseña se limpia (comportamiento normal de
  `_submit()`), el botón vuelve a "Iniciar sesión", y **no aparece ningún
  mensaje de error** — ni el panel `LoginFailurePanel`, ni el texto plano.

Captura: `login-password-silent-failure.jpg` (compárese con la pantalla
anterior: la contraseña de prueba desapareció y no hay ningún aviso).

**Punto exacto:** `theos_panel/lib/app/bootstrap.dart`,
`WebSessionAuthService.login()`:

```dart
Future<AuthServiceResult> login({...}) async =>
    const AuthServiceResult(status: AuthServiceStatus.required);
```

Retorna `AuthServiceStatus.required` de forma incondicional, sin tocar la
red. `AuthNotifier._fromResult` mapea `required` a
`AuthViewState(status: AuthControllerStatus.required)` **sin `message`**, así
que no hay nada que mostrar. El mensaje "El acceso web con contraseña está
pendiente de W01" que sí existe en el código (rama
`AuthServiceStatus.unsupportedWeb` de `_fromResult`) es inalcanzable en la
práctica: ningún servicio real devuelve ese estado — `WebSessionAuthService`
devuelve `required` directo.

## Conclusión frente a la hipótesis del encargo

La hipótesis decía: (1) el listado de bases funcionaría porque esa ruta ya
acepta cualquier origen, y (2) el acceso con contraseña fallaría porque la
ruta todavía no existe.

- **(2) se confirma**: el acceso con contraseña no funciona.
- **(1) NO se confirma como se planteó.** El listado tampoco funciona, pero
  no porque el servidor lo rechace (de hecho hoy sí lo permite y sí declara
  CORS abierto en la interfaz de datos JSON-2) — el listado de bases usa un
  endpoint distinto (`/web/database/list`) que Odoo nunca declaró como
  cross-origin, y el CLIENTE de Orbi para web decidió, de antemano, no
  intentar siquiera esa llamada. Es un bloqueo del lado del navegador/cliente,
  no del servidor.

Ambos caminos fallan sin tocar la red del todo (0 peticiones a erp2 en
ninguno de los dos intentos) — el gap no es "la ruta responde mal", es "el
cliente web nunca llama".
