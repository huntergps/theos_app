import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/services/global_error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('installs framework and platform error boundaries', () {
    final previousFlutterHandler = FlutterError.onError;
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    final captured = <String>[];

    try {
      installGlobalErrorHandlers(
        reporter: (source, error, stackTrace) {
          captured.add('$source: $error');
        },
      );

      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('framework failure'),
          stack: StackTrace.current,
        ),
      );
      final handled = PlatformDispatcher.instance.onError!(
        StateError('platform failure'),
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(captured, <String>[
        'Flutter framework: Bad state: framework failure',
        'Platform dispatcher: Bad state: platform failure',
      ]);
    } finally {
      FlutterError.onError = previousFlutterHandler;
      PlatformDispatcher.instance.onError = previousPlatformHandler;
    }
  });
}
