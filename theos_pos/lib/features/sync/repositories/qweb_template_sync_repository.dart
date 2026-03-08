/// Sync repository adapter for QWeb report templates.
///
/// Standalone implementation that syncs QWeb templates from Odoo
/// to local storage via QwebTemplateRepository.
library;

import 'package:flutter_qweb/flutter_qweb.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase;

import '../../../core/database/database_helper.dart';
import '../../reports/repositories/qweb_template_repository.dart';

/// App-specific QWeb template sync with default base template list.
class QwebTemplateSyncRepository {
  final OdooClient? odooClient;
  final DatabaseHelper db;
  final QwebTemplateRepository _templateRepo;
  bool _cancelRequested = false;

  QwebTemplateSyncRepository({
    required this.db,
    this.odooClient,
    required AppDatabase appDb,
  }) : _templateRepo = QwebTemplateRepository(appDb);

  bool get isOnline => odooClient != null;

  static const List<String> _defaultBaseTemplates = [
    // === Web base templates ===
    'web.html_container',
    'web.external_layout',
    'web.external_layout_standard',
    'web.address_layout',
    'web.report_layout',

    // === Account base templates (invoices) ===
    'account.report_invoice',
    'account.report_invoice_document',
    'account.report_invoice_with_payments',
    'account.document_tax_totals',
    'account.document_tax_totals_template',

    // === Ecuador EDI invoice templates (l10n_ec_edi) ===
    'l10n_ec_edi.report_invoice',
    'l10n_ec_edi.report_invoice_document',
    'l10n_ec_edi.report_invoice_header',
    'l10n_ec_edi.report_invoice_additional_info',
    'l10n_ec_edi.document_tax_totals',
    // Withhold templates
    'l10n_ec_edi.report_withhold',
    'l10n_ec_edi.report_withhold_document',
    'l10n_ec_edi.withhold_line_values_template',

    // === Ecuador base invoice customizations (l10n_ec_base) ===
    'l10n_ec_base.l10n_ec_invoice_header_left',
    'l10n_ec_base.l10n_ec_invoice_header_right_top',
    'l10n_ec_base.l10n_ec_invoice_header_right_bottom',
    'l10n_ec_base.l10n_ec_stock_account_report_invoice_document',
    'l10n_ec_base.l10n_ec_report_invoice_document_client_ec',
    'l10n_ec_base.l10n_ec_report_invoice_document_lines_ec',
    // === Ecuador sale/discount templates ===
    'l10n_ec_sale_discount.l10n_ec_sale_discount_ec',
    'l10n_ec_sale_discount.document_tax_totals_ecuador',
    'l10n_ec_sale_discount.document_tax_totals_sale_ecuador',
    'l10n_ec_sale_discount.report_saleorder_document_inherit_total',
    'l10n_ec_sale_discount.report_invoice_document_totals_ecuador',
  ];

  /// Request cancellation of current sync operation.
  void cancelSync() {
    _cancelRequested = true;
  }

  /// Reset the cancellation flag.
  void resetCancelFlag() {
    _cancelRequested = false;
  }

  /// Sync templates for a specific model.
  Future<int> syncTemplatesForModel(
    String model, {
    SyncProgressCallback? onProgress,
  }) async {
    if (!isOnline) return 0;

    try {
      // Fetch ir.actions.report for this model
      final reports = await odooClient!.searchRead(
        model: 'ir.actions.report',
        domain: [
          ['model', '=', model],
          ['report_type', 'in', ['qweb-pdf', 'qweb-html']],
        ],
        fields: ['report_name', 'name', 'model'],
      );

      int synced = 0;
      for (final report in reports) {
        if (_cancelRequested) break;
        final templateKey = report['report_name'] as String?;
        if (templateKey != null) {
          final success = await syncTemplate(templateKey);
          if (success) synced++;
        }
      }
      return synced;
    } catch (e) {
      logger.e('[QwebTemplateSync] Error syncing templates for $model: $e');
      return 0;
    }
  }

  /// Sync all templates for multiple models.
  Future<Map<String, int>> syncAllTemplates({
    List<String> models = const ['sale.order'],
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
    List<String> baseTemplates = const [],
  }) async {
    final results = <String, int>{};
    final templates = baseTemplates.isEmpty ? _defaultBaseTemplates : baseTemplates;

    // Sync base templates first
    int baseSynced = 0;
    for (final key in templates) {
      if (_cancelRequested) break;
      final success = await syncTemplate(key);
      if (success) baseSynced++;
    }
    results['base'] = baseSynced;

    // Sync model-specific templates
    for (final model in models) {
      if (_cancelRequested) break;
      results[model] = await syncTemplatesForModel(model, onProgress: onProgress);
    }

    return results;
  }

  /// Sync a single template by key.
  Future<bool> syncTemplate(String templateKey) async {
    if (!isOnline) return false;

    try {
      final views = await odooClient!.searchRead(
        model: 'ir.ui.view',
        domain: [
          ['key', '=', templateKey],
          ['type', '=', 'qweb'],
        ],
        fields: ['id', 'key', 'name', 'arch_db', 'model', 'write_date'],
        limit: 1,
      );

      if (views.isEmpty) return false;

      final view = views.first;
      // Odoo returns false instead of null for empty fields
      String safeStr(dynamic val) =>
          (val != null && val != false) ? val.toString() : '';
      final template = CachedTemplate(
        templateKey: view['key'] as String,
        odooId: view['id'] as int,
        name: safeStr(view['name']),
        model: safeStr(view['model']),
        xmlContent: safeStr(view['arch_db']),
        requiredFields: const [],
        dependencies: const [],
        lastSynced: DateTime.now(),
        checksum: '',
      );

      await _templateRepo.saveTemplate(template);
      return true;
    } catch (e) {
      logger.e('[QwebTemplateSync] Error syncing template $templateKey: $e');
      return false;
    }
  }

  /// Check for template updates using checksums.
  Future<List<String>> checkForUpdates(List<String> templateKeys) async {
    if (!isOnline) return [];

    final localChecksums = await _templateRepo.getTemplateChecksums();
    final needsUpdate = <String>[];

    for (final key in templateKeys) {
      if (!localChecksums.containsKey(key)) {
        needsUpdate.add(key);
      }
    }

    return needsUpdate;
  }

  /// Clear all locally stored templates.
  Future<void> clearAllTemplates() async {
    await _templateRepo.clearAll();
  }

  /// Get count of locally stored templates.
  Future<int> getLocalTemplateCount() async {
    return await _templateRepo.getTemplateCount();
  }
}
