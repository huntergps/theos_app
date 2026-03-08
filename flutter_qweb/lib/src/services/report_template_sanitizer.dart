/// Interface for custom template sanitization.
///
/// Implement this to add locale-specific or model-specific template
/// transformations (e.g., Ecuador EDI banners, country-specific fields).
///
/// ```dart
/// class EcuadorEdiSanitizer implements ReportTemplateSanitizer {
///   @override
///   String sanitize(String xmlContent, String templateKey) {
///     if (templateKey == 'sale.report_saleorder_document') {
///       // Inject offline invoice banner
///       xmlContent = xmlContent.replaceFirst(
///         '<div class="page">',
///         '<div class="page"><div>PENDING SRI AUTHORIZATION</div>',
///       );
///     }
///     return xmlContent;
///   }
/// }
/// ```
library;

/// Contract for template sanitizers that run during template loading.
abstract class ReportTemplateSanitizer {
  /// Transform template XML content before it is cached.
  ///
  /// [xmlContent] — the raw XML from Odoo.
  /// [templateKey] — the template identifier (e.g., 'sale.report_saleorder_document').
  ///
  /// Return the (possibly modified) XML string.
  String sanitize(String xmlContent, String templateKey);
}
