# Arquitectura y decisiones

## ADR-01 · independencia y reutilización

```text
theos_pos (Fluent)                theos_panel (Orbi/Material)
        \                         /
         orbi_runtime (Flutter, sin UI)
              |             |
       theos_pos_core     adaptadores de plataforma
              |
           odoo_sdk

flutter_qweb: consumido para documentos por cada app o su servicio de reportes.
odoo_widgets: consumido por theos_pos; no dependencia de theos_panel/runtime/core.
```

El dibujo es destino, no estado ya implementado. Extraer verticalmente; mantener
fachadas temporales en `theos_pos` para evitar una migración masiva.

| Paquete | Posee | No debe poseer |
| --- | --- | --- |
| `odoo_sdk` | Transporte JSON-2, errores, descubrimiento, primitivas de cola/retry | Pantallas, Fluent, reglas específicas de ventas EC |
| `theos_pos_core` | Modelos, Drift, reglas/casos de uso de negocio, contratos de repositorios | Widgets, navegación, plugin de notificaciones, ProviderScope |
| `orbi_runtime` (nuevo) | Adaptadores Flutter, sesión, apertura de BD, credenciales, composición Riverpod, avisos del SO | Tema, diálogos, rutas de pantalla, import de cualquiera de las apps |
| `theos_panel` (nuevo) | Composición final, navegación, presentación Material, formularios, recursos e instaladores | Segunda implementación de impuestos/pagos o motor de sync |
| `flutter_qweb` | Interpretación y generación de documentos | Reglas de cobro y autorización fiscal |

## ADR-02 · estructura prevista

```text
orbi_runtime/lib/src/{session,storage,auth,connectivity,sync,notifications,providers}/
theos_panel/lib/app/{bootstrap,router,theme}/
theos_panel/lib/ui/{components,forms,layouts}/
theos_panel/lib/features/{auth,home,orders,sales,collection,clients,products,
                         approvals,activities,reports,sync,notifications,settings}/
theos_panel/test/{app,ui,features}/
theos_panel/integration_test/
theos_panel/android|ios|linux|macos|windows|web/
```

La creación de shells y manifiestos pertenece a `F01`; no son carpetas ya creadas.
Los componentes visuales Orbi comienzan internos. Evitar paquetes nuevos por
cada pantalla, motor de formularios universal o marco paralelo de plugins.

## ADR-03 · estado y dependencias

- Una conexión Drift y un cliente por sesión activa en una instalación.
- Sesión parametrizada por appId/installationId/server/database/uid; empresa
  efectiva forma parte de filtros y permisos. No elegir DB por la clave API.
- Inyectar dependencias por constructor; providers componen instancias. Los
  objetos puros no reciben `Ref`, `WidgetRef` ni `BuildContext`.
- Evitar nuevos singletons mutables. Los existentes se migran por frontera,
  manteniendo binding/reset mientras los necesite `theos_pos`.
- No abrir simultáneamente una segunda base para los mismos datos con otro
  `DatabaseHelper`. Un propietario abre/cierra; los demás reciben la instancia.
- En la nueva app, `orbi_runtime` crea el executor y la instancia `AppDatabase`,
  espera su apertura/migración y la cierra. El core define esquema/migraciones y
  operaciones, pero no crea otra conexión mediante su helper estático. La fachada
  actual de `theos_pos` se adapta gradualmente en F07; no retirar su ruta vigente
  antes de que tenga consumidor y pruebas equivalentes.
- El agente de sesión es único propietario de activar/parar listeners, cola,
  timers y streams. Cambio de usuario detiene el trabajo anterior antes de abrir
  el nuevo scope. Una respuesta tardía del scope previo se descarta.
- Compartir código no comparte Keychain, preferencias o archivos automáticamente:
  definir namespaces/identificadores propios; web usa origen y appId separados.

## ADR-04 · dependencias propuestas

Base Flutter alineada inicialmente con el pin del repositorio: 3.47.1/Dart 3.13.1.
F01 verifica SDK instalado y resolución real. No hacer upgrades generales.

| Selección | Decisión |
| --- | --- |
| `material_ui` 1.1.1 | Base visual oficial; no prometer cobertura total de M3 Expressive |
| `reactive_forms` | Formularios; resolver versión compatible y fijarla en lockfile |
| Riverpod/go_router/Drift | Mantener línea compatible con paquetes existentes |
| `connectivity_plus` 7.3.1 | Señales de red; disponibilidad de Odoo por cliente/health |
| `flutter_local_notifications` 22.3.0 | Adaptador de avisos; verificar API/platform setup reales |
| `flutter_svg` | Logo existente; distribuir recursos offline |
| `widgetbook` | Catálogo de desarrollo, no dependencia del arranque productivo |
| Syncfusion DataGrid | Usar si licencia y necesidad avanzada están confirmadas |
| `flex_color_picker` | Solo selector de acento en Configuración cuando se implemente |
| `material_3_expressive` | Evaluación selectiva; no contrato obligatorio para la primera app |

No instalar varios frameworks visuales o escaladores globales. Material oficial
ya aporta navegación, selección, menús y entradas; componentes adicionales deben
justificarse con una necesidad y una prueba de compatibilidad. Si una librería
todavía usa `flutter/material.dart`, verificar `MaterialUiCompatibilityBridge`.

## ADR-05 · formularios reactivos

`FormGroup` posee el buffer de edición, touched/dirty y validación de entrada.
Riverpod posee estado de pantalla/operación. Drift posee resultados persistidos.
No duplicar el mismo buffer mutable entre tres capas. Un refresh remoto nunca
sobrescribe silenciosamente campos dirty. Las reglas comerciales son funciones
del core invocadas desde el formulario, no versiones reescritas en validadores.

Un campo puede usar `value/onChanged` para edición simple o un adaptador a
`FormControl`; no necesita conocer Odoo. Streams sirven para valores persistidos.
Crear/controlar/disponer FormGroup fuera de `build` para no perder edición.

## ADR-06 · notificaciones

Inbox persistente en tablas locales del core, no nueva tabla de cobros en Odoo.
Adaptador del SO en runtime; bandeja y navegación en app. Ver NOTIFICATIONS.md.
La incorporación al esquema compartido es aditiva y tiene un único responsable
de migración/generación. Una app anterior que no lo usa sigue funcionando.

## ADR-07 · web y documentos

Inventariar plugins nativos y recursos WASM/worker/PDF antes de afirmar soporte.
Empaquetar recursos necesarios para offline, evitando carga obligatoria desde
CDN. Verificar almacenamiento tras recarga, permisos y límites del navegador.
No cambiar CORS o autenticación backend silenciosamente. W01 debe resolverse
con el dueño si exige una extensión del servidor. Push pertenece a P01.

## Estilo de contratos

```dart
abstract interface class OrderCommands {
  Future<OperationOutcome> confirm(ConfirmOrderCommand command);
}

// El resultado describe negocio y sincronización por separado.
// El widget muestra el resultado; no ejecuta métodos Odoo directamente.
```

El fragmento es forma del contrato, no API Dart ya implementada. F01 materializa
los tipos del documento CONTRACTS.md y el integrador revisa imports públicos.
