/// Taxes feature module
///
/// Centralizes all tax-related functionality in one place.
///
/// **Models:**
/// - [Tax] - Immutable tax model with computed fields
///
/// **Services:**
/// Use [TaxCalculatorService] for all tax operations:
///
/// **Instance methods (require database):**
/// - `getProductTaxInfo()` - Get tax info for a product
/// - `calculateTaxes()` - Calculate taxes on a subtotal
/// - `calculateLineAmounts()` - Calculate full line amounts
/// - `calculateOrderTotals()` - Aggregate order totals
///
/// **Static methods (no database needed):**
/// - `TaxCalculatorService.simplifyTaxName()` - Simplify tax name for display
/// - `TaxCalculatorService.getFirstSimplifiedTaxName()` - Get first tax from list
/// - `TaxCalculatorService.parseTaxIds()` - Parse comma-separated tax IDs
/// - `TaxCalculatorService.buildTaxListForReport()` - Build tax list for QWeb
/// - `TaxCalculatorService.groupTaxesByName()` - Group taxes for totals display
library;

// Models
// Services
export 'package:theos_pos_core/theos_pos_core.dart' show TaxCalculatorService, TaxInfo;

// Widgets
export 'widgets/widgets.dart';
