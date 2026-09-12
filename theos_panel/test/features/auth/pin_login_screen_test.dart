import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/pin_credential_store.dart';
import 'package:theos_panel/features/auth/pin_login_screen.dart';
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

final class _FakeAuthService implements AuthServicePort {
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
}
