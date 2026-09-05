# Build y release

Un build exitoso no declara por sí solo que el producto esté listo para
publicación. El gate completo incluye análisis, suites, recorridos E2E,
artefactos por plataforma, escaneo de secretos y aprobación de distribución,
según [`PROJECT_COMPLETION_V1.md`](../specs/PROJECT_COMPLETION_V1.md).

## Preflight

Desde una revisión identificable y con el árbol de trabajo entendido:

```bash
flutter --version
make deps
make verify
make check-secrets
git diff --check
```

La versión reproducible es Flutter 3.47.1/Dart 3.13.1. No actualice
dependencias ni fuentes generadas como parte incidental de un release.

## Evidencia local vigente

El cierre local del 2026-08-26 comprobó, en el mismo árbol de trabajo:

- analyzers limpios en los cinco paquetes;
- 3568 pruebas aprobadas y 14 omitidas: SDK 1780 + 14 omitidas, core 558,
  widgets 188, QWeb 102 y app 940;
- escaneo de secretos y `git diff --check` en verde;
- builds release de Android APK/AAB, iOS sin firma, macOS y Web, incluido el
  dry run WebAssembly.
- E2E macOS read-only real aprobado: restauración segura en dos arranques,
  permisos, navegación principal y guard de ruta, sin escrituras en ERP2.

Esta evidencia no cubre Windows, firma, notarización, publicación, recorridos
controlados de escritura contra Odoo 19/20 ni piloto. Esos gates continúan
abiertos y no deben inferirse de las pruebas unitarias o de un build local.

## Artefactos

```bash
make build-appbundle
make build-ios
make build-macos
make build-web
```

Salidas esperadas:

| Target | Artefacto | Observación |
| --- | --- | --- |
| Android APK | `theos_pos/build/app/outputs/flutter-apk/app-release.apk` | Artefacto local; su firma de distribución se valida por separado. |
| Android AAB | `theos_pos/build/app/outputs/bundle/release/app-release.aab` | Sin firma de distribución si no existe `android/key.properties` válido. |
| iOS | `theos_pos/build/ios/iphoneos/Runner.app` | `--no-codesign`; no se instala en un dispositivo hasta firmarlo. |
| macOS | `theos_pos/build/macos/Build/Products/Release/Orbi ERP.app` | CI lo construye sin firma; firma y notarización son gates externos. |
| Web | `theos_pos/build/web/` | No contiene credenciales; el hosting aporta HTTPS/CORS y su base path. |
| Windows | `theos_pos/build/windows/x64/runner/Release/` | Se valida en el runner Windows de CI. |

Windows no se da por validado desde macOS. Ejecute `make build-windows` en
Windows o espere el job `build-windows` de GitHub Actions.

## Firma y publicación

- Android: copie `android/key.properties.example` fuera de Git, configure el
  keystore de distribución y repita el AAB. No use la clave debug.
- iOS/macOS: CI fuerza el build reproducible sin firma mediante las opciones
  de cada toolchain. Certificados, perfiles, archive, notarización y
  publicación son pasos externos y requieren autorización explícita.
- Web: nunca use `--dart-define` para una API key. Si se sirve bajo un
  subdirectorio, genere el build con el `--base-href` de ese despliegue.

No firme, publique, suba ni distribuya un artefacto desde una tarea de
diagnóstico.

## Comprobaciones posteriores

1. Verifique que el artefacto existe y registre su tamaño y checksum.
2. Ejecute los recorridos controlados de login/restauración, venta, cobro,
   factura, PDF y recuperación offline en el target correspondiente.
3. Compruebe que el artefacto no contiene `.env`, claves, certificados ni
   configuración de una base real.
4. Conserve el resultado del CI y los pasos E2E como evidencia de esa revisión;
   no reescriba informes históricos como estado permanente.

## Limitaciones conocidas del toolchain

- Flutter 3.47.1 todavía solicita el opt-out temporal de Built-in Kotlin y del
  nuevo DSL de AGP 9. No retire esas banderas hasta que el toolchain Flutter
  las soporte.
- iOS puede advertir que CocoaPods es redundante porque los plugins admiten
  Swift Package Manager. Mientras el build siga usando el Podfile actual, no
  elimine la integración sin una migración probada en un cambio separado.
- `file_picker_darwin 1.0.2` puede emitir un aviso SPM por la ruta de su
  `PrivacyInfo.xcprivacy`; es una incidencia del paquete y debe reevaluarse al
  actualizar esa dependencia.
