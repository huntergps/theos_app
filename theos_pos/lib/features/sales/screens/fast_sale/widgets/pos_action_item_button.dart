part of 'pos_actions_panel.dart';

/// Action item data
class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isPrimary = false,
  });

  bool get isEnabled => onTap != null;
}

/// Individual action button
class _ActionButton extends StatelessWidget {
  final _ActionItem action;
  final bool isCompact;
  final bool isHorizontal;

  const _ActionButton({
    required this.action,
    this.isCompact = false,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isEnabled = action.isEnabled;
    final effectiveColor = isEnabled ? action.color : theme.inactiveColor;

    if (isCompact) {
      return Tooltip(
        message: action.label,
        child: IconButton(
          icon: Icon(action.icon, size: 20, color: effectiveColor),
          onPressed: action.onTap,
        ),
      );
    }

    if (isHorizontal) {
      return Button(
        onPressed: action.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 20, color: effectiveColor),
            const SizedBox(height: Spacing.xxs),
            Text(
              action.label,
              style: theme.typography.caption?.copyWith(
                fontSize: 10,
                color: isEnabled ? null : theme.inactiveColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Vertical layout - full button with colored icon background
    // Use FilledButton for primary actions
    final buttonWidget = action.isPrimary && isEnabled
        ? FilledButton(
            onPressed: action.onTap,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(
                  vertical: Spacing.sm,
                  horizontal: Spacing.xs,
                ),
              ),
              backgroundColor: WidgetStateProperty.all(
                action.color.withValues(alpha: 0.9),
              ),
            ),
            child: _buildButtonContent(theme, Colors.white, isEnabled),
          )
        : Button(
            onPressed: action.onTap,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(
                  vertical: Spacing.sm,
                  horizontal: Spacing.xs,
                ),
              ),
            ),
            child: _buildButtonContent(theme, effectiveColor, isEnabled),
          );

    return SizedBox(width: double.infinity, child: buttonWidget);
  }

  Widget _buildButtonContent(
    FluentThemeData theme,
    Color iconColor,
    bool isEnabled,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: action.isPrimary && isEnabled
                ? Colors.white.withValues(alpha: 0.2)
                : action.color.withValues(alpha: isEnabled ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(action.icon, size: 24, color: iconColor),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          action.label,
          style: theme.typography.caption?.copyWith(
            fontWeight: FontWeight.w500,
            color: action.isPrimary && isEnabled ? Colors.white : null,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      ],
    );
  }
}
