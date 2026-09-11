# Brecha de integración de precios e impuestos

Fecha: 2026-09-11. Auditoría local read-only; no se modificó código ni backend.

## Hallazgos confirmados

- `TaxCalculatorService` (`theos_pos_core/lib/src/services/taxes/tax_calculator_service.dart:107-177,492-564`) reutiliza impuestos locales, múltiples tasas, `price_include`, posición fiscal y redondeo.
- `SaleOrderLineCalculator` (`theos_pos_core/lib/src/services/sales/line_calculator.dart:22-85`) calcula una tasa porcentual simple; requiere `taxPercent` real y no cubre `price_include` ni múltiples impuestos.
- `PricelistCalculatorService` (`theos_pos_core/lib/src/services/prices/pricelist_calculator_service.dart:123-132`) resuelve reglas/UoM, pero requiere producto variante/plantilla, lista, cantidad y precios.
- `RuntimeCatalogComposition` sincroniza productos, taxes y cabeceras de pricelist, pero no instancia calculadores ni expone reglas de pricelist (`orbi_runtime/lib/src/read/runtime_catalog_composition.dart:36-95`; `json2_read_adapters.dart:142-159,230-251`).
- `OrbiBusinessComposition` sólo compone comandos, aprobaciones, catálogos y operaciones; no existe puerto de cálculo (`theos_panel/lib/app/business_composition_factory.dart:109-133`).
- Al añadir producto, la UI copia `list_price`, UoM e IDs fiscales; `SaleDraftLine` deja `tax`, `total` en 0 y `amountsCalculated=false` (`theos_panel/lib/features/sales/sale_editor.dart:19-48,871-883`).
- El codec v2 persiste `amountsCalculated` como procedencia de UI; no es autorización ni prueba de importes confiables.

## No asumir

`list_price` no equivale necesariamente al precio final de una pricelist. No fijar IVA por defecto ni derivarlo de importes existentes. Un flag calculado sólo debe activarse después de datos fiscales/precio válidos.

## Siguiente trabajo ordenado

1. Definir un puerto de cálculo en la composición, con compañía, producto plantilla, UoM, pricelist y posición fiscal explícitos.
2. Garantizar sincronización/lectura de reglas de pricelist y taxes antes de calcular.
3. Orquestar pricelist → `TaxCalculatorService` → actualización atómica de línea; conservar pendiente ante datos ausentes/error.
4. Añadir pruebas de `price_include`, múltiples impuestos, descuento, UoM, compañía y offline; sólo entonces marcar `amountsCalculated`.

Limitación actual: la UI seguirá mostrando “Por validar”/“Pendiente de cálculo” hasta integrar esa ruta confiable.
