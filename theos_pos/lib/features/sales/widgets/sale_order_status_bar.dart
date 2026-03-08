import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show SaleOrderState;
import 'package:theos_pos/shared/widgets/model_status_bar.dart';

/// Status bar specifically for Sale Orders
class SaleOrderStatusBar extends StatelessWidget {
  final SaleOrderState state;

  const SaleOrderStatusBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ModelStatusBar<SaleOrderState>(
      currentValue: state,
      steps: [
        const StatusStep(label: 'Cotización', value: SaleOrderState.draft),
        const StatusStep(label: 'Enviado', value: SaleOrderState.sent),
        StatusStep(
          label: 'Esperando Aprobación',
          value: SaleOrderState.waitingApproval,
          color: Colors.orange,
        ),
        const StatusStep(label: 'Aprobado', value: SaleOrderState.approved),
        StatusStep(
          label: 'Orden de Venta',
          value: SaleOrderState.sale,
          color: Colors.green,
        ),
        StatusStep(
          label: 'Completado',
          value: SaleOrderState.done,
          color: Colors.grey,
        ),
        StatusStep(
          label: 'Cancelado',
          value: SaleOrderState.cancel,
          color: Colors.red,
        ),
      ],
    );
  }
}
