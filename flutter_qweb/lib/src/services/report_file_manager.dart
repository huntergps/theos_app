/// Report File Manager - Handles font loading, file I/O, and system integration
/// for PDF report generation.
///
/// Extracted from [ReportService] to separate file handling and font management
/// from template management, line preprocessing, and report generation orchestration.
library;

import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_file_native.dart'
    if (dart.library.js_interop) 'report_file_web.dart' as platform_file;

import '../models/render_options.dart';
import 'pdf_font_loader.dart';

/// Manages font loading, PDF file saving, opening, and printing.
class ReportFileManager {
  final PdfFontLoader _fontLoader = PdfFontLoader();

  /// Cached fonts for PDF generation
  pw.Font? _regularFont;
  pw.Font? _boldFont;
  pw.Font? _italicFont;
  pw.Font? _boldItalicFont;

  /// Get cached regular font.
  pw.Font? get regularFont => _regularFont;

  /// Get cached bold font.
  pw.Font? get boldFont => _boldFont;

  /// Get cached italic font.
  pw.Font? get italicFont => _italicFont;

  /// Get cached bold italic font.
  pw.Font? get boldItalicFont => _boldItalicFont;

  /// Ensure suitable fonts are loaded from LOCAL ASSETS (no internet required).
  /// Concurrent calls share one cached future.
  Future<void> ensurePdfFontsLoaded() async {
    if (_regularFont != null) return;
    final fonts = await _fontLoader.load();
    _regularFont = fonts.regular;
    _boldFont = fonts.bold;
    _italicFont = fonts.italic;
    _boldItalicFont = fonts.boldItalic;
  }

  /// Pre-load fonts at app startup.
  Future<void> preloadFonts() async {
    await ensurePdfFontsLoaded();
  }

  /// Inject cached fonts into render options if not already present.
  RenderOptions injectFonts(RenderOptions options) {
    if (options.font == null && _regularFont != null) {
      return options.copyWith(
        font: _regularFont,
        boldFont: _boldFont,
        italicFont: _italicFont,
        boldItalicFont: _boldItalicFont,
      );
    }
    return options;
  }

  /// Save PDF bytes and open — on web triggers a download, on native opens with system viewer.
  Future<bool> saveAndOpen(Uint8List pdfBytes, String filename) async {
    return platform_file.saveAndOpen(pdfBytes, filename);
  }

  /// Print PDF bytes using system print dialog.
  Future<bool> printPdf(Uint8List pdfBytes, String filename) async {
    final result = await Printing.layoutPdf(
      onLayout: (format) async {
        return pdfBytes;
      },
      name: filename,
    );
    return result;
  }
}
