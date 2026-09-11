import 'package:flutter/material.dart';

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
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(8),
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final actions = <Widget>[
              OutlinedButton.icon(
                onPressed: () => _showReview(context),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Revisar'),
              ),
              if (onDismiss != null)
                TextButton(onPressed: onDismiss, child: const Text('Cerrar')),
            ];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hay un borrador local anterior para revisar',
                        style: Theme.of(context).textTheme.titleSmall,
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
    final theme = Theme.of(context);
    return AlertDialog(
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
                style: theme.textTheme.bodyMedium,
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
        TextButton(
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
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 2),
      if (values.isEmpty)
        Text(empty)
      else
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [for (final value in values) Chip(label: Text(value))],
        ),
    ],
  );
}
