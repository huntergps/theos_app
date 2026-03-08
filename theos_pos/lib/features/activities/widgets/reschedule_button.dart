import 'package:fluent_ui/fluent_ui.dart';

/// Boton de reagendar actividades con menu flyout
///
/// Widget unificado que puede usarse tanto en el DataGrid como en cards.
/// Muestra un menu con opciones: Hoy, Manana, Proxima semana.
class RescheduleButton extends StatefulWidget {
  final VoidCallback? onRescheduleToday;
  final VoidCallback? onRescheduleTomorrow;
  final VoidCallback? onRescheduleNextWeek;
  final double iconSize;

  const RescheduleButton({
    super.key,
    this.onRescheduleToday,
    this.onRescheduleTomorrow,
    this.onRescheduleNextWeek,
    this.iconSize = 16,
  });

  @override
  State<RescheduleButton> createState() => _RescheduleButtonState();
}

class _RescheduleButtonState extends State<RescheduleButton> {
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
        message: 'Reagendar',
        child: IconButton(
          icon: Icon(FluentIcons.calendar_reply, size: widget.iconSize),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.isHovered) {
                return theme.accentColor.withValues(alpha: 0.1);
              }
              return Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.all(theme.accentColor),
          ),
          onPressed: _showRescheduleMenu,
        ),
      ),
    );
  }

  void _showRescheduleMenu() {
    _controller.showFlyout(
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.bottomCenter,
      ),
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.calendar, size: 16),
              text: Text('Hoy (${_getDayName(DateTime.now())})'),
              onPressed: () {
                _controller.close();
                widget.onRescheduleToday?.call();
              },
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.calendar, size: 16),
              text: Text(
                'Manana (${_getDayName(DateTime.now().add(const Duration(days: 1)))})',
              ),
              onPressed: () {
                _controller.close();
                widget.onRescheduleTomorrow?.call();
              },
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.calendar, size: 16),
              text: Text(
                'Proxima semana (${_getDayName(_getNextMonday())})',
              ),
              onPressed: () {
                _controller.close();
                widget.onRescheduleNextWeek?.call();
              },
            ),
          ],
        );
      },
    );
  }

  static String _getDayName(DateTime date) {
    const days = ['dom', 'lun', 'mar', 'mie', 'jue', 'vie', 'sab'];
    return days[date.weekday % 7];
  }

  static DateTime _getNextMonday() {
    final now = DateTime.now();
    final daysUntilMonday = (8 - now.weekday) % 7;
    return now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
  }
}
