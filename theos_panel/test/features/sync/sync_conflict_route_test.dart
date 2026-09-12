// Verifies the SYN-03 wiring from `router.dart`'s "Abrir conflictos" action:
// it must no longer show the old fixed `AlertDialog` and must actually reach
// a real screen, not just a registered-but-unreachable route (the exact
// class of bug `route_access_policy.dart` hit elsewhere in this branch — see
// team notes on exact-path matching for a nested route).
import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/app/session_composition.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/sync/sync_center.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _Auth implements AuthServicePort {
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.authenticated);
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() async => null;
  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;
  @override
  Future<void> close() async {}
}

final class _FakeSyncCenterPort implements SyncCenterPort {
  _FakeSyncCenterPort(this._snapshot);
  final SyncCenterSnapshot _snapshot;

  @override
  SyncCenterSnapshot get snapshot => _snapshot;
  @override
  Stream<SyncCenterSnapshot> get snapshots => const Stream.empty();
  @override
  Future<void> retry() async {}
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'opening conflicts reaches SYN-03 and never the old fixed dialog',
    (tester) async {
      final capabilities = CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime(2026),
        permissions: const ['administrator', 'sync'],
      );
      final fakeSync = _FakeSyncCenterPort(
        SyncCenterSnapshot(
          sync: SyncSnapshot(
            conflicts: [
              SyncConflict(
                jobId: 'operations',
                documentLabel: 'sale.order #482',
                message:
                    'El servidor cambió este registro después de encolarlo.',
              ),
            ],
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_Auth()),
          capabilitySnapshotProvider.overrideWithValue(capabilities),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          orbiSessionCompositionProvider.overrideWithValue(
            OrbiSessionComposition(sync: fakeSync),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(theme: OrbiFluentTheme.light, routerConfig: router),
        ),
      );
      await container.read(authControllerProvider.notifier).login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'administrator',
        password: 'secret',
      );
      final authenticatedRouter = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(theme: OrbiFluentTheme.light, routerConfig: authenticatedRouter),
        ),
      );
      await tester.pumpAndSettle();

      authenticatedRouter.go('/sync');
      await tester.pumpAndSettle();
      expect(authenticatedRouter.state.uri.path, '/sync');

      // The conflict count in the fake snapshot is what makes this button
      // exist at all (see `sync_center.dart`'s `_body`).
      final openConflicts = find.text('Abrir conflictos');
      expect(openConflicts, findsOneWidget);
      await tester.tap(openConflicts);
      await tester.pumpAndSettle();

      // The old, fixed placeholder must be gone for good.
      expect(find.byType(ContentDialog), findsNothing);
      expect(find.text('Conflictos de sincronización'), findsNothing);
      expect(
        find.text(
          'Hay operaciones que requieren revisión. '
          'No se reintentará ni resolverá automáticamente.',
        ),
        findsNothing,
      );

      // Navigation actually reached the SYN-03 slot — proven by its own
      // AppBar title — rather than doing nothing or crashing. No `catalogs`
      // composition was supplied here, so there is no live queue and the
      // explicit not-configured fallback is what should show, never a
      // silent dead end.
      expect(find.text('Resolver conflicto'), findsOneWidget);
      expect(find.textContaining('no configurado'), findsOneWidget);
    },
  );
}
