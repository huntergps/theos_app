import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../app/notification_scope_adapter.dart';
import 'notification_navigator.dart';

abstract interface class NotificationInboxPort {
  Stream<NotificationInboxSnapshot> watch(NotificationQuery query);

  Future<NotificationIngestResult> ingest(
    NotificationEvent event, {
    bool baseline = false,
  });

  Future<int> markRead(String id, NotificationScope scope);
  Future<int> markUnread(String id, NotificationScope scope);
  Future<int> archive(String id, NotificationScope scope);
}

final class NotificationInboxSnapshot {
  NotificationInboxSnapshot({
    required Iterable<NotificationEntry> entries,
    required this.unreadCount,
  }) : entries = List.unmodifiable(entries) {
    if (unreadCount < 0 || unreadCount > this.entries.length) {
      throw ArgumentError.value(unreadCount, 'unreadCount');
    }
  }

  final List<NotificationEntry> entries;
  final int unreadCount;
}

enum NotificationIngestResult { inserted, updated, duplicate, baseline }

enum _NotificationAction { toggleRead, archive }

final class UnavailableNotificationInboxPort implements NotificationInboxPort {
  const UnavailableNotificationInboxPort();

  StateError get _error => StateError('Centro de avisos no configurado');

  @override
  Stream<NotificationInboxSnapshot> watch(NotificationQuery query) =>
      Stream<NotificationInboxSnapshot>.error(_error);

  @override
  Future<NotificationIngestResult> ingest(
    NotificationEvent event, {
    bool baseline = false,
  }) => Future<NotificationIngestResult>.error(_error);

  @override
  Future<int> markRead(String id, NotificationScope scope) =>
      Future<int>.error(_error);

  @override
  Future<int> markUnread(String id, NotificationScope scope) =>
      Future<int>.error(_error);

  @override
  Future<int> archive(String id, NotificationScope scope) =>
      Future<int>.error(_error);
}

final class NotificationEventProducer {
  NotificationEventProducer(this._inbox);

  final NotificationInboxPort _inbox;
  final _revisions = <String, int>{};

  Future<NotificationIngestResult> emit(NotificationEvent event) {
    final previous = _revisions[event.dedupeKey];
    if (previous != null && event.revision <= previous) {
      return Future.value(NotificationIngestResult.duplicate);
    }
    _revisions[event.dedupeKey] = event.revision;
    return _inbox.ingest(event);
  }

  Future<void> emitBaseline(Iterable<NotificationEvent> events) async {
    for (final event in events) {
      final previous = _revisions[event.dedupeKey];
      if (previous != null && event.revision <= previous) continue;
      _revisions[event.dedupeKey] = event.revision;
      await _inbox.ingest(event, baseline: true);
    }
  }
}

final notificationInboxPortProvider = Provider<NotificationInboxPort>(
  (ref) =>
      ref.watch(sessionNotificationInboxPortProvider) ??
      const UnavailableNotificationInboxPort(),
);

final notificationEntriesProvider = StreamProvider.autoDispose
    .family<NotificationInboxSnapshot, NotificationQueryKey>((ref, key) {
      final port = ref.watch(notificationInboxPortProvider);
      return port.watch(key.query);
    });

final class NotificationQueryKey {
  const NotificationQueryKey({
    required this.scopeKey,
    required this.partitionKey,
    this.limit = 50,
    this.offset = 0,
  });

  final String scopeKey;
  final String partitionKey;
  final int limit;
  final int offset;

  NotificationQuery get query => NotificationQuery(
    scopeKey: scopeKey,
    partitionKey: partitionKey,
    limit: limit,
    offset: offset,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationQueryKey &&
      other.scopeKey == scopeKey &&
      other.partitionKey == partitionKey &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(scopeKey, partitionKey, limit, offset);
}

class NotificationInboxView extends ConsumerWidget {
  const NotificationInboxView({
    required this.query,
    required this.navigator,
    super.key,
  });

  final NotificationQueryKey query;
  final NotificationNavigator navigator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationEntriesProvider(query));
    return state.when(
      loading: () => const Center(child: ProgressRing()),
      error: (error, stack) => Semantics(
        liveRegion: true,
        child: const Center(child: Text('No se pudo cargar avisos')),
      ),
      data: (snapshot) {
        final port = ref.read(notificationInboxPortProvider);
        final items = snapshot.entries;
        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                liveRegion: true,
                label: '${snapshot.unreadCount} avisos no leídos',
                child: InfoBadge(source: Text('${snapshot.unreadCount}')),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No hay avisos'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _NotificationRow(
                          key: ValueKey(item.id),
                          item: item,
                          onOpen: () => unawaited(_open(port, item)),
                          onAction: (action) {
                            switch (action) {
                              case _NotificationAction.toggleRead:
                                unawaited(
                                  item.readAt == null
                                      ? port.markRead(item.id, item.scope)
                                      : port.markUnread(item.id, item.scope),
                                );
                              case _NotificationAction.archive:
                                unawaited(port.archive(item.id, item.scope));
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _open(NotificationInboxPort port, NotificationEntry item) async {
    final target = item.target;
    if (target == null) {
      await port.markRead(item.id, item.scope);
      return;
    }
    final result = await navigator.open(target: target, scope: item.scope);
    if (result == NotificationNavigationResult.opened) {
      await port.markRead(item.id, item.scope);
    }
  }
}

/// Una fila del listado, dueña de su propio [FlyoutController] — el menú de
/// acciones necesita uno por fila y debe liberarse con ella, así que vive en
/// un `StatefulWidget` propio en vez de fabricarse de nuevo en cada
/// reconstrucción del `ListView.builder`.
class _NotificationRow extends StatefulWidget {
  const _NotificationRow({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onAction,
  });

  final NotificationEntry item;
  final VoidCallback onOpen;
  final ValueChanged<_NotificationAction> onAction;

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow> {
  final _menuController = FlyoutController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ListTile(
      title: Text(item.titleKey),
      subtitle: Text(item.fallbackText ?? item.bodyKey),
      onPressed: widget.onOpen,
      trailing: FlyoutTarget(
        controller: _menuController,
        child: Tooltip(
          message: 'Acciones del aviso',
          child: IconButton(
            icon: const Icon(FluentIcons.more_vertical),
            onPressed: () => _menuController.showFlyout<void>(
              builder: (context) => MenuFlyout(
                items: [
                  MenuFlyoutItem(
                    text: Text(
                      item.readAt == null ? 'Marcar leído' : 'Marcar no leído',
                    ),
                    onPressed: () =>
                        widget.onAction(_NotificationAction.toggleRead),
                  ),
                  MenuFlyoutItem(
                    text: const Text('Archivar'),
                    onPressed: () =>
                        widget.onAction(_NotificationAction.archive),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
