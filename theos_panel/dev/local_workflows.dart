import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/app/orbi_app.dart';
import 'package:theos_panel/app/bootstrap.dart';
import 'package:theos_panel/app/orbi_splash_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/session_composition.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

import 'local_workflow_fixtures.dart';

const localWorkflowServer = 'https://orbi.invalid';
const localWorkflowDatabase = 'local_workflow';
const localWorkflowLogin = 'demo';
const localWorkflowPassword = 'orbi-demo';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.ensureSemantics();
  // Exercise the same branded surface and crossfade as production without
  // connecting the local fixture runner to an Odoo server.
  final startup = Stopwatch()..start();
  runApp(
    BootstrapAnimatedContent(
      phaseKey: 'local-startup',
      child: FluentApp(
        theme: OrbiFluentTheme.light,
        home: const OrbiSplashScreen(),
      ),
    ),
  );
  final preferences = await SharedPreferences.getInstance();
  final runtime = SessionRuntime();
  late ProviderContainer container;
  final auth = _LocalWorkflowAuth(
    runtime,
    onCatalogsChanged: (catalogs) => container
        .read(localWorkflowCatalogCompositionProvider.notifier)
        .setComposition(catalogs),
  );
  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      authServiceProvider.overrideWithValue(auth),
      runtimeSessionProvider.overrideWithValue(runtime),
      authInitialStateProvider.overrideWithValue(const AuthViewState()),
      orbiSessionCompositionProvider.overrideWithValue(
        OrbiSessionComposition(authService: auth, runtime: runtime),
      ),
      scopeCatalogCompositionProvider.overrideWith(
        (ref) => ref.watch(localWorkflowCatalogCompositionProvider),
      ),
    ],
  );
  await ensureMinimumSplashDuration(elapsed: startup.elapsed);
  runApp(
    BootstrapAnimatedContent(
      phaseKey: 'local-ready',
      child: UncontrolledProviderScope(
        container: container,
        child: const OrbiApp(),
      ),
    ),
  );
}

final class _LocalWorkflowAuth implements AuthServicePort {
  _LocalWorkflowAuth(this.runtime, {required this.onCatalogsChanged});

  final SessionRuntime runtime;
  final void Function(RuntimeCatalogComposition? catalogs) onCatalogsChanged;
  AuthProfile? _profile;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async {
    if (serverUrl.trim() != localWorkflowServer ||
        database.trim() != localWorkflowDatabase ||
        login.trim() != localWorkflowLogin ||
        password != localWorkflowPassword) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
    final scope = AppScope(
      appId: 'theos_panel',
      installationId: 'local-workflow-browser',
      normalizedServerUrl: localWorkflowServer,
      database: localWorkflowDatabase,
      userId: 7,
    );
    final active = await runtime.activate(scope);
    await seedLocalEnvasesExistencias(runtime: runtime, scope: scope);
    final catalogs = await seedLocalSaleCatalogs(
      runtime: runtime,
      scope: scope,
    );
    onCatalogsChanged(catalogs);
    final capabilities = CapabilitySnapshot(
      scopeKey: scope.scopeKey,
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.now().toUtc(),
      permissions: const {'seller', 'envases_read'},
    );
    _profile = AuthProfile(
      serverUrl: localWorkflowServer,
      database: localWorkflowDatabase,
      login: localWorkflowLogin,
      userId: 7,
      installationId: scope.installationId,
      credentialReference: 'local-workflow-demo',
      companyId: 1,
      allowedCompanyIds: const [1],
    );
    return AuthServiceResult(
      status: AuthServiceStatus.authenticated,
      scope: active.scope,
      profile: _profile,
      capabilities: capabilities,
    );
  }

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthProfile?> loadProfile() async => _profile;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => _profile;

  @override
  Future<void> close() async {
    _profile = null;
    onCatalogsChanged(null);
    await runtime.close();
  }
}
