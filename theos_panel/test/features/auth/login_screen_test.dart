import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_failure_messages.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
import 'package:theos_panel/features/auth/session_provenance.dart';
import 'package:theos_panel/features/auth/saved_servers.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/theme/orbi_theme.dart';
import 'package:theos_panel/ui/components/orbi_brand.dart';

/// Sets BOTH the render-surface size AND the ambient view's physical size.
///
/// `tester.binding.setSurfaceSize` alone only overrides the constraints the
/// RenderView itself is laid out with (what a LayoutBuilder inside the app
/// sees) — it does NOT touch `TestFlutterView.physicalSize`, which is what
/// `MediaQuery.sizeOf(context)` actually reads (see
/// `flutter_test/lib/src/binding.dart`'s `createViewConfigurationFor`, and
/// its own doc comment: "consider setting TestFlutterView.physicalSize...").
/// The login screen's compact-vs-normal decision now deliberately reads
/// MediaQuery instead of the LayoutBuilder constraints (so it can't be
/// nudged by a transient viewInsets change — see login_screen.dart), so
/// tests that exercise it must set both, or they'd be asking the layout to
/// resize while MediaQuery keeps reporting the 800x600 test default.
Future<void> setLoginTestWindowSize(WidgetTester tester, Size logicalSize) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(logicalSize);
}

void resetLoginTestWindowSize(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.binding.setSurfaceSize(null);
}

// Mirrors login_screen.dart's private _kApiKeySubtitle — kept as a literal
// here rather than importing a private constant, since tests should compare
// against the actual rendered string, same as a real user would see it.
const String _kApiKeySubtitleText =
    'La clave se guarda sólo en el almacén seguro del dispositivo.';

// The "Gestionar servidores…" entry inside the server selector's own dropdown
// menu — mirrors login_screen.dart's private _kManageServersLabel.
const String _kManageServersLabel = 'Gestionar servidores…';

final class _ProfileService implements AuthServicePort {
  static const _one = AuthProfile(
    serverUrl: 'https://one.test',
    database: 'db',
    login: 'alice',
    userId: 1,
    installationId: 'i',
    credentialReference: 'api-key',
  );
  static const _two = AuthProfile(
    serverUrl: 'https://two.test',
    database: 'db',
    login: 'bob',
    userId: 2,
    installationId: 'i',
    credentialReference: 'api-key',
  );

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() async => null;
  @override
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) async {
    if (serverUrl == 'https://one.test') {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return _one;
    }
    if (serverUrl == 'https://two.test') return _two;
    return null;
  }

  @override
  Future<void> close() async {}
}

final class _SlowLoginService
    implements AuthServicePort, CredentialPolicyAuthServicePort {
  final gate = Completer<AuthServiceResult>();
  bool? persisted;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential = true,
  }) {
    persisted = persistCredential;
    return gate.future;
  }

  @override
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
  }) {
    persisted = persistCredential;
    return gate.future;
  }

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

/// Fails every sign-in with [error], exactly as `NativeAuthService` does:
/// that class rolls back its own side effects and then RETHROWS the original
/// exception, so what the controller catches is the kit's own typed failure.
final class _ThrowingLoginService
    implements AuthServicePort, ApiKeyAuthServicePort {
  _ThrowingLoginService(this.error);
  final Object error;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => throw error;

  @override
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
  }) async => throw error;

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() async => null;
  @override
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) async =>
      null;
  @override
  Future<void> close() async {}
}

/// Saves [server] into a freshly created [SavedServersStore] backed by
/// [preferences], and returns that store. Every test below that needs a
/// saved environment to pick from goes through this instead of typing a raw
/// URL/database into the form — the form no longer accepts either as text.
Future<SavedServersStore> _seedServer(
  SharedPreferences preferences,
  SavedServer server,
) async {
  final store = SavedServersStore(preferences);
  await store.upsert(server);
  return store;
}

void main() {
  testWidgets(
    'selecting a saved server from its own dropdown fills the login and '
    'clears the old secret — no dialog involved',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await tester.runAsync(
        () => SharedPreferences.getInstance(),
      );
      await tester.runAsync(
        () => _seedServer(
          preferences!,
          SavedServer(
            id: 'two',
            name: 'Segundo entorno',
            url: 'https://two.test',
            database: 'db',
          ),
        ),
      );
      await setLoginTestWindowSize(tester, const Size(1200, 1000));
      addTearDown(() => resetLoginTestWindowSize(tester));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_ProfileService()),
            sharedPreferencesProvider.overrideWithValue(preferences!),
          ],
          child: MaterialApp(theme: OrbiTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      // Type a secret BEFORE ever touching the selector — this must not
      // survive the environment switch below.
      await tester.enterText(find.byType(TextField).at(1), 'old-secret');
      // The selector lives in the form itself: open it directly, no separate
      // "manage servers" dialog is involved in reaching a saved environment.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text(_kManageServersLabel), findsOneWidget);
      await tester.tap(find.text('Segundo entorno'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, 'bob');
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'first launch with no saved servers is never a dead end: the selector '
    'itself opens the manager to create the first one',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await setLoginTestWindowSize(tester, const Size(1200, 1000));
      addTearDown(() => resetLoginTestWindowSize(tester));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_ProfileService()),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: MaterialApp(theme: OrbiTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final selector = find.byType(DropdownButtonFormField<String>);
      expect(selector, findsOneWidget);
      expect(find.text('Ningún servidor guardado'), findsOneWidget);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      // The only option offered is the way out: reaching the manager.
      expect(find.text(_kManageServersLabel), findsOneWidget);
      await tester.tap(find.text(_kManageServersLabel));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo servidor'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('server_name')),
        'Primer entorno',
      );
      await tester.enterText(
        find.byKey(const ValueKey('server_url')),
        'https://first.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('server_database')),
        'first_db',
      );
      await tester.runAsync(
        () => tester.tap(find.byKey(const ValueKey('save_server'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('use_server')));
      await tester.pumpAndSettle();
      expect(find.text('Primer entorno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the database never appears anywhere in the normal login form',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await tester.runAsync(
        () => SharedPreferences.getInstance(),
      );
      await tester.runAsync(
        () => _seedServer(
          preferences!,
          SavedServer(
            id: 'x',
            name: 'Entorno',
            url: 'https://env.test',
            database: 'super_secret_db',
          ),
        ),
      );
      await setLoginTestWindowSize(tester, const Size(1200, 1000));
      addTearDown(() => resetLoginTestWindowSize(tester));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_ProfileService()),
            sharedPreferencesProvider.overrideWithValue(preferences!),
          ],
          child: MaterialApp(theme: OrbiTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Base de datos'), findsNothing);
      expect(find.textContaining('super_secret_db'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entorno'));
      await tester.pumpAndSettle();
      expect(find.text('Base de datos'), findsNothing);
      expect(find.textContaining('super_secret_db'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server switch ignores late profile and precaches selected server',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await tester.runAsync(
        () => SharedPreferences.getInstance(),
      );
      await tester.runAsync(() async {
        final store = SavedServersStore(preferences!);
        await store.upsert(
          SavedServer(id: 'one', name: 'Uno', url: 'https://one.test', database: 'db'),
        );
        await store.upsert(
          SavedServer(id: 'two', name: 'Dos', url: 'https://two.test', database: 'db'),
        );
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_ProfileService()),
            sharedPreferencesProvider.overrideWithValue(preferences!),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      // Selecting "Uno" starts the slow (40ms) lookup for alice…
      await tester.tap(find.text('Uno'));
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      // …then switching to "Dos" before that lookup resolves must win.
      await tester.tap(find.text('Dos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.at(0)).controller?.text, 'bob');
    },
  );

  testWidgets('login fields advance focus and submit from keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(
      () => SharedPreferences.getInstance(),
    );
    await tester.runAsync(
      () => _seedServer(
        preferences!,
        SavedServer(id: 'erp', name: 'ERP de prueba', url: 'https://erp.test', database: 'db'),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_ProfileService()),
          sharedPreferencesProvider.overrideWithValue(preferences!),
        ],
        child: MaterialApp(home: const LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERP de prueba'));
    await tester.pumpAndSettle();
    // Selecting an environment moves focus straight to "Usuario".
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(0)).focusNode?.hasFocus, isTrue);
    await tester.enterText(fields.at(0), 'user');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(1)).focusNode?.hasFocus, isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('login completion after unmount does not touch ref or context', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(
      () => SharedPreferences.getInstance(),
    );
    await tester.runAsync(
      () => _seedServer(
        preferences!,
        SavedServer(id: 'erp', name: 'ERP', url: 'https://erp.test', database: 'db'),
      ),
    );
    final service = _SlowLoginService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(service),
          sharedPreferencesProvider.overrideWithValue(preferences!),
        ],
        child: MaterialApp(home: const LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERP'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'user');
    await tester.enterText(fields.at(1), 'secret');
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    service.gate.complete(
      const AuthServiceResult(status: AuthServiceStatus.authenticated),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(service.persisted, isFalse);
  });

  testWidgets(
    'login remains editable and reachable across approved viewports',
    (tester) async {
      const sizes = [
        Size(1440, 900),
        Size(1180, 820),
        Size(820, 1180),
        Size(1024, 1366),
        Size(390, 844),
      ];
      for (final theme in [OrbiTheme.light, OrbiTheme.dark]) {
        for (final size in sizes) {
          await setLoginTestWindowSize(tester, size);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authServiceProvider.overrideWithValue(_ProfileService()),
              ],
              child: MaterialApp(theme: theme, home: const LoginScreen()),
            ),
          );
          await tester.pump();
          // Usuario + Contraseña only: the server selector is a dropdown,
          // not a TextField, and the database no longer has a field at all.
          expect(find.byType(TextField), findsNWidgets(2));
          final background = tester.widget<Image>(find.byType(Image));
          expect(background.image, isA<AssetImage>());
          expect(
            (background.image as AssetImage).assetName,
            orbiAuthBackgroundAsset,
          );
          final isWideLandscape = size.width >= 840 && size.width > size.height;
          if (isWideLandscape) {
            final brandingCenter = tester.getCenter(
              find.text('Ventas, caja y operaciones'),
            );
            final formCenter = tester.getCenter(find.byType(TextField).first);
            expect(brandingCenter.dx, lessThan(formCenter.dx));
          } else {
            // Portrait keeps the form compact and does not render the lateral
            // branding pane, including tall tablet widths.
            expect(find.text('Ventas, caja y operaciones'), findsNothing);
          }
          await tester.ensureVisible(find.text('Iniciar sesión'));
          expect(find.text('Iniciar sesión'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
      resetLoginTestWindowSize(tester);
    },
  );

  Future<void> expectSubmitButtonReachable(
    WidgetTester tester,
    Size windowSize,
  ) async {
    await setLoginTestWindowSize(tester, windowSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(_ProfileService())],
        child: MaterialApp(theme: OrbiTheme.dark, home: const LoginScreen()),
      ),
    );
    await tester.pump();

    final buttonFinder = find.ancestor(
      of: find.text('Iniciar sesión'),
      matching: find.byType(FilledButton),
    );
    expect(buttonFinder, findsOneWidget);

    final screenHeight = tester.getSize(find.byType(MaterialApp)).height;
    final buttonBottom = tester.getBottomLeft(buttonFinder).dy;
    final footerTop = tester
        .getTopLeft(find.byKey(const Key('login-credit-footer')))
        .dy;

    expect(
      buttonBottom,
      lessThanOrEqualTo(screenHeight),
      reason: 'El botón de iniciar sesión debe estar dentro de la zona visible.',
    );
    expect(
      buttonBottom,
      lessThanOrEqualTo(footerTop),
      reason:
          'El botón de iniciar sesión no debe quedar solapado por el pie '
          '"Desarrollado por GalapagosTech · 2026" (footerTop=$footerTop, '
          'buttonBottom=$buttonBottom, windowSize=$windowSize).',
    );
    expect(tester.takeException(), isNull);
  }

  // Compact mode is recognized the same way the owner described the
  // screenshots: the "API key" switch's descriptive subtitle is gone (it is
  // the first thing compact styling drops).
  bool isCompactModeIn(WidgetTester tester) =>
      !tester.any(find.text(_kApiKeySubtitleText));

  Future<void> pumpLoginScreen(
    WidgetTester tester,
    Size windowSize, {
    ThemeData? theme,
  }) async {
    await setLoginTestWindowSize(tester, windowSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(_ProfileService())],
        child: MaterialApp(
          theme: theme ?? OrbiTheme.dark,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  // The three cases below are the owner's own three screenshots — a short
  // window (compact, fine), a medium one (normal styling picked, and normal
  // did not fit — this is the one that was broken) and a tall one (normal,
  // fine). See the "estimated layout-budget metrics" test below for exactly
  // how the budget is measured, and login_screen.dart's
  // _estimateNormalModeContentHeight for the formula itself.
  //
  // Dropping the database field and the standalone "manage servers" row (see
  // that same function) lowered the real budget at this card width from
  // ~918px to 684px, which moves the real compact/normal boundary at 700px
  // width from ~918px of window height down to ~804px (there is a constant
  // ~120px of footer+padding taken off the window height before comparing
  // against that budget — see `availableForNormalMode`). CASE 2 used to sit
  // at 700x850, deliberately between the OLD flat 720 threshold and the OLD
  // ~918px real requirement; 850 is now comfortably ABOVE the new ~804px
  // boundary, so normal styling genuinely fits there — that is a real
  // improvement, not a regression, and asserting "must be compact" at 850
  // would be asserting a stale number. The case is kept meaningful by moving
  // it to 700x780: still above the old flat-720 threshold (so it would still
  // have hit the original bug on the old code) and still below the new real
  // boundary, so it continues to prove the same thing the flat threshold
  // could not: that compact is chosen exactly when normal actually would not
  // fit, not according to a guess.
  testWidgets(
    'CASE 1 (short window): compact styling is chosen and fits without overlap',
    (tester) async {
      await pumpLoginScreen(tester, const Size(700, 650));
      addTearDown(() => resetLoginTestWindowSize(tester));
      expect(
        isCompactModeIn(tester),
        isTrue,
        reason: 'A short window must pick the compact styling.',
      );
      await expectSubmitButtonReachable(tester, const Size(700, 650));
    },
  );

  testWidgets(
    'CASE 2 (medium window): normal styling used to be picked and not fit — '
    'now compact is chosen and it fits',
    (tester) async {
      await pumpLoginScreen(tester, const Size(700, 780));
      addTearDown(() => resetLoginTestWindowSize(tester));
      expect(
        isCompactModeIn(tester),
        isTrue,
        reason:
            'At 700x780 the normal styling\'s own budget (~684px for this '
            'card width, now that the form has three fields instead of four '
            'and no separate "manage servers" row) still does not fit — the '
            'old flat 720 threshold picked normal here anyway (720 <= 780), '
            'which is exactly the reported bug. Compact must be chosen '
            'instead, and it does fit.',
      );
      await expectSubmitButtonReachable(tester, const Size(700, 780));
    },
  );

  testWidgets(
    'CASE 3 (tall window): normal styling is chosen and fits without overlap',
    (tester) async {
      await pumpLoginScreen(tester, const Size(700, 1000));
      addTearDown(() => resetLoginTestWindowSize(tester));
      expect(
        isCompactModeIn(tester),
        isFalse,
        reason: 'A tall window has room for the spacious normal styling.',
      );
      await expectSubmitButtonReachable(tester, const Size(700, 1000));
    },
  );

  testWidgets(
    'estimated layout-budget metrics keep matching the real widgets',
    (tester) async {
      // Guards the handful of named constants _estimateNormalModeContentHeight
      // relies on for the parts TextPainter cannot see (ListTile/TextField
      // chrome). If the Material theme ever changes these, this test fails
      // loudly instead of the fits-or-not budget silently drifting out from
      // under the real widgets.
      await pumpLoginScreen(tester, const Size(700, 1400));
      expect(
        tester.getSize(find.byType(TextField).first).height,
        52.0,
        reason: 'Normal-mode TextField height moved — update _kNormalTextFieldHeight.',
      );
      final apiKeySwitchSize = tester.getSize(
        find.byKey(const Key('api-key-mode-toggle')),
      );
      final apiKeySubtitleSize = tester.getSize(
        find.text(_kApiKeySubtitleText),
      );
      final apiKeyTitleSize = tester.getSize(find.text('Usar API key'));
      expect(
        apiKeySwitchSize.height,
        apiKeyTitleSize.height + apiKeySubtitleSize.height + 16.0,
        reason:
            'A normal-mode SwitchListTile\'s height moved away from '
            'titleLineHeight + subtitleHeight + _kSwitchTileVerticalChrome — '
            'update the constant that drifted.',
      );
      expect(
        apiKeySwitchSize.width - apiKeySubtitleSize.width,
        76.0,
        reason:
            'The gap between a SwitchListTile\'s own width and its subtitle '
            "text's width moved — update _kSwitchTileTextInset.",
      );
      resetLoginTestWindowSize(tester);
    },
  );

  testWidgets(
    'focusing each field does not change the compact/normal layout decision',
    (tester) async {
      // The owner's report, verbatim: "cada vez que hago click en un
      // textedit se oculta y muestra el resto del formulario, se reconstruye
      // toda la pantalla". Before this fix, the compact/normal decision read
      // LayoutBuilder's body constraints, which shrink whenever
      // Scaffold.resizeToAvoidBottomInset reacts to MediaQuery.viewInsets —
      // and this window is deliberately picked right at the compact/normal
      // boundary so even a few stray pixels of inset would have flipped it.
      // The fix reads MediaQuery.sizeOf instead, which does not move when
      // viewInsets does — proven directly below by forcing a viewInsets
      // change and confirming nothing about the layout reacts to it,
      // regardless of what was really nudging it on the reporter's machine.
      //
      // Only the two remaining TextFields (Usuario, Contraseña) are looped
      // over: the server selector is a dropdown now, and tapping it opens an
      // overlay rather than just taking focus, which is a different — and
      // separately covered — interaction.
      await pumpLoginScreen(tester, const Size(700, 800));
      addTearDown(() => resetLoginTestWindowSize(tester));
      addTearDown(() => tester.view.resetViewInsets());

      final baselineCompact = isCompactModeIn(tester);

      final fields = find.byType(TextField);
      for (var i = 0; i < 2; i++) {
        await tester.tap(fields.at(i));
        await tester.pump();
        expect(
          isCompactModeIn(tester),
          baselineCompact,
          reason:
              'Focusing field #$i changed compact-vs-normal — the form '
              'reflowed under the user, exactly the reported symptom.',
        );
        expect(tester.takeException(), isNull);
      }

      // Directly simulate whatever might be nudging the inset on focus.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(
        isCompactModeIn(tester),
        baselineCompact,
        reason:
            'A transient viewInsets change (simulating whatever a real '
            'keyboard-like overlay does) must not flip the layout mode.',
      );
    },
  );

  testWidgets(
    'login submit button is not covered by the credit footer on a short desktop window',
    (tester) async {
      // The window reported by the user was ~900x700 (macOS, debug, dark
      // theme). Flutter's logical size for a native window is the CONTENT
      // area, which is shorter than the OS window frame by the title bar
      // (~28-30px on macOS) — so the faithful repro is slightly shorter than
      // the literal 900x700. At exactly 900x700 there is a ~36px margin and
      // the bug does not reproduce; below ~672px of logical height (still
      // "the compact branch", which only kicks in under 720) it does. 900x670
      // is the closest-to-reported size that reliably fails on the old code.
      await expectSubmitButtonReachable(tester, const Size(900, 670));
      addTearDown(() => resetLoginTestWindowSize(tester));
    },
  );

  testWidgets(
    'login submit button stays reachable without scrolling on an 800x600 desktop window',
    (tester) async {
      // This is the case that was already fixed before this change (the
      // compact-height branch kicking in below 720). Guard against a
      // regression while fixing the short-but-wide 900-ish case above.
      await expectSubmitButtonReachable(tester, const Size(800, 600));
      addTearDown(() => resetLoginTestWindowSize(tester));
    },
  );

  testWidgets('login theme icon persists dark and light choices', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_ProfileService()),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const _LoginThemeHarness(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('login-theme-toggle'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<IconButton>(toggle).tooltip, 'Cambiar a modo oscuro');
    expect(find.text('Desarrollado por GalapagosTech · 2026'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
    final footer = tester.widget<ColoredBox>(
      find.byKey(const Key('login-credit-footer')),
    );
    expect(footer.color.a, closeTo(.72, .01));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(toggle).tooltip, 'Cambiar a modo claro');

    final scope = const PreferencesScope(
      appId: 'theos_panel',
      scopeKey: 'anonymous',
    );
    final saved = AppPreferencesStore(preferences: preferences, scope: scope);
    expect((await saved.load()).themeMode, PreferenceThemeMode.dark);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(toggle).tooltip, 'Cambiar a modo oscuro');
    expect((await saved.load()).themeMode, PreferenceThemeMode.light);
    expect(tester.takeException(), isNull);
  });

  // ==========================================================================
  // The owner's report: "por que los mensajes de error se ven simples".
  //
  // Every sign-in failure used to end as ONE sentence in plain red text —
  // "No se pudo iniciar sesión. Revisa los datos e inténtalo de nuevo." — no
  // matter which of the kit's very different failures caused it. The tests
  // below drive the real screen through the real controller with the real
  // exceptions the kit raises, and assert the person is told what happened
  // and what to do about it.
  // ==========================================================================

  const kOldFlatMessage =
      'No se pudo iniciar sesión. Revisa los datos e inténtalo de nuevo.';

  Future<void> pumpFailingLogin(
    WidgetTester tester, {
    required Object error,
    NetworkPresenceProbe? networkProbe,
    bool apiKeyMode = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(
      () => SharedPreferences.getInstance(),
    );
    await tester.runAsync(
      () => _seedServer(
        preferences!,
        SavedServer(
          id: 'e2e',
          name: 'Entorno de prueba',
          url: 'https://erp.test',
          database: 'db',
        ),
      ),
    );
    await setLoginTestWindowSize(tester, const Size(1200, 1100));
    addTearDown(() => resetLoginTestWindowSize(tester));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_ThrowingLoginService(error)),
          sharedPreferencesProvider.overrideWithValue(preferences!),
          if (networkProbe != null)
            networkPresenceProbeProvider.overrideWithValue(networkProbe),
        ],
        child: MaterialApp(theme: OrbiTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entorno de prueba').last);
    await tester.pumpAndSettle();
    if (apiKeyMode) {
      await tester.tap(find.byKey(const Key('api-key-mode-toggle')));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'lo-que-sea');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
  }

  void expectFailureShown(WidgetTester tester, LoginFailureCause cause) {
    final expected = loginFailureMessageFor(cause);
    expect(
      find.byKey(const Key('login-failure-panel')),
      findsOneWidget,
      reason: '${cause.name} was not presented as a failure panel.',
    );
    expect(
      find.text(expected.title),
      findsOneWidget,
      reason: '${cause.name}: the headline is missing.',
    );
    expect(
      find.text(expected.guidance),
      findsOneWidget,
      reason: '${cause.name}: the person is not told what to do.',
    );
    expect(
      find.text(kOldFlatMessage),
      findsNothing,
      reason: '${cause.name} fell back to the old one-size-fits-all sentence.',
    );
  }

  // One case per thing the kit can actually tell apart, driven end to end.
  final endToEndCases = <String, (Object, LoginFailureCause)>{
    'a wrong password': (
      const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.invalidCredentials,
      ),
      LoginFailureCause.invalidCredentials,
    ),
    'an account that needs a second factor': (
      const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.additionalVerificationRequired,
      ),
      LoginFailureCause.additionalVerificationRequired,
    ),
    'a server that refuses the account': (
      const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.accessDenied,
      ),
      LoginFailureCause.accessDenied,
    ),
    'a credential that could not be minted': (
      const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.protocol,
      ),
      LoginFailureCause.credentialIssueFailed,
    ),
    'an address that is not https': (
      const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.insecureTransport,
      ),
      LoginFailureCause.insecureAddress,
    ),
    'an expired session': (
      const OdooSessionExpiredException(),
      LoginFailureCause.sessionExpired,
    ),
    'a server that is missing what we need': (
      const OdooMethodNotFoundException(
        targetModel: 'res.users.apikeys.description',
        methodName: 'make_key',
        message: 'missing',
      ),
      LoginFailureCause.incompatibleServer,
    ),
    'a server that took too long': (
      const OdooTimeoutException(),
      LoginFailureCause.timeout,
    ),
    'a server that broke on its own': (
      const OdooServerException('boom'),
      LoginFailureCause.serverError,
    ),
  };

  endToEndCases.forEach((label, pair) {
    final (error, cause) = pair;
    testWidgets('$label is explained as ${cause.name}, not as one red line', (
      tester,
    ) async {
      await pumpFailingLogin(tester, error: error);
      expectFailureShown(tester, cause);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'a credential that could not be created does NOT look like a bad password',
    (tester) async {
      // The exact trap the owner named: signing in proves the password AND
      // asks the server to mint this device's API key. When only the second
      // one fails, nothing the person types will ever fix it — so the screen
      // must stop telling them to check what they typed.
      await pumpFailingLogin(
        tester,
        error: const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        ),
      );
      final wrongPassword = loginFailureMessageFor(
        LoginFailureCause.invalidCredentials,
      );
      expect(find.text(wrongPassword.title), findsNothing);
      expect(find.text(wrongPassword.guidance), findsNothing);
      expect(
        find.text('No se pudo crear la clave de acceso de este dispositivo'),
        findsOneWidget,
      );
      expect(
        find.textContaining('no es una contraseña equivocada'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an API key that is not this user\'s says exactly that', (
    tester,
  ) async {
    await pumpFailingLogin(
      tester,
      error: StateError('API key belongs to another Odoo user'),
      apiKeyMode: true,
    );
    expectFailureShown(tester, LoginFailureCause.apiKeyRejected);
    expect(
      find.text('No se pudo validar la API key.'),
      findsNothing,
      reason: 'The old flat API-key sentence is back.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'no failure ever shows the raw exception to the person',
    (tester) async {
      // A server payload, a model name and a status code, all in one object.
      await pumpFailingLogin(
        tester,
        error: OdooException(
          message: 'AccessError: user 42 cannot write res.users.apikeys',
          statusCode: 403,
          model: 'res.users.apikeys.description',
          method: 'make_key',
          technicalDetails: 'Traceback (most recent call last): ...',
        ),
      );
      for (final leak in [
        'AccessError',
        'res.users.apikeys',
        'Traceback',
        '403',
        'user 42',
      ]) {
        expect(
          find.textContaining(leak),
          findsNothing,
          reason: 'The screen is showing "$leak" to someone at a counter.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  group('connectivity separates "no hay red" from "el servidor no responde"', () {
    const connectionFailed = NativeAuthBootstrapException(
      NativeAuthBootstrapFailureKind.connection,
    );

    testWidgets('with no transport at all, the device is named', (tester) async {
      await pumpFailingLogin(
        tester,
        error: connectionFailed,
        networkProbe: () async => false,
      );
      expectFailureShown(tester, LoginFailureCause.noNetwork);
      // And it explicitly clears the two things the person would otherwise
      // waste time re-checking.
      expect(
        find.textContaining('no es un problema del servidor'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('with a transport up, the server is named', (tester) async {
      await pumpFailingLogin(
        tester,
        error: connectionFailed,
        networkProbe: () async => true,
      );
      expectFailureShown(tester, LoginFailureCause.serverNotResponding);
      expect(
        find.text(loginFailureMessageFor(LoginFailureCause.noNetwork).title),
        findsNothing,
        reason:
            'Blaming the wifi when the wifi is fine is the old bug, just '
            'better dressed.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'with NO probe override at all, the screen neither hangs nor guesses',
      (tester) async {
        // The regression this guards is not a wrong message, it is a DEADLOCK.
        // A live connectivity default would await a platform channel that
        // never completes inside a widget test's fake-async zone, and
        // pumpAndSettle would sit on it for its whole ten-minute budget. The
        // probe is inert by default (the composition root hands in the real
        // one), so this must finish immediately — and, knowing nothing, must
        // keep the honest ambiguous message rather than blaming the wifi.
        await pumpFailingLogin(tester, error: connectionFailed);
        expectFailureShown(tester, LoginFailureCause.serverUnreachable);
        expect(
          find.text(loginFailureMessageFor(LoginFailureCause.noNetwork).title),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('when the probe cannot answer, neither side is blamed', (
      tester,
    ) async {
      await pumpFailingLogin(
        tester,
        error: connectionFailed,
        networkProbe: () async => throw StateError('no connectivity plugin'),
      );
      expectFailureShown(tester, LoginFailureCause.serverUnreachable);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refined verdict never survives onto the next attempt', (
      tester,
    ) async {
      // The refinement is screen-local state. If it outlived the message it
      // was derived from, a later wrong password would be reported as a
      // network problem.
      await pumpFailingLogin(
        tester,
        error: connectionFailed,
        networkProbe: () async => false,
      );
      expectFailureShown(tester, LoginFailureCause.noNetwork);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expectFailureShown(tester, LoginFailureCause.noNetwork);
      expect(tester.takeException(), isNull);
    });
  });


  group('a failed sign-in can be taken away, not just read', () {
    // The owner's second ask: "deben permitir copiar el contenido de los
    // mensajes". This is what turns "no pude entrar" into something he can
    // paste to somebody who can act on it — so it is asserted end to end,
    // from the real screen through the real controller, and against what
    // actually reaches the platform clipboard rather than an internal getter.
    String? copied;

    void spyOnClipboard(WidgetTester tester) {
      copied = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('the copy button is right there on the login form', (
      tester,
    ) async {
      await pumpFailingLogin(
        tester,
        error: const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        ),
      );
      expect(find.byKey(const Key('copy-message-button')), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
    });

    testWidgets('and it copies the WHOLE message, not a summary', (
      tester,
    ) async {
      spyOnClipboard(tester);
      await pumpFailingLogin(
        tester,
        error: const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        ),
      );
      await tester.tap(find.byKey(const Key('copy-message-button')));
      await tester.pump();

      final expected = loginFailureMessageFor(
        LoginFailureCause.credentialIssueFailed,
      );
      expect(copied, isNotNull);
      expect(copied, contains(expected.title));
      expect(
        copied,
        contains(expected.guidance),
        reason:
            'Only the headline was copied. The instruction is the half that '
            'tells whoever reads it what to do.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('what gets pasted carries no internals', (tester) async {
      spyOnClipboard(tester);
      await pumpFailingLogin(
        tester,
        error: OdooException(
          message: 'AccessError: user 42 cannot write res.users.apikeys',
          statusCode: 403,
          model: 'res.users.apikeys.description',
          method: 'make_key',
          technicalDetails: 'Traceback (most recent call last): ...',
        ),
      );
      await tester.tap(find.byKey(const Key('copy-message-button')));
      await tester.pump();
      for (final leak in [
        'AccessError',
        'res.users.apikeys',
        'Traceback',
        'user 42',
      ]) {
        expect(
          copied,
          isNot(contains(leak)),
          reason: 'The clipboard is leaking "$leak" into a chat message.',
        );
      }
    });

    testWidgets('the person is told the copy worked', (tester) async {
      spyOnClipboard(tester);
      await pumpFailingLogin(
        tester,
        error: const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.invalidCredentials,
        ),
      );
      await tester.tap(find.byKey(const Key('copy-message-button')));
      await tester.pump();
      expect(find.text('Mensaje copiado'), findsOneWidget);
    });

    testWidgets('the failure does not expire while you reach for it', (
      tester,
    ) async {
      // A sign-in failure is anchored to the form, not on a countdown. The
      // owner is expected to copy it and send it; ten seconds — what
      // theos_pos gives an error — would not be enough.
      await pumpFailingLogin(
        tester,
        error: const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        ),
      );
      await tester.pump(const Duration(minutes: 2));
      await tester.pump();
      expectFailureShown(tester, LoginFailureCause.credentialIssueFailed);
    });

    testWidgets('at phone width the copy button does not squeeze the headline', (
      tester,
    ) async {
      // theos_pos keeps the copy button on the title row, beside the close
      // button. Checked here on the narrowest supported screen, with the
      // longest headline the mapping can produce.
      SharedPreferences.setMockInitialValues({});
      final preferences = await tester.runAsync(
        () => SharedPreferences.getInstance(),
      );
      await setLoginTestWindowSize(tester, const Size(390, 844));
      addTearDown(() => resetLoginTestWindowSize(tester));
      final failure = loginFailureMessageFor(
        LoginFailureCause.credentialIssueFailed,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_ProfileService()),
            sharedPreferencesProvider.overrideWithValue(preferences!),
            authInitialStateProvider.overrideWithValue(
              AuthViewState(
                status: AuthControllerStatus.error,
                message: failure.flatten(),
              ),
            ),
          ],
          child: MaterialApp(theme: OrbiTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.text(failure.title);
      expect(title, findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('copy-message-button'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(title).dy),
        reason: 'The copy button is level with the headline, crowding it.',
      );
      expect(tester.takeException(), isNull);
    });
  });


  group('una sesión ajena se OFRECE, no se adopta', () {
    // El tercer caso del mismo silencio: la aplicación cambiaba de identidad
    // sin decir nada. En un mostrador compartido eso es que alguien venda y
    // cobre con el nombre de un compañero sin que ninguno se entere.
    const inherited = AuthProfile(
      serverUrl: 'https://erp2.tecnosmart.com.ec',
      database: 'erp2_tecnosmart_com_ec',
      login: 'jacqueline.rizo',
      userId: 23,
      installationId: 'i',
      credentialReference: 'odoo-http-session',
    );

    Future<void> pumpWithOffer(
      WidgetTester tester, {
      OfferedSession? offer,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await tester.runAsync(
        () => SharedPreferences.getInstance(),
      );
      await setLoginTestWindowSize(tester, const Size(1200, 1100));
      addTearDown(() => resetLoginTestWindowSize(tester));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_ProfileService()),
            sharedPreferencesProvider.overrideWithValue(preferences!),
            if (offer != null)
              offeredSessionProvider.overrideWithValue(offer),
          ],
          child: MaterialApp(theme: OrbiTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin oferta, la pantalla de acceso es la de siempre', (
      tester,
    ) async {
      await pumpWithOffer(tester);
      expect(find.byKey(const Key('offered-session-card')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con oferta, NOMBRA a la persona en el botón', (tester) async {
      // «Continuar con la sesión abierta» no deja ver a quién vas a
      // suplantar. «Continuar como jacqueline.rizo» sí.
      await pumpWithOffer(tester, offer: const OfferedSession(inherited));
      expect(find.byKey(const Key('offered-session-card')), findsOneWidget);
      expect(find.text('Continuar como jacqueline.rizo'), findsOneWidget);
    });

    testWidgets('y dice la consecuencia, no sólo el hecho', (tester) async {
      await pumpWithOffer(tester, offer: const OfferedSession(inherited));
      expect(
        find.textContaining('lo que hagas quedará a su nombre'),
        findsOneWidget,
      );
    });

    testWidgets('el formulario sigue estando, y por encima de la oferta', (
      tester,
    ) async {
      // La oferta es una salida rápida, no el camino principal: quien NO sea
      // esa persona tiene el formulario delante, no escondido detrás de un
      // botón.
      await pumpWithOffer(tester, offer: const OfferedSession(inherited));
      final fields = find.byType(TextField);
      expect(fields, findsWidgets);
      expect(
        tester.getTopLeft(fields.last).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('offered-session-card'))).dy,
        ),
        reason: 'La oferta tapó el formulario en vez de acompañarlo.',
      );
    });

    testWidgets('el atajo sigue siendo UN clic', (tester) async {
      // Ofrecer no mata el atajo que pidió el dueño: sólo cambia de mano
      // quién lo da.
      await pumpWithOffer(tester, offer: const OfferedSession(inherited));
      await tester.tap(find.byKey(const Key('continue-offered-session')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    test('una credencial propia NO se ofrece: se adopta en silencio', () {
      // Hacer pulsar un botón para entrar en tu propia cuenta es fricción sin
      // ganancia. El corte es por origen, no por entorno.
      const own = AuthProfile(
        serverUrl: 'https://erp2.tecnosmart.com.ec',
        database: 'erp2_tecnosmart_com_ec',
        login: 'carlos.guajala',
        userId: 9,
        installationId: 'i',
        credentialReference: 'api-key',
      );
      expect(sessionShouldBeOfferedNotAdopted(own), isFalse);
      expect(sessionShouldBeOfferedNotAdopted(inherited), isTrue);
    });
  });

  testWidgets(
    'the failure panel is announced to screen readers with both halves',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFailingLogin(
        tester,
        error: const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        ),
      );
      final expected = loginFailureMessageFor(
        LoginFailureCause.credentialIssueFailed,
      );
      expect(
        tester.getSemantics(find.byKey(const Key('login-failure-panel'))),
        matchesSemantics(
          isLiveRegion: true,
          label: '${expected.title}. ${expected.guidance}',
        ),
      );
      handle.dispose();
    },
  );

  testWidgets(
    'a message the mapping does not know is printed as-is, not mislabelled',
    (tester) async {
      // AuthNotifier still writes a few sentences by hand (PIN, W01, the
      // unavailable API-key mode). Those must keep the plain treatment
      // instead of being dressed up as a classified cause.
      const handWritten = 'El acceso web con contraseña está pendiente de W01.';
      await setLoginTestWindowSize(tester, const Size(1200, 1000));
      addTearDown(() => resetLoginTestWindowSize(tester));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_ProfileService()),
            authInitialStateProvider.overrideWithValue(
              const AuthViewState(
                status: AuthControllerStatus.error,
                message: handWritten,
              ),
            ),
          ],
          child: MaterialApp(theme: OrbiTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(handWritten), findsOneWidget);
      expect(find.byKey(const Key('login-failure-panel')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _LoginThemeHarness extends ConsumerWidget {
  const _LoginThemeHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(preferencesScopeProvider);
    final preferences = ref.watch(appPreferencesProvider(scope));
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) => MaterialApp(
        theme: OrbiTheme.light,
        darkTheme: OrbiTheme.dark,
        themeMode: preferences.snapshot.materialThemeMode,
        home: const LoginScreen(),
      ),
    );
  }
}
