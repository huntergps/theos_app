# Contrato de integración con los addons Odoo 19.5

Fecha: 2026-09-04. Complementa la especificación de finalización existente.

## Comportamiento y alcance

La app consume los addons ecuatorianos de `dev_odoo20` mediante JSON-2
Bearer. Los hosts objetivo son newerp.tecnosmart.com.ec,
epr2.tecnosmart.com.ec, pvision.galapagos.tech, jb.galapagos.tech y
dejavu.galapagos.tech. Cada servidor/base/usuario conserva su scope propio.

- El selector bancario sincroniza `l10n.ec.bank`, nunca `res.bank`.
  `code` es SPI; no es BIC/SWIFT. Se conserva la tabla local existente.
- Las líneas de pago conservan `l10n_ec_bank_id` y `bank_name_ec` al leer,
  crear y encolar sin conexión. El nombre textual de una cuenta bancaria
  no se convierte en un ID de catálogo inventado.
- Crear un anticipo incluye sus métodos e importes en `advance_line_ids`
  dentro de la misma creación remota y del mismo comando durable local.
- Un cambio de credenciales invalida versión y descubrimiento de campos.
  Un fallo de descubrimiento no equivale a un campo ausente.
- Una ausencia comprobada no se sustituye por una suposición de versión.

## Verificación

Analizar y ejecutar las suites de los cinco paquetes. Contrastar los campos
con el ORM vivo accesible por MCP y con los addons locales. Las pruebas
opt-in por host requieren configuración externa; una prueba omitida no
certifica compatibilidad. Probar el defecto bancario en rojo y su corrección
en verde. No modificar addons ni desplegar durante esta refactorización.

La validación completa requiere además el recorrido real vendedor/cajero
con sus permisos y una operación financiera controlada en cada target.
`cash_out_uuid` aparece en el ORM ERP2 y no en el fuente local auditado:
comprobarlo por host y conservar su garantía idempotente. No sustituirlo
por una clave arbitraria ni reintentar retiros sin reconciliación.

## Límites de migración

Conservar el nombre SQLite `res_bank` es compatibilidad de almacenamiento,
no compatibilidad con el modelo remoto eliminado. Un cache que contenga
IDs de `res.bank` de una instalación antigua requiere reconciliación antes
de reutilizarlos como `l10n.ec.bank`; no reasignar IDs de pagos históricos.
Esta tarea no certifica una migración de datos bancarios desde Odoo 19.1.
