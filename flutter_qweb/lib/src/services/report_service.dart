/// Report Service - Generic PDF report generation using QWeb templates
///
/// This service provides a unified way to generate PDF reports for any Odoo model.
/// It delegates all rendering to flutter_qweb, which parses QWeb XML templates
/// and converts them directly to PDF.
///
/// ## Usage
///
/// ```dart
/// final reportService = ref.read(reportServiceProvider);
///
/// // Load templates from database (after sync)
/// await reportService.loadTemplatesFromDatabase(templateRepo);
///
/// // Generate PDF for sale orders
/// final pdfBytes = await reportService.generateReport(
///   templateName: 'sale.report_saleorder_document',
///   records: [saleOrder.toReportMap()],
/// );
///
/// // Generate PDF for invoices
/// final pdfBytes = await reportService.generateReport(
///   templateName: 'account.report_invoice_document',
///   records: [invoice.toReportMap()],
/// );
/// ```
library;

import 'package:flutter/foundation.dart';

import '../models/paper_format.dart';
import '../models/render_options.dart';
import '../models/report_model_config.dart';
import '../models/report_result.dart' show ReportException;
import '../models/template_context.dart' show CompanyInfo;
import '../qweb_report_engine.dart';
import 'line_preprocessor.dart';
import 'report_file_manager.dart';
import 'report_template_sanitizer.dart';
import 'template_manager.dart';

// Re-export QwebTemplateProvider so existing consumers don't break.
export 'template_manager.dart' show QwebTemplateProvider;

class _ReportLogger {
  void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('$tag $message');
    }
  }
}

/// Logger instance for report service diagnostics
final _log = _ReportLogger();

/// Generic report service for PDF generation
///
/// Uses flutter_qweb to parse QWeb XML templates and render them to PDF.
/// The same service works for any Odoo model - sale orders, invoices,
/// stock pickings, payments, etc.
class ReportService {
  /// QWeb engine for template rendering
  final QWebReportEngine _engine = QWebReportEngine();

  late final TemplateManager _templateManager;
  final LinePreprocessor _linePreprocessor = LinePreprocessor();
  final ReportFileManager _fileManager = ReportFileManager();

  ReportService() {
    _templateManager = TemplateManager(_engine);
  }

  // ── Template management (delegated to TemplateManager) ──────────────

  /// Register a custom template sanitizer.
  void addSanitizer(ReportTemplateSanitizer sanitizer) {
    _templateManager.addSanitizer(sanitizer);
  }

  /// Load all templates from the database.
  Future<int> loadTemplatesFromDatabase(
    QwebTemplateProvider templateRepo,
  ) async {
    return _templateManager.loadTemplatesFromDatabase(templateRepo);
  }

  /// Check if templates have been loaded.
  bool get templatesLoaded => _templateManager.templatesLoaded;

  /// Get the number of loaded templates.
  int get templateCount => _templateManager.templateCount;

  /// Register a template XML for a given name.
  void registerTemplate(
    String templateName,
    String xml, {
    PaperFormat? paperFormat,
  }) {
    _templateManager.registerTemplate(
      templateName,
      xml,
      paperFormat: paperFormat,
    );
  }

  /// Check if a template is registered.
  bool hasTemplate(String templateName) {
    return _templateManager.hasTemplate(templateName);
  }

  /// Get registered template XML.
  String? getTemplateXml(String templateName) {
    return _templateManager.getTemplateXml(templateName);
  }

  /// Get paper format for a template.
  PaperFormat? getPaperFormat(String templateName) {
    return _templateManager.getPaperFormat(templateName);
  }

  /// Clear all cached templates.
  void clearTemplates() {
    _templateManager.clearTemplates();
  }

  // ── Font management (delegated to ReportFileManager) ────────────────

  /// Pre-load fonts at app startup.
  Future<void> preloadFonts() async {
    await _fileManager.preloadFonts();
  }

  // ── Report generation ───────────────────────────────────────────────

  /// Generate PDF report
  ///
  /// [templateName] - The Odoo template name (e.g., 'sale.report_saleorder_document')
  /// [records] - List of record maps to render (accessible as 'docs' in template)
  /// [company] - Company information for header/footer
  /// [user] - Current user information
  /// [options] - PDF rendering options (page format, margins, etc.)
  Future<Uint8List> generateReport({
    required String templateName,
    required List<Map<String, dynamic>> records,
    Map<String, dynamic>? company,
    Map<String, dynamic>? user,
    RenderOptions? options,
    String docModel = '',
    ReportModelConfig modelConfig = const ReportModelConfig(),
  }) async {
    // Get template XML
    final xml = _templateManager.getTemplateXml(templateName);
    if (xml == null) {
      throw ReportException(
        'Template not found: $templateName. '
        'Register the template first using registerTemplate().',
      );
    }

    // === DIAGNOSTIC: Log template content ===
    _log.d('[ReportService]', '=== TEMPLATE DEBUG ===');
    _log.d('[ReportService]', 'Template: $templateName');
    _log.d('[ReportService]', 'Template length: ${xml.length} chars');
    _log.d('[ReportService]',
        'Has th_discount: ${xml.contains('th_discount')}');
    _log.d(
        '[ReportService]', 'Has th_taxes: ${xml.contains('th_taxes')}');
    _log.d('[ReportService]',
        'Has th_priceunit: ${xml.contains('th_priceunit')}');
    _log.d('[ReportService]',
        'Has th_subtotal: ${xml.contains('th_subtotal')}');
    _log.d('[ReportService]',
        'Has display_discount: ${xml.contains('display_discount')}');
    _log.d('[ReportService]',
        'Has display_taxes: ${xml.contains('display_taxes')}');
    _log.d('[ReportService]',
        'Has price_unit: ${xml.contains('price_unit')}');
    _log.d('[ReportService]',
        'Has price_subtotal: ${xml.contains('price_subtotal')}');
    _log.d('[ReportService]',
        'Has invoice_line_ids: ${xml.contains('invoice_line_ids')}');
    _log.d('[ReportService]',
        'Has lines_to_report: ${xml.contains('lines_to_report')}');
    _log.d('[ReportService]', '=== END TEMPLATE DEBUG ===');

    // Pre-process records
    final resolvedLocale =
        (options ?? const RenderOptions()).effectiveLocale;

    final processedRecords = _linePreprocessor.processRecords(
      records: records,
      locale: resolvedLocale,
      modelConfig: modelConfig,
    );

    // Resolve render options
    var renderOptions = options ?? const RenderOptions();

    if (options == null) {
      final format = _templateManager.getPaperFormat(templateName);
      if (format != null) {
        renderOptions = RenderOptions.fromPaperFormat(format);
      } else {
        const margin = 28.35;
        renderOptions = renderOptions.copyWith(
          marginTop: margin,
          marginBottom: margin,
          marginLeft: margin,
          marginRight: margin,
        );
      }
    }

    // Ensure fonts are loaded and inject them
    if (_fileManager.regularFont == null) {
      await _fileManager.ensurePdfFontsLoaded();
    }
    renderOptions = _fileManager.injectFonts(renderOptions);

    // Prepare company map
    final companyMap = _linePreprocessor.enrichCompanyMap(company);

    // Build context
    final context = _linePreprocessor.buildContext(
      processedRecords: processedRecords,
      companyMap: companyMap,
      user: user,
      docModel: docModel,
    );

    try {
      // Try to use cached AST template first (faster)
      var pdfBytes = await _engine.renderCachedTemplate(
        templateName: templateName,
        data: context,
        company: company != null ? CompanyInfo.fromMap(company) : null,
        options: renderOptions,
      );

      // Fallback to parsing XML
      pdfBytes ??= await _engine.renderToPdf(
        xml: xml,
        data: context,
        company: company != null ? CompanyInfo.fromMap(company) : null,
        options: renderOptions,
      );

      return pdfBytes;
    } catch (e) {
      throw ReportException('Failed to generate report: $e');
    }
  }

  /// Generate and open PDF in system viewer.
  Future<bool> generateAndOpen({
    required String templateName,
    required List<Map<String, dynamic>> records,
    required String filename,
    Map<String, dynamic>? company,
    Map<String, dynamic>? user,
    RenderOptions? options,
  }) async {
    try {
      final pdfBytes = await generateReport(
        templateName: templateName,
        records: records,
        company: company,
        user: user,
        options: options,
      );
      return _fileManager.saveAndOpen(pdfBytes, filename);
    } catch (e) {
      rethrow;
    }
  }

  /// Generate and print PDF using system print dialog.
  Future<bool> generateAndPrint({
    required String templateName,
    required List<Map<String, dynamic>> records,
    required String filename,
    Map<String, dynamic>? company,
    Map<String, dynamic>? user,
    RenderOptions? options,
  }) async {
    try {
      final pdfBytes = await generateReport(
        templateName: templateName,
        records: records,
        company: company,
        user: user,
        options: options,
      );
      return _fileManager.printPdf(pdfBytes, filename);
    } catch (e) {
      rethrow;
    }
  }

  /// Get PDF bytes for preview (without opening or printing).
  Future<Uint8List> getPreviewBytes({
    required String templateName,
    required List<Map<String, dynamic>> records,
    Map<String, dynamic>? company,
    Map<String, dynamic>? user,
    RenderOptions? options,
  }) async {
    return generateReport(
      templateName: templateName,
      records: records,
      company: company,
      user: user,
      options: options,
    );
  }
}
