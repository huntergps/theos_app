import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_qweb/flutter_qweb.dart'
    show RenderOptions, ReportException, ReportService;
import 'package:odoo_sdk/odoo_sdk.dart' show logger;
import 'package:theos_pos_core/theos_pos_core.dart'
    show AccountMove, accountMoveManager, accountMoveLineManager, clientManager;

import '../../reports/providers/qweb_template_repository_provider.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/providers/report_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../shared/utils/formatting_utils.dart';
import '../../sales/screens/sale_order_form/pdf_preview_native.dart'
    if (dart.library.js_interop) '../../sales/screens/sale_order_form/pdf_preview_web.dart'
    as platform_pdf;

/// Reactive stream of invoices for a sale order.
///
/// Uses `accountMoveManager.watchLocalSearch()` so UI auto-updates
/// when invoices are created, modified, or synced locally.
///
/// Note: This provides base AccountMove records from the local DB.
/// Lines and partner data enrichment happens at print time (in _printInvoice).
final invoicesForOrderProvider = StreamProvider.family
    .autoDispose<List<AccountMove>, int>((ref, orderId) {
      return accountMoveManager.watchLocalSearch(
        domain: [
          ['sale_order_id', '=', orderId],
        ],
      );
    });

/// Widget para mostrar la sección de facturas en una orden de venta
///
/// Muestra las facturas asociadas a la orden con opción de imprimir.
/// Sigue patrón offline-first: los datos se cargan de la DB local primero.
class InvoiceSection extends ConsumerStatefulWidget {
  final int orderId;
  final String? invoiceIdsJson;
  final VoidCallback? onPrintPressed;

  const InvoiceSection({
    super.key,
    required this.orderId,
    this.invoiceIdsJson,
    this.onPrintPressed,
  });

  @override
  ConsumerState<InvoiceSection> createState() => _InvoiceSectionState();
}

class _InvoiceSectionState extends ConsumerState<InvoiceSection> {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final spacing = ref.watch(themedSpacingProvider);
    final invoicesAsync = ref.watch(invoicesForOrderProvider(widget.orderId));

    return Card(
      child: Padding(
        padding: spacing.all.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  FluentIcons.document_set,
                  size: 18,
                  color: theme.accentColor,
                ),
                spacing.horizontal.sm,
                Text('Facturas', style: theme.typography.bodyStrong),
              ],
            ),
            spacing.vertical.ms,

            // Content — stream auto-updates when local DB changes
            invoicesAsync.when(
              data: (invoices) {
                if (invoices.isEmpty) {
                  return Text(
                    'Sin facturas asociadas',
                    style: theme.typography.body?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: invoices.map((invoice) {
                    return _InvoiceRow(invoice: invoice);
                  }).toList(),
                );
              },
              loading: () => const Center(child: ProgressRing()),
              error: (error, stack) {
                return Text(
                  'Error al cargar facturas',
                  style: theme.typography.body?.copyWith(color: Colors.red),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Row widget for displaying a single invoice
class _InvoiceRow extends ConsumerStatefulWidget {
  final AccountMove invoice;

  const _InvoiceRow({required this.invoice});

  @override
  ConsumerState<_InvoiceRow> createState() => _InvoiceRowState();
}

class _InvoiceRowState extends ConsumerState<_InvoiceRow> {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final spacing = ref.watch(themedSpacingProvider);
    final invoice = widget.invoice;

    // Status badge color
    Color statusColor;
    switch (invoice.state) {
      case 'posted':
        statusColor = Colors.green;
        break;
      case 'draft':
        statusColor = Colors.orange;
        break;
      case 'cancel':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    // Payment status badge color
    Color paymentColor;
    switch (invoice.paymentState) {
      case 'paid':
        paymentColor = Colors.green;
        break;
      case 'partial':
        paymentColor = Colors.orange;
        break;
      case 'not_paid':
        paymentColor = Colors.red;
        break;
      default:
        paymentColor = Colors.grey;
    }

    return Padding(
      padding: spacing.only.bottom(spacing.sm),
      child: Row(
        children: [
          // Invoice name (clickable to show details)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.name, style: theme.typography.bodyStrong),
                spacing.vertical.xs,
                Row(
                  children: [
                    // State badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        invoice.stateDisplay,
                        style: theme.typography.caption?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    spacing.horizontal.sm,
                    // Payment state badge
                    if (invoice.paymentState != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: paymentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          invoice.paymentStateDisplay,
                          style: theme.typography.caption?.copyWith(
                            color: paymentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                spacing.vertical.xs,
                if (invoice.l10nEcAuthorizationNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FluentIcons.certificate,
                          size: 10,
                          color: theme.inactiveColor,
                        ),
                        spacing.horizontal.xs,
                        SelectableText(
                          invoice.l10nEcAuthorizationNumber!,
                          style: theme.typography.caption?.copyWith(
                            color: theme.inactiveColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                        spacing.horizontal.xs,
                        Tooltip(
                          message: 'Copiar autorización',
                          child: IconButton(
                            icon: Icon(
                              FluentIcons.copy,
                              size: 10,
                              color: theme.accentColor,
                            ),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: invoice.l10nEcAuthorizationNumber!,
                                ),
                              );
                              if (context.mounted) {
                                CopyableInfoBar.showSuccess(
                                  context,
                                  title: 'Copiado',
                                  message: 'Número de autorización copiado al portapapeles',
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Amount
          Text(
            invoice.amountTotal.toCurrency(),
            style: theme.typography.bodyStrong,
          ),

          spacing.horizontal.sm,

          // SRI Authorization indicator
          if (invoice.isSriAuthorized)
            Tooltip(
              message: 'Autorizada SRI',
              child: Icon(
                FluentIcons.certificate,
                size: 16,
                color: Colors.green,
              ),
            )
          else
            Tooltip(
              message: 'Pendiente de autorización SRI',
              child: Icon(FluentIcons.warning, size: 16, color: Colors.orange),
            ),

          spacing.horizontal.sm,
          Tooltip(
            message: 'Compartir factura',
            child: IconButton(
              icon: const Icon(FluentIcons.share, size: 14),
              onPressed: () => _shareInvoice(context, ref, invoice),
            ),
          ),
          spacing.horizontal.xs,
          // Print button - estandarizado con form_header.dart
          Button(
            onPressed: () => _printInvoice(context, ref, invoice),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.print, size: 14),
                spacing.horizontal.xs,
                const Text('Imprimir'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice(
    BuildContext context,
    WidgetRef ref,
    AccountMove invoice,
  ) async {
    try {
      final report = await _prepareInvoiceReport(ref, invoice);
      final printed = await report.service.generateAndPrint(
        templateName: report.templateName,
        records: [report.record],
        filename: report.filename,
        company: report.company,
        user: report.user,
        options: report.options,
      );
      if (!printed && context.mounted) {
        CopyableInfoBar.showInfo(
          context,
          title: 'Impresión cancelada',
          message: 'No se envió la factura a una impresora.',
        );
      }
    } catch (e, stack) {
      logger.e('[InvoiceSection]', 'Error printing invoice: $e\n$stack');
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al imprimir',
          message: 'No se pudo procesar la impresion de la factura. Intente nuevamente.',
        );
      }
    }
  }

  Future<void> _shareInvoice(
    BuildContext context,
    WidgetRef ref,
    AccountMove invoice,
  ) async {
    try {
      final report = await _prepareInvoiceReport(ref, invoice);
      final bytes = await report.service.getPreviewBytes(
        templateName: report.templateName,
        records: [report.record],
        company: report.company,
        user: report.user,
        options: report.options,
      );
      await platform_pdf.sharePdf(bytes, report.filename);
    } catch (e, stack) {
      logger.e('[InvoiceSection]', 'Error sharing invoice: $e\n$stack');
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al compartir',
          message: 'No se pudo compartir la factura. Intente nuevamente.',
        );
      }
    }
  }

  Future<_InvoiceReport> _prepareInvoiceReport(
    WidgetRef ref,
    AccountMove invoice,
  ) async {
    await _ensureTemplatesLoaded(ref);
    final reportService = ref.read(reportServiceProvider);
    const templateName = 'l10n_ec_edi.report_invoice_document';
    if (!reportService.hasTemplate(templateName)) {
      throw ReportException(
        'Template de factura no disponible. '
        'Sincronice los templates desde Odoo primero (incluir account.move).',
      );
    }

    var enrichedInvoice = invoice;
    try {
      final lines = await accountMoveLineManager.searchLocal(
        domain: [
          ['move_id', '=', invoice.id],
        ],
        orderBy: 'sequence asc',
      );
      enrichedInvoice = enrichedInvoice.copyWith(lines: lines);
    } catch (_) {
      // A cached header is still printable when lines are temporarily absent.
    }

    if (invoice.partnerId != null && invoice.partnerStreet == null) {
      try {
        final partner = await clientManager.readLocal(invoice.partnerId!);
        if (partner != null) {
          final street = partner.street ?? '';
          final street2 = partner.street2 ?? '';
          enrichedInvoice = enrichedInvoice.copyWithPartnerData(
            partnerStreet: street2.isNotEmpty ? '$street - $street2' : street,
            partnerCity: partner.city,
            partnerPhone: partner.phone,
            partnerEmail: partner.email,
          );
        }
      } catch (_) {
        // Contact enrichment is optional; fiscal values remain intact.
      }
    }

    final companyInfo = await _getCompanyInfo(ref);
    final userInfo = _getUserInfo(ref);
    return _InvoiceReport(
      service: reportService,
      templateName: templateName,
      filename: '${invoice.name.replaceAll('/', '-')}.pdf',
      record: enrichedInvoice.toReportMap(company: companyInfo),
      company: companyInfo,
      user: userInfo,
      options: _getRenderOptions(reportService, templateName),
    );
  }

  /// Ensure templates are loaded from database
  Future<void> _ensureTemplatesLoaded(WidgetRef ref) async {
    final reportService = ref.read(reportServiceProvider);
    if (!reportService.templatesLoaded) {
      final templateRepo = ref.read(qwebTemplateRepositoryProvider);
      if (templateRepo != null) {
        await reportService.loadTemplatesFromDatabase(templateRepo);
      }
    }
  }

  /// Get company info for PDF generation (includes Ecuador-specific fields)
  Future<Map<String, dynamic>> _getCompanyInfo(WidgetRef ref) async {
    final companyRepo = ref.read(companyRepositoryProvider);
    final company = await companyRepo?.getCurrentUserCompany();

    return <String, dynamic>{
      'id': company?.id,
      'name': company?.name ?? '',
      'l10n_ec_comercial_name':
          company?.l10nEcComercialName ?? company?.name ?? '',
      'vat': company?.vat ?? '',
      'street': company?.street ?? '',
      'street2': company?.street2 ?? '',
      'city': company?.city ?? '',
      'state': company?.stateName ?? '',
      'zip': company?.zip ?? '',
      'country': company?.countryName ?? 'Ecuador',
      'phone': company?.phone ?? '',
      'email': company?.email ?? '',
      'website': company?.website ?? '',
      'logo': company?.logo,
      'report_header_image': company?.reportHeaderImage,
      'report_footer': company?.reportFooter ?? '',
      'primary_color': company?.primaryColor ?? '#875A7B',
      'secondary_color': company?.secondaryColor ?? '#dee2e6',
      'font': company?.font ?? 'Lato',
      'layout_background': company?.layoutBackground ?? 'Blank',
      'external_report_layout':
          company?.externalReportLayoutId ?? 'web.external_layout_standard',
      // Ecuador-specific fields for invoice header
      'l10n_ec_legal_name': company?.l10nEcLegalName ?? company?.name ?? '',
      'l10n_ec_forced_accounting': true, // Default: most Ecuadorian companies
      'l10n_ec_special_taxpayer_number': null, // Not synced yet
      'l10n_ec_withhold_agent_number': null, // Not synced yet
      'l10n_ec_production_env': company?.l10nEcProductionEnv ?? true,
      'l10n_ec_regime': null, // Not synced yet
    };
  }

  /// Get user info for PDF generation
  Map<String, dynamic> _getUserInfo(WidgetRef ref) {
    final user = ref.read(userProvider);
    return <String, dynamic>{
      'id': user?.id,
      'name': user?.name ?? '',
      'login': user?.login ?? '',
      'email': user?.email ?? '',
    };
  }

  /// Get RenderOptions for PDF generation
  RenderOptions _getRenderOptions(
    ReportService reportService,
    String templateName,
  ) {
    final paperFormat = reportService.getPaperFormat(templateName);

    const double mmToPoints = 72.0 / 25.4;
    const double subtract15mm = 15.0;
    const double minMargin = 10.0;

    if (paperFormat != null) {
      final adjustedTop = (paperFormat.marginTop - subtract15mm).clamp(
        0.0,
        double.infinity,
      );
      final adjustedBottom = (paperFormat.marginBottom - subtract15mm).clamp(
        0.0,
        double.infinity,
      );
      final adjustedLeft = paperFormat.marginLeft < minMargin
          ? minMargin
          : paperFormat.marginLeft;
      final adjustedRight = paperFormat.marginRight < minMargin
          ? minMargin
          : paperFormat.marginRight;

      return RenderOptions(
        dpi: paperFormat.dpi,
        marginTop: adjustedTop * mmToPoints,
        marginBottom: adjustedBottom * mmToPoints,
        marginLeft: adjustedLeft * mmToPoints,
        marginRight: adjustedRight * mmToPoints,
        headerSpacing: 0,
        baseFontSize: 7, // Smaller font for invoices
      );
    } else {
      return const RenderOptions(
        dpi: 120,
        marginTop: 28.35,
        marginBottom: 0,
        marginLeft: 28.35,
        marginRight: 28.35,
        headerSpacing: 0,
        baseFontSize: 7, // Smaller font for invoices
      );
    }
  }
}

class _InvoiceReport {
  final ReportService service;
  final String templateName;
  final String filename;
  final Map<String, dynamic> record;
  final Map<String, dynamic> company;
  final Map<String, dynamic> user;
  final RenderOptions options;

  const _InvoiceReport({
    required this.service,
    required this.templateName,
    required this.filename,
    required this.record,
    required this.company,
    required this.user,
    required this.options,
  });
}

/// Widget compacto para mostrar info de factura en una línea
class InvoiceChip extends StatelessWidget {
  final AccountMove invoice;
  final VoidCallback? onTap;

  const InvoiceChip({super.key, required this.invoice, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.document, size: 12, color: theme.accentColor),
            const SizedBox(width: 4),
            Text(
              invoice.name,
              style: theme.typography.caption?.copyWith(
                color: theme.accentColor,
              ),
            ),
            if (invoice.isSriAuthorized) ...[
              const SizedBox(width: 4),
              Icon(FluentIcons.certificate, size: 10, color: Colors.green),
            ],
          ],
        ),
      ),
    );
  }
}
