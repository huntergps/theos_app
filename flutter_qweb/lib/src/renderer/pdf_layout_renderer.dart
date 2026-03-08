import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/render_options.dart';
import '../models/report_locale.dart';

/// Renders PDF layout elements: header, footer, document title, payment terms.
///
/// Extracted from [QWebPdfRenderer] to separate layout concerns from
/// node rendering and value formatting.
class PdfLayoutRenderer {
  /// Build PDF header from company info and render options.
  pw.Widget buildHeader({
    required Map<String, dynamic> context,
    required RenderOptions options,
    required PdfColor Function() getPrimaryColor,
  }) {
    final company = context['company'] as Map<String, dynamic>? ??
        context['res_company'] as Map<String, dynamic>? ??
        {};

    final companyName = company['name']?.toString() ?? '';
    final companyVat = company['vat']?.toString() ?? '';
    final companyAddress = company['street']?.toString() ?? '';
    final companyPhone = company['phone']?.toString() ?? '';
    final companyEmail = company['email']?.toString() ?? '';

    // Try to get header image from various sources
    Uint8List? headerImageBytes;

    // Priority 1: report_header_image from company (base64)
    final headerImage = company['report_header_image'];
    if (headerImage is String && headerImage.isNotEmpty) {
      try {
        // Remove data URI prefix if present
        var base64Str = headerImage;
        if (base64Str.contains(',')) {
          base64Str = base64Str.split(',').last;
        }
        headerImageBytes = base64Decode(base64Str);
      } catch (_) {}
    }

    // Priority 2: logo from company (base64)
    if (headerImageBytes == null) {
      final logo = company['logo'];
      if (logo is String && logo.isNotEmpty) {
        try {
          var base64Str = logo;
          if (base64Str.contains(',')) {
            base64Str = base64Str.split(',').last;
          }
          headerImageBytes = base64Decode(base64Str);
        } catch (_) {}
      }
    }

    // Priority 3: logoBytes from RenderOptions
    headerImageBytes ??= options.logoBytes;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Ecuador layout: When report_header_image exists, show ONLY that image centered
        // (replaces entire default header like in l10n_ec_base template)
        if (headerImageBytes != null && company['report_header_image'] != null)
          pw.Center(
            child: pw.ConstrainedBox(
              constraints: pw.BoxConstraints(
                maxWidth: options.pageFormat.width -
                    options.marginLeft -
                    options.marginRight,
                maxHeight:
                    100, // max-height: 150px in CSS, slightly smaller for PDF
              ),
              child: pw.Image(
                pw.MemoryImage(headerImageBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
          )
        // Standard layout: logo on left, company info on right
        else
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo and company name
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (headerImageBytes != null)
                    pw.ConstrainedBox(
                      constraints: const pw.BoxConstraints(
                        maxWidth: 180,
                        maxHeight: 50,
                      ),
                      child: pw.Image(
                        pw.MemoryImage(headerImageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  if (headerImageBytes == null && companyName.isNotEmpty)
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                ],
              ),
              // Company info
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (companyName.isNotEmpty && headerImageBytes != null)
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  if (companyVat.isNotEmpty)
                    pw.Text('RUC: $companyVat',
                        style:
                            pw.TextStyle(fontSize: options.baseFontSize - 1)),
                  if (companyAddress.isNotEmpty)
                    pw.Text(companyAddress,
                        style:
                            pw.TextStyle(fontSize: options.baseFontSize - 1)),
                  if (companyPhone.isNotEmpty)
                    pw.Text('Tel: $companyPhone',
                        style:
                            pw.TextStyle(fontSize: options.baseFontSize - 1)),
                  if (companyEmail.isNotEmpty)
                    pw.Text(companyEmail,
                        style:
                            pw.TextStyle(fontSize: options.baseFontSize - 1)),
                ],
              ),
            ],
          ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  /// Build PDF footer with company info and page number.
  pw.Widget buildFooter({
    required pw.Context ctx,
    required Map<String, dynamic> context,
    required RenderOptions options,
    ReportLocale locale = const ReportLocale(),
  }) {
    // Extract company information from context
    final company = context['company'] as Map<String, dynamic>? ??
        context['res_company'] as Map<String, dynamic>? ??
        {};

    final companyEmail = company['email']?.toString() ?? '';
    final companyWebsite = company['website']?.toString() ?? '';
    final companyVat = company['vat']?.toString() ?? ''; // RUC

    // Build footer info parts (only include non-empty values)
    final footerParts = <String>[];
    if (companyEmail.isNotEmpty) footerParts.add(companyEmail);
    if (companyWebsite.isNotEmpty) footerParts.add(companyWebsite);
    if (companyVat.isNotEmpty) footerParts.add(companyVat);

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      padding: const pw.EdgeInsets.only(
        top: 5,
        bottom: 10, // Add bottom padding to create separation from page margin
      ),
      margin: const pw.EdgeInsets.only(
        bottom: 15, // Add bottom margin for more separation from page edge
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Company info (email, website, RUC)
          pw.Expanded(
            child: pw.Text(
              footerParts.join(' '),
              style: pw.TextStyle(
                fontSize: options.baseFontSize - 2,
                color: PdfColors.grey600,
              ),
            ),
          ),
          // Page number
          pw.Text(
            '${locale.labelPage} ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
              fontSize: options.baseFontSize - 2,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build document title section (e.g., "Quotation S00029").
  pw.Widget? buildDocumentTitle({
    required Map<String, dynamic> context,
    required PdfColor Function() getPrimaryColor,
    ReportLocale locale = const ReportLocale(),
  }) {
    // Get document info from context
    final doc = context['doc'] as Map<String, dynamic>?;
    if (doc == null) return null;

    // Get document name/reference
    final docName = doc['name']?.toString() ?? '';
    if (docName.isEmpty) return null;

    // Determine document type based on state
    final state = doc['state']?.toString() ?? 'draft';
    String documentType;
    if (state == 'draft' || state == 'sent') {
      documentType = locale.labelQuotation;
    } else if (state == 'sale') {
      documentType = locale.labelSaleOrder;
    } else if (state == 'cancel') {
      documentType = locale.labelQuotationCancelled;
    } else {
      documentType = locale.labelQuotation;
    }

    return pw.Container(
      margin:
          const pw.EdgeInsets.only(bottom: 8), // Reduced spacing below title
      child: pw.Text(
        '$documentType $docName',
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: getPrimaryColor(),
        ),
      ),
    );
  }

  /// Build payment terms section if available in context.
  pw.Widget? buildPaymentTermsSection({
    required Map<String, dynamic> context,
    required RenderOptions options,
    ReportLocale locale = const ReportLocale(),
  }) {
    // Try to get payment terms from various context paths
    String? paymentTermName;

    // Try from 'doc' context
    final doc = context['doc'];
    if (doc is Map) {
      final paymentTermId = doc['payment_term_id'];
      if (paymentTermId is Map && paymentTermId['name'] != null) {
        paymentTermName = paymentTermId['name'].toString();
      } else if (paymentTermId is String && paymentTermId.isNotEmpty) {
        paymentTermName = paymentTermId;
      }
    }

    // Try from 'docs' context
    if (paymentTermName == null) {
      final docs = context['docs'];
      if (docs is List && docs.isNotEmpty && docs.first is Map) {
        final firstDoc = docs.first as Map;
        final paymentTermId = firstDoc['payment_term_id'];
        if (paymentTermId is Map && paymentTermId['name'] != null) {
          paymentTermName = paymentTermId['name'].toString();
        } else if (paymentTermId is String && paymentTermId.isNotEmpty) {
          paymentTermName = paymentTermId;
        }
      }
    }

    // If no payment terms found, return null
    if (paymentTermName == null || paymentTermName.isEmpty) {
      return null;
    }

    // Build the payment terms widget
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      child: pw.Text(
        '${locale.labelPaymentTerms} $paymentTermName',
        style: pw.TextStyle(
          fontSize: options.baseFontSize,
          color: PdfColors
              .grey700, // Dark grey to match Odoo style (same as info section and product lines)
        ),
      ),
    );
  }
}
