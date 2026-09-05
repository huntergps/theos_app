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
class ServerInfoBar extends ConsumerWidget {
  const ServerInfoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverInfo = ref.watch(serverInfoProvider);
    final theme = FluentTheme.of(context);

    final textColor = theme.resources.textFillColorSecondary;
    final separatorColor = textColor.withValues(alpha: 0.3);
    final bgColor = theme.resources.cardBackgroundFillColorDefault;
    final borderColor = theme.resources.cardStrokeColorDefault;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
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

          // Pending operations badge — mostrado en el header (main_screen.dart)

          // Date/Time (pushed to the right)
          const Spacer(),
          _ServerClock(
            offset: serverInfo.serverTimeOffset,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
}

/// Ticks independently so the server metadata above is not rebuilt every
/// second.
class _ServerClock extends StatefulWidget {
  final Duration offset;
  final Color textColor;

  const _ServerClock({required this.offset, required this.textColor});

  @override
  State<_ServerClock> createState() => _ServerClockState();
}

class _ServerClockState extends State<_ServerClock> {
  late DateTime _time;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _time = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _time = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adjusted = _time.toUtc().add(widget.offset).toLocal();
    return _InfoSegment(
      icon: FluentIcons.date_time,
      text: DateFormat('dd/MM/yyyy HH:mm:ss').format(adjusted),
      textColor: widget.textColor,
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
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.w400,
            ),
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
      child: Container(width: 1, height: 12, color: color),
    );
  }
}
