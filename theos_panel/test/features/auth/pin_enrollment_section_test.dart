import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/pin_credential_store.dart';
import 'package:theos_panel/features/auth/pin_enrollment_section.dart';

/// This is the other half of the defect the coordinator sent: the store
/// (`pin_credential_store.dart`, owned by another agent — not touched here)
/// already knows how to enroll a PIN, but nothing ever called it. These
/// tests exercise the SCREEN, not the store: `pin_credential_store_test.dart`
/// already covers `enroll`/`verify`/`forget` in isolation.
const _profile = AuthProfile(
  serverUrl: 'https://erp.test',
  database: 'demo',
  login: 'seller-1',
  userId: 7,
  installationId: 'i-1',
  credentialReference: 'api-key',
);

final _scopeKey = pinScopeKeyFor(
  _profile.serverUrl,
  _profile.database,
  _profile.login,
);

Future<SharedPreferences> _preferences({bool enrolled = false}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  if (enrolled) {
    await PinCredentialStore(preferences).enroll(_scopeKey, '1234');
  }
  return preferences;
}

Future<void> _pump(
  WidgetTester tester,
  SharedPreferences preferences, {
  AuthProfile? profile = _profile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authInitialStateProvider.overrideWithValue(
          AuthViewState(
            status: profile == null
                ? AuthControllerStatus.required
                : AuthControllerStatus.authenticated,
            profile: profile,
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const FluentApp(
        home: ScaffoldPage(
          content: SingleChildScrollView(child: PinEnrollmentSection()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'with no profile the section renders nothing, rather than a form with '
    'no identity to scope the PIN under',
    (tester) async {
      final preferences = await _preferences();
      await _pump(tester, preferences, profile: null);
      expect(find.byKey(const Key('pin-enroll-new-field')), findsNothing);
      expect(find.byKey(const Key('pin-enroll-status')), findsNothing);
    },
  );

  testWidgets(
    'with no PIN enrolled yet, the form is the only way in and actually '
    'calls PinCredentialStore.enroll',
    (tester) async {
      final preferences = await _preferences();
      await _pump(tester, preferences);
      expect(find.byKey(const Key('pin-enroll-new-field')), findsOneWidget);
      expect(find.byKey(const Key('pin-enroll-status')), findsNothing);
      // Not yet enrolled in the store either — the screen isn't lying about it.
      expect(PinCredentialStore(preferences).isEnrolled(_scopeKey), isFalse);

      await tester.enterText(
        find.byKey(const Key('pin-enroll-new-field')),
        '1234',
      );
      await tester.enterText(
        find.byKey(const Key('pin-enroll-confirm-field')),
        '1234',
      );
      await tester.tap(find.byKey(const Key('pin-enroll-submit')));
      await tester.pumpAndSettle();

      expect(PinCredentialStore(preferences).isEnrolled(_scopeKey), isTrue);
      expect(find.byKey(const Key('pin-enroll-status')), findsOneWidget);
      expect(find.byKey(const Key('pin-enroll-new-field')), findsNothing);
    },
  );

  testWidgets(
    'mismatched confirmation is rejected and never reaches the store',
    (tester) async {
      final preferences = await _preferences();
      await _pump(tester, preferences);

      await tester.enterText(
        find.byKey(const Key('pin-enroll-new-field')),
        '1234',
      );
      await tester.enterText(
        find.byKey(const Key('pin-enroll-confirm-field')),
        '4321',
      );
      await tester.tap(find.byKey(const Key('pin-enroll-submit')));
      await tester.pump();
      // Fluent's Button (HoverButton) schedules a 100ms Timer on tap-up to
      // reset its own pressed visual state; flush it so the test does not
      // end with a pending Timer.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('pin-enroll-error')), findsOneWidget);
      expect(PinCredentialStore(preferences).isEnrolled(_scopeKey), isFalse);
    },
  );

  testWidgets(
    'an already-enrolled PIN shows status, not the form, until "Cambiar PIN" '
    'is tapped',
    (tester) async {
      final preferences = await _preferences(enrolled: true);
      await _pump(tester, preferences);

      expect(find.byKey(const Key('pin-enroll-status')), findsOneWidget);
      expect(find.byKey(const Key('pin-enroll-new-field')), findsNothing);

      await tester.tap(find.byKey(const Key('pin-enroll-change-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('pin-enroll-new-field')), findsOneWidget);
    },
  );

  testWidgets(
    '"Quitar PIN" asks for confirmation and only forgets the PIN once '
    'confirmed',
    (tester) async {
      final preferences = await _preferences(enrolled: true);
      await _pump(tester, preferences);

      await tester.tap(find.byKey(const Key('pin-enroll-remove-button')));
      await tester.pumpAndSettle();
      // Dismissing the dialog leaves the PIN alone.
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
      expect(PinCredentialStore(preferences).isEnrolled(_scopeKey), isTrue);

      await tester.tap(find.byKey(const Key('pin-enroll-remove-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pin-enroll-remove-confirm')));
      await tester.pumpAndSettle();

      expect(PinCredentialStore(preferences).isEnrolled(_scopeKey), isFalse);
      expect(find.byKey(const Key('pin-enroll-new-field')), findsOneWidget);
    },
  );
}
