import 'package:fluent_ui/fluent_ui.dart';

import '../../ui/components/orbi_components.dart';
import 'legacy_draft_inspector.dart';

/// A safe, non-blocking notice for legacy SharedPreferences drafts.
///
/// This widget only offers inspection. It never decodes or imports values,
/// chooses a company, creates a durable draft, or mutates preferences.
final class LegacyDraftNotice extends StatelessWidget {
  const LegacyDraftNotice({
    super.key,
    required this.inspection,
    this.onDismiss,
  });

  final LegacyDraftInspection inspection;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!inspection.rawPresent) return const SizedBox.shrink();
    final theme = FluentTheme.of(context);
    return Card(
      margin: const EdgeInsets.all(8),
      backgroundColor: theme.resources.subtleFillColorSecondary,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final actions = <Widget>[
              Button(
                onPressed: () => _showReview(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.red_eye),
                    SizedBox(width: 6),
                    Text('Revisar'),
                  ],
                ),
              ),
              if (onDismiss != null)
                Button(onPressed: onDismiss, child: const Text('Cerrar')),
            ];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(FluentIcons.info, color: theme.accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hay un borrador local anterior para revisar',
                        style: theme.typography.bodyStrong,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'No se importó nada. La empresa de origen y algunos importes no están identificados.',
                      ),
                      const SizedBox(height: 8),
                      if (compact)
                        Wrap(spacing: 8, runSpacing: 4, children: actions)
                      else
                        Row(children: actions),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showReview(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => _LegacyDraftReviewDialog(inspection: inspection),
  );
}

final class _LegacyDraftReviewDialog extends StatelessWidget {
  const _LegacyDraftReviewDialog({required this.inspection});

  final LegacyDraftInspection inspection;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return ContentDialog(
      title: const Text('Revisión del borrador anterior'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Esta revisión no importa ni modifica datos.',
                style: typography.body,
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Campos disponibles',
                values: inspection.recoverableFields,
                empty: 'No hay campos confirmados.',
              ),
              const SizedBox(height: 8),
              _Section(
                title: 'Campos faltantes',
                values: inspection.missingFields,
                empty: 'No se detectaron campos faltantes.',
              ),
              const SizedBox(height: 8),
              _Section(
                title: 'Campos no reconocidos',
                values: inspection.unknownFields,
                empty: 'Ninguno.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Límites: la empresa de origen no está identificada y '
                'descuento, impuesto y total de línea no fueron almacenados. '
                'No se asignará una empresa ni se inventarán importes.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.values,
    required this.empty,
  });

  final String title;
  final List<String> values;
  final String empty;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: FluentTheme.of(context).typography.bodyStrong),
      const SizedBox(height: 2),
      if (values.isEmpty)
        Text(empty)
      else
        Wrap(
          spacing: 6,
          runSpacing: 4,
          // El mismo badge que ya usa el resto de la aplicación
          // (`OrbiStatusChip`, en el componente compartido) en vez de uno
          // propio: ni color ni forma se deciden aquí, se heredan.
          children: [
            for (final value in values) OrbiStatusChip(label: value),
          ],
        ),
    ],
  );
}
