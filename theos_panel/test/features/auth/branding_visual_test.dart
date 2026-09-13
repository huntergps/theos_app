import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/orbi_splash_screen.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_panel/features/auth/login_failure_messages.dart';
import 'package:theos_panel/features/auth/login_preferences.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
import 'package:theos_panel/features/auth/saved_servers.dart';
import 'package:theos_panel/ui/components/copyable_message.dart';
import 'package:theos_panel/ui/components/orbi_brand.dart';

final class _VisualAuthService implements AuthServicePort {
  const _VisualAuthService({this.profile, this.result});

  final AuthProfile? profile;
  final AuthServiceResult? result;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async =>
      result ?? const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthProfile?> loadProfile() async => profile;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => profile;

  @override
  Future<void> close() async {}
}

Future<Widget> _loginHarness({AuthServiceResult? result}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(_VisualAuthService(result: result)),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
    child: FluentApp(theme: OrbiFluentTheme.light, home: const LoginScreen()),
  );
}

void main() {
  test('login overlay keeps minimum contrast against the real backdrop veil', () {
    // orbiPhotoInk is the ACTUAL color the branding pane and the pin login
    // screen paint over the photo, regardless of theme (see orbi_brand.dart:
    // "Photo foreground is intentionally independent of the form's theme").
    // The veil composited underneath it is the ACTUAL one OrbiAuthBackdrop
    // paints — `Color(0x52FFFFFF)`, "one uniform veil: no breakpoint-specific
    // or theme-specific gradients" — not a hand-picked stand-in: there used
    // to be a separate, unused `loginBrandOverlayColor` inventing its own
    // veil for this same photo, which nothing ever actually painted with.
    const realBackdropVeil = Color(0x52FFFFFF);
    const representativeImageTones = [Color(0xFF526052), Color(0xFF858C85)];
    for (final imageTone in representativeImageTones) {
      final composited = Color.alphaBlend(realBackdropVeil, imageTone);
      expect(
        loginOverlayContrastRatio(orbiPhotoInk, composited),
        greaterThanOrEqualTo(3),
        reason: 'Login branding text must remain readable over the photo.',
      );
    }
  });

  test('the failure panel stays readable in both themes', () {
    // The owner's complaint was that errors "se ven simples" — one line of
    // red text. The replacement is a tinted panel, and a tinted panel is only
    // an improvement if its text still reads: red-on-red at 2:1 would be
    // worse than the plain line it replaced. Both severity tones are checked
    // against WCAG AA for body text (4.5:1), in light and dark — using the
    // SAME orbiMessageTones() the real panel paints with, opaque-blended
    // resources and all (see copyable_message.dart's own doc on why raw
    // resources can't be compared directly).
    for (final theme in [OrbiFluentTheme.light, OrbiFluentTheme.dark]) {
      for (final severity in [
        OrbiMessageSeverity.error,
        OrbiMessageSeverity.warning,
      ]) {
        final tones = orbiMessageTones(theme, severity);
        expect(
          loginOverlayContrastRatio(tones.foreground, tones.background),
          greaterThanOrEqualTo(4.5),
          reason:
              'The ${severity.name} failure panel is unreadable in '
              '${theme.brightness}.',
        );
      }
    }
  });

  test('the two severity tones are visibly different from each other', () {
    // "Revisa tu wifi" and "pide a tu administrador que revise tus permisos"
    // are not the same kind of event, and the panel is the only place the
    // difference shows before the person reads a word.
    for (final theme in [OrbiFluentTheme.light, OrbiFluentTheme.dark]) {
      final errorTones = orbiMessageTones(theme, OrbiMessageSeverity.error);
      final warningTones = orbiMessageTones(
        theme,
        OrbiMessageSeverity.warning,
      );
      expect(
        errorTones.background,
        isNot(warningTones.background),
        reason:
            'Both failure tones paint the same background in '
            '${theme.brightness}: the severity scale is decorative only.',
      );
    }
  });

  testWidgets('a failed sign-in is presented as a panel, not as a bare line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final failure = describeLoginFailure(
      const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.protocol,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(const _VisualAuthService()),
          sharedPreferencesProvider.overrideWithValue(preferences),
          authInitialStateProvider.overrideWithValue(
            AuthViewState(
              status: AuthControllerStatus.error,
              message: failure.flatten(),
            ),
          ),
        ],
        child: FluentApp(theme: OrbiFluentTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final panel = find.byKey(const Key('login-failure-panel'));
    expect(panel, findsOneWidget);
    // It is a block with real presence, not a sentence: it spans the form's
    // width and is taller than a single line of body text.
    final size = tester.getSize(panel);
    expect(size.height, greaterThan(48));
    expect(
      size.width,
      greaterThan(tester.getSize(find.byType(TextBox).first).width * .9),
    );
    expect(find.byIcon(FluentIcons.status_error_full), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login uses a compact single-column layout on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _loginHarness());
    await tester.pump();

    expect(find.text('Acceso a Orbi'), findsOneWidget);
    expect(find.text('Ventas, caja y operaciones'), findsNothing);
    expect(find.byKey(const Key('compact-login-background')), findsOneWidget);
    expect(find.byKey(const Key('save-credential-toggle')), findsOneWidget);
    // Usuario + Contraseña only: the server selector is a dropdown, not a
    // TextField, and the database has no field anywhere in this form.
    expect(find.byType(TextBox), findsNWidgets(2));
    final button = find.widgetWithText(FilledButton, 'Iniciar sesión');
    await tester.ensureVisible(button);
    expect(tester.getTopLeft(button).dy, lessThan(844));
  });

  testWidgets('login keeps submit action visible in a compact desktop window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _loginHarness());
    await tester.pump();

    final button = find.widgetWithText(FilledButton, 'Iniciar sesión');
    expect(button, findsOneWidget);
    expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(600));
  });

  testWidgets('login exposes the Orbi branding pane on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _loginHarness());
    await tester.pump();

    expect(find.text('Ventas, caja y operaciones'), findsOneWidget);
    expect(
      find.text('Trabaja con tu equipo desde un solo lugar.'),
      findsOneWidget,
    );
    expect(find.byType(TextBox), findsNWidgets(2));
  });

  testWidgets('splash is branded and reports its loading state', (
    tester,
  ) async {
    await tester.pumpWidget(
      FluentApp(
        theme: OrbiFluentTheme.light,
        home: const OrbiSplashScreen(message: 'Restaurando sesión'),
      ),
    );

    expect(find.text('Restaurando sesión'), findsOneWidget);
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.bySemanticsLabel('Marca Orbi ERP'), findsOneWidget);
    expect(find.byKey(const Key('orbi-splash')), findsOneWidget);
  });

  testWidgets('restores saved selection before using the profile fallback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      LoginPreferencesStore.key: jsonEncode(
        const LoginPreferences(
          serverUrl: 'https://saved.test',
          database: 'saved_db',
          login: 'saved_user',
        ).toJson(),
      ),
    });
    final preferences = await SharedPreferences.getInstance();
    await SavedServersStore(preferences).upsert(
      SavedServer(
        id: 'saved',
        name: 'Entorno guardado',
        url: 'https://saved.test',
        database: 'saved_db',
      ),
    );
    const profile = AuthProfile(
      serverUrl: 'https://profile.test',
      database: 'profile_db',
      login: 'profile_user',
      userId: 7,
      installationId: 'installation',
      credentialReference: 'credential',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            const _VisualAuthService(profile: profile),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: FluentApp(theme: OrbiFluentTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();

    // The remembered environment is selected — its name shows directly in
    // the (closed) selector — and the database it carries never appears.
    expect(find.text('Entorno guardado'), findsOneWidget);
    expect(find.text('Base de datos'), findsNothing);
    expect(
      tester.widget<TextBox>(find.byType(TextBox).first).controller?.text,
      'saved_user',
    );
  });

  testWidgets('debounced login selection excludes password and API key', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await SavedServersStore(preferences).upsert(
      SavedServer(
        id: 'saved',
        name: 'Entorno guardado',
        url: 'https://saved.test',
        database: 'saved_db',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(const _VisualAuthService()),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: FluentApp(theme: OrbiFluentTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(ComboBox<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entorno guardado'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextBox);
    await tester.enterText(fields.at(0), 'saved_user');
    await tester.enterText(fields.at(1), 'do-not-persist');
    await tester.pump(const Duration(milliseconds: 450));

    final raw = preferences.getString(LoginPreferencesStore.key);
    expect(raw, contains('saved_user'));
    expect(raw, contains('saved.test'));
    expect(raw, isNot(contains('do-not-persist')));
    expect(raw, isNot(contains('apiKey')));
  });

  testWidgets('successful login saves only the non-secret selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await SavedServersStore(preferences).upsert(
      SavedServer(
        id: 'login-env',
        name: 'Panel',
        url: 'https://login.test',
        database: 'panel',
      ),
    );
    final profile = const AuthProfile(
      serverUrl: 'https://login.test',
      database: 'panel',
      login: 'seller',
      userId: 7,
      installationId: 'test-install',
      credentialReference: 'fake',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _VisualAuthService(
              result: AuthServiceResult(
                status: AuthServiceStatus.authenticated,
                profile: profile,
              ),
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: FluentApp(theme: OrbiFluentTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(ComboBox<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panel'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextBox);
    await tester.enterText(fields.at(0), 'seller');
    await tester.enterText(fields.at(1), 'not-persisted');
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    // Fluent's Button (HoverButton) schedules a 100ms Timer on tap-up to
    // reset its own pressed visual state; flush it so the test does not end
    // with a pending Timer.
    await tester.pump(const Duration(milliseconds: 100));

    final saved = LoginPreferencesStore(preferences).load();
    expect(saved.serverUrl, 'https://login.test');
    expect(saved.database, 'panel');
    expect(saved.login, 'seller');
    final raw = preferences.getString(LoginPreferencesStore.key);
    expect(raw, isNot(contains('not-persisted')));
    expect(raw, isNot(contains('password')));
    expect(raw, isNot(contains('apiKey')));
  });

  testWidgets(
    'does not mix the last profile user into another saved server selection',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        LoginPreferencesStore.key: jsonEncode(
          const LoginPreferences(
            serverUrl: 'https://saved.test',
            database: 'saved_db',
          ).toJson(),
        ),
      });
      final preferences = await SharedPreferences.getInstance();
      await SavedServersStore(preferences).upsert(
        SavedServer(
          id: 'saved',
          name: 'Entorno guardado',
          url: 'https://saved.test',
          database: 'saved_db',
        ),
      );
      const profile = AuthProfile(
        serverUrl: 'https://other.test',
        database: 'other_db',
        login: 'other_user',
        userId: 8,
        installationId: 'installation',
        credentialReference: 'credential',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              const _VisualAuthService(profile: profile),
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(theme: OrbiFluentTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pump();

      // The remembered selection (matching a saved server) wins, but the
      // cached profile belongs to a DIFFERENT server/database — its login
      // must not leak into the Usuario field for this one.
      expect(find.text('Entorno guardado'), findsOneWidget);
      expect(
        tester.widget<TextBox>(find.byType(TextBox).first).controller?.text,
        isEmpty,
      );
    },
  );
}
