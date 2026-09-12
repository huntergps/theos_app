# Operational shell gallery harness

Este harness captura la maqueta web cuando exista el target
`dev/operational_shell_gallery.dart`. Es sólo visual: no usa credenciales,
ERP2, Odoo ni endpoints de negocio.

## Uso

Desde `theos_panel/`:

```bash
./tool/capture_operational_shell_gallery.sh
```

También se puede indicar otro target y directorio de salida:

```bash
ORBI_GALLERY_OUTPUT_DIR=/tmp/orbi-gallery \
  ./tool/capture_operational_shell_gallery.sh dev/operational_shell_gallery.dart
```

El script elige un puerto libre en `127.0.0.1`, levanta `flutter run -d
web-server`, espera como máximo 60 segundos, captura 390×844, 820×1180 y
1440×900 con Chromium headless, y cierra el proceso Flutter mediante `trap`.
No usa `flutter run` sobre macOS ni inicia un runner nativo.

`CHROME_BIN` permite indicar la ruta del navegador si no está en `PATH`.
`ORBI_GALLERY_PORT` permite fijar un puerto sólo para depuración local.

## Criterio de salida

La carpeta de salida contiene tres PNG y `flutter-web-server.log`. Si el
servidor termina antes de responder o el navegador no está disponible, el
script falla con código distinto de cero y ejecuta igualmente el cleanup.
