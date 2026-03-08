/// Odoo Template Service
///
/// Fetches QWeb templates from Odoo server with full inheritance resolution.
/// Uses ir.ui.view.get_combined_arch() to get the final merged template XML.
library;

import '../models/paper_format.dart';
import '../models/report_action.dart';

/// Result of fetching a template from Odoo
class OdooTemplateResult {
  /// The fully resolved template XML with all inheritance applied
  final String xml;

  /// Template view ID in Odoo
  final int viewId;

  /// Template XML ID (e.g., 'sale.report_saleorder_document')
  final String xmlId;

  /// Template name
  final String name;

  /// Associated model (if any)
  final String? model;

  const OdooTemplateResult({
    required this.xml,
    required this.viewId,
    required this.xmlId,
    required this.name,
    this.model,
  });
}

/// Abstract interface for Odoo RPC calls
/// Implement this interface with your preferred HTTP client
abstract class OdooRpcClient {
  /// Execute a method on Odoo model
  /// Returns the result of the method call
  Future<dynamic> call({
    required String model,
    required String method,
    List<dynamic> args = const [],
    Map<String, dynamic> kwargs = const {},
  });

  /// Search and read records
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    List<dynamic> domain = const [],
    List<String> fields = const [],
    int? limit,
    int? offset,
    String? order,
  });

  /// Read specific records by ID
  Future<List<Map<String, dynamic>>> read({
    required String model,
    required List<int> ids,
    List<String> fields = const [],
  });
}

/// Service for fetching and managing QWeb templates from Odoo
class OdooTemplateService {
  final OdooRpcClient _client;

  OdooTemplateService(this._client);

  /// Get the fully resolved template XML with all inheritance applied
  ///
  /// This calls ir.ui.view.get_combined_arch() which returns the template
  /// with all inherited views merged into a single XML string.
  ///
  /// [templateRef] can be:
  /// - An integer view ID
  /// - A string XML ID (e.g., 'sale.report_saleorder_document')
  Future<OdooTemplateResult> getConsolidatedTemplate(
      dynamic templateRef) async {
    // First resolve the template reference to a view record
    List<Map<String, dynamic>> views;

    if (templateRef is int) {
      views = await _client.read(
        model: 'ir.ui.view',
        ids: [templateRef],
        fields: ['id', 'key', 'name', 'model'],
      );
    } else if (templateRef is String) {
      views = await _client.searchRead(
        model: 'ir.ui.view',
        domain: [
          ['key', '=', templateRef]
        ],
        fields: ['id', 'key', 'name', 'model'],
        limit: 1,
      );
    } else {
      throw ArgumentError('templateRef must be int or String');
    }

    if (views.isEmpty) {
      throw TemplateNotFoundException('Template not found: $templateRef');
    }

    final view = views.first;
    final viewId = view['id'] as int;

    // Call get_combined_arch() to get the fully resolved template
    final combinedArch = await _client.call(
      model: 'ir.ui.view',
      method: 'get_combined_arch',
      args: [
        [viewId]
      ],
    );

    return OdooTemplateResult(
      xml: combinedArch as String,
      viewId: viewId,
      xmlId: view['key'] as String? ?? '',
      name: view['name'] as String? ?? '',
      model: view['model'] as String?,
    );
  }

  /// Get all report actions for a specific model
  Future<List<ReportAction>> getReportsForModel(String model) async {
    final records = await _client.searchRead(
      model: 'ir.actions.report',
      domain: [
        ['model', '=', model]
      ],
      fields: ReportAction.odooFields,
    );

    return records.map((r) => ReportAction.fromOdoo(r)).toList();
  }

  /// Get a specific report action by ID or XML ID
  Future<ReportAction?> getReport(dynamic reportRef) async {
    List<Map<String, dynamic>> records;

    if (reportRef is int) {
      records = await _client.read(
        model: 'ir.actions.report',
        ids: [reportRef],
        fields: ReportAction.odooFields,
      );
    } else if (reportRef is String) {
      records = await _client.searchRead(
        model: 'ir.actions.report',
        domain: [
          '|',
          ['report_name', '=', reportRef],
          ['id', '=', reportRef], // In case it's an XML ID resolved to id
        ],
        fields: ReportAction.odooFields,
        limit: 1,
      );
    } else {
      throw ArgumentError('reportRef must be int or String');
    }

    if (records.isEmpty) return null;
    return ReportAction.fromOdoo(records.first);
  }

  /// Get paper format by ID
  Future<PaperFormat?> getPaperFormat(int id) async {
    final records = await _client.read(
      model: 'report.paperformat',
      ids: [id],
      fields: [
        'name',
        'format',
        'page_width',
        'page_height',
        'margin_top',
        'margin_bottom',
        'margin_left',
        'margin_right',
        'orientation',
        'header_line',
        'header_spacing',
        'disable_shrinking',
        'dpi',
        'css_margins',
      ],
    );

    if (records.isEmpty) return null;
    return PaperFormat.fromOdoo(records.first);
  }

  /// Get all available paper formats
  Future<List<PaperFormat>> getAllPaperFormats() async {
    final records = await _client.searchRead(
      model: 'report.paperformat',
      fields: [
        'name',
        'format',
        'page_width',
        'page_height',
        'margin_top',
        'margin_bottom',
        'margin_left',
        'margin_right',
        'orientation',
        'header_line',
        'header_spacing',
        'disable_shrinking',
        'dpi',
        'css_margins',
      ],
    );

    return records.map((r) => PaperFormat.fromOdoo(r)).toList();
  }

  /// Get all QWeb report templates
  Future<List<OdooTemplateResult>> getAllReportTemplates() async {
    final views = await _client.searchRead(
      model: 'ir.ui.view',
      domain: [
        ['type', '=', 'qweb'],
        ['key', 'like', 'report_'],
      ],
      fields: ['id', 'key', 'name', 'model'],
    );

    final results = <OdooTemplateResult>[];
    for (final view in views) {
      try {
        final template = await getConsolidatedTemplate(view['id'] as int);
        results.add(template);
      } catch (e) {
        // Skip templates that fail to resolve
        continue;
      }
    }

    return results;
  }

  /// Render a report and get the PDF bytes
  /// Uses Odoo's /report/pdf endpoint
  Future<List<int>> renderReport({
    required String reportName,
    required List<int> recordIds,
    Map<String, dynamic>? context,
  }) async {
    final result = await _client.call(
      model: 'ir.actions.report',
      method: 'render_qweb_pdf',
      args: [reportName, recordIds],
      kwargs: context != null ? {'data': context} : {},
    );

    // Result is typically [pdf_bytes_base64, 'pdf']
    if (result is List && result.isNotEmpty) {
      final pdfBase64 = result[0];
      if (pdfBase64 is String) {
        // Decode base64
        return _decodeBase64(pdfBase64);
      }
    }

    throw ReportRenderException('Failed to render report: $reportName');
  }

  List<int> _decodeBase64(String base64) {
    // Simple base64 decoding
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final output = <int>[];
    var buffer = 0;
    var bits = 0;

    for (var i = 0; i < base64.length; i++) {
      final char = base64[i];
      if (char == '=') break;
      final value = alphabet.indexOf(char);
      if (value < 0) continue;

      buffer = (buffer << 6) | value;
      bits += 6;

      if (bits >= 8) {
        bits -= 8;
        output.add((buffer >> bits) & 0xFF);
      }
    }

    return output;
  }
}

/// Exception thrown when a template is not found
class TemplateNotFoundException implements Exception {
  final String message;
  const TemplateNotFoundException(this.message);

  @override
  String toString() => 'TemplateNotFoundException: $message';
}

/// Exception thrown when report rendering fails
class ReportRenderException implements Exception {
  final String message;
  const ReportRenderException(this.message);

  @override
  String toString() => 'ReportRenderException: $message';
}
