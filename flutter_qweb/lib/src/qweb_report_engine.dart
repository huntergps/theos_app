import 'dart:typed_data';

import 'models/render_options.dart';
import 'models/template_context.dart';
import 'parser/qweb_node.dart';
import 'parser/qweb_parser.dart';
import 'renderer/pdf_renderer.dart';

/// Main QWeb Report Engine
///
/// Provides a simple API for rendering QWeb XML templates to PDF.
///
/// ## Basic Usage
///
/// ```dart
/// final engine = QWebReportEngine();
///
/// final pdfBytes = await engine.renderToPdf(
///   xml: '<h1><t t-esc="doc.name"/></h1>',
///   data: {'doc': {'name': 'Hello World'}},
/// );
/// ```
class QWebReportEngine {
  final QWebParser _parser = QWebParser();
  late final QWebPdfRenderer _renderer;

  QWebReportEngine() {
    _renderer = QWebPdfRenderer(templateLoader: getTemplate);
  }

  /// Cached parsed templates
  final Map<String, QWebNode> _templateCache = {};

  /// Render XML template to PDF with data
  ///
  /// [xml] - QWeb XML template string
  /// [data] - Data map for template rendering
  /// [company] - Optional company info for header/footer
  /// [options] - PDF rendering options
  ///
  /// Returns PDF bytes that can be saved or displayed.
  Future<Uint8List> renderToPdf({
    required String xml,
    required Map<String, dynamic> data,
    CompanyInfo? company,
    RenderOptions options = const RenderOptions(),
  }) async {
    final context = TemplateContext(
      data: data,
      company: company,
    );

    return _renderer.renderFromXml(
      xml: xml,
      context: context,
      options: options,
    );
  }

  /// Render with full context control
  ///
  /// For advanced use cases where you need full control over the context.
  Future<Uint8List> renderWithContext({
    required String xml,
    required TemplateContext context,
    RenderOptions options = const RenderOptions(),
  }) async {
    return _renderer.renderFromXml(
      xml: xml,
      context: context,
      options: options,
    );
  }

  /// Register a named template for reuse
  ///
  /// Named templates can be referenced with t-call.
  void registerTemplate(String name, String xml) {
    _templateCache[name] = _parser.parse(xml);
  }

  /// Check if a template is registered
  bool hasTemplate(String name) => _templateCache.containsKey(name);

  /// Get a registered template
  QWebNode? getTemplate(String name) => _templateCache[name];

  /// Clear template cache
  void clearCache() => _templateCache.clear();

  /// Parse XML to AST without rendering
  ///
  /// Useful for pre-parsing templates or debugging.
  QWebNode parse(String xml) => _parser.parse(xml);

  /// Render a pre-parsed AST to PDF
  Future<Uint8List> renderAstToPdf({
    required QWebNode ast,
    required Map<String, dynamic> data,
    CompanyInfo? company,
    RenderOptions options = const RenderOptions(),
  }) async {
    final context = TemplateContext(
      data: data,
      company: company,
    );

    return _renderer.render(
      ast: ast,
      context: context,
      options: options,
    );
  }

  /// Render a cached template by name to PDF
  ///
  /// Uses pre-parsed AST from cache for faster rendering.
  /// The template must be registered first with [registerTemplate].
  ///
  /// Returns null if template is not found in cache.
  Future<Uint8List?> renderCachedTemplate({
    required String templateName,
    required Map<String, dynamic> data,
    CompanyInfo? company,
    RenderOptions options = const RenderOptions(),
  }) async {
    final ast = _templateCache[templateName];
    if (ast == null) return null;

    return renderAstToPdf(
      ast: ast,
      data: data,
      company: company,
      options: options,
    );
  }
}

/// Convenience function for quick PDF generation
///
/// ```dart
/// final pdf = await renderQWebToPdf(
///   xml: '<h1><t t-esc="title"/></h1>',
///   data: {'title': 'My Report'},
/// );
/// ```
Future<Uint8List> renderQWebToPdf({
  required String xml,
  required Map<String, dynamic> data,
  CompanyInfo? company,
  RenderOptions options = const RenderOptions(),
}) {
  final engine = QWebReportEngine();
  return engine.renderToPdf(
    xml: xml,
    data: data,
    company: company,
    options: options,
  );
}
