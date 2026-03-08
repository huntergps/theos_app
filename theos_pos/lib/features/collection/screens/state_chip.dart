import 'package:fluent_ui/fluent_ui.dart';
import '../../../../shared/widgets/common/theos_state_chip.dart';

/// Chip especializado para estados de sesion de cobranza
/// Utiliza [TheosStateChip] como base y agrega mapeo de estados a colores/labels
class StateChip extends StatelessWidget {
  final String state;

  const StateChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _getStateConfig(state);
    return TheosStateChip(label: label, color: color);
  }

  /// Mapea el estado a su color y label correspondiente
  (Color, String) _getStateConfig(String state) {
    return switch (state) {
      'openingControl' || 'opening_control' => (Colors.orange, 'Apertura'),
      'opened' => (Colors.green, 'Abierta'),
      'closingControl' || 'closing_control' => (Colors.blue, 'Cerrando'),
      'closed' => (Colors.grey, 'Cerrada'),
      _ => (Colors.grey, state),
    };
  }
}
