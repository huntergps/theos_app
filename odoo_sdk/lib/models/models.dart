/// Odoo SDK - Catalog Models
///
/// Exports catalog models (Product, ProductCategory, Tax, Uom) that
/// demonstrate the OdooModelManager framework with Freezed annotations.
///
/// ## Usage
///
/// ```dart
/// import 'package:odoo_sdk/models/models.dart';
///
/// final product = Product(id: 1, name: 'Widget');
/// final tax = Tax(id: 1, name: 'IVA 15%', amount: 15.0);
/// ```
library;

// Catalog models (Product, ProductCategory, Tax, Uom)
export 'catalog/catalog.dart';
