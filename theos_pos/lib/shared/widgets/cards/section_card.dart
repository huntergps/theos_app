import 'package:fluent_ui/fluent_ui.dart';

/// Reusable widget for a section card with title and icon
///
/// Used across features for consistent section styling.
/// Provides a Card with an icon header and content area.
///
/// ## Usage
/// ```dart
/// SectionCard(
///   icon: FluentIcons.payment_card,
///   title: 'Payment Details',
///   child: PaymentTable(),
/// )
/// ```
class SectionCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Widget>? actions;

  const SectionCard({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = iconColor ?? theme.accentColor;

    return Card(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: theme.typography.subtitle),
              ),
              if (actions != null) ...actions!,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
