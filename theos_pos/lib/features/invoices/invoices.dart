/// Invoice feature module
///
/// Provides offline-first invoice (account.move) management:
/// - Invoice model and repository
/// - Invoice display widgets
/// - Print functionality using QWeb templates
///
/// Usage:
/// ```dart
/// import 'package:theos_pos/features/invoices/invoices.dart';
///
/// // Load invoices for a sale order
/// final invoices = ref.watch(invoicesForOrderProvider(orderId));
///
/// // Display invoice section in a form
/// InvoiceSection(orderId: orderId)
/// ```
library;

export 'repositories/repositories.dart';
export 'widgets/widgets.dart';
export 'datasources/datasources.dart';
export 'providers/providers.dart';
export 'utils/utils.dart';
