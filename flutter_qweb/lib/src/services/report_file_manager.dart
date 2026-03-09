/// Report File Manager - Handles font loading, file I/O, and system integration
/// for PDF report generation.
///
/// Extracted from [ReportService] to separate file handling and font management
/// from template management, line preprocessing, and report generation orchestration.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_file_native.dart'
    if (dart.library.html) 'report_file_web.dart'
    as platform_file;

import '../models/render_options.dart';

/// Manages font loading, PDF file saving, opening, and printing.
class ReportFileManager {
  /// Cached fonts for PDF generation
  pw.Font? _regularFont;
  pw.Font? _boldFont;
  pw.Font? _italicFont;
  pw.Font? _boldItalicFont;

  /// Whether fonts are currently being loaded
  bool _fontsLoading = false;

  /// Get cached regular font.
  pw.Font? get regularFont => _regularFont;

  /// Get cached bold font.
  pw.Font? get boldFont => _boldFont;

  /// Get cached italic font.
  pw.Font? get italicFont => _italicFont;

  /// Get cached bold italic font.
  pw.Font? get boldItalicFont => _boldItalicFont;

  /// Load a font from assets.
  Future<pw.Font> _loadFontFromAssets(String assetPath) async {
    final fontData = await rootBundle.load(assetPath);
    return pw.Font.ttf(fontData);
  }

  /// Ensure suitable fonts are loaded from LOCAL ASSETS (no internet required).
  /// Loads all fonts in PARALLEL for faster startup.
  Future<void> ensurePdfFontsLoaded() async {
    if (_regularFont != null) return;
    if (_fontsLoading) {
      // Wait for ongoing font loading to complete
      while (_fontsLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    _fontsLoading = true;

    try {
      final results = await Future.wait([
        _loadFontFromAssets('assets/fonts/NotoSans-Regular.ttf'),
        _loadFontFromAssets('assets/fonts/NotoSans-Bold.ttf'),
        _loadFontFromAssets('assets/fonts/NotoSans-Italic.ttf'),
        _loadFontFromAssets('assets/fonts/NotoSans-BoldItalic.ttf'),
      ]);

      _regularFont = results[0];
      _boldFont = results[1];
      _italicFont = results[2];
      _boldItalicFont = results[3];
    } catch (e) {
      // If fonts fail to load, fall back to default (Helvetica)
    } finally {
      _fontsLoading = false;
    }
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
