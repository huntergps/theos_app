import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/security/development_credentials.dart';

void main() {
  group('selectDevelopmentCredential', () {
    const injected = 'test-only-injected-value';

    test('accepts an injected value only in native debug mode', () {
      expect(
        selectDevelopmentCredential(
          isDebugMode: true,
          isWeb: false,
          injectedValue: injected,
        ),
        injected,
      );
    });

    test('rejects an injected value in release/profile mode', () {
      expect(
        selectDevelopmentCredential(
          isDebugMode: false,
          isWeb: false,
          injectedValue: injected,
        ),
        isEmpty,
      );
    });

    test('rejects an injected value on Web even in debug mode', () {
      expect(
        selectDevelopmentCredential(
          isDebugMode: true,
          isWeb: true,
          injectedValue: injected,
        ),
        isEmpty,
      );
    });
  });
}
