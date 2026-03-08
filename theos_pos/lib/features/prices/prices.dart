/// Prices feature module
///
/// Centralizes all price-related functionality in one place.
/// Use [PricelistCalculatorService] for all price operations:
///
/// **Instance methods (require database):**
/// - `calculatePrice()` - Calculate price from pricelist rules
/// - `preloadPricelistRules()` - Preload rules for performance
/// - UoM conversion with caching
/// - Category hierarchy matching
///
/// **Static methods (no database needed):**
/// - `PricelistCalculatorService.applyDiscount()` - Apply discount to price
/// - `PricelistCalculatorService.calculateDiscountAmount()` - Calc discount amount
/// - `PricelistCalculatorService.calculateSubtotal()` - Calc line subtotal
/// - `PricelistCalculatorService.convertPriceByFactor()` - Convert price by UoM
/// - `PricelistCalculatorService.calculateDiscountPercent()` - Reverse calc discount %
/// - `PricelistCalculatorService.roundPrice()` - Round price to decimals
library;

export 'providers/providers.dart';
export 'services/pricelist_calculator_service.dart';
