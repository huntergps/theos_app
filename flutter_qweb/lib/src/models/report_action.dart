/// Report Action Configuration
///
/// Represents an Odoo ir.actions.report record with all its configuration
/// for report generation.
library;

import 'paper_format.dart';

/// Report type enumeration
enum ReportType {
  /// Render as PDF (using QWeb + PDF conversion)
  qwebPdf('qweb-pdf'),

  /// Render as HTML
  qwebHtml('qweb-html'),

  /// Render as plain text
  qwebText('qweb-text');

  final String value;
  const ReportType(this.value);

  static ReportType fromString(String value) {
    return ReportType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportType.qwebPdf,
    );
  }
}

/// Report action matching Odoo's ir.actions.report model
class ReportAction {
  /// Odoo record ID
  final int id;

  /// Report name/title
  final String name;

  /// Model this report operates on (e.g., 'sale.order')
  final String model;

  /// Report type (qweb-pdf, qweb-html, qweb-text)
  final ReportType reportType;

  /// Template XML ID (e.g., 'sale.report_saleorder')
  final String reportName;

  /// Path to report file (optional)
  final String? reportFile;

  /// Paper format configuration
  final PaperFormat? paperFormat;

  /// Paper format ID in Odoo
  final int? paperFormatId;

  /// Dynamic filename expression
  /// e.g., "(object.state == 'draft' and 'Quotation' or 'Order') + ' - ' + object.name"
  final String? printReportName;

  /// Attachment save pattern
  /// e.g., "'Sales Order - ' + object.name"
  final String? attachment;

  /// Whether to reuse existing attachment
  final bool attachmentUse;

  /// Groups that can access this report
  final List<int> groupIds;

  /// Domain filter for when report appears
  final String? domain;

  /// Whether report works on multiple documents
  final bool multi;

  const ReportAction({
    required this.id,
    required this.name,
    required this.model,
    this.reportType = ReportType.qwebPdf,
    required this.reportName,
    this.reportFile,
    this.paperFormat,
    this.paperFormatId,
    this.printReportName,
    this.attachment,
    this.attachmentUse = false,
    this.groupIds = const [],
    this.domain,
    this.multi = false,
  });

  /// Create from Odoo ir.actions.report record
  factory ReportAction.fromOdoo(Map<String, dynamic> data) {
    PaperFormat? paperFormat;
    final paperFormatData = data['paperformat_id'];
    if (paperFormatData is Map<String, dynamic>) {
      paperFormat = PaperFormat.fromOdoo(paperFormatData);
    }

    return ReportAction(
      id: data['id'] as int,
      name: data['name'] as String? ?? '',
      model: data['model'] as String? ?? '',
      reportType:
          ReportType.fromString(data['report_type'] as String? ?? 'qweb-pdf'),
      reportName: data['report_name'] as String? ?? '',
      reportFile: data['report_file'] as String?,
      paperFormat: paperFormat,
      paperFormatId: _extractMany2oneId(data['paperformat_id']),
      printReportName: data['print_report_name'] as String?,
      attachment: data['attachment'] as String?,
      attachmentUse: data['attachment_use'] == true,
      groupIds: _extractIds(data['group_ids']),
      domain: data['domain'] as String?,
      multi: data['multi'] == true,
    );
  }

  /// Extract ID from Many2one field (can be [id, name] or just id)
  static int? _extractMany2oneId(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is List && value.isNotEmpty) return value[0] as int;
    return null;
  }

  /// Extract IDs from Many2many field
  static List<int> _extractIds(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.whereType<int>().toList();
    return [];
  }

  /// Fields to request from Odoo when fetching report actions
  static const List<String> odooFields = [
    'id',
    'name',
    'model',
    'report_type',
    'report_name',
    'report_file',
    'paperformat_id',
    'print_report_name',
    'attachment',
    'attachment_use',
    'group_ids',
    'domain',
    'multi',
  ];

  /// Convert to Odoo format
  Map<String, dynamic> toOdoo() => {
        'id': id,
        'name': name,
        'model': model,
        'report_type': reportType.value,
        'report_name': reportName,
        'report_file': reportFile,
        'paperformat_id': paperFormatId,
        'print_report_name': printReportName,
        'attachment': attachment,
        'attachment_use': attachmentUse,
        'group_ids': groupIds,
        'domain': domain,
        'multi': multi,
      };

  /// Get the effective paper format (use provided or default A4)
  PaperFormat get effectivePaperFormat => paperFormat ?? PaperFormat.a4;

  ReportAction copyWith({
    int? id,
    String? name,
    String? model,
    ReportType? reportType,
    String? reportName,
    String? reportFile,
    PaperFormat? paperFormat,
    int? paperFormatId,
    String? printReportName,
    String? attachment,
    bool? attachmentUse,
    List<int>? groupIds,
    String? domain,
    bool? multi,
  }) {
    return ReportAction(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      reportType: reportType ?? this.reportType,
      reportName: reportName ?? this.reportName,
      reportFile: reportFile ?? this.reportFile,
      paperFormat: paperFormat ?? this.paperFormat,
      paperFormatId: paperFormatId ?? this.paperFormatId,
      printReportName: printReportName ?? this.printReportName,
      attachment: attachment ?? this.attachment,
      attachmentUse: attachmentUse ?? this.attachmentUse,
      groupIds: groupIds ?? this.groupIds,
      domain: domain ?? this.domain,
      multi: multi ?? this.multi,
    );
  }
}
