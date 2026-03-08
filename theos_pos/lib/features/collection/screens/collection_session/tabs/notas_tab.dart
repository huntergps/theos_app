import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tab para mostrar las notas de la sesion
/// Incluye notas de apertura, cierre y supervisor
class NotasTab extends StatelessWidget {
  final CollectionSession session;

  const NotasTab({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNotesSection(
            context,
            title: 'Notas de Apertura',
            content: session.openingNotes,
            emptyMessage: 'Sin notas de apertura',
          ),
          const SizedBox(height: 24),
          _buildNotesSection(
            context,
            title: 'Notas de Cierre',
            content: session.closingNotes,
            emptyMessage: 'Sin notas de cierre',
          ),
          const SizedBox(height: 24),
          _buildNotesSection(
            context,
            title: 'Notas del Supervisor',
            content: session.supervisorNotes,
            emptyMessage: 'Sin notas del supervisor',
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(
    BuildContext context, {
    required String title,
    required String? content,
    required String emptyMessage,
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
            child: SizedBox(
              width: double.infinity,
              child: Text(
                content ?? emptyMessage,
                style: theme.typography.body,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
