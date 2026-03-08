/// Paper Format Configuration
///
/// Defines paper sizes and formatting options for PDF generation,
/// matching Odoo's report.paperformat model.
library;

import 'package:pdf/pdf.dart';

/// Standard paper sizes with dimensions in millimeters
/// Based on Odoo's report_paperformat.py PAPER_SIZES
const Map<String, PaperSize> paperSizes = {
  'A0': PaperSize(
      key: 'A0', width: 841.0, height: 1189.0, description: 'A0 841 x 1189 mm'),
  'A1': PaperSize(
      key: 'A1', width: 594.0, height: 841.0, description: 'A1 594 x 841 mm'),
  'A2': PaperSize(
      key: 'A2', width: 420.0, height: 594.0, description: 'A2 420 x 594 mm'),
  'A3': PaperSize(
      key: 'A3', width: 297.0, height: 420.0, description: 'A3 297 x 420 mm'),
  'A4': PaperSize(
      key: 'A4', width: 210.0, height: 297.0, description: 'A4 210 x 297 mm'),
  'A5': PaperSize(
      key: 'A5', width: 148.0, height: 210.0, description: 'A5 148 x 210 mm'),
  'A6': PaperSize(
      key: 'A6', width: 105.0, height: 148.0, description: 'A6 105 x 148 mm'),
  'A7': PaperSize(
      key: 'A7', width: 74.0, height: 105.0, description: 'A7 74 x 105 mm'),
  'A8': PaperSize(
      key: 'A8', width: 52.0, height: 74.0, description: 'A8 52 x 74 mm'),
  'A9': PaperSize(
      key: 'A9', width: 37.0, height: 52.0, description: 'A9 37 x 52 mm'),
  'B0': PaperSize(
      key: 'B0',
      width: 1000.0,
      height: 1414.0,
      description: 'B0 1000 x 1414 mm'),
  'B1': PaperSize(
      key: 'B1', width: 707.0, height: 1000.0, description: 'B1 707 x 1000 mm'),
  'B2': PaperSize(
      key: 'B2', width: 500.0, height: 707.0, description: 'B2 500 x 707 mm'),
  'B3': PaperSize(
      key: 'B3', width: 353.0, height: 500.0, description: 'B3 353 x 500 mm'),
  'B4': PaperSize(
      key: 'B4', width: 250.0, height: 353.0, description: 'B4 250 x 353 mm'),
  'B5': PaperSize(
      key: 'B5', width: 176.0, height: 250.0, description: 'B5 176 x 250 mm'),
  'B6': PaperSize(
      key: 'B6', width: 125.0, height: 176.0, description: 'B6 125 x 176 mm'),
  'B7': PaperSize(
      key: 'B7', width: 88.0, height: 125.0, description: 'B7 88 x 125 mm'),
  'B8': PaperSize(
      key: 'B8', width: 62.0, height: 88.0, description: 'B8 62 x 88 mm'),
  'B9': PaperSize(
      key: 'B9', width: 33.0, height: 62.0, description: 'B9 33 x 62 mm'),
  'B10': PaperSize(
      key: 'B10', width: 31.0, height: 44.0, description: 'B10 31 x 44 mm'),
  'C5E': PaperSize(
      key: 'C5E', width: 163.0, height: 229.0, description: 'C5E 163 x 229 mm'),
  'Comm10E': PaperSize(
      key: 'Comm10E',
      width: 105.0,
      height: 241.0,
      description: 'Comm10E 105 x 241 mm'),
  'DLE': PaperSize(
      key: 'DLE', width: 110.0, height: 220.0, description: 'DLE 110 x 220 mm'),
  'Executive': PaperSize(
      key: 'Executive',
      width: 190.5,
      height: 254.0,
      description: 'Executive 190.5 x 254 mm'),
  'Folio': PaperSize(
      key: 'Folio',
      width: 210.0,
      height: 330.0,
      description: 'Folio 210 x 330 mm'),
  'Ledger': PaperSize(
      key: 'Ledger',
      width: 431.8,
      height: 279.4,
      description: 'Ledger 431.8 x 279.4 mm'),
  'Legal': PaperSize(
      key: 'Legal',
      width: 215.9,
      height: 355.6,
      description: 'Legal 215.9 x 355.6 mm'),
  'Letter': PaperSize(
      key: 'Letter',
      width: 215.9,
      height: 279.4,
      description: 'Letter 215.9 x 279.4 mm'),
  'Tabloid': PaperSize(
      key: 'Tabloid',
      width: 279.4,
      height: 431.8,
      description: 'Tabloid 279.4 x 431.8 mm'),
  // Receipt sizes (common for POS)
  'Receipt80mm': PaperSize(
      key: 'Receipt80mm',
      width: 80.0,
      height: 297.0,
      description: 'Receipt 80mm'),
  'Receipt58mm': PaperSize(
      key: 'Receipt58mm',
      width: 58.0,
      height: 297.0,
      description: 'Receipt 58mm'),
};

/// Paper size definition
class PaperSize {
  final String key;
  final double width;
  final double height;
  final String description;

  const PaperSize({
    required this.key,
    required this.width,
    required this.height,
    required this.description,
  });

  /// Convert to PdfPageFormat (width/height in points, 1mm = 2.83465 points)
  PdfPageFormat toPdfPageFormat({bool landscape = false}) {
    const mmToPoints = 72.0 / 25.4; // 1 inch = 25.4mm, 1 inch = 72 points
    final w = width * mmToPoints;
    final h = height * mmToPoints;
    return landscape ? PdfPageFormat(h, w) : PdfPageFormat(w, h);
  }
}

/// Page orientation
enum PageOrientation {
  portrait,
  landscape,
}

/// Paper format configuration matching Odoo's report.paperformat
class PaperFormat {
  /// Format name
  final String name;

  /// Paper size key (A4, Letter, custom, etc.)
  final String format;

  /// Custom page width in mm (used when format is 'custom')
  final double? pageWidth;

  /// Custom page height in mm (used when format is 'custom')
  final double? pageHeight;

  /// Top margin in mm
  final double marginTop;

  /// Bottom margin in mm
  final double marginBottom;

  /// Left margin in mm
  final double marginLeft;

  /// Right margin in mm
  final double marginRight;

  /// Page orientation
  final PageOrientation orientation;

  /// Display header separator line
  final bool headerLine;

  /// Header spacing in mm
  final double headerSpacing;

  /// Disable smart shrinking (wkhtmltopdf option)
  final bool disableShrinking;

  /// Output DPI (default 90 like Odoo)
  final int dpi;

  /// Use CSS-based margins
  final bool cssMargins;

  const PaperFormat({
    this.name = 'Default',
    this.format = 'A4',
    this.pageWidth,
    this.pageHeight,
    this.marginTop = 40.0,
    this.marginBottom = 20.0,
    this.marginLeft = 7.0,
    this.marginRight = 7.0,
    this.orientation = PageOrientation.portrait,
    this.headerLine = false,
    this.headerSpacing = 35.0,
    this.disableShrinking = false,
    this.dpi = 90,
    this.cssMargins = false,
  });

  /// Create from Odoo report.paperformat record
  factory PaperFormat.fromOdoo(Map<String, dynamic> data) {
    return PaperFormat(
      name: data['name'] as String? ?? 'Default',
      format: data['format'] as String? ?? 'A4',
      pageWidth: (data['page_width'] as num?)?.toDouble(),
      pageHeight: (data['page_height'] as num?)?.toDouble(),
      marginTop: (data['margin_top'] as num?)?.toDouble() ?? 40.0,
      marginBottom: (data['margin_bottom'] as num?)?.toDouble() ?? 20.0,
      marginLeft: (data['margin_left'] as num?)?.toDouble() ?? 7.0,
      marginRight: (data['margin_right'] as num?)?.toDouble() ?? 7.0,
      orientation: data['orientation'] == 'Landscape'
          ? PageOrientation.landscape
          : PageOrientation.portrait,
      headerLine: data['header_line'] == true,
      headerSpacing: (data['header_spacing'] as num?)?.toDouble() ?? 35.0,
      disableShrinking: data['disable_shrinking'] == true,
      dpi: (data['dpi'] as num?)?.toInt() ?? 90,
      cssMargins: data['css_margins'] == true,
    );
  }

  /// Standard A4 format
  static const a4 = PaperFormat(format: 'A4');

  /// Standard Letter format
  static const letter = PaperFormat(format: 'Letter');

  /// Standard Legal format
  static const legal = PaperFormat(format: 'Legal');

  /// Receipt 80mm format (for POS)
  static const receipt80mm = PaperFormat(
    format: 'Receipt80mm',
    marginTop: 5.0,
    marginBottom: 5.0,
    marginLeft: 5.0,
    marginRight: 5.0,
  );

  /// Receipt 58mm format (for POS)
  static const receipt58mm = PaperFormat(
    format: 'Receipt58mm',
    marginTop: 5.0,
    marginBottom: 5.0,
    marginLeft: 3.0,
    marginRight: 3.0,
  );

  /// Get the actual page dimensions
  PaperSize get paperSize {
    if (format == 'custom' && pageWidth != null && pageHeight != null) {
      return PaperSize(
        key: 'custom',
        width: pageWidth!,
        height: pageHeight!,
        description: 'Custom ${pageWidth}x$pageHeight mm',
      );
    }
    return paperSizes[format] ?? paperSizes['A4']!;
  }

  /// Get effective print dimensions considering orientation
  ({double width, double height}) get printPageSize {
    final size = paperSize;
    if (orientation == PageOrientation.landscape) {
      return (width: size.height, height: size.width);
    }
    return (width: size.width, height: size.height);
  }

  /// Convert to PdfPageFormat
  PdfPageFormat toPdfPageFormat() {
    final size = printPageSize;
    const mmToPoints = 72.0 / 25.4;
    return PdfPageFormat(
      size.width * mmToPoints,
      size.height * mmToPoints,
      marginTop: marginTop * mmToPoints,
      marginBottom: marginBottom * mmToPoints,
      marginLeft: marginLeft * mmToPoints,
      marginRight: marginRight * mmToPoints,
    );
  }

  /// Convert to Odoo format
  Map<String, dynamic> toOdoo() => {
        'name': name,
        'format': format,
        'page_width': pageWidth,
        'page_height': pageHeight,
        'margin_top': marginTop,
        'margin_bottom': marginBottom,
        'margin_left': marginLeft,
        'margin_right': marginRight,
        'orientation':
            orientation == PageOrientation.landscape ? 'Landscape' : 'Portrait',
        'header_line': headerLine,
        'header_spacing': headerSpacing,
        'disable_shrinking': disableShrinking,
        'dpi': dpi,
        'css_margins': cssMargins,
      };

  PaperFormat copyWith({
    String? name,
    String? format,
    double? pageWidth,
    double? pageHeight,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    PageOrientation? orientation,
    bool? headerLine,
    double? headerSpacing,
    bool? disableShrinking,
    int? dpi,
    bool? cssMargins,
  }) {
    return PaperFormat(
      name: name ?? this.name,
      format: format ?? this.format,
      pageWidth: pageWidth ?? this.pageWidth,
      pageHeight: pageHeight ?? this.pageHeight,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      orientation: orientation ?? this.orientation,
      headerLine: headerLine ?? this.headerLine,
      headerSpacing: headerSpacing ?? this.headerSpacing,
      disableShrinking: disableShrinking ?? this.disableShrinking,
      dpi: dpi ?? this.dpi,
      cssMargins: cssMargins ?? this.cssMargins,
    );
  }
}
