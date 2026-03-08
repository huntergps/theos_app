import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tab para mostrar informacion de cheques
/// Incluye cheques al dia y cheques posfechados
class ChequesTab extends StatelessWidget {
  final CollectionSession session;

  const ChequesTab({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCheckSection(
            context,
            title: 'Cheques al Dia',
            total: session.checksOnDayTotal,
          ),
          const SizedBox(height: 24),
          _buildCheckSection(
            context,
            title: 'Cheques Posfechados',
            total: session.checksPostdatedTotal,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckSection(
    BuildContext context, {
    required String title,
    required double total,
  }) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.typography.subtitle),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Total: ${total.toCurrency()}',
                style: theme.typography.bodyLarge,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
