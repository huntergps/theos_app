import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show SessionState;
import '../../../../shared/widgets/model_status_bar.dart';

/// Status bar specifically for Collection Sessions
class SessionStatusBar extends StatelessWidget {
  final SessionState state;

  const SessionStatusBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ModelStatusBar<SessionState>(
      currentValue: state,
      steps: const [
        StatusStep(
          label: 'Apertura',
          value: SessionState.openingControl,
        ),
        StatusStep(label: 'En Proceso', value: SessionState.opened),
        StatusStep(
          label: 'Control de Cierre',
          value: SessionState.closingControl,
        ),
        StatusStep(label: 'Cerrada', value: SessionState.closed),
      ],
    );
  }
}
