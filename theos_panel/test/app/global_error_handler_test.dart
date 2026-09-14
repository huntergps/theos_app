import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/app/global_error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterExceptionHandler? previousFlutterHandler;
  late ErrorCallback? previousPlatformHandler;

  setUp(() {
    previousFlutterHandler = FlutterError.onError;
    previousPlatformHandler = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    // Deja los manejadores tal como estaban, para no contaminar otras
    // pruebas que corran después de esta.
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
  });

  test(
    'FlutterError.onError anota el error y el stack en el registro',
    () {
      final captured = <String>[];

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

      expect(captured, ['Flutter framework: Bad state: framework failure']);
    },
  );

  test(
    'PlatformDispatcher.instance.onError anota el error y devuelve true',
    () {
      final captured = <String>[];

      installGlobalErrorHandlers(
        reporter: (source, error, stackTrace) {
          captured.add('$source: $error');
        },
      );

      final handled = PlatformDispatcher.instance.onError!(
        StateError('platform failure'),
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(captured, ['Platform dispatcher: Bad state: platform failure']);
    },
  );

  test(
    'un error lanzado dentro de la zona protegida, sin atrapar, llega al registro',
    () async {
      final captured = <String>[];
      void reporter(String source, Object error, StackTrace stackTrace) {
        captured.add('$source: $error');
      }

      final done = Completer<void>();

      // Mismo cableado que usa main.dart: runZonedGuarded entrega el error
      // no atrapado de la zona al reportero inyectado.
      runZonedGuarded(
        () {
          Timer.run(() {
            throw StateError('zone failure');
          });
          Timer(const Duration(milliseconds: 20), done.complete);
        },
        (error, stackTrace) =>
            reporter('Uncaught asynchronous error', error, stackTrace),
      );

      await done.future;

      expect(captured, ['Uncaught asynchronous error: Bad state: zone failure']);
    },
  );
}
