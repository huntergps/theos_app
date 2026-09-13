import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show SaleOrderState;

import '../../../ui/state_labels.dart';

/// Cadena de pasos del estado de la orden, como la de theos_pos
/// (`theos_pos/lib/features/sales/widgets/sale_order_status_bar.dart`), pero
/// con un control nativo de Fluent en vez de un `CustomPainter` a mano: el
/// [BreadcrumbBar] ya trae su propio manejo de desbordamiento (menú "…"
/// cuando los pasos no caben), así que no hay que reescribir esa lógica.
///
/// Mismo conjunto y orden de siete pasos que la referencia. Queda fuera
/// `SaleOrderState.rejected`: tampoco aparece en la cadena de theos_pos (se
/// avisa aparte, con un `InfoBar`).
class SaleOrderStatusChain extends StatelessWidget {
  const SaleOrderStatusChain({super.key, required this.state});

  final SaleOrderState state;

  static const List<SaleOrderState> _steps = [
    SaleOrderState.draft,
    SaleOrderState.sent,
    SaleOrderState.waitingApproval,
    SaleOrderState.approved,
    SaleOrderState.sale,
    SaleOrderState.done,
    SaleOrderState.cancel,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexOf(state);
    final resolvedIndex = currentIndex < 0 ? 0 : currentIndex;
    return BreadcrumbBar<SaleOrderState>(
      items: [
        for (final (index, step) in _steps.indexed)
          BreadcrumbItem(
            value: step,
            label: _StepLabel(
              label: saleOrderStateLabel(step),
              isActive: index == resolvedIndex,
              isPast: index < resolvedIndex,
            ),
          ),
      ],
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.label,
    required this.isActive,
    required this.isPast,
  });

  final String label;
  final bool isActive;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = isActive
        ? theme.accentColor
        : isPast
        ? theme.resources.textFillColorPrimary
        : theme.resources.textFillColorTertiary;
    return Text(
      label,
      // Sólo el paso activo lleva key: es lo único que las pruebas necesitan
      // ubicar sin depender de color ni de si el `BreadcrumbBar` decidió
      // mandar este paso al menú de desbordamiento.
      key: isActive ? const Key('sale-status-active') : null,
      style: TextStyle(
        color: color,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
