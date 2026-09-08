import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/auth_controller.dart';
import 'orbi_splash_screen.dart';
import 'preferences/app_preferences.dart';
import 'orbi_app.dart';
import 'session_composition.dart';
import 'web_redirect.dart';

/// Web-only authentication bridge. It consumes the existing Odoo HttpOnly
/// session and never accepts a password or API key from browser state.
final class _WebSessionAuthService implements AuthServicePort {
  _WebSessionAuthService({
    required this.runtime,
    required this.installationIds,
    required this.identityReader,
    required this.capabilityPort,
  });

  final SessionRuntime runtime;
  final InstallationIdStore installationIds;
  final ActiveIdentityReader identityReader;
  final CapabilitySnapshotPort capabilityPort;
  AuthProfile? _profile;

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async {
    if (offline) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
    final client = OdooClient(
      config: OdooClientConfig(
        baseUrl: Uri.base.origin,
        apiKey: '',
        transportMode: OdooTransportMode.webSession,
        allowInsecure: Uri.base.scheme != 'https',
      ),
    );
    try {
      final response = await client.http.get('/orbi/bootstrap');
      final payload = Map<String, dynamic>.from(response.data as Map);
      final identity = Map<String, dynamic>.from(payload['identity'] as Map);
      final company = Map<String, dynamic>.from(payload['company'] as Map);
      final database = payload['database'] as String?;
      final userId = (identity['uid'] as num?)?.toInt();
      final csrf = payload['csrf_token'] as String?;
      if (database == null ||
          database.isEmpty ||
          userId == null ||
          csrf == null) {
        throw StateError('Invalid /orbi/bootstrap contract');
      }
      final installationId = await installationIds.loadOrCreate('theos_panel');
      final scope = AppScope(
        appId: 'theos_panel',
        installationId: installationId,
        normalizedServerUrl: Uri.base.origin,
        database: database,
        userId: userId,
      );
      final active = await runtime.activate(
        scope,
        webSession: true,
        csrfToken: csrf,
      );
      final effective = await identityReader.read(scope);
      final profile = AuthProfile(
        serverUrl: scope.normalizedServerUrl,
        database: database,
        login: identity['login'] as String? ?? '',
        userId: userId,
        installationId: installationId,
        credentialReference: 'odoo-http-session',
        companyId: (company['id'] as num).toInt(),
        allowedCompanyIds: effective.allowedCompanyIds,
      );
      _profile = profile;
      return AuthServiceResult(
        status: AuthServiceStatus.restored,
        scope: active.scope,
        profile: profile,
        capabilities: await capabilityPort.refresh(scope, effective.companyId),
      );
    } catch (_) {
      // Keep local durable queues untouched; an expired browser session simply
      // returns to reauthentication and never falls back to bearer credentials.
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
  }

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthProfile?> loadProfile() async => _profile;
  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => _profile;
  @override
  Future<void> close() => runtime.close();
}

final class _SessionIdentityReader implements ActiveIdentityReader {
  const _SessionIdentityReader(this.runtime);
  final SessionRuntime runtime;
  @override
  Future<({int companyId, List<int> allowedCompanyIds})> read(AppScope scope) {
    final active = runtime.active;
    if (active == null || active.scope != scope || active.client == null) {
      return Future.error(StateError('Active Odoo session is required'));
    }
    return OdooActiveIdentityReader(active.client!).read(scope);
  }
}

final class _SessionCapabilityReader implements CapabilityReader {
  const _SessionCapabilityReader(this.runtime);
  final SessionRuntime runtime;
  @override
  Future<CapabilitySnapshot> fetch(AppScope scope, int companyId) {
    final active = runtime.active;
    if (active == null || active.scope != scope || active.client == null) {
      return Future.error(StateError('Active Odoo session is required'));
    }
    return OdooCapabilityReader(active.client!).read(
      scope: scope,
      companyId: companyId,
      revision: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapHost());
}

final class _BootstrapHost extends StatefulWidget {
  const _BootstrapHost();

  @override
  State<_BootstrapHost> createState() => _BootstrapHostState();
}

final class _BootstrapHostState extends State<_BootstrapHost> {
  late Future<Widget> _application = _initializeApplication();

  void _retry() {
    setState(() => _application = _initializeApplication());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _application,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.requireData;
      if (snapshot.hasError) {
        return MaterialApp(
          title: 'Orbi ERP',
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No se pudo preparar Orbi ERP.',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tus datos locales no se han eliminado. Puedes intentarlo de nuevo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return MaterialApp(
        title: 'Orbi ERP',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007E82)),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007E82),
            brightness: Brightness.dark,
          ),
        ),
        home: const OrbiSplashScreen(),
      );
    },
  );
}

Future<Widget> _initializeApplication() async {
  // Keep a real Flutter surface visible while plugins, secure storage and the
  // bounded session restore initialize. This replaces the previous blank wait
  // before runApp without adding an artificial startup delay.
  final preferences = await SharedPreferences.getInstance();
  final random = Random.secure();
  final sessionRuntime = SessionRuntime();
  final installationIds = InstallationIdStore(
    SharedPreferencesInstallationIdBackend(preferences),
    generator: () =>
        base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)))
            .replaceAll('=', ''),
  );
  final installationId = await installationIds.loadOrCreate('theos_panel');
  final notificationIds = NotificationSystemIdRegistry(
    preferences: preferences,
    appId: 'theos_panel',
    installationId: installationId,
  );
  final notificationPresenter = SystemNotificationPresenter(
    FlutterLocalNotificationPlugin(),
    notificationIds,
    activeScopeKey: 'unconfigured',
  );
  await notificationPresenter.initialize();
  final service = NativeAuthService(
    credentialStore: CredentialStore(
      FlutterSecureCredentialBackend(),
      durability: CredentialDurability.secureStore,
    ),
    preferences: preferences,
    sessionRuntime: sessionRuntime,
    installationIds: installationIds,
    identityReader: _SessionIdentityReader(sessionRuntime),
    capabilityPort: RuntimeCapabilitySnapshotPort(
      RuntimeCapabilityService(
        owner: sessionRuntime.databaseOwner,
        reader: _SessionCapabilityReader(sessionRuntime),
      ),
    ),
  );
  final webService = _WebSessionAuthService(
    runtime: sessionRuntime,
    installationIds: installationIds,
    identityReader: _SessionIdentityReader(sessionRuntime),
    capabilityPort: RuntimeCapabilitySnapshotPort(
      RuntimeCapabilityService(
        owner: sessionRuntime.databaseOwner,
        reader: _SessionCapabilityReader(sessionRuntime),
      ),
    ),
  );
  // One bounded online restore, with one explicit offline fallback.
  final restored = await restoreOnce(
    kIsWeb ? webService : NativeAuthServicePort(service),
  );
  if (kIsWeb && restored.status == AuthServiceStatus.required) {
    redirectToOdooLogin();
  }
  final composition = OrbiSessionComposition(
    authService: kIsWeb ? webService : NativeAuthServicePort(service),
    runtime: sessionRuntime,
    notificationPresenter: notificationPresenter,
    notificationIds: notificationIds,
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      ...composition.overrides,
      authInitialStateProvider.overrideWithValue(
        authViewStateFromResult(restored),
      ),
    ],
    child: const OrbiApp(),
  );
}
