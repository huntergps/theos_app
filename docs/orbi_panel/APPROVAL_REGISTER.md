# Registro de aprobaciones visuales — Orbi

Actualizado: 2026-09-10. Reconstruido de las respuestas explícitas del usuario.
Este registro distingue aprobación visual, definición funcional e implementación.
No certifica que las pantallas estén implementadas o probadas.

La [matriz maestra de cobertura](VISUAL_COVERAGE.md) enumera los listados,
formularios, recorridos y estados todavía pendientes. Es obligatoria para no
confundir una aprobación parcial con la aprobación del módulo completo.

## Aprobaciones anteriores

| Bloque | Evidencia del usuario | Alcance y límites |
|---|---|---|
| Ventas, distribución B | «me gusta la opcion B para ordenadores» | Distribución superior y rejilla. Búsqueda de productos inline. No equivale a aprobar recorridos completos de mostrador y consultiva. |
| Adaptaciones de ventas y cobro | «aceptado esos diseños» | Láminas presentadas en esa ronda, incluida tablet vertical añadida. No aprueba todo Caja. |
| Pendientes y resultado de cobro | «aprobadas esas» | Propuestas de esa ronda; no operaciones auxiliares ni cierre. |
| Bodega y primeras vistas de envases | «aceptado las pantallas» | Aprobación del conjunto presentado, no de todas las tareas de inventario. Alcance detallado por lámina pendiente de inventario histórico. |
| Envases desde factura y toma física | «aprobado las pantalla para registrar desde facura y desde toma fisica» | Aprobación explícita de ambas propuestas, desktop, iPad horizontal, iPad vertical y teléfono. |

## Definiciones aceptadas de envases

- Workspace del responsable de envases; no requiere sesión de caja.
- Control por producto y múltiples líneas/cantidades, no recipiente por recipiente.
- Envases propios comprados por la empresa; se pueden comprar más y venderlos.
- Separar contenido comercial, recipiente y presentación con equivalencia.
- No limitar a botellas: incluir los tipos de envase configurados por producto.
- Dashboard consolidado: ubicaciones, tránsito en ambos sentidos, clientes y proveedores.
- Inicio desde factura o toma física; no duplicar movimientos o saldos al contar.
- Inventario/Bodega y Envases son áreas distintas de la misma app.
- Autorizados módulos custom de envases cuando se pase a implementación; no tocar core.

## No presentadas o no aprobadas expresamente

- Recorridos completos de mostrador y venta consultiva.
- PIN/Workspace y cambio de usuario; navegación conjunta multirrol.
- Aprobaciones comerciales.
- Apertura, arqueo y cierre de caja.
- Retención SRI, anticipo, depósito bancario, salida de efectivo y cruce de cuentas: nuevas propuestas de esta entrega pendientes de aprobación.
- Cabecera/punto de cobro y sesión: nueva propuesta pendiente de aprobación.
- Sincronización, cola offline, conflictos y configuración del nuevo panel.
- Último dashboard consolidado de Envases: definición funcional aceptada; imagen no aprobada expresamente.

## Evidencia visual aprobada preservada

Los PNG son copias originales sin modificaciones. Una lámina puede contener
varias vistas; las limitaciones indicadas aquí prevalecen sobre sus dibujos.

| ID / imagen | Alcance |
|---|---|
| [VENTAS-B-v1](visual_baselines/approved/VENTAS-B-v1.png) | Sólo opción B de la lámina A/B; incluye referencia de ficha de producto. |
| [VENTAS-TABLET-MOVIL-v1](visual_baselines/approved/VENTAS-TABLET-MOVIL-v1.png) | Adaptaciones de ventas. |
| [VENTAS-VERTICAL-COBRO-v1](visual_baselines/approved/VENTAS-VERTICAL-COBRO-v1.png) | Vertical y cobros de la ronda aceptada. Los importes ilustrativos no definen cálculo fiscal. |
| [PENDIENTES-RESULTADO-COBRO-v1](visual_baselines/approved/PENDIENTES-RESULTADO-COBRO-v1.png) | Pendientes y resultado. |
| [BODEGA-ENVASES-v1](visual_baselines/approved/BODEGA-ENVASES-v1.png) | Primera propuesta envases/Bodega; aplicar las aclaraciones posteriores de producto, propiedad, presentación y workspace separado. |
| [ENV-FACTURA-v1](visual_baselines/approved/ENV-FACTURA-v1.png) | Registro desde factura. |
| [ENV-TOMA-FISICA-v1](visual_baselines/approved/ENV-TOMA-FISICA-v1.png) | Registro desde toma física. |

Se preservan además TODAS las imágenes generadas recuperadas de la carpeta de
esta conversación en `visual_baselines/archive/`, incluidas propuestas rechazadas,
superadas o sin aprobación demostrable. Estar en ese archivo NO significa aprobación.
En particular `exec-2eea3063-2c11-440a-8877-c979fb6dfcf3.png` es la propuesta
inicial de preparación de Bodega que el usuario consideró insuficiente, y
`exec-f063a6d0-f3aa-4480-bbd1-700afd802d7b.png` es el dashboard posterior de
envases, sin aprobación visual explícita identificada.

## Comparación con desarrollo

Para cada pantalla implementada registrar ID de referencia aprobado, captura
real por tamaño, diferencias encontradas y resolución. No sobrescribir un PNG
aprobado: una revisión produce v2 y requiere aprobación independiente. Las
capturas de aplicaciones existentes aportadas por el usuario son referencias,
no nuevas propuestas aprobadas de theos_panel.

## Nuevas propuestas

### Aprobación completa de round-02 — 2026-09-10

El usuario revisó la carpeta y declaró: «he revisado
/Users/elmers/Documents/develop/2026/theos_app/docs/orbi_panel/visual_baselines/proposed/round-02
y estan todas aprobadas».

**Las 33 láminas de round-02 quedan aprobadas visualmente**, incluidos sus formatos
representados y las seis revisiones de Caja. Copias originales preservadas en
`visual_baselines/approved/round-02/`; las propuestas permanecen como evidencia.
Esta aprobación sustituye el estado pendiente anotado en ROUND_02_REVIEW.md.
No equivale a aprobación de imágenes/estados que no aparecen ni a cambiar reglas
de Odoo, campos, permisos o el logo corporativo real.

Ronda 02: [33 láminas archivadas e identificadas](ROUND_02_REVIEW.md), todas
aprobadas por la declaración anterior. Las seis revisiones CAJ-04..09-v2 están
incluidas expresamente en el lote aprobado.

Las nuevas láminas y sus referencias de código se enumeran en CASH_FORMS_REVIEW.md.
Mostrar una imagen no la aprueba. Un «procede» autoriza preparar propuestas, no
implementarlas. Registrar cada aprobación posterior con el identificador de lámina.

## Ronda 03 — aprobación parcial, 10/09/2026

Declaración del usuario: «aprobaas las propuestas que me mostraste».
Se registra para SHELL-01, ALERT-01 y ALERT-02: las tres imágenes abiertas en
Vista Previa y guardadas en `proposed/round-03/` antes de esa declaración.
Copias idénticas preservadas en `approved/round-03/`.

Segunda declaración del usuario, después de abrir CONT-01, OUT-01 y AI-01:
«aprobado, que mas falta?». Se aprueban esas tres versiones y se preservan
copias idénticas en `approved/round-03/`. Quedan seis láminas aprobadas en esta ronda.
Las revisiones generadas después de
las versiones mostradas no heredan aprobación, especialmente ajustes de orientación.
La aprobación visual no certifica implementación, bindings ni pruebas funcionales.
Véase [índice de revisión](ROUND_03_REVIEW.md).

## Alcance del registro histórico

Antes de este registro existían la especificación y una checklist de aceptación,
pero no un registro completo de las aprobaciones recientes. No se atribuyen fechas
exactas ni aprobaciones por pantalla que la conversación no permite demostrar.
