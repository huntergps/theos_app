import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/theme/spacing.dart';
import 'package:theos_pos/features/authentication/services/server_service.dart';
import 'package:theos_pos/features/authentication/widgets/login_form.dart';

void main() {
  testWidgets('login validates the entered access key before submission', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
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
            servers: [server],
            selectedServer: server,
            spacing: const ThemedSpacing(1),
            showPassword: false,
            isLoading: false,
            loadingStage: '',
            onServerChanged: (_) {},
            onTogglePassword: () {},
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
        of: find.byKey(LoginFormKeys.apiKey),
        matching: find.byType(EditableText),
      ),
      'dummy-test-key',
    );
    await tester.pump();
    await tester.tap(find.byKey(LoginFormKeys.submit));
    expect(submittedValid, isTrue);
    expect(controller.text, 'dummy-test-key');
    await tester.pumpAndSettle();
  });
}
