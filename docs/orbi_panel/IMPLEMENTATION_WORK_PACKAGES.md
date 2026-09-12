# Paquetes de trabajo para desarrollo posterior

Estado: plan técnico propuesto; ninguna tarea se está implementando en esta entrega.
No altera `tasks.json` histórico de 24 tareas ni convierte sus estados done en
evidencia de estos contratos nuevos. Activar tareas requiere autorización de desarrollo.

## Contratos de entrada

- [Auditoría de núcleo](OFFLINE_CORE_TECHNICAL_AUDIT.md): mecanismos presentes y huecos.
- [Interfaces](COMPONENT_INTERFACE_CONTRACTS.md): propuestas, no imports existentes.
- [Bindings Odoo](ODOO_ACTION_BINDINGS.md): fuentes y guardas; instancia por comprobar.
- [Índice visual](APPROVED_SCREEN_INDEX.md), [widgets](REACTIVE_COMPONENTS_SPEC.md)
  y [cobros](OPERATION_INTERACTION_OFFLINE_MATRIX.md): comportamiento requerido.

## Reglas de asignación

Máximo tres ejecutores y un integrador. Una tarea tiene un propietario y hasta cinco
archivos manuales concretos. Rutas nuevas abajo son propuestas, no archivos existentes.
El integrador aprueba firmas/imports antes de distribuir; no crear tipos duplicados.
Dependencia significa integrada y verificada, no «el otro agente casi acaba».

El integrador posee exports, router raíz, composición global, pubspec/locks y
migraciones. Cambios necesarios en core/paquetes compartidos se desglosan antes de
autorizar; no se amplía el alcance de una fila por iniciativa del ejecutor.
ERP2 es un entorno de pruebas: se puede escribir en él sin pedir autorización
caso por caso; producción (`newerp`) sigue excluida, sin excepción. Pruebas web
locales, sin simuladores; usar ERP2 sólo cuando el entorno/instancia estén
identificados.

## Tareas acotadas

| ID | Objetivo | Depende de | Archivos asignables (máximo 5) | Aceptación |
|---|---|---|---|---|
| CT01 | Integrar tipos definitivos para estado, identidad y eventos, adaptando tipos existentes | Revisión de interfaces | `theos_panel/lib/ui/bindings/field_binding.dart`; `theos_panel/lib/ui/bindings/query_binding.dart`; `theos_panel/lib/ui/bindings/image_binding.dart`; `theos_panel/test/ui/bindings/contracts_test.dart` | Eventos tipados, ID sin ambigüedad local/remoto, sin Flutter en núcleo, sin SQL en widget; ejemplos mínimos de consumo |
| RT01 | Conectar listados/catálogos a observables existentes y cerrar recursos | CT01 | `theos_panel/lib/app/order_scope_repository.dart`; `theos_panel/lib/app/scope_catalog_repository.dart`; `theos_panel/test/app/order_scope_repository_test.dart`; `theos_panel/test/app/scope_catalog_repository_test.dart` | Commit local actualiza lista y contador; dispose/cambio de contexto cancela; no emisión de A en B. Si falta puerto del lector, dividir ampliación antes de implementar |
| RT02 | Unificar propiedad y persistencia del borrador editable | Decisión de store durable y migración aprobada | `theos_panel/lib/features/sales/sale_editor.dart`; `orbi_runtime/lib/src/sales/sale_draft_repository.dart`; `theos_panel/test/features/sales/sale_draft_controller_integration_test.dart`; `orbi_runtime/test/sales/sale_draft_repository_test.dart` | Reinicio conserva campos completos, descuento/impuesto y texto incompleto; empresa aislada; escrituras serializadas; guardar borrador no confirma ni encola venta automáticamente |
| RT03 | Corregir presentación de resultados y conteos de sincronización | RT02 | `orbi_runtime/lib/src/sales/sale_command_port.dart`; `orbi_runtime/lib/src/sync/sync_coordinator_impl.dart`; `orbi_runtime/test/sales/sale_runtime_adapters_test.dart`; `orbi_runtime/test/sync/sync_coordinator_test.dart` | Rechazo/conflicto/incertidumbre no se muestran como aprobación pendiente; contadores coinciden con operaciones reales; extender a composición en tarea propia si necesario |
| UI01 | Campos enlazados y selectores con foco estable | CT01, RT01, RT02 | `theos_panel/lib/ui/components/orbi_bound_fields.dart`; `theos_panel/lib/ui/components/orbi_entity_selector.dart`; `theos_panel/test/ui/bound_fields_test.dart`; `theos_panel/test/ui/entity_selector_test.dart` | Vacío ≠ cero, selección ID/etiqueta atómica, búsqueda tardía descartada, Enter contextual, KI03/04 y RC03/04 |
| UI02 | Adaptador Syncfusion y alternativa compacta | CT01, RT01, licencia/SDK verificados por integrador | `theos_panel/lib/ui/components/orbi_record_grid.dart`; `theos_panel/lib/ui/components/orbi_record_list.dart`; `theos_panel/lib/ui/bindings/record_view_controller.dart`; `theos_panel/test/ui/record_views_test.dart` | Misma consulta/filtro/selección; rejilla wide, tarjetas vertical/teléfono; anchos/visibilidad por contexto; RC05 y KI14/15 |
| IM01 | Contrato y store durable de propuestas de imagen | CT01, campo/permisos Odoo verificados, decisión de almacenamiento | `orbi_runtime/lib/src/media/image_resource_port.dart`; `orbi_runtime/lib/src/media/image_resource_store.dart`; `orbi_runtime/test/media/image_resource_store_test.dart` | Blob pendiente protegido de caché, reinicio, fallo de escritura sin falso éxito, identidad/revisión y scope; no suponer filesystem en web. Si necesita esquema core, tarea separada del integrador |
| IM02 | Componentes imagen/avatar y cambio autorizado | IM01, CT01 | `theos_panel/lib/ui/components/orbi_product_image.dart`; `theos_panel/lib/ui/components/orbi_customer_avatar.dart`; `theos_panel/lib/ui/components/orbi_image_editor.dart`; `theos_panel/test/ui/image_components_test.dart` | Miniatura/detalle, archivo/cámara según soporte, quitar con confirmación, permisos/rechazo/conflicto, RC06–11. Sync remoto no se finge con mocks |
| CA01 | Adaptador de las cuatro acciones de cobro existentes | Bindings y recuperación Odoo probados en entorno seguro | `theos_panel/lib/features/collection/collection_contracts.dart`; `theos_panel/lib/features/collection/runtime_collection_actions.dart`; `orbi_runtime/lib/src/sales/collection_operation_port.dart`; `theos_panel/test/features/collection/runtime_collection_actions_test.dart` | Abonar/Guardar Abono/Cobrar/Pago Completo separados, términos mixtos y vuelto; CJ08–12. No implementar dinero con reglas inventadas ni llamar Guardar Abono a guardar draft |
| SH01 | Menú/contexto y avisos del shell aprobado | CT01, capacidades enlazadas | `theos_panel/lib/ui/components/orbi_workspace_shell.dart`; `theos_panel/lib/ui/components/orbi_context_footer.dart`; `theos_panel/lib/ui/components/orbi_operation_notice.dart`; `theos_panel/test/ui/workspace_shell_test.dart` | Unión multirrol, PIN sólo ventas, hora remota rotulada, sesión/punto, estados separados; NAV01–10 conforme equivalencia de IDs del documento |
| SL01 | Integrar primer recorrido vertical de venta | RT01–03, UI01–02, SH01 | `theos_panel/lib/features/sales/sale_editor.dart`; `theos_panel/test/features/sales/sale_editor_test.dart`; `theos_panel/integration_test/sales_offline_journey_test.dart` | Login digitado por campos, alta inline, cantidad, guardar, cerrar/reabrir offline y recuperar; cuatro formatos y baseline B; prueba de red fallida sin perder trabajo |
| QA01 | Evidencia E2E y comparación visual del primer recorrido | SL01 | `theos_panel/tool/e2e/sales_offline_journey.spec.ts`; `docs/orbi_panel/reports/SL01_ACCEPTANCE.md` | Herramienta navegador disponible verificada antes; evidencia de cada campo/foco/valor, sin API para simular login visual; capturas reales comparadas con aprobadas, errores/pendientes explícitos |

Los escenarios se nombran RC01–12, KI-01–18, CJ-8–12 y NAV-1–10 en sus documentos.
Las referencias sin guion en la tabla son abreviaciones, no casos nuevos.

## Orden y paralelismo

1. Integrador cierra CT01 y decisiones de persistencia/licencia. No migrar ni instalar
   dependencias sólo porque están mencionadas en este plan.
2. RT01 y RT02 pueden ejecutarse en paralelo; tercer agente puede preparar SH01
   cuando sus capacidades estén resueltas. RT03 espera RT02 para evitar solapamiento.
3. UI01 y UI02 después de sus dependencias; IM01 puede avanzar sólo con su contrato
   de backend y almacenamiento resuelto. IM02 no simula un store todavía inexistente.
4. SL01 integra una venta completa antes de extender pantallas. CA01 es otro bloque
   condicionado a bindings y pruebas; no frena la edición/recuperación de ventas.
5. QA01 valida lo integrado. Sólo después se desglosan tareas de Caja auxiliar,
   Bodega, Aprobaciones y Envases con archivos y puertos verificados por operación.

## Pendientes reales antes de llamar cerrado al contrato

**Resolución posterior:** [Decisiones técnicas](TECHNICAL_DECISIONS.md),
[estado local](LOCAL_STATE_DECISIONS.md) e [imágenes](IMAGE_STORAGE_DECISIONS.md)
cierran la elección de store, ownership, migración conservadora, observables,
identidad/cursor y almacenamiento de blobs. RT01 no espera migración de drafts;
RT02 sí integra esquema y migración con propiedad del integrador. Los puntos de
pruebas/instancia siguientes permanecen como puertas de aceptación, no como nuevas
decisiones de producto. Syncfusion está elegido; su licencia no se presume.

- Firmas definitivas/imports frente a APIs existentes: propuestas no son compilación.
- Estrategia durable de edición y migración de borradores actuales sin pérdida.
- Ciclo de vida/paginación y contadores de cola verificados con fallos inducidos.
- Modelo/campo de imágenes, límites, revisión/conflicto y transporte por plataforma.
- Permisos efectivos y límites transaccionales de cada operación Odoo en instancia segura.
- Envases sigue entrega externa: no asumir instalado por recibir un documento preliminar.
- Herramienta E2E concreta y dependencias de test antes de crear scripts; ninguna
  prueba live heredada con ERP2 forma parte de estas tareas.

## Entrega por tarea

Commit acotado, diff, pruebas ejecutadas con comando/salida, qué falló primero y qué
pasó después, escenarios cubiertos y bloqueos. Tests de widget acreditan interacción;
integración local acredita persistencia; sólo prueba de backend acredita efecto remoto.
No declarar E2E por compilar ni superioridad a theos_pos por una captura.
