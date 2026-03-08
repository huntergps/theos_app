// Barrel file for sales models/DTOs
library;

export 'sale_order.model.dart';
// Hide generated SaleOrderLineManager - we use the mixin from providers
export 'sale_order_line.model.dart' hide SaleOrderLineManager;
export 'sales_team.model.dart';

