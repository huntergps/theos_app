import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ActivityStatus { overdue, today, planned, done }

final class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.title,
    required this.status,
    this.canComplete = false,
  });
  final String id;
  final String title;
  final ActivityStatus status;
  final bool canComplete;
}

abstract interface class ActivityPort {
  Stream<List<ActivityItem>> get changes;
  List<ActivityItem> get snapshot;
  Future<bool> complete(ActivityItem item);
}

final activityPortProvider = Provider<ActivityPort>(
  (ref) => const _EmptyActivityPort(),
);

final class _EmptyActivityPort implements ActivityPort {
  const _EmptyActivityPort();
  @override
  List<ActivityItem> get snapshot => const [];
  @override
  Stream<List<ActivityItem>> get changes => const Stream.empty();
  @override
  Future<bool> complete(ActivityItem item) async => false;
}

class ActivityCenterView extends StatelessWidget {
  const ActivityCenterView({required this.port, super.key});
  final ActivityPort port;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ActivityItem>>(
    stream: port.changes,
    initialData: port.snapshot,
    builder: (context, snapshot) {
      final items = snapshot.data ?? const <ActivityItem>[];
      if (items.isEmpty) return const Center(child: Text('No hay actividades'));
      return ListView(
        children: items
            .map(
              (item) => ListTile(
                title: Text(item.title),
                subtitle: Text(switch (item.status) {
                  ActivityStatus.overdue => 'Vencida',
                  ActivityStatus.today => 'Hoy',
                  ActivityStatus.planned => 'Planificada',
                  ActivityStatus.done => 'Completada',
                }),
                trailing: item.canComplete && item.status != ActivityStatus.done
                    ? Tooltip(
                        message: 'Completar actividad',
                        child: IconButton(
                          icon: const Icon(FluentIcons.check_mark),
                          onPressed: () => unawaited(port.complete(item)),
                        ),
                      )
                    : null,
              ),
            )
            .toList(),
      );
    },
  );
}
