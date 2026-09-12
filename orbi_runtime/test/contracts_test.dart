import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

void main() {
  test('AppScope canonicalizes URL and produces unambiguous stable key', () {
    final first = AppScope(
      appId: 'orbi-panel',
      installationId: 'install-1',
      normalizedServerUrl: 'HTTPS://ERP.Example.test:443/odoo///',
      database: 'erp',
      userId: 7,
    );
    final second = AppScope(
      appId: 'orbi-panel',
      installationId: 'install-1',
      normalizedServerUrl: 'https://erp.example.test/odoo',
      database: 'erp',
      userId: 7,
    );
    expect(first, equals(second));
    expect(first.scopeKey, equals(second.scopeKey));
    expect(first.normalizedServerUrl, 'https://erp.example.test/odoo');
    expect(first.scopeKey, isNot(contains('secret')));
  });

  test('scope identity changes when app, installation, or user changes', () {
    final base = AppScope(
      appId: 'orbi-panel',
      installationId: 'a',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 1,
    );
    expect(base, isNot(equals(base.copyWith(userId: 2))));
    expect(base.scopeKey, isNot(equals(base.copyWith(appId: 'other').scopeKey)));
    expect(base.scopeKey, isNot(equals(base.copyWith(installationId: 'b').scopeKey)));
  });

  test('CompanyContext sorts and validates the selected company', () {
    final scope = AppScope(
      appId: 'orbi-panel',
      installationId: 'a',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 1,
    );
    final context = CompanyContext.forScope(
      scope: scope,
      companyId: 2,
      allowedCompanyIds: [3, 2, 3],
      capabilityRevision: 4,
    );
    expect(context.allowedCompanyIds, [2, 3]);
    expect(context.scopeKey, scope.scopeKey);
  });

  test('SessionLease rejects stale scope generations', () {
    final scope = AppScope(
      appId: 'orbi-panel',
      installationId: 'a',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 1,
    );
    final lease = SessionLease(scope: scope, generation: 3);
    expect(lease.accepts(scope: scope, generation: 3), isTrue);
    expect(lease.accepts(scope: scope, generation: 2), isFalse);
  });

  test('network signal and sync contracts expose explicit states', () {
    final signal = NetworkSignal(
      transports: [NetworkTransport.wifi],
      observedAt: DateTime.utc(2026, 1, 1),
    );
    expect(signal.hasNetwork, isTrue);
    expect(signal.observedAt.isUtc, isTrue);
    expect(const BackendHealth().state, BackendHealthState.unknown);
    expect(SyncSnapshot().active, isFalse);
    expect(AuthStatus.values, contains(AuthStatus.expired));
  });

  test('network signal treats none as exclusive and orders transports', () {
    final signal = NetworkSignal(
      transports: [NetworkTransport.wifi, NetworkTransport.none, NetworkTransport.mobile],
    );
    expect(signal.transports, [NetworkTransport.wifi, NetworkTransport.mobile]);
    expect(signal.hasNetwork, isTrue);

    final offline = NetworkSignal(transports: const []);
    expect(offline.transports, [NetworkTransport.none]);
    expect(offline.hasNetwork, isFalse);
  });

  test('SyncSnapshot rejects negative counters in release semantics', () {
    expect(() => SyncSnapshot(queuedCount: -1), throwsArgumentError);
    expect(() => SyncSnapshot(conflictCount: -1), throwsArgumentError);
  });

  // `failedCount` ya no se puede pasar suelto: se deriva del detalle. Así no
  // puede volver a existir un número sin nada detrás que lo explique, que es
  // justo lo que dejaba a la pantalla diciendo «5 con error» y nada más.
  test('los fallos de sincronización llevan su detalle, no sólo su número', () {
    final snapshot = SyncSnapshot(
      failures: [
        SyncFailure(jobId: 'catalog:uom', message: "Invalid field 'rounding'"),
        SyncFailure(jobId: 'catalog:cardBrand', message: 'model does not exist'),
      ],
    );
    expect(snapshot.failedCount, 2);
    expect(snapshot.failures.first.jobId, 'catalog:uom');
    expect(snapshot.failures.first.message, contains('rounding'));
    expect(SyncSnapshot().failedCount, 0);
  });

  test('un fallo sin trabajo o sin mensaje no se acepta', () {
    expect(
      () => SyncFailure(jobId: '', message: 'algo'),
      throwsArgumentError,
    );
    expect(
      () => SyncFailure(jobId: 'catalog:uom', message: ''),
      throwsArgumentError,
    );
  });
}
