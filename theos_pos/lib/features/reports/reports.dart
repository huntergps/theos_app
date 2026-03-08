/// Reports feature module
///
/// Provides QWeb template management for offline PDF report generation.
/// Used by both sales (sale.order) and invoices (account.move) features.
///
/// Usage:
/// ```dart
/// import 'package:theos_pos/features/reports/reports.dart';
///
/// // Get QWeb template repository
/// final templateRepo = QwebTemplateRepository(db);
/// final template = await templateRepo.getTemplate('sale.order.report');
///
/// // Sync templates from Odoo
/// final syncRepo = QwebTemplateSyncRepository(db: db, odooClient: odoo);
/// await syncRepo.syncAllTemplates();
/// ```
library;

export 'repositories/repositories.dart';
export 'providers/providers.dart';
