import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/server_info_provider.dart';

/// A compact status bar displayed at the bottom of the main screen.
///
/// Shows: Odoo version | server host | database name | current date/time.
/// The clock updates every second locally, but syncs from the server
/// every 10 minutes.
class ServerInfoBar extends ConsumerStatefulWidget {
  const ServerInfoBar({super.key});

  @override
  ConsumerState<ServerInfoBar> createState() => _ServerInfoBarState();
}

class _ServerInfoBarState extends ConsumerState<ServerInfoBar> {
  Timer? _clockTimer;
  DateTime _displayTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _displayTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverInfo = ref.watch(serverInfoProvider);
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use server time offset for display
    final adjustedTime = _displayTime.toUtc().add(serverInfo.serverTimeOffset).toLocal();
    final dateTimeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(adjustedTime);

    final textColor = isDark
        ? theme.resources.textFillColorSecondary
        : theme.resources.textFillColorSecondary;

    final separatorColor = textColor.withValues(alpha: 0.3);

    final bgColor = isDark
        ? theme.resources.cardBackgroundFillColorDefault
        : theme.resources.cardBackgroundFillColorDefault;

    final borderColor = isDark
        ? theme.resources.cardStrokeColorDefault
        : theme.resources.cardStrokeColorDefault;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Odoo version
          if (serverInfo.odooVersion.isNotEmpty) ...[
            _InfoSegment(
              icon: FluentIcons.server_enviroment,
              text: serverInfo.odooVersion,
              textColor: textColor,
            ),
            _Separator(color: separatorColor),
          ],

          // Server URL
          if (serverInfo.serverUrl.isNotEmpty) ...[
            _InfoSegment(
              icon: FluentIcons.globe,
              text: serverInfo.serverUrl,
              textColor: textColor,
            ),
            _Separator(color: separatorColor),
          ],

          // Database name
          if (serverInfo.database.isNotEmpty) ...[
            _InfoSegment(
              icon: FluentIcons.database,
              text: serverInfo.database,
              textColor: textColor,
            ),
            _Separator(color: separatorColor),
          ],

          // Date/Time (pushed to the right)
          const Spacer(),
          _InfoSegment(
            icon: FluentIcons.date_time,
            text: dateTimeStr,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
}

/// A single info segment with an icon and text label.
class _InfoSegment extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;

  const _InfoSegment({
    required this.icon,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: textColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: textColor,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// A vertical separator between info segments.
class _Separator extends StatelessWidget {
  final Color color;

  const _Separator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 1,
        height: 12,
        color: color,
      ),
    );
  }
}
