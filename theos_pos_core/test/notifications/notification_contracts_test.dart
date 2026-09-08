import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  final scope = NotificationScope(
    scopeKey: 'app|install|user',
    partitionKey: 'company:7',
    companyId: 7,
  );

  test(
    'entry dedupe includes scope, partition and source, revision is separate',
    () {
      final first = NotificationEntry(
        id: 'n1',
        scope: scope,
        sourceKey: 'approval:9',
        revision: 1,
        kind: NotificationKind.approval,
        severity: NotificationSeverity.attention,
        titleKey: 'approval.title',
        bodyKey: 'approval.body',
        occurredAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        origin: NotificationOrigin.poll,
      );
      final same = NotificationEntry(
        id: 'n2',
        scope: scope,
        sourceKey: 'approval:9',
        revision: 1,
        kind: NotificationKind.approval,
        severity: NotificationSeverity.attention,
        titleKey: 'approval.title',
        bodyKey: 'approval.body',
        occurredAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        origin: NotificationOrigin.poll,
      );
      expect(first.sameRevision(same), isTrue);
      expect(first.dedupeKey, same.dedupeKey);
    },
  );

  test('company and global scopes remain explicit', () {
    final global = NotificationScope(scopeKey: 'scope', partitionKey: 'global');
    expect(global.isGlobal, isTrue);
    expect(scope.isGlobal, isFalse);
    expect(scope.companyId, 7);
  });

  test(
    'preferences and capabilities distinguish muted, unsupported and denied',
    () {
      final preferences = NotificationPreferences(
        mutedKinds: {NotificationKind.sync},
      );
      expect(preferences.allows(NotificationKind.approval), isTrue);
      expect(preferences.allows(NotificationKind.sync), isFalse);
      final capabilities = NotificationCapabilities(
        supported: {NotificationCapability.show},
        permission: NotificationPermission.denied,
      );
      expect(capabilities.supports(NotificationCapability.show), isTrue);
      expect(capabilities.supports(NotificationCapability.schedule), isFalse);
      expect(capabilities.permission, NotificationPermission.denied);
    },
  );

  test('delivery dedupe retains revision and channel', () {
    final delivery = NotificationDelivery(
      entryId: 'n1',
      scope: globalScope,
      revision: 2,
      channel: NotificationChannel.system,
      state: NotificationDeliveryState.pending,
    );
    expect(delivery.dedupeKey, contains('2'));
  });

  test('rejects invalid or mismatched scopes and identities', () {
    expect(
      () => NotificationScope(scopeKey: '', partitionKey: 'global'),
      throwsArgumentError,
    );
    expect(
      () => NotificationScope(
        scopeKey: 's',
        partitionKey: 'company:8',
        companyId: 7,
      ),
      throwsArgumentError,
    );
    expect(
      () => NotificationScope(
        scopeKey: 's',
        partitionKey: 'company:0',
        companyId: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => NotificationTarget(type: '', reference: 'x'),
      throwsArgumentError,
    );
    expect(
      () => NotificationEvent(
        scope: scope,
        sourceKey: '',
        revision: 0,
        kind: NotificationKind.system,
        severity: NotificationSeverity.info,
        titleKey: 't',
        bodyKey: 'b',
        occurredAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(
      () => NotificationDelivery(
        entryId: 'e',
        scope: scope,
        revision: -1,
        channel: NotificationChannel.system,
        state: NotificationDeliveryState.pending,
      ),
      throwsArgumentError,
    );
  });

  test('copies caller collections and avoids delimiter collisions', () {
    final muted = <NotificationKind>{NotificationKind.sync};
    final preferences = NotificationPreferences(mutedKinds: muted);
    muted.clear();
    expect(preferences.allows(NotificationKind.sync), isFalse);
    final args = <String, String>{'x': '1'};
    final entry = NotificationEntry(
      id: 'e',
      scope: scope,
      sourceKey: 'a|b',
      revision: 0,
      kind: NotificationKind.system,
      severity: NotificationSeverity.info,
      titleKey: 't',
      bodyKey: 'b',
      args: args,
      occurredAt: DateTime.utc(2026),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      origin: NotificationOrigin.local,
    );
    args['x'] = 'changed';
    expect(entry.args['x'], '1');
    expect(entry.dedupeKey, isNot(contains('|a|b')));
  });
}

final globalScope = NotificationScope(
  scopeKey: 'scope',
  partitionKey: 'global',
);
