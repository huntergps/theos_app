import 'package:fluent_ui/fluent_ui.dart';

/// A generic state chip widget that displays a label with a colored background.
/// Can be used with any enum or state type by providing a color and label.
class TheosStateChip extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const TheosStateChip({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final foreground = isDark && color.computeLuminance() < 0.35
        ? Color.lerp(color, Colors.white, 0.55)!
        : color;
    return Semantics(
      label: 'Estado: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: isDark ? 0.24 : 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: foreground.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}
