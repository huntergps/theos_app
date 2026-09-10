# Contrato de dominio: Envases

Estado: propuesta de dominio para el backend Odoo 19.5. No es una descripción de
modelos o campos ya instalados. En la inspección actual no se identificó un
binding funcional de Envases; eso no demuestra que no exista fuera del alcance
inspeccionado. Ningún nombre técnico de este documento debe implementarse sin
confirmarlo en Odoo.

## Decisiones aceptadas

- Odoo es la fuente de verdad de inventario, propiedad, custodia, movimientos,
  auditoría y permisos. La UI web nativa de Odoo debe operar el módulo completo
  mediante vistas, acciones, ACL, reportes y reglas de negocio nativas.
- Orbi es otra interfaz sobre los mismos datos, reglas y permisos; no requiere
  estar abierta para que el negocio continúe. Su API debe ser pública,
  versionada, documentada y probada antes de conectarla.
- Envases no depende de una sesión de Caja. Un responsable autorizado puede
  operar Envases sin Caja; el servidor debe comprobar empresa, ubicación,
  alcance y capacidad, no una sesión de efectivo.
- No se habilita ninguna acción hasta verificar el mapeo backend. No se crea un
  stock, crédito o saldo paralelo en dispositivo; el offline sólo conserva
  comandos y resultados explícitos.

## Modelo conceptual (propuesta técnica)

Separar tres conceptos, aunque la implementación pueda normalizarlos:

1. **Contenido**: producto que contiene o acompaña el envase; sus cantidades se
   registran por línea de producto.
2. **Recipiente**: activo físico comprado y propiedad de la empresa. Puede estar
   en custodia de clientes/proveedores, venderse/comprarse o quedar dañado/perdido.
   Custodia de terceros no transfiere propiedad. Gestionar envases propiedad de
   terceros no es un requisito confirmado y no debe ampliar esta entrega.
3. **Presentación**: relación comercial/logística entre contenido, recipiente,
   capacidad y cantidad. Una operación con productos distintos conserva líneas
   independientes; nunca se totalizan por nombre si la unidad o variante difiere.

La propiedad (empresa/cliente/tercero), custodia actual, ubicación y estado son
dimensiones distintas. Las ubicaciones canónicas incluyen GYE y GPS, pero no se
presupone que sean códigos Odoo existentes. Un tránsito GYE→GPS es distinto de
GPS→GYE: tiene origen, destino y líneas; queda en tránsito desde despacho hasta
recepción, y una recepción parcial deja el remanente en tránsito.

El movimiento comercial de compra/venta de un recipiente y el movimiento físico
son hechos relacionados pero no intercambiables. La factura puede ser referencia
comercial; el backend debe definir qué documento actualiza existencias.

## Movimientos y conservación

Cada evento debe indicar producto/recipiente, cantidad positiva, unidad,
propietario, custodio, origen/destino, motivo, actor, fecha y referencia de
negocio. La partición propuesta es:

`existencia_propia_controlada = en_sedes + en_clientes + en_proveedores + en_transito`

Las categorías son excluyentes; dañado es condición dentro de una categoría,
no otra cantidad que se suma. Pérdidas/bajas definitivas y ventas que transfieren
propiedad se excluyen de existencia propia vigente y se conservan en historial.
Balance: `apertura + compras/altas - ventas con transferencia de propiedad - bajas
+ ajustes netos autorizados = existencia propia controlada`. Una incidencia de
pérdida pendiente no se descuenta otra vez si ya se contabilizó su baja.

Las cantidades se calculan por empresa, tipo de recipiente, ubicación y estado;
no se mezclan contenidos distintos. Compra, venta, devolución, transferencia,
daño y pérdida cambian las particiones según la regla aprobada, preservando la
ecuación. Una corrección no edita historia: agrega un evento compensatorio con
motivo y autoridad. Una reversión referencia al evento original.

Una devolución parcial es por línea y cantidad. Debe registrar condición
(reutilizable, dañado, perdido u otra condición aprobada), causa y evidencia;
`n` devueltos no puede alterar las otras `m-n` unidades de la misma línea.

La toma física observa el total real, incluyendo unidades ya registradas; no se
pide excluirlas del conteo. Su validación compara observado con registrado al
corte y propone sólo la diferencia autorizada. Si una factura ya originó entrada,
enlazarla no vuelve a aumentar cantidades. Una factura posterior puede documentar
una adquisición ya incluida en apertura: procedencia/corte y conciliación explícita
deben impedir sumarla otra vez, sin adivinar que toda factura posterior es compra nueva.

## Dashboard, reconciliación y permisos

Un snapshot es una lectura derivada con alcance (empresa, ubicación, tipo),
instante y revisión de fuente. Es cache/reporting, no autoridad: los totales se
reconstruyen desde movimientos Odoo. Si snapshot y fuente difieren, mostrar
`needs_reconcile` con detalle y conservar ambos valores; nunca corregir en
silencio. La reconciliación debe identificar evento faltante, duplicado,
conflicto de propiedad o recepción parcial.

El responsable de Envases es una asignación conceptual a usuario/partner/grupo;
no se inventa un campo. Operadores sólo ejecutan acciones dentro de su alcance.
Supervisor/admin puede aprobar ajustes, reversas y cierres, siempre auditados.
Toda ACL y regla de compañía/ubicación debe existir también en la UI nativa y
en la API.

## Offline, idempotencia y conflictos

Cada comando lleva `commandId` estable, actor, dispositivo, versión de contrato,
precondiciones y líneas. Replay debe ser seguro: el servidor debe ofrecer una
garantía atómica (clave única o endpoint transaccional equivalente) y probarla
bajo concurrencia. Buscar UUID y luego crear no demuestra idempotencia atómica.
Mientras esa garantía no esté verificada, el resultado es `unknown` y no se
reintenta ciegamente; se consulta estado o se reconcilia manualmente. Estados
de negocio, sincronización y fiscalidad permanecen separados. Un conflicto no
se resuelve sumando dos veces: queda rechazado o pendiente de decisión con
autoría y motivo.

## Casos de aceptación numéricos

1. Apertura: 100 recipientes propios en GYE y 20 en GPS ⇒ `owned_total=120`.
2. Despacho de 10 GYE→GPS: GYE disponible 90, tránsito 10, total 120; recepción
   completa produce GYE 90/GPS 30. El retorno GPS→GYE sigue el mismo flujo.
3. Venta con dos líneas (1 tipo A y 3 tipo B) mantiene ambas líneas y reduce
   cuatro unidades sólo si la regla comercial/física lo autoriza.
4. Compra/factura de 12 y toma inicial que ya incluía esas 12: el total sube
   una sola vez; el test debe fallar ante doble aplicación.
5. Devolución de 5 de 10: sólo cinco regresan; cada condición (usable/dañado/
   perdido) conserva trazabilidad y la ecuación.
6. Dos dispositivos reenvían el mismo `commandId`: una aplicación atómica,
   una respuesta reproducible; carrera concurrente y conflicto de ubicación se
   prueban explícitamente.
7. Responsable autorizado opera sin Caja; usuario fuera de compañía/ubicación
   es rechazado tanto por Odoo web como por API.

Referencias: [CONTRACTS.md](CONTRACTS.md),
[ODOO_OFFLINE_CONTRACT_MATRIX.md](ODOO_OFFLINE_CONTRACT_MATRIX.md),
[ODOO_OPTIONAL_CAPABILITIES.md](ODOO_OPTIONAL_CAPABILITIES.md),
[CASH_FORMS_REVIEW.md](CASH_FORMS_REVIEW.md).
