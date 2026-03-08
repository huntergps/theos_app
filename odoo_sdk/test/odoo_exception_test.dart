import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('OdooException', () {
    test('creates with message', () {
      const exception = OdooException(message: 'Test error');
      expect(exception.message, 'Test error');
      expect(exception.statusCode, 0);
    });

    test('creates with all fields', () {
      const exception = OdooException(
        message: 'Test error',
        statusCode: 400,
        model: 'sale.order',
        method: 'write',
        data: {'field': 'name'},
        technicalDetails: 'Stack trace here',
      );

      expect(exception.message, 'Test error');
      expect(exception.statusCode, 400);
      expect(exception.model, 'sale.order');
      expect(exception.method, 'write');
      expect(exception.data, {'field': 'name'});
      expect(exception.technicalDetails, 'Stack trace here');
    });

    test('simple constructor works', () {
      const exception = OdooException.simple(404, 'Not found');
      expect(exception.statusCode, 404);
      expect(exception.message, 'Not found');
    });

    test('simple constructor with data', () {
      const exception = OdooException.simple(400, 'Bad request', {'id': 1});
      expect(exception.data, {'id': 1});
    });

    test('toString includes message', () {
      const exception = OdooException(message: 'Test error');
      expect(exception.toString(), contains('Test error'));
    });

    test('toString includes status code when > 0', () {
      const exception = OdooException(message: 'Test', statusCode: 404);
      expect(exception.toString(), contains('HTTP 404'));
    });

    test('toString includes model and method', () {
      const exception = OdooException(
        message: 'Test',
        model: 'sale.order',
        method: 'write',
      );
      expect(exception.toString(), contains('sale.order.write'));
    });

    group('fromResponse factory', () {
      test('handles string error', () {
        final exception = OdooException.fromResponse('Error message');
        expect(exception.message, 'Error message');
      });

      test('handles null data', () {
        final exception = OdooException.fromResponse(null);
        expect(exception.message, contains('Unknown'));
      });

      test('handles map with message', () {
        final exception = OdooException.fromResponse({
          'message': 'Custom error',
        });
        expect(exception.message, 'Custom error');
      });

      test('handles nested error structure', () {
        final exception = OdooException.fromResponse({
          'error': {
            'message': 'Nested error',
            'data': {'debug': 'Debug info'},
          },
        });
        expect(exception.message, 'Nested error');
        expect(exception.technicalDetails, 'Debug info');
      });

      test('handles description field', () {
        final exception = OdooException.fromResponse({
          'description': 'Description error',
        });
        expect(exception.message, 'Description error');
      });

      test('preserves status code and model', () {
        final exception = OdooException.fromResponse(
          {'message': 'Test'},
          statusCode: 422,
          model: 'product.product',
          method: 'create',
        );
        expect(exception.statusCode, 422);
        expect(exception.model, 'product.product');
        expect(exception.method, 'create');
      });
    });
  });

  group('HTTP Status Exceptions', () {
    test('OdooBadRequestException has status 400', () {
      const exception = OdooBadRequestException('Bad request');
      expect(exception.statusCode, 400);
      expect(exception.message, 'Bad request');
    });

    test('OdooBadRequestException with data', () {
      const exception = OdooBadRequestException('Bad request', {'field': 'name'});
      expect(exception.data, {'field': 'name'});
    });

    test('OdooAuthenticationException has status 401', () {
      const exception = OdooAuthenticationException('Unauthorized');
      expect(exception.statusCode, 401);
    });

    test('OdooAccessDeniedException has status 403', () {
      const exception = OdooAccessDeniedException('Forbidden');
      expect(exception.statusCode, 403);
    });

    test('OdooNotFoundException has status 404', () {
      const exception = OdooNotFoundException('Not found');
      expect(exception.statusCode, 404);
    });

    test('OdooServerException has status 500', () {
      const exception = OdooServerException('Server error');
      expect(exception.statusCode, 500);
    });
  });

  group('Validation Exception', () {
    test('OdooValidationException has status 400', () {
      final exception = OdooValidationException('Validation failed');
      expect(exception.statusCode, 400);
    });

    test('extracts field errors from data', () {
      final exception = OdooValidationException(
        'Validation failed',
        {
          'field_errors': {
            'name': ['Required'],
            'email': ['Invalid format', 'Must be unique'],
          },
        },
      );

      expect(exception.fieldErrors, isNotNull);
      expect(exception.fieldErrors!['name'], ['Required']);
      expect(exception.fieldErrors!['email'], ['Invalid format', 'Must be unique']);
    });

    test('fieldErrors is null when no field_errors in data', () {
      final exception = OdooValidationException('Validation failed', null);
      expect(exception.fieldErrors, null);
    });
  });

  group('Network Exceptions', () {
    test('OdooTimeoutException has default message', () {
      const exception = OdooTimeoutException();
      expect(exception.message, contains('timeout'));
      expect(exception.statusCode, 0);
    });

    test('OdooTimeoutException accepts custom message', () {
      const exception = OdooTimeoutException('Custom timeout');
      expect(exception.message, 'Custom timeout');
    });

    test('OdooConnectionException has default message', () {
      const exception = OdooConnectionException();
      expect(exception.message, contains('connection'));
      expect(exception.statusCode, 0);
    });

    test('OdooConnectionException accepts custom message', () {
      const exception = OdooConnectionException('Custom connection error');
      expect(exception.message, 'Custom connection error');
    });
  });

  group('Offline-First Exceptions', () {
    test('OdooRecordNotFoundException includes model and id', () {
      final exception = OdooRecordNotFoundException('sale.order', 42);
      expect(exception.recordModel, 'sale.order');
      expect(exception.recordId, 42);
      expect(exception.statusCode, 404);
      expect(exception.model, 'sale.order');
      expect(exception.message, contains('sale.order'));
      expect(exception.message, contains('42'));
    });

    test('OdooDuplicateUuidException includes uuid and model', () {
      final exception = OdooDuplicateUuidException(
        'sale.order',
        'uuid-123-456',
      );
      expect(exception.conflictModel, 'sale.order');
      expect(exception.uuid, 'uuid-123-456');
      expect(exception.statusCode, 409);
      expect(exception.message, contains('uuid-123-456'));
    });

    test('OdooSyncConflictException includes all conflict details', () {
      final localDate = DateTime(2024, 1, 1, 10, 0);
      final serverDate = DateTime(2024, 1, 1, 12, 0);

      final exception = OdooSyncConflictException(
        conflictModel: 'sale.order',
        conflictRecordId: 42,
        localWriteDate: localDate,
        serverWriteDate: serverDate,
      );

      expect(exception.conflictModel, 'sale.order');
      expect(exception.conflictRecordId, 42);
      expect(exception.localWriteDate, localDate);
      expect(exception.serverWriteDate, serverDate);
      expect(exception.statusCode, 409);
      expect(exception.message, contains('sale.order'));
      expect(exception.message, contains('42'));
    });

    test('OdooOfflineException has default message', () {
      const exception = OdooOfflineException();
      expect(exception.message, contains('connection'));
      expect(exception.statusCode, 0);
    });

    test('OdooQueueException includes operation details', () {
      final exception = OdooQueueException(
        42,
        3,
        'Failed to sync',
      );
      expect(exception.operationId, 42);
      expect(exception.retryCount, 3);
      expect(exception.message, 'Failed to sync');
    });
  });
}
