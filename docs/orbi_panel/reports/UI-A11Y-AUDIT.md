# Auditoría UI/A11Y de Orbi ERP

Fecha: 2026-09-07. Alcance: rutas de `theos_panel/lib/app/router.dart` y pantallas
de login, inicio, ventas/órdenes, editor de venta, clientes, productos, caja,
aprobaciones, actividades, avisos, documentos, sincronización y configuración.
Se revisaron compacto `<600`, medio `600–839` y amplio `>=840`, entrada de
teclado/mouse/touch, text scale 0.8–2.0, temas, targets y semantics por inspección
de código. No hubo render manual en dispositivo ni sesión VoiceOver/TalkBack; esos
resultados quedan explícitamente como no verificados.

## Bloqueos priorizados

### P1 — riesgo de overflow/reflow en text scale 2.0

1. **Editor de venta amplio** — `theos_panel/lib/features/sales/sale_editor.dart:560-568,573-695`.
   La rama `>=840` devuelve un `Row` con el formulario izquierdo sin `ScrollView`; la
   columna contiene picker fijo de 260 px, líneas y controles. A text scale 2.0 o
   ventana baja puede desbordar verticalmente. Corrección mínima: envolver la columna
   de formulario y el resumen en scroll independiente (`SingleChildScrollView`) o
   limitar el layout a una altura disponible; conservar el borrador.

2. **Aprobaciones amplias** — `theos_panel/lib/features/approvals/approvals_screen.dart:78-93`.
   `GridView.count(childAspectRatio: 3.2)` fija la altura de cada tarjeta aunque el
   contenido incluya título, estado y tres botones. Aumentar texto/nombre de pedido
   puede producir overflow o controles comprimidos. Corrección mínima: `GridView.extent`
   con altura mínima robusta, o tarjetas de altura intrínseca mediante lista en medio/
   amplio cuando el contenido crece.

3. **Caja compacta/media** — `theos_panel/lib/features/collection/collection_screen.dart:58-73,127-178`.
   La columna compacta combina `Expanded(_pendingList())` con `_editor()` no
   desplazable; el editor contiene dropdown, campos, totales y acciones. Con 2.0 el
   editor puede exceder el remanente y generar overflow vertical. Corrección mínima:
   hacer desplazable el editor o usar un layout de una sola lista con sección de
   detalle; probar teclado abierto y 599 px.

4. **Avisos compactos** — `theos_panel/lib/features/notifications/notification_inbox.dart:165-200`.
   Cada `ListTile` reserva un `Wrap` de dos `IconButton` en `trailing`, además de
   títulos/subtítulos potencialmente largos. No hay estrategia de reflujo para ancho
   estrecho/text scale 2.0. Corrección mínima: mover acciones a `PopupMenuButton` o
   permitir una segunda fila/acción deslizable con labels accesibles.

## P2 — accesibilidad/robustez

5. **Semantics duplicada en entidades** — `theos_panel/lib/features/clients/entity_picker.dart:94-109`.
   El `Semantics(button: true, label: ...)` envuelve un `ListTile(onTap: ...)`, que
   también expone control accionable; puede anunciarse dos veces. Corrección mínima:
   usar `MergeSemantics` o `excludeSemantics` en uno de los niveles y conservar
   `selected`/nombre en un único control.

6. **Errores no anunciados como región viva** —
   `approvals_screen.dart:68-74`, `notification_inbox.dart:149-153`,
   `document_view.dart:56-60`, `sync_center.dart:135-140`.
   Son `Text` centrados (uno con `semanticsLabel`) pero no `liveRegion`; un cambio
   posterior a carga puede no anunciarse al lector de pantalla. Corrección mínima:
   reutilizar `OrbiErrorState` o `Semantics(liveRegion: true, container: true)` con
   mensaje y acción de reintento.

7. **Flujo de teclado del login** — `theos_panel/lib/features/auth/login_screen.dart:121-152`.
   Los cuatro `TextField` tienen labels y autofill, pero no `textInputAction`,
   `onSubmitted` ni foco explícito para avanzar/submit desde teclado móvil. Corrección
   mínima: `next` entre servidor/base/usuario, `done` en contraseña y foco/submit al
   botón; mantener el orden de lectura actual.

8. **Selector de término** — `theos_panel/lib/features/sales/sale_editor.dart:604-625`.
   Usa `DropdownButton` separado de su texto visual “Término de pago”, sin
   `InputDecoration(labelText:)`; requiere verificación de nombre accesible y foco
   visible en lector/teclado. Corrección mínima: `DropdownButtonFormField` etiquetado.

## Evidencia y límites

- `flutter test test/ui/component_gallery_test.dart test/features/orders/orders_screen_test.dart test/features/sales/sale_editor_test.dart test/features/catalogs/catalog_features_test.dart`: pasó (21 tests), incluyendo breakpoints y varios cambios de tamaño/text scale.
- El test de editor emitió warning de `tap()` sobre “Seleccionar término” fuera del
  hit-test viewport (`sale_editor_test.dart:248`); no falló, pero respalda revisar
  scroll/foco del editor compacto.
- No se ejecutó suite completa ni pruebas de lector de pantalla, contraste medido,
  mouse hover o navegación real con Tab; esos criterios permanecen no verificados.
- Base positiva: Material 3/ColorScheme oficial en `app/theme/orbi_theme.dart:29-57`,
  mínimos de botones de 48 px, labels en campos, tooltips de iconos y breakpoints
  centralizados en `ui/layouts/orbi_adaptive_layout.dart:7-10`.

## Revisión independiente posterior (2026-09-07)

Los siguientes hallazgos del recorrido inicial ya tienen corrección visible en el
código y pruebas focales: aprobaciones usa `GridView.extent` con altura adaptada a
escala y región viva de error (`features/approvals/approvals_screen.dart:81-108`),
caja compacta usa scroll (`features/collection/collection_screen.dart:68-85`), el
login avanza por foco/teclado y tiene `done` (`features/auth/login_screen.dart`),
y el término de pago es `DropdownButtonFormField` etiquetado
(`features/sales/sale_editor.dart:611-618`). Sus pruebas focales pasan.

Pendientes que siguen abiertos:

- El editor wide mantiene formulario y resumen en un `Row` (`sale_editor.dart:561-572`);
  no hay prueba a `>=840` y escala 2.0 que demuestre ausencia de overflow vertical.
- La bandeja de avisos mantiene dos `IconButton` en `ListTile.trailing`
  (`notification_inbox.dart:176-205`); a ancho compacto y escala 2.0 requiere
  verificación manual de reflow/targets.
- `EntityPicker` aún anida `Semantics(button: true)` sobre un `ListTile(onTap:)`
  (`entity_picker.dart:94-107`), con riesgo de anuncio duplicado.
- No se ejecutó VoiceOver/TalkBack, teclado real, contraste medido ni recorrido
  manual por 200%; por tanto estos criterios permanecen sin certificación manual.
