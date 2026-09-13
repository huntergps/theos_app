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

/// Cuántos avisos siguen sin leerse para la [NotificationQueryKey] dada.
///
/// Pensado para que el armazón (la barra superior) lo observe sin repetir la
/// consulta: usa la misma [NotificationQueryKey] que arma la ruta
/// `/notifications` en `router.dart` — `scopeKey: active.scope.scopeKey`,
/// `partitionKey`: `'global'` o `'company:<id>'` según
/// `capabilities.companyId`.
final notificationUnreadCountProvider = Provider.autoDispose
    .family<int, NotificationQueryKey>((ref, key) {
      final state = ref.watch(notificationEntriesProvider(key));
      return state.maybeWhen(
        data: (snapshot) => snapshot.unreadCount,
        orElse: () => 0,
      );
    });

/// Cuántos avisos de severidad [NotificationSeverity.error] siguen sin
/// leerse. Mismo uso que [notificationUnreadCountProvider]: un indicador de
/// error en la barra superior que no dependa de abrir Avisos para saberlo.
final notificationErrorCountProvider = Provider.autoDispose
    .family<int, NotificationQueryKey>((ref, key) {
      final state = ref.watch(notificationEntriesProvider(key));
      return state.maybeWhen(
        data: (snapshot) => snapshot.entries
            .where(
              (entry) =>
                  entry.severity == NotificationSeverity.error &&
                  entry.readAt == null,
            )
            .length,
        orElse: () => 0,
      );
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

InfoBarSeverity _infoBarSeverity(NotificationSeverity severity) =>
    switch (severity) {
      NotificationSeverity.info => InfoBarSeverity.info,
      NotificationSeverity.attention => InfoBarSeverity.warning,
      NotificationSeverity.error => InfoBarSeverity.error,
    };

String _kindLabel(NotificationKind kind) => switch (kind) {
  NotificationKind.activity => 'Actividades',
  NotificationKind.approval => 'Aprobaciones',
  NotificationKind.sync => 'Sincronización',
  NotificationKind.system => 'Sistema',
};

String _dayLabel(DateTime occurredAt) {
  final local = occurredAt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _timeLabel(DateTime occurredAt) {
  final local = occurredAt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
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
        if (items.isEmpty) return const _EmptyState();

        final sorted = [...items]
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        final groups = <String, List<NotificationEntry>>{};
        for (final entry in sorted) {
          groups.putIfAbsent(_dayLabel(entry.occurredAt), () => []).add(entry);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, snapshot, port, items),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final group in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Text(
                        group.key,
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                    ),
                    for (final item in group.value)
                      _NotificationRow(
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
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    NotificationInboxSnapshot snapshot,
    NotificationInboxPort port,
    List<NotificationEntry> items,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: '${snapshot.unreadCount} avisos no leídos',
              child: Text(
                snapshot.unreadCount == 0
                    ? 'Todo leído'
                    : '${snapshot.unreadCount} sin leer',
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
            ),
          ),
          if (snapshot.unreadCount > 0)
            HyperlinkButton(
              onPressed: () => unawaited(_markAllRead(port, items)),
              child: const Text('Marcar todo leído'),
            ),
        ],
      ),
    );
  }

  Future<void> _markAllRead(
    NotificationInboxPort port,
    List<NotificationEntry> items,
  ) {
    final unread = items.where((item) => item.readAt == null);
    return Future.wait(unread.map((item) => port.markRead(item.id, item.scope)));
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.ringer,
            size: 48,
            color: theme.resources.textFillColorDisabled,
          ),
          const SizedBox(height: 12),
          const Text('No hay avisos'),
          const SizedBox(height: 4),
          Text('Aquí verás sincronización, actividades y aprobaciones.',
              style: theme.typography.caption),
        ],
      ),
    );
  }
}

/// Una fila del listado, dueña de su propio [FlyoutController] — el menú de
/// acciones necesita uno por fila y debe liberarse con ella, así que vive en
/// un `StatefulWidget` propio en vez de fabricarse de nuevo en cada
/// reconstrucción del `ListView`.
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
    final isUnread = item.readAt == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onOpen,
          child: Semantics(
            button: true,
            label: isUnread ? 'Sin leer' : 'Leído',
            child: Opacity(
              opacity: isUnread ? 1 : 0.7,
              child: InfoBar(
                title: Text(item.titleKey),
                isLong: true,
                severity: _infoBarSeverity(item.severity),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.fallbackText ?? item.bodyKey),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetaText(
                          icon: FluentIcons.timeline,
                          text: _kindLabel(item.kind),
                        ),
                        _MetaText(
                          icon: FluentIcons.clock,
                          text: _timeLabel(item.occurredAt),
                        ),
                        if (item.target != null)
                          _MetaText(
                            icon: FluentIcons.open_in_new_window,
                            text: 'Ver documento',
                          ),
                      ],
                    ),
                  ],
                ),
                action: FlyoutTarget(
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
                                isUnread ? 'Marcar leído' : 'Marcar no leído',
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = theme.resources.textFillColorSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
