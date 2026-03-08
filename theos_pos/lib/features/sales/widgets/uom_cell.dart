import 'package:fluent_ui/fluent_ui.dart';

/// Shared widget for displaying Unit of Measure (UoM).
///
/// Displays the UoM name, and if [isEditable] is true, adds a dropdown chevron
/// and handles tap events.
class UomCell extends StatelessWidget {
  final String name;
  final bool isEditable;
  final VoidCallback? onTap;
  final TextStyle? style;
  final Color? iconColor;

  const UomCell({
    super.key,
    required this.name,
    this.isEditable = false,
    this.onTap,
    this.style,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEditable) {
      return Text(name, style: style, overflow: TextOverflow.ellipsis);
    }

    final theme = FluentTheme.of(context);
    final effectiveIconColor = iconColor ?? theme.accentColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              style:
                  style?.copyWith(color: effectiveIconColor) ??
                  TextStyle(color: effectiveIconColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(FluentIcons.chevron_down, size: 10, color: effectiveIconColor),
        ],
      ),
    );
  }
}
