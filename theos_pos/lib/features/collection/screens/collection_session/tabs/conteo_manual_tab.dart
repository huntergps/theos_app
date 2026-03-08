import 'package:fluent_ui/fluent_ui.dart';

import '../widgets/conteo_manual_table.dart';
import '../widgets/detalle_cobros_table.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tab de conteo manual de la sesion de cobranza
class ConteoManualTab extends StatelessWidget {
  final CollectionSession session;

  const ConteoManualTab({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ConteoManualTable(session: session)),
                    const SizedBox(width: 16),
                    Expanded(child: DetalleCobrosTable(session: session)),
                  ],
                )
              : Column(
                  children: [
                    ConteoManualTable(session: session),
                    const SizedBox(height: 16),
                    DetalleCobrosTable(session: session),
                  ],
                ),
        );
      },
    );
  }
}
