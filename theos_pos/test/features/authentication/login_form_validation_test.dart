import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/theme/spacing.dart';
import 'package:theos_pos/features/authentication/services/server_service.dart';
import 'package:theos_pos/features/authentication/widgets/login_form.dart';

void main() {
  testWidgets('native login validates username and password', (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    final usernameController = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(usernameController.dispose);
    final server = ServerConfig(
      name: 'Test ERP2',
      url: 'https://erp2.tecnosmart.com.ec',
      database: 'test',
    );
    bool? submittedValid;
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: LoginForm(
            formKey: formKey,
            controller: controller,
            usernameController: usernameController,
            credentialMode: LoginCredentialMode.password,
            nativePasswordLoginAvailable: true,
            servers: [server],
            selectedServer: server,
            spacing: const ThemedSpacing(1),
            showPassword: false,
            isLoading: false,
            loadingStage: '',
            onServerChanged: (_) {},
            onTogglePassword: () {},
            onCredentialModeChanged: (_) {},
            onSubmit: () => submittedValid = formKey.currentState!.validate(),
            onManageServers: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(LoginFormKeys.submit));
    await tester.pump();
    expect(submittedValid, isFalse);

    await tester.enterText(
      find.descendant(
        of: find.byKey(LoginFormKeys.username),
        matching: find.byType(EditableText),
      ),
      'seller@example.com',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(LoginFormKeys.password),
        matching: find.byType(EditableText),
      ),
      'test-password',
    );
    await tester.pump();
    await tester.tap(find.byKey(LoginFormKeys.submit));
    expect(submittedValid, isTrue);
    expect(controller.text, 'test-password');
    await tester.pumpAndSettle();
  });

  testWidgets('advanced mode keeps API key available on native', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    final usernameController = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(usernameController.dispose);
    var mode = LoginCredentialMode.password;
    final server = ServerConfig(
      name: 'Test ERP2',
      url: 'https://erp2.example.com',
      database: 'test',
    );

    await tester.pumpWidget(
      FluentApp(
        home: StatefulBuilder(
          builder: (context, setState) => ScaffoldPage(
            content: LoginForm(
              formKey: formKey,
              controller: controller,
              usernameController: usernameController,
              credentialMode: mode,
              nativePasswordLoginAvailable: true,
              servers: [server],
              selectedServer: server,
              spacing: const ThemedSpacing(1),
              showPassword: false,
              isLoading: false,
              loadingStage: '',
              onServerChanged: (_) {},
              onTogglePassword: () {},
              onCredentialModeChanged: (next) => setState(() => mode = next),
              onSubmit: () {},
              onManageServers: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(LoginFormKeys.username), findsOneWidget);
    expect(find.byKey(LoginFormKeys.password), findsOneWidget);
    await tester.tap(find.byKey(LoginFormKeys.credentialMode));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(LoginFormKeys.username), findsNothing);
    expect(find.byKey(LoginFormKeys.apiKey), findsOneWidget);
  });
}
