import 'package:fluent_ui/fluent_ui.dart';

/// Widget reutilizable para mostrar items de ayuda con icono, título y descripción
class SyncHelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final double iconSize;

  const SyncHelpItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.typography.bodyStrong),
                Text(
                  description,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
