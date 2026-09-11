# Primera integración de componentes reactivos — 2026-09-10

Alcance: R01–R04 son entregas parciales de RT01, CT01/UI01, UI02 y RT03.
No significan que esos paquetes completos ni la app estén terminados.

## Implementado

- R01: catálogos UI conectados al observable del store local existente; replay,
  cancelación, errores y cierre. Router libera repositorios al retirar el scope.
- R02: binding tipado y campo de texto con foco estable, guardado inyectado,
  protección de escrituras simultáneas y resolución explícita de cambios externos.
- R03: rejilla Syncfusion y lista de tarjetas con controlador compartido y selección
  por ID. Fuente de rejilla estable. Escritorio/horizontal usan rejilla; vertical
  y teléfono usan lista. Selección conservada al cambiar tamaño/reordenar.
- R04: resultado de venta conserva issues y dimensiones comercial/sync/fiscal;
  no convierte cualquier error en aprobación ni sincronización en confirmación.
- Dependencia `syncfusion_flutter_datagrid` 34.2.5 incorporada mediante pub get;
  core resuelto 34.2.7. La autorización de desarrollo no sustituye comprobar
  licencia aplicable antes de distribuir.

## Evidencia y límites

- Análisis estático focal de los siete destinos modificados: sin incidencias.
- Resultado de regresión conjunta del integrador: **52 pruebas pasan**.
- Comando de regresión ejecutado desde `theos_panel`:
  `flutter test --no-pub --concurrency=1 test/app test/features/catalogs/runtime_scope_catalog_test.dart test/ui/bindings/field_binding_test.dart test/ui/bound_fields_test.dart test/ui/record_views_test.dart test/features/sales/sale_editor_test.dart test/features/sales/runtime_sale_outcome_test.dart`.
- Las pruebas de componentes usan tamaños lógicos, no navegador ni simulador.
  Los tests de puertos usan fixtures; no acreditan login/cobro real ni E2E.
- No se cambió Odoo, ERP2, datos reales ni el módulo externo de Envases.
- Las imágenes aprobadas no se modifican. No se aprueban nuevas pantallas aquí.

## Lo que falta y orden de continuación

1. RT02: store Drift del borrador por scope/empresa/draftId, migración conservadora
   y pruebas de reinicio/rollback. El editor sigue usando su store anterior;
   `FieldBinding.onSave` no constituye por sí mismo persistencia durable.
2. Completar contratos de campos/selectores: validación, permisos y adaptadores
   al store anterior antes de sustituir formularios. Widget no escribe SQL/Odoo.
3. Integrar rejilla/lista en pantallas aprobadas, edición y búsqueda de producto
   inline. Esta entrega es el componente de registros, no la rejilla comercial completa.
4. RT01 órdenes y RT03 conteos durables de cola: aún pendientes.
5. Imágenes editables/cache durable, cuatro acciones de cobro y contexto global.
6. Verificación web local en cuatro tamaños con recorridos aprobados y capturas;
   recién entonces contrastar implementación visual con las imágenes aprobadas.
