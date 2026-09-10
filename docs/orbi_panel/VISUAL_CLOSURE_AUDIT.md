# Auditoría de cierre visual — Orbi
Fecha: 2026-09-10. Revisión documental y de PNG; no revoca aprobaciones, no prueba
implementación ni certifica bindings Odoo.
## Inventario aprobado
- `approved/round-02/`: 33 IDs aprobados (índice en `ROUND_02_REVIEW.md`).
- `approved/round-03/`: 6 IDs: SHELL-01, ALERT-01, ALERT-02, CONT-01, OUT-01, AI-01.
- `approved/` raíz: 7 históricos: VENTAS-B-v1, VENTAS-TABLET-MOVIL-v1,
  VENTAS-VERTICAL-COBRO-v1, PENDIENTES-RESULTADO-COBRO-v1, BODEGA-ENVASES-v1,
  ENV-FACTURA-v1 y ENV-TOMA-FISICA-v1.
- Total: 46 archivos/IDs aprobados visualmente; la aprobación sólo cubre lo representado.
## Muestras inspeccionadas
Abrí con `view_image` SHELL-01, OUT-01, ALERT-02 y CAJ-10, además de un contacto de
los 33+6+históricos. Las láminas presentan desktop, iPad horizontal, iPad vertical y
teléfono, normalmente con listas/tarjetas en portrait. No observé recortes graves.
## Huecos concretos
- No existen cuatro variantes oscuras completas por ID; sólo detalles/swatches oscuros.
- No existe cobertura completa por recorrido de `loading`, `empty`, `error`, `forbidden`,
  `offline`, resultado parcial, reconexión y conflicto; hay ejemplos, no matriz completa.
- No quedan demostrados todos los subrecorridos/pestañas de CAJ-02/03/10/11, BOD-02/03/04,
  ENV-02/03/06/07, SUP-01, SYN-01/02/03, CFG-01, NOT-01 y OPS-01.
- No hay evidencia visual de las seis plataformas, push con app cerrada, login web/offline,
  replay fiscal ni permisos efectivos.
## Consistencia shell
- SHELL-01 fija el menú unión Ventas, Caja, Bodega, Envases, Aprobaciones y Sistema.
  CAJ-10 conserva Inventario/Compras/Clientes/Proveedores/Reportes/Configuración y
  OUT-01 usa otra variante. Unificar nomenclatura en implementación sin revocar históricos.
- El pie no es uniforme: SHELL-01 muestra servidor/BD/hora y panel con zona; CAJ-10 y
  OUT-01 muestran pies distintos o incompletos. Falta evidencia aprobada de servidor,
  base, hora, zona y última referencia obsoleta/offline en los cuatro formatos.
- Logos/headers difieren entre rondas; el registro ya advierte que son aproximados.
  Logo real e identidad corporativa siguen sin evidencia de implementación.
## No visto / pendiente
No vi capturas de app real, APIs/ACL efectivos, estados Odoo, impresión física, entrega
WhatsApp/Telegram, cola deduplicada ni capacidades IA. Las imágenes guían UI; no permiten
declarar esos comportamientos terminados.
