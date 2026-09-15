import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/pin_credential_store.dart';
import 'package:theos_panel/features/auth/pin_login_screen.dart';
import 'package:theos_panel/ui/components/orbi_brand.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Mirrors login_screen_test.dart's own window-size helper: MediaQuery.sizeOf
/// is what PinLoginScreen's compact-vs-normal decision reads, so a test that
/// exercises it must set both the surface AND the ambient view size.
Future<void> _setWindowSize(WidgetTester tester, Size logicalSize) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(logicalSize);
}

void _resetWindowSize(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.binding.setSurfaceSize(null);
}

const _profile = AuthProfile(
  serverUrl: 'https://erp.test',
  database: 'demo',
  login: 'seller-multirole',
  userId: 7,
  installationId: 'i-1',
  credentialReference: 'api-key',
);

CapabilitySnapshot _snapshot(List<String> permissions) => CapabilitySnapshot(
  scopeKey: 'scope',
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026, 9, 11),
  permissions: permissions,
);

// PinLoginScreen ya no llama a `restoreForSellerPin` (que usaba `restore()`):
// con el selector de usuarios (decisión del dueño, 14-sep-2026) puede haber
// más de un perfil con PIN en el mismo dispositivo, así que la pantalla entra
// con `AuthNotifier.loginWithSellerPin`, que exige `SellerPinAuthServicePort`.
// Este fake lo implementa reutilizando el mismo `result` que ya modelaba
// login/restore, y `pinRetainedProfilesFor` ofrece exactamente el perfil
// bajo prueba — igual que antes del selector, para que un solo usuario en
// juego siga preseleccionado sin selector visible.
final class _FakeAuthService
    implements AuthServicePort, SellerPinAuthServicePort {
  _FakeAuthService(this.result);
  AuthServiceResult result;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => result;

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async => result;

  @override
  Future<AuthProfile?> loadProfile() async => result.profile;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => result.profile;

  @override
  Future<void> close() async {}

  @override
  Future<AuthServiceResult> loginWithPinCredential(
    AuthProfile profile, {
    bool offline = false,
  }) async => result;

  @override
  Future<void> retainCredentialForPin(AuthProfile profile, bool retained) async {}

  @override
  Future<List<AuthProfile>> pinRetainedProfilesFor(
    String serverUrl,
    String database,
  ) async {
    final profile = result.profile;
    if (profile == null ||
        profile.serverUrl != serverUrl ||
        profile.database != database) {
      return const [];
    }
    return [profile];
  }

  @override
  Future<List<AuthProfile>> profilesWithStoredKeyFor(
    String serverUrl,
    String database,
  ) async => const [];
}

// --- Selector «elegir entre los usuarios con PIN de este equipo para esa
// base» (decisión del dueño, 14-sep-2026). ---------------------------------
const _profileA = AuthProfile(
  serverUrl: 'https://erp.test',
  database: 'demo',
  login: 'user-a',
  userId: 11,
  installationId: 'i-1',
  credentialReference: 'api-key',
  name: 'Usuario A',
);

const _profileB = AuthProfile(
  serverUrl: 'https://erp.test',
  database: 'demo',
  login: 'user-b',
  userId: 12,
  installationId: 'i-1',
  credentialReference: 'api-key',
  name: 'Usuario B',
);

/// Simula dos usuarios con PIN retenido en la misma base: `loadProfile()`
/// devuelve el ÚLTIMO perfil (A, igual que `NativeAuthService.loadProfile`),
/// pero `pinRetainedProfilesFor` ofrece los dos — lo que hace aparecer el
/// selector. `loginWithPinCredential` entra exactamente con el perfil que se
/// le pasó, nunca con "el último" — así una prueba puede comprobar que elegir
/// a B en el selector de verdad activa a B, no a A.
final class _MultiUserFakeAuthService
    implements AuthServicePort, SellerPinAuthServicePort {
  AuthProfile? lastAuthenticatedAs;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      AuthServiceResult(
        status: AuthServiceStatus.restored,
        profile: _profileA,
        capabilities: _snapshot(const ['seller']),
      );

  @override
  Future<AuthProfile?> loadProfile() async => _profileA;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => _profileA;

  @override
  Future<void> close() async {}

  @override
  Future<AuthServiceResult> loginWithPinCredential(
    AuthProfile profile, {
    bool offline = false,
  }) async {
    lastAuthenticatedAs = profile;
    return AuthServiceResult(
      status: AuthServiceStatus.authenticated,
      profile: profile,
      capabilities: _snapshot(const ['seller']),
    );
  }

  @override
  Future<void> retainCredentialForPin(
    AuthProfile profile,
    bool retained,
  ) async {}

  @override
  Future<List<AuthProfile>> pinRetainedProfilesFor(
    String serverUrl,
    String database,
  ) async =>
      serverUrl == _profileA.serverUrl && database == _profileA.database
      ? [_profileA, _profileB]
      : const [];

  @override
  Future<List<AuthProfile>> profilesWithStoredKeyFor(
    String serverUrl,
    String database,
  ) async => const [];
}

Future<SharedPreferences> _preferencesWithPin(
  String pin, {
  AuthProfile profile = _profile,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final store = PinCredentialStore(preferences);
  final scopeKey = pinScopeKeyFor(
    profile.serverUrl,
    profile.database,
    profile.login,
  );
  await store.enroll(scopeKey, pin);
  return preferences;
}

Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.byKey(Key('pin-key-$digit')));
    await tester.pump();
  }
}

void main() {
  testWidgets('with no stored profile, PIN mode explains it cannot start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var cancelled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              const AuthServiceResult(status: AuthServiceStatus.required),
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: PinLoginScreen(onCancel: () => cancelled = true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining('Ingresa primero con tu usuario y contraseña'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pin-use-credentials')));
    // Fluent's Button (HoverButton) schedules a 100ms Timer on tap-up to
    // reset its own pressed visual state; flush it so the test does not end
    // with a pending Timer.
    await tester.pump(const Duration(milliseconds: 100));
    expect(cancelled, isTrue);
  });

  testWidgets(
    'with a profile but no enrolled PIN, the screen sends the user back '
    'to credentials rather than showing a keypad that can never succeed',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                AuthServiceResult(
                  status: AuthServiceStatus.restored,
                  profile: _profile,
                  capabilities: _snapshot(const ['seller']),
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(theme: OrbiFluentTheme.light, home: const PinLoginScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.textContaining('Aún no configuraste un PIN de vendedor'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pin-key-1')), findsNothing);
    },
  );

  testWidgets('entering the correct enrolled PIN grants seller access', (
    tester,
  ) async {
    final preferences = await _preferencesWithPin('1234');
    var granted = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              AuthServiceResult(
                status: AuthServiceStatus.restored,
                profile: _profile,
                capabilities: _snapshot(const ['seller', 'cashier']),
              ),
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: PinLoginScreen(onSellerAccessGranted: () => granted = true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('pin-key-1')), findsOneWidget);
    await _tapDigits(tester, '1234');
    await tester.pumpAndSettle();
    expect(granted, isTrue);
  });

  testWidgets(
    'an authenticated-but-non-seller account is refused even with the '
    'right PIN, and the screen never claims success',
    (tester) async {
      final preferences = await _preferencesWithPin('1234');
      var granted = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                AuthServiceResult(
                  status: AuthServiceStatus.restored,
                  profile: _profile,
                  capabilities: _snapshot(const ['cashier']),
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: PinLoginScreen(onSellerAccessGranted: () => granted = true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await _tapDigits(tester, '1234');
      await tester.pumpAndSettle();
      expect(granted, isFalse);
      expect(
        find.textContaining('no tiene acceso de vendedor por PIN'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a wrong PIN shows the invalid message and clears the dots', (
    tester,
  ) async {
    final preferences = await _preferencesWithPin('1234');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              // Only bootstrap (loadProfile) is exercised by this test; the
              // PIN is always wrong, so restoreForSellerPin's own `restore`
              // is never reached — the profile only needs to be findable so
              // the screen leaves the "no profile"/"not enrolled" states.
              const AuthServiceResult(
                status: AuthServiceStatus.required,
                profile: _profile,
              ),
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: FluentApp(theme: OrbiFluentTheme.light, home: const PinLoginScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await _tapDigits(tester, '9999');
    await tester.pump();
    expect(find.text('PIN inválido. Intenta nuevamente.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('PIN inválido. Intenta nuevamente.'), findsNothing);
    // The keypad is usable again, not stuck.
    expect(find.byKey(const Key('pin-key-1')), findsOneWidget);
  });

  testWidgets(
    'reaching the maximum failed attempts locks the screen with a '
    'countdown, and "Entendido" hands control back to the caller',
    (tester) async {
      final preferences = await _preferencesWithPin('1234');
      var cancelled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                const AuthServiceResult(
                  status: AuthServiceStatus.required,
                  profile: _profile,
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: PinLoginScreen(onCancel: () => cancelled = true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      for (var attempt = 0; attempt < kSellerPinMaxAttempts; attempt++) {
        await _tapDigits(tester, '0000');
        // Let the invalid-PIN reset timer (or the lockout transition) run
        // without pumpAndSettle: once locked, a periodic countdown Timer
        // keeps scheduling frames and pumpAndSettle would never converge.
        await tester.pump(const Duration(milliseconds: 750));
      }
      expect(find.text('Acceso bloqueado'), findsOneWidget);
      expect(find.byKey(const Key('pin-lockout-countdown')), findsOneWidget);
      expect(find.byKey(const Key('pin-key-1')), findsNothing);
      await tester.tap(find.byKey(const Key('pin-locked-acknowledge')));
      // Fluent's Button (HoverButton) schedules a 100ms Timer on tap-up to
      // reset its own pressed visual state; flush it so the test does not
      // end with a pending Timer.
      await tester.pump(const Duration(milliseconds: 100));
      expect(cancelled, isTrue);
    },
  );

  testWidgets(
    'estimated layout-budget metrics keep matching the real widgets',
    (tester) async {
      // Mirrors login_screen_test.dart's own guard: these are the fixed
      // constants pin_login_screen.dart's height budget assumes for a
      // normal-styling keypad row and its icon — if the theme or the keypad
      // button size ever changes, this must fail loudly instead of letting
      // the budget silently drift from what actually renders.
      final preferences = await _preferencesWithPin('1234');
      // Tall enough that the normal (non-compact) styling actually fits —
      // this test exists to catch the budget drifting from what NORMAL
      // styling renders, so it must not silently run in compact mode.
      await _setWindowSize(tester, const Size(1200, 1000));
      addTearDown(() => _resetWindowSize(tester));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                const AuthServiceResult(
                  status: AuthServiceStatus.required,
                  profile: _profile,
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(theme: OrbiFluentTheme.light, home: const PinLoginScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      final oneKeySize = tester.getSize(find.byKey(const Key('pin-key-1')));
      expect(oneKeySize.height, 64.0);
      final dotsRow = tester.getSize(find.byKey(const Key('pin-dots')));
      expect(dotsRow.height, 16.0);
    },
  );

  testWidgets('the screen fits a short desktop window without overflowing', (
    tester,
  ) async {
    final preferences = await _preferencesWithPin('1234');
    await _setWindowSize(tester, const Size(1200, 620));
    addTearDown(() => _resetWindowSize(tester));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              const AuthServiceResult(
                status: AuthServiceStatus.required,
                profile: _profile,
              ),
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: const PinLoginScreen(equipmentLabel: 'Mostrador 02'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Exercises the actual keypad layout, not just the (much smaller)
    // "blocked" state, so this genuinely tests the overflow guard.
    expect(find.byKey(const Key('pin-key-1')), findsOneWidget);
  });

  testWidgets(
    'the approved photo starts at the very top of the screen, no scaffold '
    'padding strip above it',
    (tester) async {
      final preferences = await _preferencesWithPin('1234');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                const AuthServiceResult(
                  status: AuthServiceStatus.required,
                  profile: _profile,
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: const PinLoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(find.byType(OrbiAuthBackdrop)).dy, 0.0);
    },
  );

  testWidgets(
    'the PIN card paints with theme.menuColor, the same opaque surface '
    'ContentDialog uses — light and dark',
    (tester) async {
      for (final theme in [OrbiFluentTheme.light, OrbiFluentTheme.dark]) {
        final preferences = await _preferencesWithPin('1234');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(
                _FakeAuthService(
                  const AuthServiceResult(
                    status: AuthServiceStatus.required,
                    profile: _profile,
                  ),
                ),
              ),
              sharedPreferencesProvider.overrideWithValue(preferences),
            ],
            child: FluentApp(theme: theme, home: const PinLoginScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();
        // FluentApp wraps its content in an AnimatedTheme: this settles it,
        // so the second iteration isn't caught mid-transition from the
        // first iteration's theme.
        await tester.pumpAndSettle();
        final card = tester.widget<Card>(find.byType(Card).first);
        expect(
          card.backgroundColor,
          theme.menuColor,
          reason:
              'The card must use theme.menuColor, not a hardcoded color or '
              'the translucent Acrylic default.',
        );
      }
    },
  );

  testWidgets('a phone-sized window fits without overflowing', (tester) async {
    final preferences = await _preferencesWithPin('1234');
    await _setWindowSize(tester, const Size(393, 852));
    addTearDown(() => _resetWindowSize(tester));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              const AuthServiceResult(
                status: AuthServiceStatus.required,
                profile: _profile,
              ),
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: FluentApp(
          theme: OrbiFluentTheme.light,
          home: const PinLoginScreen(equipmentLabel: 'Mostrador 02'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pin-key-1')), findsOneWidget);
  });

  testWidgets(
    'lists pin users of this database and verifies the chosen one',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = PinCredentialStore(preferences);
      await store.enroll(
        pinScopeKeyFor(
          _profileA.serverUrl,
          _profileA.database,
          _profileA.login,
        ),
        '1111',
      );
      await store.enroll(
        pinScopeKeyFor(
          _profileB.serverUrl,
          _profileB.database,
          _profileB.login,
        ),
        '2222',
      );
      final service = _MultiUserFakeAuthService();
      var granted = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(service),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: PinLoginScreen(onSellerAccessGranted: () => granted = true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Dos usuarios con PIN en esta base: el selector aparece.
      expect(find.byKey(const Key('pin-user-selector')), findsOneWidget);
      expect(find.textContaining('Usuario A'), findsOneWidget);

      // Elige a B en el selector.
      await tester.tap(find.byKey(const Key('pin-user-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuario B (user-b)').last);
      await tester.pumpAndSettle();

      // El PIN de A, con B ya elegido, falla: se verifica contra el scope
      // de B, no el de A.
      await _tapDigits(tester, '1111');
      await tester.pump();
      expect(find.text('PIN inválido. Intenta nuevamente.'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(granted, isFalse);

      // El PIN correcto de B entra como B, nunca como A.
      await _tapDigits(tester, '2222');
      await tester.pumpAndSettle();
      expect(granted, isTrue);
      expect(service.lastAuthenticatedAs?.login, 'user-b');
    },
  );

  // --- Lámina ACC-02: teclado y panel del equipo (14-sep-2026) --------------
  // Estas cuatro pruebas fallan contra b0645cd (antes de este cambio): ahí
  // las teclas numéricas son OutlinedButton con CircleBorder casi sin
  // contorno, «Entrar» es un círculo gris con un ícono de visto, el aviso de
  // seguridad es una Row a mano (sin InfoBar) y el contorno de los puntos
  // vacíos usa controlStrokeColorDefault en vez de
  // controlStrongStrokeColorDefault.

  testWidgets(
    '(a) the numeric keys are standard Fluent Buttons, not the almost '
    'invisible outlined circles',
    (tester) async {
      final preferences = await _preferencesWithPin('1234');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                const AuthServiceResult(
                  status: AuthServiceStatus.required,
                  profile: _profile,
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: const PinLoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      for (final digit in [
        '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', //
      ]) {
        expect(
          find.widgetWithText(Button, digit),
          findsOneWidget,
          reason: 'la tecla "$digit" debe ser un Button estándar de Fluent',
        );
      }
    },
  );

  testWidgets(
    '(b) the enter action is a labeled FilledButton ("Entrar"), disabled '
    'while the PIN is incomplete',
    (tester) async {
      final preferences = await _preferencesWithPin('1234');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                const AuthServiceResult(
                  status: AuthServiceStatus.required,
                  profile: _profile,
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: const PinLoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Antes era un círculo gris con FluentIcons.accept; ahora debe ser un
      // FilledButton con el texto «Entrar», como en la lámina ACC-02.
      expect(find.widgetWithText(FilledButton, 'Entrar'), findsOneWidget);
      FilledButton enterButton() => tester.widget<FilledButton>(
        find.byKey(const Key('pin-key-enter')),
      );
      expect(
        enterButton().onPressed,
        isNull,
        reason: 'con el PIN vacío debe estar desactivado',
      );
      // El PIN se auto-envía apenas llega al cuarto dígito (_onDigit hace
      // dos setState seguidos, sin ningún await entre medio: uno agrega el
      // dígito y el otro pasa a «verifying»), así que el instante
      // «entering con 4 dígitos y el botón ya habilitado» dura menos que un
      // microtask y no es observable por fuera del widget con pump(). Lo
      // que sí se puede comprobar aquí es que sigue desactivado con 1, 2 y
      // 3 dígitos; que se activa exactamente al llegar a 4 lo cubre, de
      // forma indirecta, "entering the correct enrolled PIN grants seller
      // access" más arriba en este archivo (el envío sólo ocurre si la
      // condición de habilitado deja de bloquearlo).
      for (final digit in ['1', '2', '3']) {
        await tester.tap(find.byKey(Key('pin-key-$digit')));
        await tester.pump();
        expect(
          enterButton().onPressed,
          isNull,
          reason: 'con menos de 4 dígitos debe seguir desactivado',
        );
      }
      // Fluent's Button (HoverButton) schedules a 100ms Timer on tap-up to
      // reset its own pressed visual state; flush it so the test does not
      // end with a pending Timer.
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets(
    '(c) the security notice sits inside a Fluent InfoBar, not a hand-rolled '
    'row',
    (tester) async {
      final preferences = await _preferencesWithPin('1234');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                const AuthServiceResult(
                  status: AuthServiceStatus.required,
                  profile: _profile,
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: const PinLoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(InfoBar),
          matching: find.text(
            'Por seguridad, tu actividad quedará registrada.',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '(d) the empty PIN dots outline with controlStrongStrokeColorDefault, '
    'not the barely-visible default stroke',
    (tester) async {
      final preferences = await _preferencesWithPin('1234');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _FakeAuthService(
                const AuthServiceResult(
                  status: AuthServiceStatus.required,
                  profile: _profile,
                ),
              ),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: const PinLoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final context = tester.element(find.byKey(const Key('pin-dots')));
      final expectedColor = FluentTheme.of(
        context,
      ).resources.controlStrongStrokeColorDefault;
      final firstDot = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byKey(const Key('pin-dots')),
              matching: find.byType(Container),
            ),
          )
          .first;
      final decoration = firstDot.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, expectedColor);
    },
  );
}
