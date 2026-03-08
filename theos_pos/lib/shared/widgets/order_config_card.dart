import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show Pricelist, PaymentTerm, Warehouse, User;

import '../providers/master_data_stream_providers.dart';
import 'reactive/reactive_widgets.dart';

/// Unified Order Configuration Card
///
/// Shows order configuration fields (date, pricelist, payment term, warehouse, user)
/// in either view or edit mode. Works with both Fast Sale and Sale Order Form screens.
///
/// Usage in Fast Sale:
/// ```dart
/// OrderConfigCard(
///   isCompact: isCompact,
///   dateOrder: order?.dateOrder,
///   pricelistId: order?.pricelistId,
///   pricelistName: order?.pricelistName,
///   // ... other fields
///   authorizedPaymentTermIds: activeTab?.partnerPaymentTermIds ?? [],
///   onDateChanged: (date) => notifier.updateOrderField('date_order', date),
///   onPricelistChanged: (id) => notifier.updateOrderField('pricelist_id', id),
///   // ... other callbacks
/// )
/// ```
///
/// Usage in Sale Order Form:
/// ```dart
/// OrderConfigCard(
///   isCompact: isCompact,
///   isEditing: isEditing,
///   dateOrder: state.dateOrder,
///   pricelistId: state.pricelistId,
///   pricelistName: state.pricelistName,
///   // ... other fields
///   authorizedPaymentTermIds: state.partnerPaymentTermIds,
///   onDateChanged: (date) => notifier.updateField('date_order', date),
///   // ... other callbacks
/// )
/// ```
class OrderConfigCard extends ConsumerWidget {
  /// Show in compact mode (only date field visible)
  final bool isCompact;

  /// Enable editing mode (show interactive selectors)
  final bool isEditing;

  // Current values
  final DateTime? dateOrder;
  final int? pricelistId;
  final String? pricelistName;
  final int? paymentTermId;
  final String? paymentTermName;
  final int? warehouseId;
  final String? warehouseName;
  final int? userId;
  final String? userName;

  /// Payment term IDs authorized for the current partner (for filtering)
  final List<int> authorizedPaymentTermIds;

  // Callbacks for changes (null = not editable for that field)
  // Note: Uses nullable types to match ReactiveFieldBase signatures
  final ValueChanged<DateTime?>? onDateChanged;
  final ValueChanged<int?>? onPricelistChanged;
  final ValueChanged<int?>? onPaymentTermChanged;
  final ValueChanged<int?>? onWarehouseChanged;
  final ValueChanged<int?>? onUserChanged;

  const OrderConfigCard({
    super.key,
    this.isCompact = false,
    this.isEditing = true,
    this.dateOrder,
    this.pricelistId,
    this.pricelistName,
    this.paymentTermId,
    this.paymentTermName,
    this.warehouseId,
    this.warehouseName,
    this.userId,
    this.userName,
    this.authorizedPaymentTermIds = const [],
    this.onDateChanged,
    this.onPricelistChanged,
    this.onPaymentTermChanged,
    this.onWarehouseChanged,
    this.onUserChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(themedSpacingProvider);

    return Card(
      padding: EdgeInsets.all(spacing.ms),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date - always visible
          ReactiveDateField(
            config: ReactiveFieldConfig(label: 'Fecha', isEditing: isEditing),
            value: dateOrder,
            showTime: true,
            onChanged: isEditing ? onDateChanged : null,
          ),

          if (!isCompact) ...[
            SizedBox(height: spacing.xs),
            _buildPricelistField(ref),
            SizedBox(height: spacing.xs),
            _buildPaymentTermField(ref),
            SizedBox(height: spacing.xs),
            _buildWarehouseField(ref),
            SizedBox(height: spacing.xs),
            _buildUserField(ref),
          ],
        ],
      ),
    );
  }

  /// Pricelist selector
  Widget _buildPricelistField(WidgetRef ref) {
    return ReactiveMasterSelector<Pricelist>(
      config: ReactiveFieldConfig(
        label: 'Lista de precios',
        isEditing: isEditing && onPricelistChanged != null,
      ),
      value: pricelistId,
      displayValue: pricelistName ?? (isEditing ? null : 'Predeterminado'),
      itemsProvider: pricelistsStreamProvider,
      getId: (p) => p.id,
      getName: (p) => p.name,
      onChanged: onPricelistChanged,
    );
  }

  /// Payment terms selector with partner filtering
  Widget _buildPaymentTermField(WidgetRef ref) {
    return ReactiveMasterSelector<PaymentTerm>(
      config: ReactiveFieldConfig(
        label: 'Términos de pago',
        isEditing: isEditing && onPaymentTermChanged != null,
      ),
      value: paymentTermId,
      displayValue: paymentTermName ?? '-',
      itemsProvider: paymentTermsStreamProvider,
      getId: (p) => p.id,
      getName: (p) => p.name,
      // Filter by authorized payment terms if any
      filter: authorizedPaymentTermIds.isEmpty
          ? null
          : (pt) => authorizedPaymentTermIds.contains(pt.id),
      onChanged: onPaymentTermChanged,
    );
  }

  /// Warehouse selector
  Widget _buildWarehouseField(WidgetRef ref) {
    return ReactiveMasterSelector<Warehouse>(
      config: ReactiveFieldConfig(
        label: 'Almacén',
        isEditing: isEditing && onWarehouseChanged != null,
      ),
      value: warehouseId,
      displayValue: warehouseName ?? '-',
      itemsProvider: warehousesStreamProvider,
      getId: (w) => w.id,
      getName: (w) => w.name,
      onChanged: onWarehouseChanged,
    );
  }

  /// User/salesperson selector
  Widget _buildUserField(WidgetRef ref) {
    return ReactiveMasterSelector<User>(
      config: ReactiveFieldConfig(
        label: 'Vendedor',
        isEditing: isEditing && onUserChanged != null,
      ),
      value: userId,
      displayValue: userName ?? '-',
      itemsProvider: salespeopleStreamProvider,
      getId: (s) => s.id,
      getName: (s) => s.name,
      onChanged: onUserChanged,
    );
  }
}
