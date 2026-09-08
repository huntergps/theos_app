# F01-A · Scaffold independiente de theos_panel

Estado propuesto: ready_for_review

## Cambio observable

Se creó la shell Flutter de `theos_panel` con nombre visible Orbi ERP en la UI
y metadatos visibles de plataforma, tema
Material 3, `ProviderScope`, router `go_router` y una pantalla inicial mínima.
No contiene features, servicios Odoo ni contratos ficticios.

## Archivos

Generados por `flutter create` dentro de `theos_panel/`: shells Android, iOS,
Linux, macOS, Windows y Web, manifiestos y configuración de plataforma.
Metadatos visibles ajustados en Android, iOS, macOS, Linux, Windows y Web.
Cambios manuales: `pubspec.yaml`, `lib/main.dart`, `lib/app/`, `lib/ui/`,
`test/widget_test.dart` y metadatos de plataforma.

Dependencias resueltas: `orbi_runtime` por path, `material_ui 1.1.1`,
`flutter_riverpod 3.4.2`, `go_router 18.0.1` y `reactive_forms 18.2.2`.
`material_ui 1.1.1` declara Flutter >=3.44.0, compatible con Flutter 3.47.1.

## Evidencia ejecutada

| Comando | Entorno | Resultado |
| --- | --- | --- |
| `flutter pub get --offline` | Flutter 3.47.1 / Dart 3.13.1 | OK |
| `flutter analyze` | macOS, Flutter 3.47.1 | OK, sin issues |
| `flutter test test/widget_test.dart` | macOS, Flutter 3.47.1 | OK, 1 test |
| `dart pub deps --style=compact` + `rg` | paquete app | Sin `fluent_ui`, `odoo_widgets` ni `theos_pos`; `orbi_runtime` solo depende de Flutter |

## Criterios

- Shell independiente y exports básicos: cumplido para la app; `orbi_runtime`
  se consume mediante dependencia path existente.
- No dependencia directa/transitiva de `theos_pos`, `odoo_widgets` o
  `fluent_ui`: verificación de árbol y búsqueda, cumplido.
- Identidad Orbi ERP y paquete técnico `theos_panel`: cumplido; `flutter create`
  usó organización `com.tecnosmart` y los shells generados.
- Base Material oficial, Riverpod y go_router: cumplido. `reactive_forms` queda
  resuelto para tareas posteriores, sin uso prematuro.
- Test focal de app: cumplido; solo valida la shell, no integración ERP2.
- Metadatos visibles de plataforma muestran `Orbi ERP`; IDs técnicos y nombres
  de ejecutable se conservan para no romper los shells.

## Limitaciones

No se ejecutaron builds ni recorridos de seis plataformas; tampoco login, web
W01, runtime, ERP2, notificaciones o features. El primer `flutter pub get`
online quedó bloqueado durante resolución; la evidencia final usa `--offline`
con el caché local y resolución completa. No se modificaron runtime, CI, locks
fuera de `theos_panel`, contratos ni paquetes existentes.

## Revisión del integrador

Pendiente.
