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

1. **Existencia de modelos, una sola llamada.** Antes del ciclo se leen de `ir.model` los modelos de todos
   los catálogos. Si el modelo de un catálogo no existe, ese catálogo queda en `unsupported` para ese
   servidor+base: no se ejecuta, no cuenta como error y `/sync` lo muestra aparte, atenuado, con el texto
   «No disponible en este servidor».
2. **Campos opcionales por `fields_get`.** Cada descriptor distingue campos obligatorios de opcionales. Solo
   para los modelos que existen, un `fields_get` (reusar el patrón de `FieldAvailabilityCache`):
   - si falta un opcional, el catálogo se sincroniza sin él (`taxes_id` en productos);
   - si falta un campo del que depende el filtro (`customer_rank`), el filtro se omite y se dice en el
     descriptor por qué;
   - si falta un obligatorio, el catálogo queda en `unsupported`.
3. **Clasificación de fallos.** 404 de modelo o campo inexistente = `unsupported`, recordado por
   servidor+base. Red, 401/403 o cualquier 500 de otra causa = fallo que se reintenta, igual que hoy.
4. **`unknown` no apaga nada.** Si la lectura de `ir.model` o de `fields_get` falla por red, ningún catálogo
   pasa a `unsupported`: sigue en `unknown` y se reintenta en el siguiente ciclo.
5. **Se re-evalúa** al entrar, al cambiar de servidor o base, y con «Forzar sync completo». Un módulo
   instalado después vuelve a habilitar su catálogo sin reinstalar la app.
6. **No se inventa ni se quita nada del código.** Los 17 catálogos siguen declarados; lo único que cambia es
   que el servidor decide cuáles corren.

## Fuera de esta decisión

- Filtrar catálogos por el rol del usuario (bodega frente a caja). Hoy los permisos por área existen para
  las pantallas, no para los catálogos; se decide aparte si con este cambio no basta.
- Los 9 catálogos sin consumidor en Orbi (mapa, sección 7 d): no se retiran aquí.
