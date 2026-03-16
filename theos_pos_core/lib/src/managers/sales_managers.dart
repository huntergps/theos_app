/// Sales domain manager exports
///
/// Note: paymentLineManager, withholdLineManager, cardLoteManager singletons
/// are generated in their respective .model.g.dart files and accessible via
/// model barrel exports (sales_models.dart). Extension methods for those
/// managers should be added here when needed.
library;

export 'sales/sale_order_manager.dart';
export 'sales/sale_order_line_manager.dart';
export 'sales/team_manager.dart';
