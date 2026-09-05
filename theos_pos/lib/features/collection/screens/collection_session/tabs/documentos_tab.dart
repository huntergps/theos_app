import 'package:drift/drift.dart' as drift;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show CollectionSession;

import '../../../../../core/managers/manager_providers.dart'
    show appDatabaseProvider;
import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/widgets/common/theos_info_bars.dart';

/// Documents cached locally for a collection session.
///
/// The query watches the three tables together, so this screen remains useful
/// offline and refreshes as soon as an order, invoice or withholding is synced.
final collectionDocumentsProvider = StreamProvider.autoDispose
    .family<List<CollectionDocument>, int>((ref, sessionId) {
      final db = ref.watch(appDatabaseProvider);
      final query = db.select(db.saleOrder).join([
        drift.leftOuterJoin(
          db.accountMove,
          db.accountMove.saleOrderId.equalsExp(db.saleOrder.odooId),
        ),
        drift.leftOuterJoin(
          db.saleOrderWithholdLine,
          db.saleOrderWithholdLine.orderId.equalsExp(db.saleOrder.odooId),
        ),
      ])..where(db.saleOrder.collectionSessionId.equals(sessionId));

      return query.watch().map((rows) {
        final documents = <String, CollectionDocument>{};
        for (final row in rows) {
          final order = row.readTable(db.saleOrder);
          documents['order:${order.odooId}'] = CollectionDocument(
            key: 'order:${order.odooId}',
            type: CollectionDocumentType.saleOrder,
            name: order.name,
            partnerName: order.partnerName,
            state: order.state ?? 'draft',
            date: order.dateOrder,
            amount: order.amountTotal,
          );

          final invoice = row.readTableOrNull(db.accountMove);
          if (invoice != null) {
            documents['invoice:${invoice.odooId}'] = CollectionDocument(
              key: 'invoice:${invoice.odooId}',
              type: CollectionDocumentType.invoice,
              name: invoice.name ?? 'Factura borrador',
              partnerName: invoice.partnerName ?? order.partnerName,
              state: invoice.state,
              date: invoice.invoiceDate ?? invoice.date,
              amount: invoice.amountTotal,
              secondaryState: invoice.paymentState,
            );
          }

          final withholding = row.readTableOrNull(db.saleOrderWithholdLine);
          if (withholding != null) {
            final identity = withholding.odooId ?? withholding.id;
            documents['withhold:$identity'] = CollectionDocument(
              key: 'withhold:$identity',
              type: CollectionDocumentType.withholding,
              name: withholding.taxName,
              partnerName: order.partnerName,
              state: withholding.isSynced ? 'synced' : 'pending',
              date: withholding.writeDate ?? order.dateOrder,
              amount: withholding.amount,
              relatedDocument: order.name,
            );
          }
        }

        final result = documents.values.toList()
          ..sort((a, b) {
            final dateComparison = (b.date ?? DateTime(0)).compareTo(
              a.date ?? DateTime(0),
            );
            return dateComparison != 0
                ? dateComparison
                : a.name.compareTo(b.name);
          });
        return result;
      });
    });

enum CollectionDocumentType { saleOrder, invoice, withholding }

class CollectionDocument {
  final String key;
  final CollectionDocumentType type;
  final String name;
  final String? partnerName;
  final String state;
  final String? secondaryState;
  final DateTime? date;
  final double amount;
  final String? relatedDocument;

  const CollectionDocument({
    required this.key,
    required this.type,
    required this.name,
    required this.state,
    required this.amount,
    this.partnerName,
    this.secondaryState,
    this.date,
    this.relatedDocument,
  });
}

/// Orders, invoices and withholdings linked to a collection session.
class DocumentosTab extends ConsumerWidget {
  final CollectionSession session;

  const DocumentosTab({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(collectionDocumentsProvider(session.id));
    return documents.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Spacing.xl),
        child: Center(child: ProgressRing()),
      ),
      error: (error, _) => TheosInfoBars.error(
        title: 'No se pudieron cargar los documentos',
        message: error.toString(),
      ),
      data: (items) => _DocumentsContent(items: items),
    );
  }
}

class _DocumentsContent extends StatelessWidget {
  final List<CollectionDocument> items;

  const _DocumentsContent({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final orderCount = items
        .where((item) => item.type == CollectionDocumentType.saleOrder)
        .length;
    final invoiceCount = items
        .where((item) => item.type == CollectionDocumentType.invoice)
        .length;
    final withholdingCount = items
        .where((item) => item.type == CollectionDocumentType.withholding)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.document_set,
                    color: theme.accentColor,
                    size: 24,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    'Resumen de documentos',
                    style: theme.typography.subtitle,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.sm,
                children: [
                  _DocumentCount(
                    icon: FluentIcons.shopping_cart,
                    label: 'Órdenes',
                    count: orderCount,
                    color: Colors.blue,
                  ),
                  _DocumentCount(
                    icon: FluentIcons.document,
                    label: 'Facturas',
                    count: invoiceCount,
                    color: Colors.teal,
                  ),
                  _DocumentCount(
                    icon: FluentIcons.receipt_check,
                    label: 'Retenciones',
                    count: withholdingCount,
                    color: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Text('Detalle', style: theme.typography.subtitle),
        const SizedBox(height: Spacing.sm),
        if (items.isEmpty)
          TheosInfoBars.info(
            title: 'Sin documentos',
            message: 'Esta sesión todavía no tiene órdenes, facturas ni retenciones guardadas.',
          )
        else
          ...items.map((document) => _DocumentCard(document: document)),
      ],
    );
  }
}

class _DocumentCount extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _DocumentCount({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(label, style: theme.typography.caption)),
          Text(
            count.toString(),
            style: theme.typography.subtitle?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final CollectionDocument document;

  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = _typeColor(document.type);
    final amount = NumberFormat.currency(symbol: r'$').format(document.amount);
    final date = document.date == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy').format(document.date!);

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: ListTile(
        onPressed: () => _showDetails(context, document),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_typeIcon(document.type), color: color),
        ),
        title: Text(
          document.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.bodyStrong,
        ),
        subtitle: Text(
          [
            _typeLabel(document.type),
            if (document.partnerName?.isNotEmpty == true) document.partnerName!,
            date,
            _stateLabel(document.state),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(amount, style: theme.typography.bodyStrong),
      ),
    );
  }
}

Future<void> _showDetails(BuildContext context, CollectionDocument document) {
  final amount = NumberFormat.currency(symbol: r'$').format(document.amount);
  final date = document.date == null
      ? 'Sin fecha'
      : DateFormat('dd/MM/yyyy').format(document.date!);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: Text(document.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailLine(label: 'Tipo', value: _typeLabel(document.type)),
          _DetailLine(
            label: 'Cliente',
            value: document.partnerName ?? 'Sin cliente',
          ),
          _DetailLine(label: 'Fecha', value: date),
          _DetailLine(label: 'Estado', value: _stateLabel(document.state)),
          if (document.secondaryState != null)
            _DetailLine(
              label: 'Estado de pago',
              value: _stateLabel(document.secondaryState!),
            ),
          if (document.relatedDocument != null)
            _DetailLine(
              label: 'Documento relacionado',
              value: document.relatedDocument!,
            ),
          _DetailLine(label: 'Total', value: amount),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.typography.bodyStrong),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

IconData _typeIcon(CollectionDocumentType type) => switch (type) {
  CollectionDocumentType.saleOrder => FluentIcons.shopping_cart,
  CollectionDocumentType.invoice => FluentIcons.document,
  CollectionDocumentType.withholding => FluentIcons.receipt_check,
};

Color _typeColor(CollectionDocumentType type) => switch (type) {
  CollectionDocumentType.saleOrder => Colors.blue,
  CollectionDocumentType.invoice => Colors.teal,
  CollectionDocumentType.withholding => Colors.orange,
};

String _typeLabel(CollectionDocumentType type) => switch (type) {
  CollectionDocumentType.saleOrder => 'Orden de venta',
  CollectionDocumentType.invoice => 'Factura',
  CollectionDocumentType.withholding => 'Retención',
};

String _stateLabel(String state) => switch (state) {
  'draft' => 'Borrador',
  'sent' => 'Enviada',
  'sale' => 'Confirmada',
  'posted' => 'Publicada',
  'cancel' || 'cancelled' => 'Cancelada',
  'paid' => 'Pagada',
  'not_paid' => 'No pagada',
  'partial' => 'Pago parcial',
  'in_payment' => 'En pago',
  'synced' => 'Sincronizada',
  'pending' => 'Pendiente de sincronizar',
  _ => state,
};
