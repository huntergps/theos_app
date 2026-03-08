import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_widgets/odoo_widgets.dart' show OdooFieldConfig, OdooMultilineField;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/spacing.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../widgets/totals/sales_order_totals.dart';

/// Section 2: Client Info + Credit Info + Dates/Configuration
///
/// Displays cards side by side on desktop, stacked on mobile.
/// The cards are passed as widgets to allow different implementations
/// for view mode (read-only) vs edit mode (with form controls).
class FormSection2Info extends ConsumerWidget {
  final Widget clientCard;
  final Widget? creditCard;
  final Widget datesCard;

  const FormSection2Info({
    super.key,
    required this.clientCard,
    this.creditCard,
    required this.datesCard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(themedSpacingProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ScreenBreakpoints.mobileMaxWidth) {
          // Desktop: Client | Credit | Dates (si creditCard existe)
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: clientCard),
              if (creditCard != null) ...[
                SizedBox(width: spacing.md),
                Expanded(flex: 1, child: creditCard!),
              ],
              SizedBox(width: spacing.lg),
              Expanded(child: datesCard),
            ],
          );
        } else {
          // Mobile: Client, Credit (si existe), Dates (stacked)
          return Column(
            children: [
              clientCard,
              if (creditCard != null) ...[
                spacing.vertical.md,
                creditCard!,
              ],
              spacing.vertical.md,
              datesCard,
            ],
          );
        }
      },
    );
  }
}

/// Section 4: Order Totals
///
/// Displays order totals (subtotal, discount, taxes, total) aligned to the right.
class FormSection4Totals extends StatelessWidget {
  final SaleOrder? order;
  final List<SaleOrderLine> lines;
  final double width;

  const FormSection4Totals({
    super.key,
    this.order,
    required this.lines,
    this.width = 320,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: width,
          child: SalesOrderTotals(
            order: order,
            lines: lines,
          ),
        ),
      ],
    );
  }
}

/// Section 5: Terms and Conditions / Notes
///
/// Displays and optionally allows editing of order notes/terms.
/// Uses [OdooMultilineField] for both view and edit modes.
class FormSection5Notes extends StatelessWidget {
  final String? note;
  final bool isEditing;
  final ValueChanged<String?>? onNoteChanged;

  const FormSection5Notes({
    super.key,
    this.note,
    this.isEditing = false,
    this.onNoteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OdooMultilineField(
          config: OdooFieldConfig(
            label: 'Terminos y condiciones',
            isEditing: isEditing,
            prefixIcon: FluentIcons.quick_note,
            hint: 'Terminos y condiciones de la orden...',
          ),
          value: note,
          maxLines: 4,
          minLines: 3,
          onChanged: onNoteChanged,
        ),
      ),
    );
  }
}
