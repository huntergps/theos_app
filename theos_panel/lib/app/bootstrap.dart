import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/login_failure_messages.dart';
import '../features/sync/network_signal_provider.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/unlock_backend_factory.dart';
import '../features/auth/web_token_auth.dart';
import '../features/auth/workspace_unlock_store.dart';
import '../ui/fluent/orbi_fluent_theme.dart';
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
/// when bootstrap is still above [FluentApp] and no inherited media query
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
      // 🔴 Color escrito a mano A PROPÓSITO, no un olvido: este widget corre
      // POR ENCIMA de FluentApp, antes de que exista ningún árbol — no hay
      // FluentTheme del que heredar todavía (ver el comentario de más abajo,
      // "Bootstrap lives above FluentApp"). No lo reemplaces por un color de
      // tema ni lo quites creyendo que quedó suelto (orden del dueño,
      // 12-sep-2026: fuera de esta excepción, todo color sale del tema).
      color: const Color(0xFFF7F9FA),
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: duration,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          // Bootstrap lives above FluentApp, so no Directionality exists
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
/// 🔴 **`restore()` used to try the inherited Odoo HttpOnly session first**,
/// hitting a same-origin session-bootstrap connector before ever looking at
/// any stored credential. That connector never shipped as a durable feature,
/// and the dueño's decision on 12-sep-2026 — Orbi web lives only at
/// `orbi.galapagos.tech`, never same-origin with an Odoo backend — retired it
/// for good: the connector and its companion logout route both measure 404 on
/// ERP2 and Mepriga now. This is dead code against a server that no longer
/// serves it: nothing here reproduces a defect anyone actually saw on
/// screen. It is removed anyway because it was a latent risk regardless — a
/// browser's leftover Odoo session cookie for one person outliving `close()`
/// (which only ever revoked a bearer key, never that cookie) could in
/// principle get silently re-adopted on a later `restore()` and disagree with
/// whoever had since logged in with their own API key (see
/// `identity_after_user_change_test.dart`, which models that risk without
/// claiming it was ever observed). `restore()` now goes straight to the
/// stored bearer credential — see `_restoreFromStoredCredential` — with
/// nothing else to try first.
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
        CredentialPolicyAuthServicePort,
        ExpirableAuthServicePort,
        RenewableAuthServicePort,
        StoredCredentialAuthServicePort {
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
  // 🔴 This used to try a same-origin session-bootstrap connector first (the
  // inherited Odoo HttpOnly session) and only fall back to the stored
  // bearer credential when that failed. Removed for good on 12-sep-2026:
  // no server serves that connector any more (measured 404 on ERP2 and
  // Mepriga, now that Orbi web lives only at `orbi.galapagos.tech`), which
  // makes this dead code, not a fix for anything witnessed on screen — see
  // the class doc above for the latent risk it removes anyway. There is
  // nothing left to try before the stored credential, offline or not.
  Future<AuthServiceResult> restore({bool offline = false}) =>
      _restoreFromStoredCredential(offline: offline);

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
    final result = await _apiKeyPort.service.loginWithApiKey(
      serverUrl: serverUrl,
      // The database the SERVER says it served, never the one that was typed:
      // the route refuses a mismatch rather than entering another database, so
      // its answer is the authoritative one.
      database: token.database,
      login: login,
      apiKey: token.apiKey,
      persistCredential: persistCredential,
      // Esta llave vino de una contraseña (`/orbi/auth/token`), no de que el
      // operador la pegara a mano: sin «Guardar clave», `close()` debe
      // revocarla al cerrar sesión, igual que en escritorio.
      passwordDerived: true,
    );
    // A diferencia del bootstrap nativo (que calcula la expiración desde su
    // propio wizard), esta ruta la RECIBE explícita en la respuesta de
    // `/orbi/auth/token` — grabarla es lo que permite renovar proactivamente
    // antes de que caduque (auditoría de sesión, 13-sep-2026). Best-effort:
    // nunca debe convertir un login ya exitoso en un fallo.
    if (result.status == AuthServiceStatus.authenticated) {
      try {
        await _apiKeyPort.service.recordApiKeyLifetime(
          issuedAt: DateTime.now().toUtc(),
          expiresAt: token.expiresAt,
        );
      } catch (_) {}
    }
    return result;
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
    // 🔴 Hasta el 13-sep-2026 esto delegaba en un `NativeAuthService.close()`
    // que SIEMPRE revocaba y borraba la llave de este dispositivo — antes de
    // W04, ni eso: sólo vaciaba un mapa en memoria, que ya no bastaba en
    // cuanto el navegador empezó a persistir (una llave viva se habría
    // quedado en IndexedDB sin que este `close()` se enterara). Ahora, por
    // decisión del dueño («Recordar la llave tras salir»,
    // `W04-el-navegador-tambien-guarda.md`), `NativeAuthService.close()`
    // tampoco toca la llave: sólo termina la sesión en memoria. Con eso, si
    // el operador entró con «Guardar clave», su llave sigue en el almacén
    // cifrado del navegador después de esto — igual que en escritorio — y
    // `forgetStoredCredential`/`closeExpired` son los únicos caminos que
    // todavía la borran.
    //
    // Esto es el único camino detrás de "Cerrar sesión" y "Cambiar de
    // usuario", así que es el único sitio que tiene que estar bien.
    await _apiKeyPort.close();
    // Belt and braces for the tab-lifetime backend, whose entries are not
    // namespaced by a profile that may never have been written.
    final backend = _apiKeyBackend;
    if (backend is _InMemoryCredentialBackend) backend.clear();
    _profile = null;
  }

  // Variante para cuando el SERVIDOR ya rechazó la clave — ver
  // `NativeAuthService.closeExpired`: nunca intenta revocarla, sólo borra la
  // copia local y cierra el runtime. Auditoría de sesión, 13-sep-2026.
  @override
  Future<void> closeExpired() async {
    await _apiKeyPort.closeExpired();
    final backend = _apiKeyBackend;
    if (backend is _InMemoryCredentialBackend) backend.clear();
    _profile = null;
  }

  // Igual que en native: el ciclo de renovación proactiva vive entero en
  // `NativeAuthService`, compartido por los dos caminos. Auditoría de
  // sesión, 13-sep-2026.
  @override
  Future<void> renewApiKeyIfNeeded() => _apiKeyPort.renewApiKeyIfNeeded();

  // «Recordar la llave tras salir» (decisión del dueño, 13-sep-2026): el
  // mismo mecanismo que en escritorio, compartido vía `NativeAuthService` —
  // aquí sólo delega, salvo `loginWithStoredCredential`, que además tiene
  // que actualizar `_profile` como ya hace `loginWithApiKey` arriba.
  @override
  Future<AuthProfile?> findRememberedCredential(
    String serverUrl,
    String database,
    String login,
  ) => _apiKeyPort.findRememberedCredential(serverUrl, database, login);

  @override
  Future<AuthServiceResult> loginWithStoredCredential(
    AuthProfile profile,
  ) async {
    final result = await _apiKeyPort.loginWithStoredCredential(profile);
    if (result.status == AuthServiceStatus.authenticated) {
      _profile = result.profile;
    }
    return result;
  }

  @override
  Future<void> forgetStoredCredential(AuthProfile profile) =>
      _apiKeyPort.forgetStoredCredential(profile);

  @override
  Future<bool> hasStoredCredential(AuthProfile profile) =>
      _apiKeyPort.hasStoredCredential(profile);
}

final class _SessionIdentityReader implements ActiveIdentityReader {
  const _SessionIdentityReader(this.runtime);
  final SessionRuntime runtime;
  @override
  Future<
    ({
      int companyId,
      String? companyName,
      String? name,
      List<int> allowedCompanyIds,
      String? lang,
      String? tz,
    })
  >
  read(AppScope scope) {
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

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      const [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform)) {
    // Lo usa `DesktopCloseGuard` para confirmar el cierre de la ventana.
    await windowManager.ensureInitialized();
  }
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
        content = FluentApp(
          title: 'Orbi ERP',
          theme: OrbiFluentTheme.light,
          darkTheme: OrbiFluentTheme.dark,
          home: ScaffoldPage(
            content: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Builder(
                      builder: (context) {
                        final typography = FluentTheme.of(context).typography;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FluentIcons.cloud, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'No se pudo preparar Orbi ERP.',
                              style: typography.title,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tus datos locales no se han eliminado. Puedes intentarlo de nuevo.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _retry,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(FluentIcons.refresh, size: 16),
                                  SizedBox(width: 8),
                                  Text('Reintentar'),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        phaseKey = 'error';
      } else {
        content = FluentApp(
          title: 'Orbi ERP',
          theme: OrbiFluentTheme.light,
          darkTheme: OrbiFluentTheme.dark,
          home: const OrbiSplashScreen(),
        );
        phaseKey = 'splash';
      }
      return BootstrapAnimatedContent(phaseKey: phaseKey, child: content);
    },
  );
}

Future<Widget> _initializeApplication({
  NotificationPluginPort? notificationPlugin,
}) async {
  // Keep a real Flutter surface visible while plugins, secure storage and the
  // bounded session restore initialize. The stopwatch makes the splash budget
  // a minimum total duration, so a slow restore is never delayed twice. It
  // also times every step below: measured 12-sep-2026, the web build got
  // stuck on "Preparando Orbi ERP…" for minutes with several Orbi tabs open,
  // and there was nothing in the log saying which step was the slow one.
  final startupStopwatch = Stopwatch()..start();
  void logStep(String step) => logger.i(
    '[Bootstrap]',
    '$step (${startupStopwatch.elapsedMilliseconds} ms)',
  );

  final preferences = await SharedPreferences.getInstance();
  logStep('preferencias listas');
  final random = Random.secure();
  final sessionRuntime = SessionRuntime();
  final installationIds = InstallationIdStore(
    SharedPreferencesInstallationIdBackend(preferences),
    generator: () =>
        base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)))
            .replaceAll('=', ''),
  );
  final installationId = await installationIds.loadOrCreate('theos_panel');
  logStep('id de instalación listo');
  final notificationIds = NotificationSystemIdRegistry(
    preferences: preferences,
    appId: 'theos_panel',
    installationId: installationId,
  );
  final notificationPresenter = SystemNotificationPresenter(
    notificationPlugin ?? FlutterLocalNotificationPlugin(),
    notificationIds,
    activeScopeKey: 'unconfigured',
  );
  // 🔴 Notifications are optional; the login screen and session restore are
  // not hostage to them. `initialize()` reaches
  // `serviceWorker.getRegistration()`/`.register()` on the web with no
  // timeout of its own — that is what got stuck for minutes on 12-sep-2026.
  // So this is fired and forgotten, not awaited: every consumer
  // (`showOrReplace`/`cancel` in `SystemNotificationPresenter`) already
  // tolerates `_initialized == false` by answering `unsupported` instead of
  // assuming readiness, so nothing here needs to wait for it either.
  unawaited(
    notificationPresenter
        .initialize()
        .then((ready) => logStep('notificaciones listas=$ready'))
        .catchError((Object error, StackTrace stackTrace) {
          logger.w(
            '[Bootstrap]',
            'no se pudieron inicializar las notificaciones: $error',
          );
        }),
  );
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
  logStep('credenciales configuradas');
  // One bounded online restore, with one explicit offline fallback. On web
  // this is now only the stored bearer credential (see
  // `WebSessionAuthService.restore()`); a failed restore falls through to
  // `required`, which lets the in-app router show /login, the same as every
  // other unauthenticated status already does.
  final restored = await restoreOnce(
    kIsWeb ? webService : NativeAuthServicePort(service),
  );
  logStep('restauración de sesión resuelta: ${restored.status}');
  final composition = OrbiSessionComposition(
    authService: kIsWeb ? webService : NativeAuthServicePort(service),
    runtime: sessionRuntime,
    notificationPresenter: notificationPresenter,
    notificationIds: notificationIds,
  );
  await ensureMinimumSplashDuration(elapsed: startupStopwatch.elapsed);
  logStep('arranque completo');
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
      // El mismo motivo, para el pie de la aplicación operativa: sin esta
      // sustitución no llega ninguna señal y el estado queda en «sin
      // verificar», que es preferible a inventarlo.
      networkSignalOverride,
      ...composition.overrides,
      authInitialStateProvider.overrideWithValue(
        authViewStateFromResult(restored),
      ),
    ],
    child: const OrbiApp(),
  );
}

/// Test-only seam into [_initializeApplication]. Lets a test inject a
/// [NotificationPluginPort] whose `initialize()` never completes, or throws,
/// and prove startup still reaches a restored session or the login screen
/// instead of waiting on it — the defect measured 12-sep-2026 (minutes stuck
/// on "Preparando Orbi ERP…"). Production ([bootstrap]) never passes this;
/// the real app always gets the platform's [FlutterLocalNotificationPlugin].
@visibleForTesting
Future<Widget> buildInitializedApplication({
  NotificationPluginPort? notificationPlugin,
}) => _initializeApplication(notificationPlugin: notificationPlugin);
