import 'dart:async';

import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_panel/features/notifications/notification_inbox.dart';
import 'package:theos_panel/features/notifications/notification_navigator.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _Inbox implements NotificationInboxPort {
  final controller = StreamController<NotificationInboxSnapshot>.broadcast();
  final events = <NotificationEvent>[];
  final baselines = <bool>[];
  final _stored = <String, NotificationEvent>{};
  var outboxCount = 0;
  var reads = 0;
  var unreads = 0;
  var archives = 0;

  @override
  Stream<NotificationInboxSnapshot> watch(NotificationQuery query) =>
      controller.stream;

  @override
  Future<NotificationIngestResult> ingest(
    NotificationEvent event, {
    bool baseline = false,
  }) async {
    baselines.add(baseline);
    final old = _stored[event.dedupeKey];
    if (old != null && event.revision <= old.revision) {
      return NotificationIngestResult.duplicate;
    }
    _stored[event.dedupeKey] = event;
    events.add(event);
    if (!baseline) outboxCount++;
    return baseline
        ? NotificationIngestResult.baseline
        : old == null
        ? NotificationIngestResult.inserted
        : NotificationIngestResult.updated;
  }

  @override
  Future<int> markRead(String id, NotificationScope scope) async => ++reads;

  @override
  Future<int> markUnread(String id, NotificationScope scope) async => ++unreads;

  @override
  Future<int> archive(String id, NotificationScope scope) async => ++archives;

  void publish(NotificationInboxSnapshot snapshot) => controller.add(snapshot);
}

final class _Allocator implements NotificationSystemIdAllocator {
  @override
  Future<int> allocate({
    required String scopeKey,
    required String entryId,
    required String channel,
  }) async => 1;
}

NotificationEvent event(String source, {int revision = 1}) => NotificationEvent(
  scope: NotificationScope(scopeKey: 'scope', partitionKey: 'global'),
  sourceKey: source,
  revision: revision,
  kind: NotificationKind.activity,
  severity: NotificationSeverity.info,
  titleKey: 'title',
  bodyKey: 'body',
  occurredAt: DateTime.utc(2026),
);

NotificationEntry entry({NotificationTarget? target}) => NotificationEntry(
  id: 'entry',
  scope: NotificationScope(scopeKey: 'scope', partitionKey: 'global'),
  sourceKey: 'source',
  revision: 1,
  kind: NotificationKind.activity,
  severity: NotificationSeverity.info,
  titleKey: 'Aviso',
  bodyKey: 'Detalle',
  occurredAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  origin: NotificationOrigin.local,
  target: target,
);

void main() {
  test(
    'provider without bootstrap exposes a visible unavailable error',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final port = container.read(notificationInboxPortProvider);
      expect(port, isA<UnavailableNotificationInboxPort>());
      await expectLater(
        port.watch(
          NotificationQuery(scopeKey: 'scope', partitionKey: 'global'),
        ),
        emitsError(isA<StateError>()),
      );
    },
  );

  test(
    'active runtime adapter rejects stale scope/partition before DB access',
    () async {
      final scope = AppScope(
        appId: 'theos_panel',
        installationId: 'install',
        normalizedServerUrl: 'https://example.test',
        database: 'db',
        userId: 7,
      );
      final runtime = SessionRuntime(
        databaseOwner: RuntimeDatabaseOwner(
          factory: (_) => AppDatabase(NativeDatabase.memory()),
        ),
      );
      await runtime.activate(scope);
      final container = ProviderContainer(
        overrides: [
          runtimeSessionProvider.overrideWithValue(runtime),
          notificationSystemIdAllocatorProvider.overrideWithValue(_Allocator()),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await runtime.close();
      });
      final port = container.read(notificationInboxPortProvider);
      expect(port, isA<SessionNotificationInboxPort>());
      await expectLater(
        port.watch(
          NotificationQuery(
            scopeKey: scope.scopeKey,
            partitionKey: 'company:999',
          ),
        ),
        emitsError(isA<StateError>()),
      );
    },
  );

  test(
    'durable store dedupes rebuild and baseline never creates outbox',
    () async {
      final inbox = _Inbox();
      final first = NotificationEventProducer(inbox);
      expect(await first.emit(event('one')), NotificationIngestResult.inserted);
      expect(
        await first.emit(event('one')),
        NotificationIngestResult.duplicate,
      );
      final rebuilt = NotificationEventProducer(inbox);
      expect(
        await rebuilt.emit(event('one')),
        NotificationIngestResult.duplicate,
      );
      expect(
        await rebuilt.emit(event('one', revision: 2)),
        NotificationIngestResult.updated,
      );
      expect(
        await inbox.ingest(event('baseline'), baseline: true),
        NotificationIngestResult.baseline,
      );
      expect(inbox.baselines, [false, false, false, true]);
      expect(inbox.outboxCount, 2);
      await inbox.controller.close();
    },
  );

  testWidgets('tap opens only after navigator validation, then marks read', (
    tester,
  ) async {
    final inbox = _Inbox();
    final scope = NotificationScope(scopeKey: 'scope', partitionKey: 'global');
    final target = NotificationTarget(type: 'activity', reference: '42');
    final calls = <String>[];
    final navigator = NotificationNavigator(
      validation: _Validation(calls),
      allowedTargetTypes: {'activity'},
      opener: (target, scope) async => calls.add('open'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationInboxPortProvider.overrideWithValue(inbox)],
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: NotificationInboxView(
            query: const NotificationQueryKey(
              scopeKey: 'scope',
              partitionKey: 'global',
            ),
            navigator: navigator,
          ),
        ),
      ),
    );
    inbox.publish(
      NotificationInboxSnapshot(
        entries: [entry(target: target)],
        unreadCount: 1,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Aviso'));
    // Fluent's `ListTile` runs its press feedback through `HoverButton`,
    // which schedules a 100ms timer to reset the pressed state after the
    // tap. A single `pump()` leaves it pending at teardown.
    await tester.pump(const Duration(milliseconds: 150));
    expect(calls.last, 'open');
    expect(inbox.reads, 1);
    expect(scope.scopeKey, 'scope');
    await inbox.controller.close();
  });

  testWidgets('rejected navigation does not mark the notification read', (
    tester,
  ) async {
    final inbox = _Inbox();
    final navigator = NotificationNavigator(
      validation: _Validation(<String>[], allow: false),
      allowedTargetTypes: {'activity'},
      opener: (target, scope) async {},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationInboxPortProvider.overrideWithValue(inbox)],
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: NotificationInboxView(
            query: const NotificationQueryKey(
              scopeKey: 'scope',
              partitionKey: 'global',
            ),
            navigator: navigator,
          ),
        ),
      ),
    );
    inbox.publish(
      NotificationInboxSnapshot(
        entries: [
          entry(
            target: NotificationTarget(type: 'activity', reference: '42'),
          ),
        ],
        unreadCount: 1,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Aviso'));
    // See the same note above: Fluent's `HoverButton` needs the press
    // feedback timer to expire before teardown.
    await tester.pump(const Duration(milliseconds: 150));
    expect(inbox.reads, 0);
    await inbox.controller.close();
  });

  testWidgets('notification actions remain usable on an iPad at large text', (
    tester,
  ) async {
    final inbox = _Inbox();
    final navigator = NotificationNavigator(
      validation: _Validation(<String>[]),
      allowedTargetTypes: {'activity'},
      opener: (target, scope) async {},
    );
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: ProviderScope(
          overrides: [notificationInboxPortProvider.overrideWithValue(inbox)],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: NotificationInboxView(
              query: const NotificationQueryKey(
                scopeKey: 'scope',
                partitionKey: 'global',
              ),
              navigator: navigator,
            ),
          ),
        ),
      ),
    );
    inbox.publish(
      NotificationInboxSnapshot(entries: [entry()], unreadCount: 1),
    );
    await tester.pump();
    expect(find.byTooltip('Acciones del aviso'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await inbox.controller.close();
  });
}

final class _Validation implements NotificationNavigationValidation {
  _Validation(this.calls, {this.allow = true});
  final List<String> calls;
  final bool allow;

  @override
  Future<bool> sessionIsActive(NotificationScope scope) async {
    calls.add('session');
    return allow;
  }

  @override
  Future<bool> companyIsAllowed(NotificationScope scope) async {
    calls.add('company');
    return allow;
  }

  @override
  Future<bool> targetExists(
    NotificationTarget target,
    NotificationScope scope,
  ) async {
    calls.add('exists');
    return allow;
  }

  @override
  Future<bool> canOpen(
    NotificationTarget target,
    NotificationScope scope,
  ) async {
    calls.add('permission');
    return allow;
  }
}
