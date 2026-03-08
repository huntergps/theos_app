/// Repository adapter for QWeb report template storage (Drift).
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_qweb/flutter_qweb.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Drift-backed store for QWeb templates and paper formats.
class DriftQwebTemplateStore {
  final AppDatabase _db;

  DriftQwebTemplateStore(this._db);

  Future<CachedTemplate?> getTemplate(String templateKey) async {
    final row = await (_db.select(_db.qwebReportTemplate)
          ..where((t) => t.templateKey.equals(templateKey)))
        .getSingleOrNull();

    if (row == null) return null;

    return CachedTemplate(
      templateKey: row.templateKey,
      odooId: row.odooId,
      name: row.name,
      model: row.model,
      xmlContent: row.xmlContent ?? row.templateContent,
      requiredFields: _decodeJsonList(row.requiredFields ?? '[]'),
      dependencies: _decodeJsonList(row.dependencies ?? '[]'),
      lastSynced: row.lastSynced ?? DateTime.now(),
      checksum: row.checksum ?? '',
    );
  }

  Future<List<CachedTemplate>> getTemplatesForModel(String model) async {
    final rows = await (_db.select(_db.qwebReportTemplate)
          ..where((t) => t.model.equals(model)))
        .get();

    return rows
        .map((row) => CachedTemplate(
              templateKey: row.templateKey,
              odooId: row.odooId,
              name: row.name,
              model: row.model,
              xmlContent: row.xmlContent ?? row.templateContent,
              requiredFields: _decodeJsonList(row.requiredFields ?? '[]'),
              dependencies: _decodeJsonList(row.dependencies ?? '[]'),
              lastSynced: row.lastSynced ?? DateTime.now(),
              checksum: row.checksum ?? '',
            ))
        .toList();
  }

  Future<void> saveTemplate(CachedTemplate template) async {
    await _db.transaction(() async {
      await (_db.delete(_db.qwebReportTemplate)
            ..where((t) => t.templateKey.equals(template.templateKey)))
          .go();

      await _db.into(_db.qwebReportTemplate).insert(
            QwebReportTemplateCompanion.insert(
              templateKey: template.templateKey,
              odooId: template.odooId,
              name: template.name ?? '',
              model: template.model ?? '',
              reportType: 'pdf', // Default to PDF reports
              reportName: template.templateKey, // Use templateKey as reportName
              templateContent: template.xmlContent,
              xmlContent: Value(template.xmlContent),
              requiredFields: Value(jsonEncode(template.requiredFields)),
              dependencies: Value(jsonEncode(template.dependencies)),
              checksum: Value(template.checksum),
              lastSynced: Value(template.lastSynced),
              writeDate: Value(DateTime.now()),
            ),
          );
    });
  }

  Future<void> deleteTemplate(String templateKey) async {
    await (_db.delete(_db.qwebReportTemplate)
          ..where((t) => t.templateKey.equals(templateKey)))
        .go();
  }

  Future<void> saveTemplates(List<CachedTemplate> templates) async {
    await _db.batch((batch) {
      for (final template in templates) {
        batch.insert(
          _db.qwebReportTemplate,
          QwebReportTemplateCompanion.insert(
            templateKey: template.templateKey,
            odooId: template.odooId,
            name: template.name ?? '',
            model: template.model ?? '',
            reportType: 'pdf', // Default to PDF reports
            reportName: template.templateKey, // Use templateKey as reportName
            templateContent: template.xmlContent,
            xmlContent: Value(template.xmlContent),
            requiredFields: Value(jsonEncode(template.requiredFields)),
            dependencies: Value(jsonEncode(template.dependencies)),
            checksum: Value(template.checksum),
            lastSynced: Value(template.lastSynced),
            writeDate: Value(DateTime.now()),
          ),
          onConflict: DoUpdate((old) => QwebReportTemplateCompanion(
                odooId: Value(template.odooId),
                name: Value(template.name ?? ''),
                model: Value(template.model ?? ''),
                xmlContent: Value(template.xmlContent),
                requiredFields: Value(jsonEncode(template.requiredFields)),
                dependencies: Value(jsonEncode(template.dependencies)),
                checksum: Value(template.checksum),
                lastSynced: Value(template.lastSynced),
                writeDate: Value(DateTime.now()),
              )),
        );
      }
    });
  }

  Future<List<CachedTemplate>> getAllTemplates() async {
    final rows = await _db.select(_db.qwebReportTemplate).get();

    return rows
        .map((row) => CachedTemplate(
              templateKey: row.templateKey,
              odooId: row.odooId,
              name: row.name,
              model: row.model,
              xmlContent: row.xmlContent ?? row.templateContent,
              requiredFields: _decodeJsonList(row.requiredFields ?? '[]'),
              dependencies: _decodeJsonList(row.dependencies ?? '[]'),
              lastSynced: row.lastSynced ?? DateTime.now(),
              checksum: row.checksum ?? '',
            ))
        .toList();
  }

  Future<bool> templateExists(String templateKey) async {
    final count = await (_db.selectOnly(_db.qwebReportTemplate)
          ..addColumns([_db.qwebReportTemplate.id.count()])
          ..where(_db.qwebReportTemplate.templateKey.equals(templateKey)))
        .map((row) => row.read(_db.qwebReportTemplate.id.count()))
        .getSingle();

    return (count ?? 0) > 0;
  }

  Future<int> getTemplateCount() async {
    final count = await (_db.selectOnly(_db.qwebReportTemplate)
          ..addColumns([_db.qwebReportTemplate.id.count()]))
        .map((row) => row.read(_db.qwebReportTemplate.id.count()))
        .getSingle();

    return count ?? 0;
  }

  Future<Map<String, String>> getTemplateChecksums() async {
    final rows = await (_db.selectOnly(_db.qwebReportTemplate)
          ..addColumns([
            _db.qwebReportTemplate.templateKey,
            _db.qwebReportTemplate.checksum
          ]))
        .get();

    return Map.fromEntries(rows.map((row) => MapEntry(
          row.read(_db.qwebReportTemplate.templateKey)!,
          row.read(_db.qwebReportTemplate.checksum)!,
        )));
  }

  Future<String?> getTemplateChecksum(String templateKey) async {
    final row = await (_db.selectOnly(_db.qwebReportTemplate)
          ..addColumns([_db.qwebReportTemplate.checksum])
          ..where(_db.qwebReportTemplate.templateKey.equals(templateKey)))
        .getSingleOrNull();

    return row?.read(_db.qwebReportTemplate.checksum);
  }

  // ============ Paper Format Operations ============

  Future<PaperFormat?> getPaperFormat(String templateKey) async {
    // Note: QwebPaperFormat doesn't have templateKey field
    // Using first available format as default
    final row = await (_db.select(_db.qwebPaperFormat)
          ..limit(1))
        .getSingleOrNull();

    if (row == null) return null;

    return PaperFormat(
      format: row.format ?? 'A4',
      orientation: row.orientation == 'landscape'
          ? PageOrientation.landscape
          : PageOrientation.portrait,
      marginTop: row.marginTop,
      marginBottom: row.marginBottom,
      marginLeft: row.marginLeft,
      marginRight: row.marginRight,
      headerSpacing: 0.0, // Default value (field doesn't exist in table)
      dpi: 96, // Default DPI (field doesn't exist in table)
    );
  }

  Future<void> savePaperFormat(String templateKey, PaperFormat format) async {
    // Note: QwebPaperFormat doesn't have templateKey field
    // This is a simplified implementation that creates/updates a default format
    await _db.transaction(() async {
      await _db.into(_db.qwebPaperFormat).insert(
            QwebPaperFormatCompanion.insert(
              odooId: 1, // Use fixed ID for default format
              name: 'Default Format',
              format: Value(format.format),
              orientation: Value(format.orientation == PageOrientation.landscape
                  ? 'landscape'
                  : 'portrait'),
              marginTop: Value(format.marginTop),
              marginBottom: Value(format.marginBottom),
              marginLeft: Value(format.marginLeft),
              marginRight: Value(format.marginRight),
              writeDate: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  Future<Map<String, PaperFormat>> getAllPaperFormats() async {
    final rows = await _db.select(_db.qwebPaperFormat).get();

    return Map.fromEntries(rows.map((row) => MapEntry(
          row.name, // Use name as key since templateKey doesn't exist
          PaperFormat(
            format: row.format ?? 'A4',
            orientation: row.orientation == 'landscape'
                ? PageOrientation.landscape
                : PageOrientation.portrait,
            marginTop: row.marginTop,
            marginBottom: row.marginBottom,
            marginLeft: row.marginLeft,
            marginRight: row.marginRight,
            headerSpacing: 0.0, // Default value (field doesn't exist)
            dpi: 96, // Default DPI (field doesn't exist)
          ),
        )));
  }

  Future<void> clearAll() async {
    await _db.delete(_db.qwebReportTemplate).go();
    await _db.delete(_db.qwebPaperFormat).go();
  }

  // ============ Helper Methods ============

  List<String> _decodeJsonList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.cast<String>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

/// App-facing repository that implements QwebTemplateProvider for flutter_qweb.
class QwebTemplateRepository implements QwebTemplateProvider {
  final DriftQwebTemplateStore _store;

  QwebTemplateRepository(AppDatabase db) : _store = DriftQwebTemplateStore(db);

  /// Access the underlying store for direct CRUD operations.
  DriftQwebTemplateStore get store => _store;

  @override
  Future<List<CachedTemplate>> getAllTemplates() => _store.getAllTemplates();

  @override
  Future<Map<String, PaperFormat>> getAllPaperFormats() =>
      _store.getAllPaperFormats();

  /// Delegate additional store methods for sync usage.
  Future<CachedTemplate?> getTemplate(String templateKey) =>
      _store.getTemplate(templateKey);

  Future<List<CachedTemplate>> getTemplatesForModel(String model) =>
      _store.getTemplatesForModel(model);

  Future<void> saveTemplate(CachedTemplate template) =>
      _store.saveTemplate(template);

  Future<void> saveTemplates(List<CachedTemplate> templates) =>
      _store.saveTemplates(templates);

  Future<void> deleteTemplate(String templateKey) =>
      _store.deleteTemplate(templateKey);

  Future<bool> templateExists(String templateKey) =>
      _store.templateExists(templateKey);

  Future<int> getTemplateCount() => _store.getTemplateCount();

  Future<Map<String, String>> getTemplateChecksums() =>
      _store.getTemplateChecksums();

  Future<String?> getTemplateChecksum(String templateKey) =>
      _store.getTemplateChecksum(templateKey);

  Future<PaperFormat?> getPaperFormat(String templateKey) =>
      _store.getPaperFormat(templateKey);

  Future<void> savePaperFormat(String templateKey, PaperFormat format) =>
      _store.savePaperFormat(templateKey, format);

  Future<void> clearAll() => _store.clearAll();
}
