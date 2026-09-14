# E02 — Los catálogos se sincronizan según lo que tiene el servidor (13-sep-2026)

Estado: **decidido**, sin código. Decide team-lead; implementa un agente contra este texto.

## El defecto

En Mepriga (Odoo solo con `stock` + `l10n_ec_stock_envases`), la usuaria de bodega Soledad Jinez ve en
`/sync` 14 catálogos y 11 en error: 9 por modelo inexistente (`account.tax`, `account.journal`,
`collection.config`…, HTTP 404) y 2 por campo inexistente (`res.partner.customer_rank`,
`product.product.taxes_id`, HTTP 500). Pregunta del dueño: «¿por qué tiene que sincronizar todas esas
tablas?».

Causa, medida en el código (sección 7 del mapa de envases):
- `orbi_runtime/lib/src/read/runtime_catalog_composition.dart:47-103` arma 17 catálogos sin ninguna
  condición: ni modelo existente, ni módulo, ni permiso.
- `customer_rank` (`json2_read_adapters.dart:190`) y `taxes_id` (`:206`) están cableados; no pasan por
  `fields_get` ni por `FieldAvailabilityCache`.
- `CatalogSyncJob.run` (`catalog_sync.dart:96-107`) trata igual un 404 de modelo, un 500 de campo y un
  corte de red.

Contradice la regla del proyecto (CLAUDE.md, «Odoo 19 frente a Odoo 20»): **la evidencia gana**, y
`unknown` no es `unsupported`.

## La decisión

1. **Existencia por modelo con `fields_get`, no con `ir.model`** (corregido el 13-sep-2026, ver abajo).
   Por cada modelo de los catálogos, un `fields_get(attributes=['type'])` memorizado por servidor+base:
   404 de modelo inexistente → el catálogo queda `unsupported` (no se ejecuta, no cuenta como error, `/sync`
   lo muestra aparte, atenuado, «No disponible en este servidor»); respuesta válida → lista de campos
   disponibles; red, 401 o 403 → `unknown`.
2. **Campos opcionales y de filtro.** Cada descriptor distingue obligatorios, opcionales y campos de los que
   depende un filtro. Con la lista de `fields_get`: falta un opcional → se sincroniza sin él (`taxes_id`);
   falta un campo de filtro → se omite ese filtro (`customer_rank`); falta un obligatorio → `unsupported`.
   Si aun así el `search_read` real devuelve `OdooFieldNotFoundException` por un opcional o de filtro, se
   quita ese campo y se reintenta UNA vez; solo un obligatorio deja el catálogo en `unsupported`.
3. **Clasificación de fallos.** 404 de modelo o campo inexistente = `unsupported`, recordado por
   servidor+base. Red, 401/403 o cualquier 500 de otra causa = fallo que se reintenta, igual que hoy.
4. **`unknown` no apaga nada.** Si `fields_get` falla por red o permisos, el catálogo no pasa a
   `unsupported`: sigue en `unknown`, corre con su descriptor de siempre y se reintenta el sondeo en el
   siguiente ciclo.
5. **Se re-evalúa** al entrar, al cambiar de servidor o base, y con «Forzar sync completo». Un módulo
   instalado después vuelve a habilitar su catálogo sin reinstalar la app.
6. **No se inventa ni se quita nada del código.** Los 17 catálogos siguen declarados; lo único que cambia es
   que el servidor decide cuáles corren.

## Fuera de esta decisión

- Filtrar catálogos por el rol del usuario (bodega frente a caja). Hoy los permisos por área existen para
  las pantallas, no para los catálogos; se decide aparte si con este cambio no basta.
- Los 9 catálogos sin consumidor en Orbi (mapa, sección 7 d): no se retiran aquí.

## Corrección del 13-sep-2026: por qué no `ir.model`

La primera versión pedía una sola lectura de `ir.model`. El agente que la implementó (commit `3832d36`)
señaló que en ERP2 un vendedor normal recibe 403 al leer `ir.model`: con ese perfil todo quedaría en
`unknown` y el defecto de Mepriga no se arreglaría para la usuaria de bodega. `fields_get` sobre el propio
modelo da la misma evidencia (404 si no existe) sin exigir leer `ir.model`, y además trae los campos.
El error «Invalid field … (HTTP 500)» llega como `OdooFieldNotFoundException`
(`odoo_sdk/lib/src/api/odoo_error_mapper.dart:88-93`), así que un campo opcional ausente se puede quitar
y reintentar en vez de apagar el catálogo entero.
