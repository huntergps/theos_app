import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_qweb/flutter_qweb.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Reads the QWeb cache already owned by the shared local database.
///
/// The panel does not sync or mutate templates here. A separate catalog/sync
/// producer is responsible for populating `qweb_report_template`; this reader
/// makes the existing cache available to flutter_qweb after a restart.
final class DatabaseQwebTemplateProvider implements QwebTemplateProvider {
  DatabaseQwebTemplateProvider(this.database);

  final AppDatabase database;

  @override
  Future<List<CachedTemplate>> getAllTemplates() async {
    final rows = await (database.select(
      database.qwebReportTemplate,
    )..where((row) => row.active.equals(true))).get();
    return [
      for (final row in rows)
        if (row.xmlContent.trim().isNotEmpty)
          CachedTemplate(
            templateKey: row.templateKey,
            odooId: row.odooId,
            name: row.name,
            model: row.model,
            xmlContent: row.xmlContent,
            requiredFields: _decodeList(row.requiredFields),
            dependencies: _decodeList(row.dependencies),
            lastSynced: row.lastSynced ?? DateTime.now().toUtc(),
            checksum: row.checksum ?? '',
          ),
    ];
  }

  @override
  Future<Map<String, PaperFormat>> getAllPaperFormats() async {
    final rows = await (database.select(
      database.qwebPaperFormat,
    )..where((row) => row.active.equals(true))).get();
    return {
      for (final row in rows)
        row.name: PaperFormat(
          name: row.name,
          format: row.format ?? 'A4',
          pageHeight: row.pageHeight,
          pageWidth: row.pageWidth,
          marginTop: row.marginTop,
          marginBottom: row.marginBottom,
          marginLeft: row.marginLeft,
          marginRight: row.marginRight,
          orientation: row.orientation.toLowerCase() == 'landscape'
              ? PageOrientation.landscape
              : PageOrientation.portrait,
        ),
    };
  }

  static List<String> _decodeList(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return const [];
    try {
      final value = jsonDecode(encoded);
      return value is List ? value.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }
}

/// Generates a PDF exclusively from templates and report data already local.
///
/// This is intentionally separate from [DocumentRenderPort]: a generated PDF
/// is not automatically fiscal or SRI-authorized. The caller must persist the
/// returned bytes with the correct fiscal/sync states and may only claim
/// authorization from the domain's own fiscal contract.
final class OfflineQwebReportGenerator {
  OfflineQwebReportGenerator(
    QwebTemplateProvider provider, {
    ReportService? service,
  }) : _provider = provider,
       _service = service ?? ReportService();

  final QwebTemplateProvider _provider;
  final ReportService _service;
  bool _loaded = false;

  bool get templatesLoaded => _loaded && _service.templatesLoaded;
  int get templateCount => _service.templateCount;

  Future<int> loadCache() async {
    final count = await _service.loadTemplatesFromDatabase(_provider);
    _loaded = true;
    return count;
  }

  Future<Uint8List> render({
    required String templateName,
    required List<Map<String, dynamic>> records,
    Map<String, dynamic>? company,
    Map<String, dynamic>? user,
    RenderOptions? options,
    String docModel = '',
    ReportModelConfig modelConfig = const ReportModelConfig(),
  }) async {
    if (!_loaded) await loadCache();
    if (!_service.hasTemplate(templateName)) {
      throw StateError(
        'La plantilla $templateName no está disponible offline; sincronízala antes de salir.',
      );
    }
    final bytes = await _service.generateReport(
      templateName: templateName,
      records: records,
      company: company,
      user: user,
      options: options,
      docModel: docModel,
      modelConfig: modelConfig,
    );
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw StateError('El renderizador no devolvió un PDF válido');
    }
    return bytes;
  }
}
