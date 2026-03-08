import 'package:fluent_ui/fluent_ui.dart';

/// Quick amount button widget
class QuickAmountButton extends StatelessWidget {
  final String label;
  final double amount;
  final bool isExact;
  final VoidCallback onTap;

  const QuickAmountButton({
    super.key,
    required this.label,
    required this.amount,
    this.isExact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Button(
      onPressed: onTap,
      style: ButtonStyle(
        backgroundColor: isExact
            ? WidgetStateProperty.all(theme.accentColor.withValues(alpha: 0.1))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isExact ? theme.accentColor : null,
          fontWeight: isExact ? FontWeight.bold : null,
        ),
      ),
    );
  }
}
