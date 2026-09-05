import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/e2e_configuration.dart';
import 'support/read_only_app_driver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final configuration = E2eConfiguration.fromEnvironment();

  testWidgets('read-only startup, session restoration, menu and route guards', (
    tester,
  ) async {
    final driver = ReadOnlyAppDriver(tester, configuration);
    addTearDown(driver.dispose);

    await driver.launch();
    await driver.authenticateOrVerifyRestoredSession();
    await driver.verifySessionRestoration();
    await driver.verifyMenuAndQuickActionNavigation();
    await driver.verifyProtectedRouteRedirect();
  }, skip: !configuration.canRun);
}
