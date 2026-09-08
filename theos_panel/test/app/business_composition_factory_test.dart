import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/business_composition_factory.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/app/session_composition.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/features/approvals/approval_contracts.dart';

final class _Approval implements ApprovalPort {
  @override
  Future<List<ApprovalRequest>> pending() async => const [];
  @override
  Future<ApprovalResult> request(ApprovalRequest request) async =>
      const ApprovalResult(accepted: false, message: 'test');
  @override
  Future<ApprovalResult> resolve({
    required ApprovalRequest request,
    required ApprovalDecision decision,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async => const ApprovalResult(accepted: false, message: 'test');
  @override
  Future<ApprovalResult> performAction({
    required ApprovalRequest request,
    required ApprovalAction action,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async => const ApprovalResult(accepted: false, message: 'test');
}

AppScope _scope(String server) => AppScope(
  appId: 'theos_panel',
  installationId: 'install',
  normalizedServerUrl: server,
  database: 'db',
  userId: 7,
);
CapabilitySnapshot _cap(AppScope scope) => CapabilitySnapshot(
  scopeKey: scope.scopeKey,
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026),
);

// Scope rotation intentionally opens two independent databases. Distinct test
// database types keep Drift's runtime-type diagnostic from mistaking this
// fixture's closed scope boundary for two owners sharing one executor.
final class _ScopeADatabase extends AppDatabase {
  _ScopeADatabase() : super(NativeDatabase.memory());
}

final class _ScopeBDatabase extends AppDatabase {
  _ScopeBDatabase() : super(NativeDatabase.memory());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'replaces stale lease composition and rejects mismatched/offline restore',
    () async {
      final scopeA = _scope('https://a.example');
      final scopeB = _scope('https://b.example');
      var databaseNumber = 0;
      final runtime = SessionRuntime(
        databaseOwner: RuntimeDatabaseOwner(
          factory: (_) => databaseNumber++ == 0
              ? _ScopeADatabase()
              : _ScopeBDatabase(),
        ),
      );
      final factory = OrbiBusinessCompositionFactory(
        approvalBuilder: (_, _, _) => _Approval(),
      );

      expect(
        await factory.compose(runtime: runtime, capabilities: _cap(scopeA)),
        isNull,
      );
      expect(factory.current, isNull);

      await runtime.activate(scopeA);
      final first = await factory.compose(
        runtime: runtime,
        capabilities: _cap(scopeA),
      );
      expect(first, isNotNull);
      expect(first!.approvals, isA<_Approval>());
      expect(
        first.catalogs,
        isNull,
      ); // offline restore: no client, no sync graph
      final autoContainer = ProviderContainer(
        overrides: [
          runtimeSessionProvider.overrideWithValue(runtime),
          capabilitySnapshotProvider.overrideWithValue(_cap(scopeA)),
        ],
      );
      addTearDown(autoContainer.dispose);
      final autoBusiness = autoContainer.read(businessCompositionProvider);
      expect(autoBusiness?.saleCommands, isNotNull);
      expect(autoBusiness?.approvals, isNotNull);
      expect(autoBusiness?.catalogs, isNull);
      // Collections must remain available during an offline restore; the
      // runtime port persists the cashier intent and its Odoo actions fail
      // closed until the operations job reconnects.
      expect(autoBusiness?.collectionOperations, isNotNull);

      await runtime.activate(scopeB);
      final second = await factory.compose(
        runtime: runtime,
        capabilities: _cap(scopeB),
      );
      expect(second, isNotNull);
      expect(second!.lease, runtime.active!.lease);
      expect(factory.current, same(second));
      final container = ProviderContainer(
        overrides: [
          orbiSessionCompositionProvider.overrideWithValue(
            OrbiSessionComposition(business: second),
          ),
          runtimeSessionProvider.overrideWithValue(runtime),
          capabilitySnapshotProvider.overrideWithValue(_cap(scopeB)),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(approvalPortProvider), same(second.approvals));
      expect(container.read(scopeCatalogCompositionProvider), isNull);
      await factory.close();
      await runtime.close();
      expect(scopeB.scopeKey, isNot(scopeA.scopeKey));
    },
  );

  test(
    'online composition registers durable operations job on active scope',
    () async {
      final scope = _scope('https://online.example');
      final runtime = SessionRuntime(
        databaseOwner: RuntimeDatabaseOwner(
          factory: (_) => _ScopeADatabase(),
        ),
      );
      final factory = OrbiBusinessCompositionFactory(
        approvalBuilder: (_, _, _) => _Approval(),
      );
      await runtime.activate(scope, apiKey: 'test-key');
      final composition = await factory.compose(
        runtime: runtime,
        capabilities: _cap(scope),
      );
      addTearDown(() async {
        await factory.close();
        await runtime.close();
      });
      expect(composition?.catalogs, isNotNull);
      expect(composition?.collectionOperations, isNotNull);
      expect(composition!.catalogs!.jobs.containsKey('operations'), isTrue);
      expect(
        composition.catalogs!.jobs['operations'],
        isA<OperationsSyncJob>(),
      );
    },
  );
}
