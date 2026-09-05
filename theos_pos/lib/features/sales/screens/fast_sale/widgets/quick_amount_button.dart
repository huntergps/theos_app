import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../core/adaptive/adaptive_layout_policy.dart';

/// Quick amount button widget
class QuickAmountButton extends StatelessWidget {
  final String label;
  final double amount;
  final bool isExact;
  final VoidCallback onTap;
  final AdaptiveInputCapabilities inputCapabilities;

  const QuickAmountButton({
    super.key,
    required this.label,
    required this.amount,
    this.isExact = false,
    required this.onTap,
    this.inputCapabilities = const AdaptiveInputCapabilities(touch: true),
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final minimumExtent = AdaptiveUiPolicy(
      AdaptiveEnvironment(width: 0, height: 0, inputs: inputCapabilities),
    ).minimumInteractiveExtent;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minimumExtent,
        minHeight: minimumExtent,
      ),
      child: Button(
        onPressed: onTap,
        style: ButtonStyle(
          backgroundColor: isExact
              ? WidgetStateProperty.all(
                  theme.accentColor.withValues(alpha: 0.1),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isExact ? theme.accentColor : null,
            fontWeight: isExact ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}
