# Checklist de aceptación del backend Envases

Documento de recepción para el backend Odoo 19.5 construido por un agente
externo. No implementa ni presupone modelos, campos, rutas o identificadores.
Hasta recibir código, entorno de pruebas y resultados reproducibles, cada punto
queda **pendiente**. La aceptación exige operar desde Odoo web sin Orbi.

## Evidencia mínima de entrega

- [ ] Nombre técnico, versión, dependencias y compatibilidad 19.5; manifiesto,
  instalación/actualización y migración revisados en entorno aislado.
- [ ] Modelos reales y campos reales documentados: producto/contenido,
  recipiente, presentación/equivalencia, propiedad, custodia, ubicación,
  tránsito, condición, movimiento, documento origen y auditoría. Para cada uno:
  tipo, unidad/precisión, compañía y relación, con rutas de archivo y líneas.
- [ ] Se declara qué reutiliza `stock`, `sale`, `purchase` y facturación y qué
  extensión agrega. No existe libro auxiliar editable que compita con Odoo.
- [ ] Navegación, listas, formularios, filtros, acciones, reportes y dashboard
  funcionan en la web nativa. Apertura, despacho, recepción, devolución,
  conteo, compra, venta/no devolución, incidencia, corrección y reversión son
  ejecutables sin Orbi.
- [ ] Vistas/acciones aprobadas tienen IDs XML reales y se entrega una tabla
  `approvedId -> operación -> modelo/método -> permiso`. No aceptar IDs de
  ejemplo ni llamadas a métodos privados.

## Dominio e invariantes

- [ ] Prueba de múltiples líneas conserva producto, unidad, presentación y
  cantidad sin sumar tipos incompatibles. Se demuestra la política explícita
  para productos que comparten recipiente compatible.
- [ ] Propiedad y custodia son dimensiones separadas; se prueban empresa,
  cliente y proveedor. Una custodia de tercero no transfiere propiedad.
- [ ] GYE→GPS y GPS→GYE son operaciones distintas; despacho y recepción son
  hechos separados, con recepción parcial, diferencia, daño y pérdida.
  `en_transito` no se cuenta simultáneamente en origen/destino.
- [ ] Compra/venta de recipiente, factura y movimiento físico tienen enlaces y
  efectos separados. Facturar no implica automáticamente pago ni salida.
- [ ] Toma inicial compara observado contra registrado al corte y aplica sólo
  diferencia autorizada. Asociar una factura o compra ya incluida no duplica.
- [ ] Devolución parcial es por línea; daño/pérdida, baja, corrección y reversión
  conservan historial, autoría, motivo y documento relacionado. No se borran
  movimientos validados.
- [ ] Dashboard consolida por producto/recipiente/presentación, sedes,
  clientes/proveedores y tránsito por sentido; cada total abre exactamente sus
  líneas. Snapshot/reporte es derivado y reconciliable, no otra autoridad.

## Seguridad y operación sin Caja

- [ ] ACL, reglas multiempresa, ubicación y grupos nativos verificadas en UI y
  API para consulta, operación y ajustes sensibles. El servidor no confía en
  `user_id` enviado por el cliente ni usa `sudo()` indiscriminado.
- [ ] Un responsable autorizado opera Envases sin sesión de Caja; usuario fuera
  de compañía/ubicación, o sin capacidad, es rechazado con error verificable.
- [ ] Se documentan estados, transiciones, permisos por acción, actor auditado,
  corrección y reversión. Las mismas reglas aplican con Orbi cerrada.

## Contrato API/delta para Orbi

- [ ] Contrato versionado con transporte confirmado en la instalación real;
  métodos públicos, parámetros, respuestas saneadas, límites, paginación,
  cursores/revisión de cambios y comportamiento de anulaciones documentados.
- [ ] Existe mapeo de cada `approvedId` de pantalla/acción Orbi a una acción
  nativa Odoo y a su método público. El endpoint no expone métodos privados ni
  crea un inventario paralelo.
- [ ] Delta devuelve altas, cambios, anulaciones y registros que salen del
  filtro, con compañía/alcance y revisión consistente. Se prueba reinicio y
  reanudación desde cursor.
- [ ] Cada comando comprueba actor autenticado, compañía, documento,
  precondiciones y versión esperada. Respuesta distingue aplicado, rechazado,
  conflicto y resultado incierto.

## Idempotencia, concurrencia y offline

- [ ] `commandId`/identidad equivalente tiene deduplicación **atómica** y
  persistente: mismo payload concurrente produce un efecto y permite recuperar
  exactamente su respuesta tras timeout/reinicio.
- [ ] Mismo identificador con payload distinto se rechaza. Se aporta prueba de
  carrera; “buscar antes de crear” por sí solo no es evidencia suficiente.
- [ ] Dependencias despacho→recepción y acciones que exigen servidor están
  declaradas. Offline sólo prepara/cola lo autorizado; nunca inventa stock,
  deuda, cupo o saldo. Resultado incierto no se reintenta ciegamente.
- [ ] Conflictos de conteo, ubicación, propiedad y recepción conservan evidencia
  y requieren resolución autorizada; no se aplica “último gana” ni se suman
  cantidades para ocultar diferencias.

## Pruebas de aceptación obligatorias

- [ ] Fixture A: GYE100/GPS20; envío10, recepción6 (tránsito4), recepción4,
  con totales 120 en cada etapa; repetir en sentido contrario.
- [ ] Cliente/proveedor en custodia no altera total propio; varias líneas y
  presentaciones conservan unidades base.
- [ ] Compra/factura12 ya incluida en apertura suma una sola vez; conteo118 vs
  registrado120 propone −2, no entrada118, y detecta cambio concurrente.
- [ ] Devolver5 de10, con daño en2, no suma daño nuevamente; venta/no devolución
  y compra adicional mantienen efectos comerciales/físicos auditables.
- [ ] Dos solicitudes concurrentes con el mismo comando, timeout tras commit,
  reintento tras reinicio y payload distinto satisfacen la garantía anterior.
- [ ] Responsable sin Caja, usuario no autorizado y cruce multiempresa probados.
  Se repite el recorrido completo desde Odoo web y se compara el efecto vía API.

## Estado de recepción

**No aceptado / no probado en este repositorio.** La evidencia deberá completarse
con rutas, líneas, capturas o logs saneados y resultados de tests ejecutados en
un entorno aislado; no se debe afirmar validación en vivo, instalación o
permisos hasta contar con ellos.

Referencias: [PROMPT_ODOO_ENVASES_AGENT.md](PROMPT_ODOO_ENVASES_AGENT.md),
[ENVASES_DOMAIN_CONTRACT.md](ENVASES_DOMAIN_CONTRACT.md),
[ODOO_OFFLINE_CONTRACT_MATRIX.md](ODOO_OFFLINE_CONTRACT_MATRIX.md),
[CONTRACTS.md](CONTRACTS.md).
