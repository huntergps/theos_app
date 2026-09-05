import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

import '../models/render_options.dart';

/// The Unicode-capable font family bundled with `flutter_qweb`.
class PdfFontFamily {
  const PdfFontFamily({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;
}

/// Loads and caches the package-owned PDF fonts.
///
/// The package-qualified asset paths work both when `flutter_qweb` is tested
/// directly and when it is consumed by another Flutter application.
class PdfFontLoader {
  static const _assetRoot = 'packages/flutter_qweb/assets/fonts';

  static Future<PdfFontFamily>? _sharedFonts;

  /// Loads the bundled Noto Sans family exactly once per process.
  Future<PdfFontFamily> load() => _sharedFonts ??= _loadFonts();

  /// Supplies a complete Unicode-capable family when the caller did not.
  ///
  /// A caller-provided base font is reused for missing variants. This avoids
  /// silently mixing a custom typeface with Helvetica, which cannot encode
  /// arbitrary Unicode text.
  Future<RenderOptions> resolve(RenderOptions options) async {
    final base = options.font;
    if (base != null) {
      return options.copyWith(
        boldFont: options.boldFont ?? base,
        italicFont: options.italicFont ?? base,
        boldItalicFont: options.boldItalicFont ?? base,
      );
    }

    final fonts = await load();
    return options.copyWith(
      font: fonts.regular,
      boldFont: options.boldFont ?? fonts.bold,
      italicFont: options.italicFont ?? fonts.italic,
      boldItalicFont: options.boldItalicFont ?? fonts.boldItalic,
    );
  }

  static Future<PdfFontFamily> _loadFonts() async {
    final regular = await _loadAsset('NotoSans-Regular.ttf');
    final bold = await _loadAsset('NotoSans-Bold.ttf');
    final italic = await _loadAsset('NotoSans-Italic.ttf');
    final boldItalic = await _loadAsset('NotoSans-BoldItalic.ttf');

    return PdfFontFamily(
      regular: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
      italic: pw.Font.ttf(italic),
      boldItalic: pw.Font.ttf(boldItalic),
    );
  }

  static Future<ByteData> _loadAsset(String filename) async {
    try {
      final packageAsset = await rootBundle.load('$_assetRoot/$filename');
      if (packageAsset.lengthInBytes > 0) return packageAsset;
    } on FlutterError {
      // When this package is the test application, Flutter stores its own
      // assets without the `packages/flutter_qweb/` prefix.
    }

    return rootBundle.load('assets/fonts/$filename');
  }
}
