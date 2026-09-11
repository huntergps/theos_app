# Registros compartidos: Órdenes y Envases

Referencias: SHELL-01 / ENV-01 aprobadas. Fecha: 2026-09-11.

- Órdenes abandona el mosaico de tarjetas desktop y consume OrbiRecordGrid
  (Syncfusion). En portrait/teléfono usa la lista adaptable compartida.
- `cardBuilder` opcional permite contenido específico sin duplicar consultas
  ni selección; la lista compartida conserva selección y apertura del registro.
- Envases muestra propiedad por producto/unidad, filtro y contador de registros,
  panel de datos, total propio destacado y métricas por tarjeta en portrait.
- No se añaden sedes, direcciones, presentaciones, exportaciones ni importes
  ficticios para rellenar la referencia visual.
- Pruebas integrador: 15 tests combinados de shell, órdenes y envases pasaron.
  Después se corrigió tarjeta de órdenes para evitar interceptar selección;
  sus 6 tests pasaron de nuevo, con cuatro viewports exactos.
- Build web `dev/local_workflows.dart` correcto; nueva versión servida en 8769.
  Sigue el aviso preexistente de fuente CupertinoIcons.

Pendientes de fidelidad: Órdenes requiere exponer campos existentes de cliente,
fecha, total y moneda desde su consulta local. Envases requiere integrar lectura
por ubicación/sentido del tránsito y presentación. La versión no acredita todavía
paridad visual/funcional completa ni E2E comercial contra Odoo.
