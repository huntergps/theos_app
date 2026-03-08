/// Sale Order Form Dialogs
///
/// Re-exports dialogs from their respective feature modules.
/// This file provides backwards compatibility for existing imports.
library;

// Client dialogs - from clients feature
export '../../../clients/widgets/dialogs/select_client_dialog.dart';
export '../../../clients/widgets/dialogs/create_client_offline_dialog.dart';

// Product dialogs - from products feature
export '../../../products/widgets/dialogs/select_product_dialog.dart';
export '../../../products/widgets/product_info_dialog.dart';

// UoM dialog - local to sales (specific to sale order lines)
export 'select_uom_dialog.dart';
