# Contrato para Modelos Reportables (Cabecera + Líneas)

**Fecha**: 2025-12-29  
**Versión**: 1.0

Este documento define el contrato que debe cumplir cualquier modelo con estructura de **cabecera + líneas** para generar reportes PDF correctamente usando `ReportService` y `flutter_qweb`.

---

## Contrato de Documento (Cabecera)

Cualquier modelo que represente un documento con cabecera y líneas debe implementar un método `toReportMap()` que retorne un `Map<String, dynamic>` compatible con templates QWeb de Odoo.

### Método Requerido

```dart
Map<String, dynamic> toReportMap({
  Map<String, dynamic>? company,
  Map<String, dynamic>? user,
});
```

### Campos Mínimos Requeridos

El `Map` retornado debe incluir:

#### Información del Documento
- `id`: ID del documento (int)
- `name`: Número/nombre del documento (String)
- `state`: Estado del documento (String, compatible con Odoo)

#### Información del Cliente/Proveedor
- `partner_id`: Map con `id`, `name`, `vat`, `street`, `phone`, `email` (opcional)

#### Información de la Compañía
- `company_id`: Map con información de la compañía (se puede pasar como parámetro)

#### Totales
- `amount_untaxed`: Monto sin impuestos (double)
- `amount_tax`: Monto de impuestos (double)
- `amount_total`: Monto total (double)

#### Líneas del Documento (CRÍTICO)
- `lines_to_report`: Lista de `Map<String, dynamic>` con las líneas ya transformadas

### Ejemplo de Implementación

```dart
Map<String, dynamic> toReportMap({
  Map<String, dynamic>? company,
  Map<String, dynamic>? user,
}) {
  return {
    'id': odooId,
    'name': name,
    'state': state.toOdooString(),
    'partner_id': {
      'id': partnerId,
      'name': partnerName,
      'vat': partnerVat,
      'street': partnerStreet,
      'phone': partnerPhone,
      'email': partnerEmail,
    },
    'company_id': company ?? {},
    'amount_untaxed': amountUntaxed,
    'amount_tax': amountTax,
    'amount_total': amountTotal,
    'lines_to_report': lines.map((line) => line.toReportMap()).toList(),
    // Campos adicionales específicos del modelo...
  };
}
```

---

## Contrato de Línea

Cualquier modelo que represente una línea de documento debe implementar un método `toReportMap()` que retorne un `Map<String, dynamic>` compatible con templates QWeb.

### Método Requerido

```dart
Map<String, dynamic> toReportMap();
```

### Campos Mínimos Requeridos

#### Identificación
- `id`: ID de la línea (int)
- `name`: Descripción/nombre de la línea (String)
- `display_type`: Tipo de línea (`false`, `'line_section'`, `'line_note'`, etc.)
- `sequence`: Secuencia/orden de la línea (int)

#### Producto
- `product_id`: Map con `id`, `name`, `default_code`, `barcode` (opcional, puede ser `null`)

#### Cantidad y Precio
- `quantity`: Cantidad (double) - **o** `product_uom_qty` (double)
- `product_uom_id`: Map con `id`, `name` (opcional)
- `price_unit`: Precio unitario (double)
- `discount`: Porcentaje de descuento (double, 0.0 si no hay descuento)

#### Totales
- `price_subtotal`: Subtotal sin impuestos (double)
- `price_total`: Total con impuestos (double)
- `price_tax`: Monto de impuestos (double) - **opcional pero recomendado**
- `tax_amount`: Alias de `price_tax` - **opcional pero recomendado**
- `discount_amount`: Monto de descuento calculado - **opcional pero recomendado**

#### Impuestos
- `tax_ids`: Lista de Maps con `id`, `name`, `tax_label` (opcional pero recomendado)

#### Campos de Compatibilidad
- `collapse_composition`: bool (default: false)
- `collapse_prices`: bool (default: false)
- `is_downpayment`: bool (default: false)
- `product_type`: String (default: 'product' o 'consu')

#### Métodos Requeridos
- `_has_taxes()`: Function que retorna `bool` - indica si la línea tiene impuestos
- `with_context([Map<String, dynamic>? ctx])`: Function que retorna el mismo Map

### Ejemplo de Implementación

```dart
Map<String, dynamic> toReportMap() {
  // Calcular valores derivados
  final priceTax = priceTotal - priceSubtotal;
  final discountAmount = discount > 0 && quantity > 0
      ? priceUnit * quantity * discount / 100
      : 0.0;

  // Parsear tax_ids si están disponibles
  final taxList = <Map<String, dynamic>>[];
  if (taxNames != null && taxNames!.isNotEmpty) {
    final names = taxNames!.split(', ');
    final ids = taxIds?.split(',') ?? [];
    for (var i = 0; i < names.length; i++) {
      taxList.add({
        'id': i < ids.length ? int.tryParse(ids[i].trim()) : null,
        'name': names[i].trim(),
        'tax_label': names[i].trim(),
      });
    }
  }

  final result = <String, dynamic>{
    'id': odooId,
    'name': name,
    'display_type': _displayTypeToString(displayType),
    'sequence': sequence,
    'product_id': productId != null ? {
      'id': productId,
      'name': productName,
      'default_code': productCode,
      'barcode': productBarcode ?? productCode ?? '',
    } : null,
    'quantity': quantity,
    'product_uom_qty': quantity, // Alias para compatibilidad
    'product_uom_id': productUomId != null ? {
      'id': productUomId,
      'name': productUomName,
    } : null,
    'price_unit': priceUnit,
    'discount': discount,
    'discount_amount': discountAmount,
    'price_subtotal': priceSubtotal,
    'price_tax': priceTax,
    'tax_amount': priceTax, // Alias
    'price_total': priceTotal,
    'tax_ids': taxList,
    'collapse_composition': collapseComposition,
    'collapse_prices': collapsePrices,
    'is_downpayment': false,
    'product_type': productType ?? 'consu',
  };

  // Métodos requeridos
  result['_has_taxes'] = () => taxList.isNotEmpty || priceTax > 0;
  result['with_context'] = ([Map<String, dynamic>? ctx]) => result;

  return result;
}
```

---

## Normalización Automática

**IMPORTANTE**: `ReportService._preprocessLineForReport()` se ejecuta automáticamente sobre todas las líneas en `lines_to_report`. Esto significa que:

1. **No necesitas calcular todos los campos manualmente**: Si falta `tax_amount` o `discount_amount`, se calcularán automáticamente.

2. **Los defaults se aplican automáticamente**: Campos como `discount`, `price_unit`, `display_type`, etc. recibirán valores por defecto si son `null`.

3. **Los métodos se agregan automáticamente**: `_has_taxes()` y `with_context()` se agregan si no están presentes.

4. **El pre-procesamiento es idempotente**: Ejecutarlo múltiples veces no cambia el resultado.

### Qué Hacer en `toReportMap()`

**Recomendado**:
- Calcular `priceTax` y `discountAmount` si es fácil hacerlo (evita recálculos en `ReportService`)
- Incluir todos los campos que ya tienes disponibles
- Incluir `tax_ids` como lista de Maps si tienes la información

**Opcional**:
- Si no calculas `tax_amount` o `discount_amount`, `ReportService` los calculará automáticamente
- Si no incluyes `_has_taxes()`, `ReportService` lo agregará automáticamente

---

## Checklist para Nuevos Modelos

Cuando agregues un nuevo modelo con cabecera+líneas (ej: `purchase.order`, `stock.picking`):

### 1. Implementar `toReportMap()` en el modelo de cabecera
- [ ] Retorna `Map<String, dynamic>` con estructura compatible con QWeb
- [ ] Incluye `lines_to_report` como lista de maps transformados
- [ ] Incluye campos estándar: `partner_id`, `company_id`, `amount_*`, fechas
- [ ] Incluye `id`, `name`, `state`

### 2. Implementar `toReportMap()` en el modelo de línea
- [ ] Retorna `Map<String, dynamic>` con campos estándar
- [ ] Incluye campos mínimos: `id`, `name`, `display_type`, `sequence`, `product_id`, `quantity`, `price_unit`, `discount`, `price_subtotal`, `price_total`
- [ ] Incluye campos recomendados: `price_tax`, `tax_amount`, `discount_amount`, `tax_ids`
- [ ] Incluye métodos: `_has_taxes()`, `with_context()`

### 3. Sincronizar template QWeb desde Odoo
- [ ] El template está registrado en `ReportService`
- [ ] El template sigue la estructura estándar de Odoo para tablas de líneas
- [ ] El template usa `lines_to_report` o el campo específico del modelo

### 4. Verificar pre-procesamiento
- [ ] Las líneas pasan por `_preprocessLineForReport()` automáticamente (si usas `lines_to_report`)
- [ ] Los campos calculados se normalizan correctamente
- [ ] Los métodos requeridos están presentes

### 5. Probar renderizado
- [ ] Las columnas se renderizan correctamente en el PDF
- [ ] Los valores numéricos son correctos
- [ ] El formato monetario es consistente con Odoo
- [ ] `display_discount` y `display_taxes` funcionan correctamente
- [ ] Las líneas de sección/nota se renderizan correctamente

---

## Ejemplos de Implementación

### Ejemplo 1: Orden de Venta (SaleOrder)

**Referencia (theos_pos)**: `theos_pos/lib/features/sales/screens/sale_order_form/form_header.dart`

**Método**: `_orderToReportMap()`

**Características**:
- Transforma `SaleOrder` y `List<SaleOrderLine>` a Map
- Calcula totales de secciones
- Maneja facturas offline

### Ejemplo 2: Factura (AccountMove)

**Referencia (theos_pos)**: `theos_pos/lib/features/invoices/models/account_move.model.dart`

**Método**: `AccountMove.toReportMap()`

**Características**:
- Transforma `AccountMove` y `List<AccountMoveLine>` a Map
- Maneja campos específicos de Ecuador (SRI)
- Calcula `priceTax` y `discountAmount`

### Ejemplo 3: Línea de Factura (AccountMoveLine)

**Referencia (theos_pos)**: `theos_pos/lib/features/invoices/models/account_move.model.dart`

**Método**: `AccountMoveLine.toReportMap()`

**Características**:
- Transforma línea individual a Map
- Parsea `tax_ids` a lista de Maps con `tax_label`
- Incluye métodos `_has_taxes()` y `_l10n_ec_prepare_edi_vals_to_export_USD()`

---

## Referencias

- **ReportService**: `flutter_qweb/lib/src/services/report_service.dart`
- **Método de pre-procesamiento**: `ReportService._preprocessLineForReport()`

---

## Notas Finales

- El pre-procesamiento automático garantiza consistencia entre diferentes modelos
- No es necesario implementar toda la lógica de normalización en cada modelo
- El contrato es flexible: puedes incluir campos adicionales específicos del modelo
- Los templates QWeb de Odoo esperan ciertos campos y métodos; el pre-procesamiento asegura que estén presentes
