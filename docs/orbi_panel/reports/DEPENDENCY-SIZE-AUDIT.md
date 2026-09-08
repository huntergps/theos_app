# F01 · Auditoría de dependencias y tamaño de `theos_panel`

Auditoría sólo lectura, 2026-09-07. No se ejecutaron builds ni se modificaron
`pubspec`, lockfiles o código.

## Independencia

`flutter pub deps --json` no contiene paquetes llamados `theos_pos`,
`odoo_widgets` ni `fluent_ui`; tampoco hay imports de esos nombres en `lib/` o
`test/`. Por tanto no existe dependencia directa o transitiva con esas tres
apps/librerías. Sí existe la dependencia esperada `orbi_runtime →
theos_pos_core → odoo_sdk`; `theos_pos_core` es transitive para el panel y no
debe confundirse con la app `theos_pos`.

Evidencia de grafo resuelto:

```text
orbi_runtime direct: ... odoo_sdk, theos_pos_core
theos_pos_core transitive: ... odoo_sdk
odoo_sdk dev-only directo del panel
```

## Tamaño y assets

```text
theos_panel/lib:       300K, 40 Dart files
theos_panel/test:      144K, 21 Dart files
assets:                  8K (orbi_logo.svg: 7,178 bytes)
android/ios/macos:     4.7M
linux/windows/web:     228K
```

El checkout contiene artefactos locales que no representan el paquete fuente:
`build/` ocupa 2.3G y `.dart_tool/` 274M. Las fuentes locales enlazadas suman
aprox. `theos_pos_core/lib` 6.9M, `odoo_sdk/lib` 1.4M y `orbi_runtime/lib`
196K.

## Dependencias pesadas o duplicadas

- `material_ui` está declarado pero no aparece en imports; es una oportunidad
  clara de eliminación, su copia de caché ocupa 25M.
- `cupertino_icons` tampoco aparece en imports; revisar y eliminar si no se
  requiere desde un asset/config indirecto.
- `shared_preferences` está declarado por panel y runtime; el lock resuelve una
  sola versión (`2.5.5`), por lo que no es duplicación binaria, pero conviene
  dejarlo bajo ownership de runtime si el panel no necesita acceso directo.
- Drift/SQLite, secure storage y local notifications arrastran familias de
  plugins por plataforma; son coste funcional, no duplicación accidental.
- `flutter_svg` sólo tiene un consumidor (logo); conservarlo si el logo sigue
  siendo SVG o convertir el asset si se busca reducir dependencia.

## Plataformas/build disponible

Existen shells y archivos de entrada para Android, iOS, macOS, Linux, Windows y
Web (`android/app/build.gradle.kts`, proyectos Xcode, CMake y `web/index.html`).
La disponibilidad estructural no acredita builds: esta auditoría no ejecutó
`flutter build`.

Recomendaciones: eliminar primero dependencias directas sin imports; mantener
`orbi_runtime` como frontera de persistencia/notificaciones; medir tamaño con
builds release por plataforma después de limpiar artefactos locales, sin usar el
tamaño de `build/` como proxy del binario.
