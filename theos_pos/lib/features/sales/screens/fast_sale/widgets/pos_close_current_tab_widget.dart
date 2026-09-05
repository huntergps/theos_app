part of 'pos_actions_panel.dart';

/// Widget to display current order name with close button [Nuevo-2][X]
class _CloseCurrentTabWidget extends StatelessWidget {
  final String orderName;
  final VoidCallback onClose;
  final bool isCompact;

  const _CloseCurrentTabWidget({
    required this.orderName,
    required this.onClose,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Order name section
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 12,
              vertical: isCompact ? 4 : 8,
            ),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.accentColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Text(
              orderName,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.accentColor,
                fontSize: isCompact ? 12 : 14,
              ),
            ),
          ),

          // Close button section [X]
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 6 : 10,
                vertical: isCompact ? 4 : 8,
              ),
              child: Icon(
                FluentIcons.chrome_close,
                size: isCompact ? 10 : 12,
                color: theme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
