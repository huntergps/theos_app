import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/login_failure_messages.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/workspace_unlock_store.dart';
import 'orbi_splash_screen.dart';
import 'preferences/app_preferences.dart';
import 'orbi_app.dart';
import 'session_composition.dart';

/// The splash is visible for about 1.2 seconds on a fast cold start. This is
/// a lower bound, not an additional startup delay: slow initialization uses
/// the time it already needed and does not wait again.
const minimumSplashDuration = Duration(milliseconds: 1200);
const _bootstrapTransitionDuration = Duration(milliseconds: 300);

Future<void> _defaultSplashDelay(Duration duration) =>
    Future<void>.delayed(duration);

/// Waits only for the portion of the splash budget not already spent by
/// initialization. The delay callback keeps this deterministic in tests.
Future<void> ensureMinimumSplashDuration({
  required Duration elapsed,
  Duration minimum = minimumSplashDuration,
  Future<void> Function(Duration) delay = _defaultSplashDelay,
}) {
  final remaining = minimum - elapsed;
  if (remaining <= Duration.zero) return Future<void>.value();
  return delay(remaining);
}

/// Resolves reduced-motion from the nearest [MediaQuery], or from the engine
/// when bootstrap is still above [MaterialApp] and no inherited media query
/// exists yet.
bool bootstrapDisableAnimations({
  required bool? mediaQueryDisableAnimations,
  required bool platformDisableAnimations,
}) => mediaQueryDisableAnimations ?? platformDisableAnimations;

/// Crossfades the bootstrap surface without introducing a black frame or a
/// spatial motion effect. [phaseKey] changes when the splash is replaced by
/// the initialized app, allowing both surfaces to overlap during the fade.
class BootstrapAnimatedContent extends StatelessWidget {
  const BootstrapAnimatedContent({
    required this.phaseKey,
    required this.child,
    super.key,
  });

  final Object phaseKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = bootstrapDisableAnimations(
      mediaQueryDisableAnimations: MediaQuery.maybeOf(context)
          ?.disableAnimations,
      platformDisableAnimations: WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations,
    );
    final duration = reduceMotion
        ? Duration.zero
        : _bootstrapTransitionDuration;
    return ColoredBox(
      color: const Color(0xFFF7F9FA),
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: duration,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          // Bootstrap lives above MaterialApp, so no Directionality exists
          // yet. Use an absolute alignment to avoid failing before the first
          // splash frame on a real native runner.
          alignment: Alignment.topLeft,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (transitionChild, animation) =>
            FadeTransition(opacity: animation, child: transitionChild),
        child: KeyedSubtree(key: ValueKey<Object>(phaseKey), child: child),
      ),
    );
  }
}

/// In-memory-only [CredentialBackend]. Backs the web API-key path with
/// `CredentialDurability.webSessionOnly` (declared in orbi_runtime and,
/// before this, never wired to production): the secret lives only in this
/// tab's Dart heap, never in SharedPreferences/localStorage, and a fresh
/// instance — created on every cold start — begins empty. `clear()` lets
/// [WebSessionAuthService.close] drop the key immediately on logout instead
/// of waiting for a reload, in case the tab stays open.
final class _InMemoryCredentialBackend implements CredentialBackend {
  final _values = <String, String>{};

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async => _values.remove(key);

  void clear() => _values.clear();
}

/// Web-only authentication bridge.
///
/// `restore()`/`login()` are unchanged: they only ever consume the existing
/// Odoo HttpOnly session (the same-origin connector this app will use once
/// an addon serves `/orbi/bootstrap`) and never accept a password from
/// browser state. Password login in the browser stays unsupported here on
/// purpose — that gap is a CORS/same-origin decision another workstream is
/// resolving, not something this class can paper over.
///
/// `loginWithApiKey()` is what W02 unblocks: pasting an already-issued Odoo
/// API key, exactly like theos_pos's own web build already does. It forwards
/// to an internal [NativeAuthService] wired to [_InMemoryCredentialBackend]
/// instead of secure storage, so the key never reaches browser storage; a
/// page reload always starts from an empty store and the user must paste it
/// again. That matches theos_pos's (undocumented) behavior — conservative,
/// but a real recurring cost on every reload, which is the owner's call to
/// change, not this class's.
///
/// This closes the API-key gap only. It does not close web/native parity:
/// username+password in the browser is still blocked on the CORS decision
/// above. See docs/orbi_panel/decisions/W02-web-clave-api-pegada.md.
final class WebSessionAuthService
    implements
        AuthServicePort,
        ApiKeyAuthServicePort,
        CredentialPolicyAuthServicePort {
  WebSessionAuthService({
    required this.runtime,
    required this.installationIds,
    required this.identityReader,
    required this.capabilityPort,
    required SharedPreferences preferences,
    // Test-only seams: production always probes the real Odoo server and
    // shares the real session runtime declared above.
    ApiKeyIdentityProbe? apiKeyIdentityProbe,
    SessionRuntimePort? apiKeyRuntimePort,
  }) {
    _apiKeyPort = NativeAuthServicePort(
      NativeAuthService(
        credentialStore: CredentialStore(
          _apiKeyBackend,
          durability: CredentialDurability.webSessionOnly,
        ),
        preferences: preferences,
        sessionRuntime: runtime,
        runtimePort: apiKeyRuntimePort,
        installationIds: installationIds,
        identityReader: identityReader,
        capabilityPort: capabilityPort,
        apiKeyIdentityProbe: apiKeyIdentityProbe,
      ),
    );
  }

  final SessionRuntime runtime;
  final InstallationIdStore installationIds;
  final ActiveIdentityReader identityReader;
  final CapabilitySnapshotPort capabilityPort;
  final _InMemoryCredentialBackend _apiKeyBackend = _InMemoryCredentialBackend();
  late final NativeAuthServicePort _apiKeyPort;
  AuthProfile? _profile;

  /// Test-only window into the in-memory store, so a test can prove the
  /// pasted key actually disappears on [close] instead of merely trusting a
  /// comment. Never read in production code.
  @visibleForTesting
  Map<String, String> get debugStoredApiKeyValues =>
      Map.unmodifiable(_apiKeyBackend._values);

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
    bool persistCredential = true,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);

  /// Activates a session from an already-issued Odoo API key, the same
  /// pasted-key path theos_pos already ships in its web build. The key never
  /// becomes profile metadata or touches browser storage: it is handed
  /// straight to [_apiKeyBackend], an in-memory [CredentialBackend].
  @override
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
  }) async {
    final result = await _apiKeyPort.loginWithApiKey(
      serverUrl: serverUrl,
      database: database,
      login: login,
      apiKey: apiKey,
      persistCredential: persistCredential,
    );
    if (result.status == AuthServiceStatus.authenticated) {
      _profile = result.profile;
    }
    return result;
  }

  @override
  Future<AuthProfile?> loadProfile() async =>
      _profile ?? await _apiKeyPort.loadProfile();
  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => _profile ?? await _apiKeyPort.loadProfileFor(serverUrl, database);
  @override
  Future<void> close() async {
    // Drop the pasted key immediately on logout, in case the tab stays open
    // instead of reloading — never rely solely on the next reload to clear
    // it.
    _apiKeyBackend.clear();
    _profile = null;
    await runtime.close();
  }
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
      final Widget content;
      final Object phaseKey;
      if (snapshot.hasData) {
        content = snapshot.requireData;
        phaseKey = 'application';
      } else if (snapshot.hasError) {
        content = MaterialApp(
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
        phaseKey = 'error';
      } else {
        content = MaterialApp(
          title: 'Orbi ERP',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF007E82),
            ),
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
        phaseKey = 'splash';
      }
      return BootstrapAnimatedContent(phaseKey: phaseKey, child: content);
    },
  );
}

Future<Widget> _initializeApplication() async {
  // Keep a real Flutter surface visible while plugins, secure storage and the
  // bounded session restore initialize. The stopwatch makes the splash budget
  // a minimum total duration, so a slow restore is never delayed twice.
  final startupStopwatch = Stopwatch()..start();
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
  final webService = WebSessionAuthService(
    runtime: sessionRuntime,
    installationIds: installationIds,
    identityReader: _SessionIdentityReader(sessionRuntime),
    capabilityPort: RuntimeCapabilitySnapshotPort(
      RuntimeCapabilityService(
        owner: sessionRuntime.databaseOwner,
        reader: _SessionCapabilityReader(sessionRuntime),
      ),
    ),
    preferences: preferences,
  );
  // One bounded online restore, with one explicit offline fallback.
  //
  // This used to force-navigate to `/web/login` whenever the cookie-session
  // restore above failed on web — a route that only exists once a same-
  // origin Odoo connector serves `/orbi/bootstrap`. Nothing serves it yet,
  // so that redirect fired on every real web cold start and sent the tab to
  // a 404 before the Orbi login screen — with its API key toggle — ever
  // painted, regardless of which credential mode the user wanted. Falling
  // through to `required` instead lets the in-app router show /login, the
  // same as every other unauthenticated status already does.
  final restored = await restoreOnce(
    kIsWeb ? webService : NativeAuthServicePort(service),
  );
  final composition = OrbiSessionComposition(
    authService: kIsWeb ? webService : NativeAuthServicePort(service),
    runtime: sessionRuntime,
    notificationPresenter: notificationPresenter,
    notificationIds: notificationIds,
  );
  await ensureMinimumSplashDuration(elapsed: startupStopwatch.elapsed);
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      // Hands the workspace lock screen somewhere to keep a derivation of the
      // password, so it can be opened with no network — the operating system's
      // secure store on native, nothing at all on the web. It lives here and
      // not in the provider's own default on purpose: a plugin-backed platform
      // channel never completes inside a widget test's fake-async zone, and
      // `AuthNotifier.login`/`close` await this store, so a live default
      // deadlocks every widget test that did not ask for storage. See
      // `workspaceUnlockBackendProvider`.
      workspaceUnlockBackendOverride,
      // Same inert-by-default shape, same reason: the connectivity plugin is
      // a platform channel, and the login screen awaits it when a connection
      // fails. Registered here so only a real device consults it — see
      // `networkPresenceProbeProvider`.
      networkPresenceProbeOverride,
      ...composition.overrides,
      authInitialStateProvider.overrideWithValue(
        authViewStateFromResult(restored),
      ),
    ],
    child: const OrbiApp(),
  );
}
