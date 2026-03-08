/// Report Generation Result
///
/// Contains the output PDF bytes and metadata from report generation.
library;

import 'dart:typed_data';

/// Result of generating a PDF report
class ReportResult {
  /// Generated PDF as bytes
  final Uint8List pdfBytes;

  /// Template key used to generate the report
  final String templateKey;

  /// Number of records included in the report
  final int recordCount;

  /// When the report was generated
  final DateTime generatedAt;

  /// Any warnings encountered during generation
  final List<String> warnings;

  const ReportResult({
    required this.pdfBytes,
    required this.templateKey,
    required this.recordCount,
    required this.generatedAt,
    this.warnings = const [],
  });

  /// Size of the PDF in bytes
  int get sizeInBytes => pdfBytes.length;

  /// Human-readable size (e.g., "125 KB")
  String get formattedSize {
    final bytes = sizeInBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Whether there were any warnings during generation
  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() =>
      'ReportResult($templateKey, $recordCount records, $formattedSize)';
}

/// Exception for report generation errors
class ReportException implements Exception {
  /// Error message
  final String message;

  /// Original error (if any)
  final Object? cause;

  /// Stack trace (if available)
  final StackTrace? stackTrace;

  const ReportException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() {
    if (cause != null) {
      return 'ReportException: $message\nCaused by: $cause';
    }
    return 'ReportException: $message';
  }
}
