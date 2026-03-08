import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'paper_format.dart';
import 'report_locale.dart';

/// Options for PDF rendering
///
/// Configures page format, margins, DPI, and other rendering parameters.
/// Compatible with Odoo's report.paperformat settings.
class RenderOptions {
  /// Page format (default: A4)
  final PdfPageFormat pageFormat;

  /// Page margins in points
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  /// Company logo bytes (optional)
  final Uint8List? logoBytes;

  /// Whether to include header
  final bool includeHeader;

  /// Whether to include footer with page numbers
  final bool includeFooter;

  /// Custom header template XML (if null, uses default)
  final String? headerTemplate;

  /// Custom footer template XML (if null, uses default)
  final String? footerTemplate;

  /// Header spacing in points (space between header and content)
  final double headerSpacing;

  /// Display header separator line
  final bool headerLine;

  /// Base font size in points
  final double baseFontSize;

  /// Output DPI (affects image quality, default 90 like Odoo)
  final int dpi;

  /// Disable smart shrinking (useful for exact sizing)
  final bool disableShrinking;

  /// Document title (for PDF metadata)
  final String? title;

  /// Document author (for PDF metadata)
  final String? author;

  /// Document subject (for PDF metadata)
  final String? subject;

  /// Document keywords (for PDF metadata)
  final List<String>? keywords;

  /// Document creator (for PDF metadata)
  final String? creator;

  /// Page orientation
  final PageOrientation orientation;

  /// Locale for number/date formatting (e.g., 'es_EC', 'en_US')
  final String locale;

  /// Currency symbol for monetary formatting
  final String currencySymbol;

  /// Date format pattern
  final String dateFormat;

  /// Regular font (defaults to Helvetica if null)
  final pw.Font? font;

  /// Bold font (defaults to Helvetica-Bold if null)
  final pw.Font? boldFont;

  /// Italic font (defaults to Helvetica-Oblique if null)
  final pw.Font? italicFont;

  /// Bold Italic font (defaults to Helvetica-BoldOblique if null)
  final pw.Font? boldItalicFont;

  /// Report locale for number/currency formatting and translatable labels.
  ///
  /// When null, falls back to the generic locale (US-style formatting).
  /// Use [ReportLocale.ecuador()], [ReportLocale.europe()], or custom for other locales.
  final ReportLocale? reportLocale;

  /// Resolved locale: uses [reportLocale] if set, otherwise builds from
  /// [locale]/[currencySymbol]/[dateFormat] fields for backward compatibility.
  ReportLocale get effectiveLocale => reportLocale ?? const ReportLocale();

  const RenderOptions({
    this.pageFormat = PdfPageFormat.a4,
    this.marginTop = 40,
    this.marginBottom = 40,
    this.marginLeft = 40,
    this.marginRight = 40,
    this.logoBytes,
    this.includeHeader = true,
    this.includeFooter = true,
    this.headerTemplate,
    this.footerTemplate,
    this.headerSpacing = 35,
    this.headerLine = false,
    this.baseFontSize = 9,
    this.dpi = 140,
    this.disableShrinking = false,
    this.title,
    this.author,
    this.subject,
    this.keywords,
    this.creator,
    this.orientation = PageOrientation.portrait,
    this.locale = 'en_US',
    this.currencySymbol = r'$',
    this.dateFormat = 'MM/dd/yyyy',
    this.font,
    this.boldFont,
    this.italicFont,
    this.boldItalicFont,
    this.reportLocale,
  });

  /// Create options from Odoo PaperFormat
  factory RenderOptions.fromPaperFormat(
    PaperFormat paperFormat, {
    Uint8List? logoBytes,
    bool includeHeader = true,
    bool includeFooter = true,
    String? headerTemplate,
    String? footerTemplate,
    String? title,
    String? author,
    String locale = 'en_US',
    String currencySymbol = r'$',
    String dateFormat = 'MM/dd/yyyy',
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
    ReportLocale? reportLocale,
  }) {
    return RenderOptions(
      pageFormat: paperFormat.toPdfPageFormat(),
      marginTop: paperFormat.marginTop * 72.0 / 25.4, // mm to points
      marginBottom: paperFormat.marginBottom * 72.0 / 25.4,
      marginLeft: paperFormat.marginLeft * 72.0 / 25.4,
      marginRight: paperFormat.marginRight * 72.0 / 25.4,
      logoBytes: logoBytes,
      includeHeader: includeHeader,
      includeFooter: includeFooter,
      headerTemplate: headerTemplate,
      footerTemplate: footerTemplate,
      headerSpacing: paperFormat.headerSpacing * 72.0 / 25.4,
      headerLine: paperFormat.headerLine,
      dpi: paperFormat.dpi,
      disableShrinking: paperFormat.disableShrinking,
      title: title,
      author: author,
      orientation: paperFormat.orientation,
      locale: locale,
      currencySymbol: currencySymbol,
      dateFormat: dateFormat,
      font: font,
      boldFont: boldFont,
      italicFont: italicFont,
      boldItalicFont: boldItalicFont,
      reportLocale: reportLocale,
    );
  }

  /// Create options for A4 portrait
  factory RenderOptions.a4({
    Uint8List? logoBytes,
    String? title,
    String? author,
    pw.Font? font,
  }) =>
      RenderOptions(
        pageFormat: PdfPageFormat.a4,
        logoBytes: logoBytes,
        title: title,
        author: author,
        font: font,
      );

  /// Create options for A4 landscape
  factory RenderOptions.a4Landscape({
    Uint8List? logoBytes,
    String? title,
    String? author,
    pw.Font? font,
  }) =>
      RenderOptions(
        pageFormat: const PdfPageFormat(
          29.7 * PdfPageFormat.cm,
          21.0 * PdfPageFormat.cm,
        ),
        orientation: PageOrientation.landscape,
        logoBytes: logoBytes,
        title: title,
        author: author,
        font: font,
      );

  /// Create options for Letter size
  factory RenderOptions.letter({
    Uint8List? logoBytes,
    String? title,
    String? author,
    pw.Font? font,
  }) =>
      RenderOptions(
        pageFormat: PdfPageFormat.letter,
        logoBytes: logoBytes,
        title: title,
        author: author,
        font: font,
      );

  /// Create options for Legal size
  factory RenderOptions.legal({
    Uint8List? logoBytes,
    String? title,
    String? author,
    pw.Font? font,
  }) =>
      RenderOptions(
        pageFormat: PdfPageFormat.legal,
        logoBytes: logoBytes,
        title: title,
        author: author,
        font: font,
      );

  /// Create options for thermal receipt (80mm width)
  factory RenderOptions.receipt80mm({
    Uint8List? logoBytes,
    pw.Font? font,
  }) =>
      RenderOptions(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
        ),
        marginTop: 10,
        marginBottom: 10,
        marginLeft: 5,
        marginRight: 5,
        includeHeader: false,
        includeFooter: false,
        baseFontSize: 8,
        dpi: 203, // Typical thermal printer DPI
        logoBytes: logoBytes,
        font: font,
      );

  /// Create options for thermal receipt (58mm width)
  factory RenderOptions.receipt58mm({
    Uint8List? logoBytes,
    pw.Font? font,
  }) =>
      RenderOptions(
        pageFormat: PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
        ),
        marginTop: 5,
        marginBottom: 5,
        marginLeft: 3,
        marginRight: 3,
        includeHeader: false,
        includeFooter: false,
        baseFontSize: 7,
        dpi: 203, // Typical thermal printer DPI
        logoBytes: logoBytes,
        font: font,
      );

  /// Get effective page width (considering orientation)
  double get effectivePageWidth {
    if (orientation == PageOrientation.landscape) {
      return pageFormat.height;
    }
    return pageFormat.width;
  }

  /// Get effective page height (considering orientation)
  double get effectivePageHeight {
    if (orientation == PageOrientation.landscape) {
      return pageFormat.width;
    }
    return pageFormat.height;
  }

  /// Get content area width (page width minus margins)
  double get contentWidth {
    return effectivePageWidth - marginLeft - marginRight;
  }

  /// Get content area height (page height minus margins and header/footer)
  double get contentHeight {
    var height = effectivePageHeight - marginTop - marginBottom;
    if (includeHeader) height -= headerSpacing;
    if (includeFooter) height -= 20; // Approximate footer height
    return height;
  }

  /// Copy with new values
  RenderOptions copyWith({
    PdfPageFormat? pageFormat,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    Uint8List? logoBytes,
    bool? includeHeader,
    bool? includeFooter,
    String? headerTemplate,
    String? footerTemplate,
    double? headerSpacing,
    bool? headerLine,
    double? baseFontSize,
    int? dpi,
    bool? disableShrinking,
    String? title,
    String? author,
    String? subject,
    List<String>? keywords,
    String? creator,
    PageOrientation? orientation,
    String? locale,
    String? currencySymbol,
    String? dateFormat,
    pw.Font? font,
    pw.Font? boldFont,
    pw.Font? italicFont,
    pw.Font? boldItalicFont,
    ReportLocale? reportLocale,
  }) {
    return RenderOptions(
      pageFormat: pageFormat ?? this.pageFormat,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      logoBytes: logoBytes ?? this.logoBytes,
      includeHeader: includeHeader ?? this.includeHeader,
      includeFooter: includeFooter ?? this.includeFooter,
      headerTemplate: headerTemplate ?? this.headerTemplate,
      footerTemplate: footerTemplate ?? this.footerTemplate,
      headerSpacing: headerSpacing ?? this.headerSpacing,
      headerLine: headerLine ?? this.headerLine,
      baseFontSize: baseFontSize ?? this.baseFontSize,
      dpi: dpi ?? this.dpi,
      disableShrinking: disableShrinking ?? this.disableShrinking,
      title: title ?? this.title,
      author: author ?? this.author,
      subject: subject ?? this.subject,
      keywords: keywords ?? this.keywords,
      creator: creator ?? this.creator,
      orientation: orientation ?? this.orientation,
      locale: locale ?? this.locale,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      dateFormat: dateFormat ?? this.dateFormat,
      font: font ?? this.font,
      boldFont: boldFont ?? this.boldFont,
      italicFont: italicFont ?? this.italicFont,
      boldItalicFont: boldItalicFont ?? this.boldItalicFont,
      reportLocale: reportLocale ?? this.reportLocale,
    );
  }
}
