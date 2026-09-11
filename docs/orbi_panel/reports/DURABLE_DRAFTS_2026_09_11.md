# Borradores durables — integración local 2026-09-11

## Implementación

- Tabla aditiva `orbi_editable_draft` creada al abrir la BD de Orbi, sin modificar
  el esquema compartido de theos_pos ni crear otra conexión.
- Clave `(scope_key, company_id, draft_id)`, payload JSON y revisión local CAS.
  El borrador no crea órdenes comerciales ni comandos en outbox.
- Store runtime con lectura, guardado transaccional y observable Drift; usa el
  lease existente. Pruebas con archivos SQLite temporales y reapertura real.
- Codec versionado preserva todos los campos actuales, incluidos descuento,
  impuesto, total, versiones y aprobación. Datos corruptos/incompletos se rechazan.
- Adaptador del editor valida ámbito, revisión e identidad; no pisa un borrador
  existente si el usuario editó antes de recuperarlo.
- Router usa el store durable cuando hay runtime y empresa explícita. Sin ellos,
  no simula persistencia con memoria ni preferencias.
- Controller serializa guardados, expone errores, espera `flush` antes de acciones,
  evita restore tardío sobre edición y no elimina datos al cerrar listeners.
- Cliente digitado tiene listener activo; cliente y nota restaurados actualizan
  campos. El error local muestra aviso y bloquea acciones comerciales.

## Límites explícitos

- La ruta actual tiene un único editor y usa `workspace-active-editor` como slot
  por usuario/empresa. Store admite IDs múltiples; aún falta navegación multi-tab
  con IDs estables. No se confunde este ID con commandId.
- Preferencias legacy se conservan intactas y no se migran ni asignan a empresas.
  Recuperación asistida de ese legado queda pendiente; no afirmar migración completa.
- No se implementó aún resolución visual de CAS ni recuperación del error sin
  reabrir/editar según el caso. No introducir un botón que sobrescriba conflictos.
- No se cambió el contrato de confirmación/acciones ni se acreditó idempotencia
  backend con estos tests de almacenamiento local.
- No E2E web, prueba de cierre abrupto del proceso ni validación visual final en
  cuatro formatos en esta entrega. Reapertura de SQLite no equivale a esos E2E.

## Envases

El dueño informó la entrega del módulo. La revisión de fuentes identificó
`l10n_ec_stock_envases` y su contrato local. Ver el informe enlazado desde handoff.
No se instaló/actualizó Odoo, no se tocó ERP2 y no se habilitó replay de movimientos
de envases sin verificar su contrato. No confundir esto con ausencia de capacidades
nativas de Inventario: deben reutilizarse, no duplicarse.

## Verificación

- `orbi_runtime`: seis pruebas de `test/sales/editable_draft_store_test.dart`
  pasan; análisis estático focal de store/owner/tests limpio.
- `theos_panel`: `flutter test --no-pub --concurrency=1 test/app test/features/sales`
  pasó 58 pruebas. La prueba adicional de reemplazo de controller se verifica
  separadamente después de esa regresión.
- El fixture de lease abre dos instancias durante el relevo y Drift emite un
  aviso de múltiples instancias; las pruebas pasan, no se ocultó ese aviso.
- Regresión final tras lifecycle/errores posteriores: 23 pruebas de
  `sale_draft_persistence_test.dart` y `sale_editor_test.dart` pasan. Análisis
  focal de siete destinos de panel sin incidencias.
- `flutter build web --no-pub`: éxito (136,7 s), con aviso de fuente Cupertino
  ausente; pendiente revisión visual de iconos. Compilación anterior a los últimos
  ajustes de manejo de errores, que sí fueron analizados y probados después.
