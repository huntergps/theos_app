import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
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

void main() {
  testWidgets('saved server selection fills connection and clears old secret', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(
      () => SharedPreferences.getInstance(),
    );
    final store = SavedServersStore(preferences!);
    await tester.runAsync(
      () => store.upsert(
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
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(theme: OrbiTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), 'old-secret');
    await tester.tap(find.byKey(const Key('manage-saved-servers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('use_server')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'https://two.test',
    );
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, 'db');
    expect(tester.widget<TextField>(fields.at(2)).controller!.text, 'bob');
    expect(tester.widget<TextField>(fields.at(3)).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'server switch ignores late profile and precaches selected server',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(_ProfileService())],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'https://one.test');
      await tester.enterText(fields.at(1), 'db');
      await tester.enterText(fields.at(0), 'https://two.test');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.widget<TextField>(fields.at(2)).controller?.text, 'bob');
    },
  );

  testWidgets('login fields advance focus and submit from keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(_ProfileService())],
        child: MaterialApp(home: const LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'https://erp.test');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(1)).focusNode?.hasFocus, isTrue);
    await tester.enterText(fields.at(1), 'db');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(2)).focusNode?.hasFocus, isTrue);
    await tester.enterText(fields.at(2), 'user');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(3)).focusNode?.hasFocus, isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('login completion after unmount does not touch ref or context', (
    tester,
  ) async {
    final service = _SlowLoginService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(service)],
        child: MaterialApp(home: const LoginScreen()),
      ),
    );
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'https://erp.test');
    await tester.enterText(fields.at(1), 'db');
    await tester.enterText(fields.at(2), 'user');
    await tester.enterText(fields.at(3), 'secret');
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
          expect(find.byType(TextField), findsNWidgets(4));
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
  // the first thing compact styling drops), and "manage servers" shares its
  // row with the theme toggle instead of getting a row of its own.
  bool isCompactModeIn(WidgetTester tester) =>
      !tester.any(find.text(_kApiKeySubtitleText));

  bool manageServersSharesRowWithThemeToggle(WidgetTester tester) {
    final manageServersY = tester
        .getCenter(find.byKey(const Key('manage-saved-servers')))
        .dy;
    final themeToggleY = tester
        .getCenter(find.byKey(const Key('login-theme-toggle')))
        .dy;
    return (manageServersY - themeToggleY).abs() < 1.0;
  }

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
  // fine). The medium size (700x850) is deliberately BETWEEN the old flat
  // 720 threshold and the ~918px this app's own normal-mode content (at this
  // card width) really needs — see the "estimated layout-budget metrics"
  // test below for exactly how that number was measured, and
  // login_screen.dart's _estimateNormalModeContentHeight for the budget.
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
      expect(
        manageServersSharesRowWithThemeToggle(tester),
        isTrue,
        reason:
            '"Gestionar servidores" must share the top row with the theme '
            'icon in compact mode.',
      );
      await expectSubmitButtonReachable(tester, const Size(700, 650));
    },
  );

  testWidgets(
    'CASE 2 (medium window): normal styling used to be picked and not fit — '
    'now compact is chosen and it fits',
    (tester) async {
      await pumpLoginScreen(tester, const Size(700, 850));
      addTearDown(() => resetLoginTestWindowSize(tester));
      expect(
        isCompactModeIn(tester),
        isTrue,
        reason:
            'At 700x850 the normal styling\'s own budget (~918px for this '
            'card width, measured in "estimated layout-budget metrics keep '
            'matching the real widgets") does not fit — the previous flat '
            '720 threshold picked normal here anyway (720 <= 850), which is '
            'exactly the reported bug: content ending at "Guardar clave" '
            'with the footer right below, submit button gone. Compact must '
            'be chosen instead, and it does fit.',
      );
      await expectSubmitButtonReachable(tester, const Size(700, 850));
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
      expect(
        manageServersSharesRowWithThemeToggle(tester),
        isFalse,
        reason: '"Gestionar servidores" gets its own row in normal mode.',
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
      // boundary (~918px for this card width) so even a few stray pixels of
      // inset would have flipped it. The fix reads MediaQuery.sizeOf instead,
      // which does not move when viewInsets does — proven directly below by
      // forcing a viewInsets change and confirming nothing about the layout
      // reacts to it, regardless of what was really nudging it on the
      // reporter's machine.
      await pumpLoginScreen(tester, const Size(700, 915));
      addTearDown(() => resetLoginTestWindowSize(tester));
      addTearDown(() => tester.view.resetViewInsets());

      final baselineCompact = isCompactModeIn(tester);
      final baselineSharesRow = manageServersSharesRowWithThemeToggle(
        tester,
      );

      final fields = find.byType(TextField);
      for (var i = 0; i < 4; i++) {
        await tester.tap(fields.at(i));
        await tester.pump();
        expect(
          isCompactModeIn(tester),
          baselineCompact,
          reason:
              'Focusing field #$i changed compact-vs-normal — the form '
              'reflowed under the user, exactly the reported symptom.',
        );
        expect(
          manageServersSharesRowWithThemeToggle(tester),
          baselineSharesRow,
          reason: 'Focusing field #$i moved "Gestionar servidores".',
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
      expect(
        manageServersSharesRowWithThemeToggle(tester),
        baselineSharesRow,
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
