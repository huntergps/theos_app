import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';

/// Widget para mostrar una fila de cheques con al dia y posfechados
class CheckRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double onDay;
  final double postdated;

  const CheckRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onDay,
    required this.postdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: theme.resources.textFillColorSecondary,
              ),
              const SizedBox(width: 8),
              Text(label, style: theme.typography.body),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            onDay.toCurrency(),
            style: theme.typography.body,
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            postdated.toCurrency(),
            style: theme.typography.body,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
