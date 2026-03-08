import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/reports/services/report_service.dart';

part 'report_provider.g.dart';

/// Provider for the ReportService singleton
///
/// The ReportService is a singleton that caches QWeb templates
/// and provides methods to generate PDFs for any Odoo model.
///
/// ## Usage
/// ```dart
/// final reportService = ref.read(reportServiceProvider);
///
/// // Register template (usually done once during sync)
/// reportService.registerTemplate(
///   'sale.report_saleorder_document',
///   xmlFromOdoo,
/// );
///
/// // Generate PDF
/// final pdfBytes = await reportService.generateReport(
///   templateName: 'sale.report_saleorder_document',
///   records: [saleOrder.toReportMap()],
///   company: companyInfo,
///   user: userInfo,
/// );
/// ```
@Riverpod(keepAlive: true)
ReportService reportService(Ref ref) {
  return ReportService();
}
