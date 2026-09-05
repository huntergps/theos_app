# Instalación y configuración

Este runbook implementa la política de instalación limpia definida en
[`PROJECT_COMPLETION_V1.md`](../specs/PROJECT_COMPLETION_V1.md). La aplicación
no importa perfiles, credenciales, colas ni bases creadas por versiones de
desarrollo anteriores. Como nunca se desplegó en producción, no existe un
procedimiento de migración productiva ni una capa de compatibilidad legacy que
deba conservarse.

## Requisitos

- Flutter global 3.47.1 con Dart 3.13.1.
- Git y el toolchain nativo del target:
  - Android Studio/SDK y Java 17 para Android.
  - Xcode y sus Command Line Tools para iOS/macOS.
  - Visual Studio con Desktop development with C++ para Windows.
  - Chrome para desarrollo Web.
- Un servidor Odoo 19.x o 20.x con API JSON-2 y una clave API del usuario.

Compruebe que se usa el Flutter global esperado, no una copia temporal:

```bash
command -v flutter
flutter --version
flutter doctor -v
```

## Preparar el repositorio

Desde la raíz:

```bash
make deps
make verify
```

`make generate` solo es necesario al cambiar fuentes Drift, Freezed o
Riverpod. No edite archivos `*.g.dart` o `*.freezed.dart` manualmente.

## Configurar un servidor

En la pantalla de servidores registre:

- URL HTTPS base, sin una ruta `/web/...`.
- Nombre de la base Odoo.
- Clave API del usuario.

La app autentica cada petición JSON-2 con `Authorization: Bearer`. No usa
`/web/session/authenticate`, cookies de sesión ni `withCredentials`. Odoo es la
autoridad final de permisos; una clave solo permite lo concedido por sus ACL y
record rules.

En nativo, la clave se guarda en el almacén seguro de la plataforma. En Web es
efímera: un refresh o una nueva sesión del navegador puede requerir ingresarla
de nuevo. Nunca incluya claves en el repositorio, argumentos de un build
release, capturas, fixtures o logs.

## Desarrollo nativo con ERP2

El helper local es exclusivamente para builds debug nativos. Lee un archivo
ignorado, nunca incorpora la clave en un release y rechaza targets Web:

```bash
mkdir -p ~/.config/tecnosmart
chmod 700 ~/.config/tecnosmart
# Cree ~/.config/tecnosmart/erp2_api.env con su editor y una línea:
# ERP2_API_KEY=<clave local>
chmod 600 ~/.config/tecnosmart/erp2_api.env
make run-macos
```

Para Web use `flutter run -d chrome` e introduzca la clave en la UI. No use
`--disable-web-security`; el servidor debe responder CORS en `/json/2/...`.

## Validación inicial

1. Inicie sesión y confirme servidor, base, usuario y versión detectada.
2. Compruebe que el menú coincide con los grupos del usuario.
3. Ejecute una sincronización de lectura y confirme que el catálogo local se
   conserva al desconectar la red.
4. No realice escrituras sobre `erp2` durante diagnóstico. Las pruebas de
   escritura requieren un entorno controlado y autorización separada.

Si algo falla, no borre la base ni la cola. Continúe con
[`OFFLINE_SUPPORT.md`](OFFLINE_SUPPORT.md).
