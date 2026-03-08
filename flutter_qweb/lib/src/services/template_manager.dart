/// Template Manager - Manages QWeb template cache, loading, and sanitization.
///
/// Extracted from [ReportService] to separate template management concerns
/// from report generation and file handling.
library;

import 'package:flutter/foundation.dart';

import '../models/cached_template.dart';
import '../models/paper_format.dart';
import '../qweb_report_engine.dart';
import 'report_template_sanitizer.dart';

/// Repository contract for accessing cached QWeb templates and paper formats.
abstract class QwebTemplateProvider {
  Future<List<CachedTemplate>> getAllTemplates();
  Future<Map<String, PaperFormat>> getAllPaperFormats();
}

class _TemplateLogger {
  void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('$tag $message');
    }
  }
}

final _log = _TemplateLogger();

/// Manages template caching, loading from database, registration, and
/// sanitization for QWeb PDF report generation.
class TemplateManager {
  /// QWeb engine for template rendering
  final QWebReportEngine engine;

  /// Cached templates (templateName -> xml)
  final Map<String, String> templateCache = {};

  /// Paper formats (templateName -> PaperFormat)
  final Map<String, PaperFormat> paperFormats = {};

  /// Whether templates have been loaded from database
  bool templatesLoaded = false;

  /// Custom template sanitizers registered by the app layer.
  final List<ReportTemplateSanitizer> _sanitizers = [];

  TemplateManager(this.engine);

  /// Register a custom template sanitizer.
  void addSanitizer(ReportTemplateSanitizer sanitizer) {
    _sanitizers.add(sanitizer);
  }

  /// Load all templates from the database.
  Future<int> loadTemplatesFromDatabase(
    QwebTemplateProvider templateRepo,
  ) async {
    _log.d('[TemplateManager]', '=== Loading templates from database ===');
    try {
      final templates = await templateRepo.getAllTemplates();
      final formats = await templateRepo.getAllPaperFormats();
      _log.d('[TemplateManager]', 'Found ${templates.length} templates');

      // Clear existing cache
      templateCache.clear();
      paperFormats.clear();
      engine.clearCache();

      // Register all templates from DB
      for (final template in templates) {
        if (template.xmlContent.isNotEmpty) {
          try {
            var xmlContent = template.xmlContent;

            // --- TEMPLATE SANITIZATION & FIXES ---

            // 1. Handle 'groups' attributes smarter
            xmlContent = xmlContent.replaceAll(
              RegExp(r'''groups=['"][^'"]*tax_included[^'"]*['"]'''),
              't-if="0"',
            );
            xmlContent = xmlContent.replaceAll(
              RegExp(r'''groups=['"][^'"]*['"]'''),
              '',
            );

            // 2. Fix Python lambda expressions for taxes
            xmlContent = xmlContent.replaceAllMapped(
              RegExp(
                  r't-esc="[^"]*lambda[^"]*([a-zA-Z0-9_]+)\.tax_ids[^"]*"'),
              (match) => 't-esc="${match.group(1)}.tax_names"',
            );

            // 3. Fix empty fields by replacing t-field with formatted t-esc
            String replaceField(
              String content,
              String field,
              String formattedField,
            ) {
              return content.replaceAllMapped(
                RegExp('t-field=["\']([a-zA-Z0-9_]+)\\.$field["\']'),
                (match) => 't-esc="${match.group(1)}.$formattedField"',
              );
            }

            xmlContent = replaceField(
                xmlContent, 'price_subtotal', 'formatted_price_subtotal');
            xmlContent = replaceField(
                xmlContent, 'price_total', 'formatted_price_total');
            xmlContent = replaceField(
                xmlContent, 'price_unit', 'formatted_price_unit');
            xmlContent =
                replaceField(xmlContent, 'discount', 'formatted_discount');

            // 4. Run registered sanitizers (app-layer customizations)
            for (final sanitizer in _sanitizers) {
              xmlContent =
                  sanitizer.sanitize(xmlContent, template.templateKey);
            }

            // DEBUG: Dump template for troubleshooting
            if (template.templateKey.contains('invoice') ||
                template.templateKey.contains('lines')) {
              final hasOriginalDiscount =
                  xmlContent.contains('t-field="line.discount"');
              final hasFormattedDiscount =
                  xmlContent.contains('t-esc="line.formatted_discount"');
              _log.d(
                '[TemplateManager]',
                'Template: ${template.templateKey} - '
                    'has t-field="line.discount": $hasOriginalDiscount, '
                    'has t-esc="line.formatted_discount": $hasFormattedDiscount',
              );
            }

            templateCache[template.templateKey] = xmlContent;
            engine.registerTemplate(template.templateKey, xmlContent);
          } catch (e) {
            // Skip malformed templates but continue loading others
          }
        }
      }

      // Store paper formats
      paperFormats.addAll(formats);

      templatesLoaded = true;

      return templates.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get the number of loaded templates.
  int get templateCount => templateCache.length;

  /// Register a template XML for a given name.
  void registerTemplate(
    String templateName,
    String xml, {
    PaperFormat? paperFormat,
  }) {
    templateCache[templateName] = xml;
    engine.registerTemplate(templateName, xml);
    if (paperFormat != null) {
      paperFormats[templateName] = paperFormat;
    }
  }

  /// Check if a template is registered.
  bool hasTemplate(String templateName) {
    return templateCache.containsKey(templateName);
  }

  /// Get registered template XML.
  String? getTemplateXml(String templateName) {
    return templateCache[templateName];
  }

  /// Get paper format for a template.
  PaperFormat? getPaperFormat(String templateName) {
    return paperFormats[templateName];
  }

  /// Clear all cached templates.
  void clearTemplates() {
    templateCache.clear();
    paperFormats.clear();
    engine.clearCache();
    templatesLoaded = false;
  }
}
