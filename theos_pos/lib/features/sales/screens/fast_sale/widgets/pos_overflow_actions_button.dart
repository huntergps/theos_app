part of 'pos_actions_panel.dart';

/// Botón de menú de desbordamiento para acciones secundarias en layout horizontal.
///
/// Muestra un [Flyout] de Fluent UI con los ítems que no caben en la barra
/// principal, garantizando área táctil ≥44 px y separación visual de las
/// acciones destructivas respecto de las primarias.
class _OverflowActionsButton extends StatefulWidget {
  final List<_ActionItem> actions;

  const _OverflowActionsButton({required this.actions});

  @override
  State<_OverflowActionsButton> createState() => _OverflowActionsButtonState();
}

class _OverflowActionsButtonState extends State<_OverflowActionsButton> {
  final FlyoutController _controller = FlyoutController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return FlyoutTarget(
      controller: _controller,
      child: Tooltip(
        message: 'Más opciones',
        child: SizedBox(
          // Área táctil mínima 44 px
          height: 44,
          child: Button(
            onPressed: () {
              _controller.showFlyout(
                autoModeConfiguration: FlyoutAutoConfiguration(
                  preferredMode: FlyoutPlacementMode.topRight,
                ),
                barrierDismissible: true,
                builder: (context) => MenuFlyout(
                  items: [
                    for (final action in widget.actions)
                      MenuFlyoutItem(
                        leading: Icon(
                          action.icon,
                          size: 16,
                          color: action.isEnabled
                              ? action.color
                              : theme.inactiveColor,
                        ),
                        text: Text(
                          action.label,
                          style: TextStyle(
                            color: action.isEnabled
                                ? null
                                : theme.inactiveColor,
                          ),
                        ),
                        onPressed: action.isEnabled
                            ? () {
                                Flyout.of(context).close();
                                action.onTap!();
                              }
                            : null,
                      ),
                  ],
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.more, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Más',
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
