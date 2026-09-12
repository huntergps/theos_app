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
import '../features/auth/unlock_backend_factory.dart';
import '../features/auth/web_token_auth.dart';
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
/// `loginWithApiKey()` forwards to an internal [NativeAuthService] wired to
/// whatever [CredentialBackend] the composition root supplies.
///
/// 🔴 **It used to be hard-wired to [_InMemoryCredentialBackend], so the key
/// died with the tab and the user pasted it again on every reload.** That was
/// this class's own call — the doc here said so — and the owner revoked it on
/// 11-sep-2026: «yo he dicho que navegador también guarda igual que
/// escritorio». The browser now persists, through
/// `WebCryptoCredentialBackend`: AES-GCM under a **non-extractable** key kept
/// in IndexedDB, which the page's code can use and cannot read. See
/// `docs/orbi_panel/decisions/W04-el-navegador-tambien-guarda.md`, and with it
/// [CredentialDurability.webSessionOnly] stops being the web's lot.
///
/// The backend stays **injected rather than constructed here**, and the
/// default stays in-memory, for a reason measured the hard way: a
/// plugin-backed or browser-backed store never completes inside a widget
/// test's fake-async zone, so a durable default would deadlock every test that
/// builds this service without asking for storage.
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
    /// Where the issued API key is kept. `null` keeps the historical
    /// tab-lifetime behaviour; the composition root passes the browser's
    /// durable, encrypted store so a reload no longer costs a new login.
    CredentialBackend? credentialBackend,
    /// Calls `POST /orbi/auth/token`. `null` leaves password login in the
    /// browser unavailable instead of half-working.
    this.tokenClient,
    // Test-only seams: production always probes the real Odoo server and
    // shares the real session runtime declared above.
    ApiKeyIdentityProbe? apiKeyIdentityProbe,
    SessionRuntimePort? apiKeyRuntimePort,
  }) : _apiKeyBackend = credentialBackend ?? _InMemoryCredentialBackend(),
       _durable = credentialBackend != null {
    _apiKeyPort = NativeAuthServicePort(
      NativeAuthService(
        credentialStore: CredentialStore(
          _apiKeyBackend,
          // Says what is actually true of the backend above, instead of
          // claiming session-only for a store that now survives the tab.
          durability: _durable
              ? CredentialDurability.secureStore
              : CredentialDurability.webSessionOnly,
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
  /// Mints the scoped, expiring API key from a username and password.
  final OrbiWebTokenAuthClient? tokenClient;
  final CredentialBackend _apiKeyBackend;
  final bool _durable;
  late final NativeAuthServicePort _apiKeyPort;
  AuthProfile? _profile;

  /// Whether the issued key outlives the tab. `false` means a reload starts
  /// from an empty store, which is the historical behaviour the owner revoked.
  bool get keepsCredentialAcrossReloads => _durable;

  /// Test-only window into the in-memory store, so a test can prove the
  /// pasted key actually disappears on [close] instead of merely trusting a
  /// comment. Never read in production code. Empty for a durable backend,
  /// whose contents are asserted against the real store in `test/web/`.
  @visibleForTesting
  Map<String, String> get debugStoredApiKeyValues {
    final backend = _apiKeyBackend;
    return backend is _InMemoryCredentialBackend
        ? Map.unmodifiable(backend._values)
        : const {};
  }

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async {
    // An offline start has no cookie session to probe, so the only thing that
    // can bring the session back is the stored credential.
    if (offline) return _restoreFromStoredCredential(offline: true);
    try {
      // Built INSIDE the try on purpose: `Uri.base.origin` throws outright for
      // any scheme that is not http(s), and this method must never throw —
      // every failure here means "go to the login screen", which is what the
      // catch below decides. Outside the try it escaped instead, so a host
      // without an http base took down the restore rather than falling back.
      final client = OdooClient(
        config: OdooClientConfig(
          baseUrl: Uri.base.origin,
          apiKey: '',
          transportMode: OdooTransportMode.webSession,
          allowInsecure: Uri.base.scheme != 'https',
        ),
      );
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
      // Keep local durable queues untouched.
      //
      // 🔴 This used to end here with `required` and a comment saying it
      // "never falls back to bearer credentials". That was true and correct
      // while the browser stored none: there was nothing to fall back TO. Now
      // that it keeps an encrypted, expiring key (W04), stopping here would
      // make persisting it pointless — the key would sit in IndexedDB while
      // the user retyped their password on every reload, which is exactly the
      // cost the owner asked us to remove.
      return _restoreFromStoredCredential(offline: false);
    }
  }

  /// Brings the session back from the API key kept by [_apiKeyBackend].
  ///
  /// Only when that backend is durable: with the tab-lifetime default there is
  /// nothing stored and this would be a pointless round trip. The inner
  /// service reads the saved profile, reads the credential under its scoped
  /// name and reactivates the runtime — the same path native has always used
  /// for a cold start, which is the whole point of "igual que escritorio".
  ///
  /// Never throws: a failed restore is a return to the login screen, never a
  /// crash at startup.
  Future<AuthServiceResult> _restoreFromStoredCredential({
    required bool offline,
  }) async {
    if (!_durable) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
    try {
      return await _apiKeyPort.restore(offline: offline);
    } catch (_) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
  }

  @override
  /// Username and password in the browser, in the two steps the route makes
  /// possible: ask `POST /orbi/auth/token` for a scoped, expiring API key, then
  /// hand that key to the path that already worked.
  ///
  /// 🔴 This used to `return required` without touching the network at all,
  /// which is why pressing "Entrar" in the browser produced **zero requests,
  /// zero messages and a cleared field**: the browser was not failing to log
  /// in, it was not trying. See `WEB_AUTH.md` in
  /// `l10n_ec_collection_box_pos` for why a token is needed instead of
  /// `/web/session/authenticate` — that core route declares no CORS, so the
  /// browser's preflight gets a 415 before the password ever leaves the page.
  ///
  /// Without a token client this keeps returning `required`, rather than
  /// pretending: the client is inert by default and the composition root
  /// supplies the real one (same reason as every other platform-backed seam
  /// here — a real socket in a widget test's fake-async zone never completes).
  ///
  /// The client's exception is deliberately **allowed to propagate**.
  /// `AuthNotifier.login` catches it and turns it into words with
  /// `describeLoginFailure`, which knows sixteen distinct causes; flattening it
  /// into `AuthServiceStatus.required` here would put back exactly the silent
  /// failure that was just removed.
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential = true,
  }) async {
    final client = tokenClient;
    if (client == null) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
    final token = await client.issue(
      serverUrl: serverUrl,
      login: login,
      password: password,
      database: database,
    );
    return _apiKeyPort.loginWithApiKey(
      serverUrl: serverUrl,
      // The database the SERVER says it served, never the one that was typed:
      // the route refuses a mismatch rather than entering another database, so
      // its answer is the authoritative one.
      database: token.database,
      login: login,
      apiKey: token.apiKey,
      persistCredential: persistCredential,
    );
  }

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
    // 🔴 This used to just empty an in-memory map, which was enough only while
    // the key died with the tab. The moment the browser started persisting
    // (W04), clearing a map stopped deleting anything durable — a logout would
    // have left a live, replayable API key in IndexedDB. Delegating to the
    // inner service is what actually removes it: `NativeAuthService.close()`
    // rebuilds the scope from the saved profile and deletes the namespaced
    // credential, then ends the runtime session in its own `finally`.
    //
    // This is the single path behind both "Cerrar sesión" and "Cambiar de
    // usuario", so it is the one place that has to be right.
    await _apiKeyPort.close();
    // Belt and braces for the tab-lifetime backend, whose entries are not
    // namespaced by a profile that may never have been written.
    final backend = _apiKeyBackend;
    if (backend is _InMemoryCredentialBackend) backend.clear();
    _profile = null;
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
  // The browser keeps its credential now (W04). On a native target this
  // service is never the one selected, so building its backend costs nothing.
  final webService = WebSessionAuthService(
    credentialBackend: createUnlockCredentialBackend(),
    // Password login in the browser, which until now returned `required`
    // without sending a single request.
    tokenClient: OrbiWebTokenAuthClient(transport: odooSdkTokenTransport()),
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
      // Anything that reads the client through Riverpod gets the real one too,
      // not just the service built above.
      orbiWebTokenClientOverride,
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
