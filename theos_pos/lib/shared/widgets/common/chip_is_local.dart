import 'package:fluent_ui/fluent_ui.dart';

class SyncPendingChip extends StatefulWidget {
  const SyncPendingChip({
    super.key,
    required this.onSync,
    this.label = 'Pendiente de sincronizar',
    this.syncingLabel = 'Sincronizando...',
    this.style = SyncPendingStyle.chip,
    this.showBorder = true,
  });

  /// Callback to execute when the widget is tapped.
  /// Should return a Future that completes when sync is done.
  /// Returns true if sync was successful, false otherwise.
  final Future<bool> Function() onSync;

  /// Label to show when not syncing
  final String label;

  /// Label to show while syncing
  final String syncingLabel;

  /// Visual style of the widget
  final SyncPendingStyle style;

  /// If true, shows border around the chip (only for chip style)
  final bool showBorder;

  @override
  State<SyncPendingChip> createState() => _SyncPendingChipState();
}

/// Visual style options for SyncPendingChip
enum SyncPendingStyle {
  /// Shows with background color, padding and optional border
  chip,

  /// Shows only the icon and text without background
  text,
}

class _SyncPendingChipState extends State<SyncPendingChip> {
  bool _isSyncing = false;

  Future<void> _handleTap() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await widget.onSync();
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = _isSyncing ? Colors.blue : Colors.orange;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isSyncing)
          SizedBox(
            width: 14,
            height: 14,
            child: ProgressRing(strokeWidth: 2, activeColor: color),
          )
        else
          Icon(FluentIcons.cloud_upload, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          _isSyncing ? widget.syncingLabel : widget.label,
          style: theme.typography.caption?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    return Tooltip(
      message: _isSyncing
          ? 'Sincronizando con el servidor...'
          : 'Toca para sincronizar con el servidor',
      child: GestureDetector(
        onTap: _handleTap,
        child: MouseRegion(
          cursor: _isSyncing
              ? SystemMouseCursors.wait
              : SystemMouseCursors.click,
          child: widget.style == SyncPendingStyle.chip
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: widget.showBorder
                        ? Border.all(color: color.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: content,
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: content,
                ),
        ),
      ),
    );
  }
}
