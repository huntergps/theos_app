import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/sync/services/data_purge_service.dart';

void main() {
  // ============================================================
  // PurgeResult data class
  // ============================================================
  group('PurgeResult', () {
    group('success factory', () {
      test('creates successful result with default counts', () {
        final result = PurgeResult.success();

        expect(result.success, isTrue);
        expect(result.ordersDeleted, 0);
        expect(result.linesDeleted, 0);
        expect(result.operationsCleared, 0);
        expect(result.error, isNull);
      });

      test('creates successful result with custom counts', () {
        final result = PurgeResult.success(
          ordersDeleted: 5,
          linesDeleted: 20,
          operationsCleared: 3,
        );

        expect(result.success, isTrue);
        expect(result.ordersDeleted, 5);
        expect(result.linesDeleted, 20);
        expect(result.operationsCleared, 3);
      });
    });

    group('error factory', () {
      test('creates failed result with error message', () {
        final result = PurgeResult.error('Something went wrong');

        expect(result.success, isFalse);
        expect(result.error, 'Something went wrong');
        expect(result.ordersDeleted, 0);
        expect(result.linesDeleted, 0);
        expect(result.operationsCleared, 0);
      });
    });

    group('permissionDenied factory', () {
      test('creates failed result with permission message', () {
        final result = PurgeResult.permissionDenied();

        expect(result.success, isFalse);
        expect(result.error, contains('permisos'));
      });
    });

    group('toString()', () {
      test('success shows counts', () {
        final result = PurgeResult.success(
          ordersDeleted: 3,
          linesDeleted: 10,
          operationsCleared: 2,
        );

        final str = result.toString();
        expect(str, contains('3'));
        expect(str, contains('10'));
        expect(str, contains('2'));
        expect(str, contains('Eliminados'));
      });

      test('error shows error message', () {
        final result = PurgeResult.error('Database locked');

        final str = result.toString();
        expect(str, contains('Error'));
        expect(str, contains('Database locked'));
      });
    });

    group('const constructor', () {
      test('creates result with all fields', () {
        const result = PurgeResult(
          success: true,
          ordersDeleted: 1,
          linesDeleted: 5,
          operationsCleared: 2,
        );

        expect(result.success, isTrue);
        expect(result.ordersDeleted, 1);
        expect(result.linesDeleted, 5);
        expect(result.operationsCleared, 2);
        expect(result.error, isNull);
      });

      test('creates result with error', () {
        const result = PurgeResult(
          success: false,
          error: 'Custom error',
        );

        expect(result.success, isFalse);
        expect(result.error, 'Custom error');
        expect(result.ordersDeleted, 0);
      });
    });
  });
}
