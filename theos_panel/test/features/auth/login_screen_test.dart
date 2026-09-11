import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
import 'package:theos_panel/app/theme/orbi_theme.dart';

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
        Size(390, 844),
      ];
      for (final theme in [OrbiTheme.light, OrbiTheme.dark]) {
        for (final size in sizes) {
          await tester.binding.setSurfaceSize(size);
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
          expect(find.byType(Image), findsOneWidget);
          await tester.ensureVisible(find.text('Iniciar sesión'));
          expect(find.text('Iniciar sesión'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
