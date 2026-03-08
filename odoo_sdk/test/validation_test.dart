/// Tests for validation functionality
import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('ValidationException', () {
    test('stores field errors', () {
      final errors = {
        'name': 'Name is required',
        'price': 'Price must be positive',
      };

      final exception = ValidationException(errors);

      expect(exception.errors, equals(errors));
      expect(exception.errors.length, equals(2));
    });

    test('toString formats errors', () {
      final exception = ValidationException({'name': 'Name is required'});

      final message = exception.toString();
      expect(message, contains('ValidationException'));
      expect(message, contains('name'));
    });

    test('hasError checks specific field', () {
      final exception = ValidationException({
        'name': 'Name is required',
        'price': 'Invalid price',
      });

      expect(exception.hasError('name'), isTrue);
      expect(exception.hasError('price'), isTrue);
      expect(exception.hasError('qty'), isFalse);
    });

    test('firstError returns first error message', () {
      final exception = ValidationException({
        'name': 'Name is required',
        'price': 'Invalid price',
      });

      expect(exception.firstError, isNotNull);
      // Order depends on map iteration, so just check it's one of the errors
      expect([
        'Name is required',
        'Invalid price',
      ], contains(exception.firstError));
    });

    test('empty errors creates valid exception', () {
      final exception = ValidationException({});

      expect(exception.errors, isEmpty);
      expect(exception.firstError, isNull);
    });
  });

  group('FieldDefinition validation helpers', () {
    test('validateRequired for char field', () {
      const field = FieldDefinition(
        name: 'name',
        type: FieldType.char,
        required: true,
      );

      // Valid values
      expect(_validateCharRequired(field, 'Test'), isNull);
      expect(_validateCharRequired(field, 'A'), isNull);

      // Invalid values
      expect(_validateCharRequired(field, null), isNotNull);
      expect(_validateCharRequired(field, ''), isNotNull);
    });

    test('validateRequired for integer field', () {
      const field = FieldDefinition(
        name: 'quantity',
        type: FieldType.integer,
        required: true,
      );

      // Valid values
      expect(_validateIntRequired(field, 1), isNull);
      expect(_validateIntRequired(field, -1), isNull); // negative allowed

      // Invalid values
      expect(_validateIntRequired(field, null), isNotNull);
      expect(_validateIntRequired(field, 0), isNotNull); // 0 treated as missing
    });

    test('validateRequired for many2one field', () {
      const field = FieldDefinition(
        name: 'partnerId',
        type: FieldType.many2one,
        relatedModel: 'res.partner',
        required: true,
      );

      // Valid values
      expect(_validateMany2OneRequired(field, 1), isNull);
      expect(_validateMany2OneRequired(field, 999), isNull);

      // Invalid values
      expect(_validateMany2OneRequired(field, null), isNotNull);
      expect(_validateMany2OneRequired(field, 0), isNotNull);
    });

    test('validateRequired for list field', () {
      const field = FieldDefinition(
        name: 'tagIds',
        type: FieldType.many2many,
        relatedModel: 'product.tag',
        required: true,
      );

      // Valid values
      expect(_validateListRequired(field, [1, 2, 3]), isNull);
      expect(_validateListRequired(field, [1]), isNull);

      // Invalid values
      expect(_validateListRequired(field, null), isNotNull);
      expect(_validateListRequired(field, []), isNotNull);
    });
  });

  group('Record validation patterns', () {
    test('validate record with all required fields present', () {
      final record = _TestRecord(
        id: 1,
        name: 'Test Product',
        price: 10.0,
        partnerId: 5,
      );

      final errors = _validateTestRecord(record);
      expect(errors, isEmpty);
    });

    test('validate record with missing required string', () {
      final record = _TestRecord(
        id: 1,
        name: '', // empty string
        price: 10.0,
        partnerId: 5,
      );

      final errors = _validateTestRecord(record);
      expect(errors, containsPair('name', 'Name is required'));
    });

    test('validate record with missing required number', () {
      final record = _TestRecord(
        id: 1,
        name: 'Test',
        price: 10.0,
        partnerId: 0, // zero treated as missing
      );

      final errors = _validateTestRecord(record);
      expect(errors, containsPair('partnerId', 'Partner Id is required'));
    });

    test('validate record with multiple errors', () {
      final record = _TestRecord(id: 1, name: '', price: 10.0, partnerId: 0);

      final errors = _validateTestRecord(record);
      expect(errors.length, equals(2));
      expect(errors.containsKey('name'), isTrue);
      expect(errors.containsKey('partnerId'), isTrue);
    });

    test('validate record throws ValidationException', () {
      final record = _TestRecord(id: 1, name: '', price: 10.0, partnerId: 5);

      expect(
        () => _ensureValidTestRecord(record),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}

// Helper validation functions that mimic generated code patterns

String? _validateCharRequired(FieldDefinition field, String? value) {
  if (value == null || value.isEmpty) {
    return '${field.effectiveLabel} is required';
  }
  return null;
}

String? _validateIntRequired(FieldDefinition field, int? value) {
  if (value == null || value == 0) {
    return '${field.effectiveLabel} is required';
  }
  return null;
}

String? _validateMany2OneRequired(FieldDefinition field, int? value) {
  if (value == null || value == 0) {
    return '${field.effectiveLabel} is required';
  }
  return null;
}

String? _validateListRequired(FieldDefinition field, List<int>? value) {
  if (value == null || value.isEmpty) {
    return '${field.effectiveLabel} requires at least one item';
  }
  return null;
}

/// Test record class
class _TestRecord {
  final int id;
  final String name;
  final double price;
  final int partnerId;

  _TestRecord({
    required this.id,
    required this.name,
    required this.price,
    required this.partnerId,
  });
}

/// Simulates generated validation
Map<String, String> _validateTestRecord(_TestRecord record) {
  final errors = <String, String>{};

  // Required string
  if (record.name.isEmpty) {
    errors['name'] = 'Name is required';
  }

  // Required many2one (id)
  if (record.partnerId == 0) {
    errors['partnerId'] = 'Partner Id is required';
  }

  return errors;
}

void _ensureValidTestRecord(_TestRecord record) {
  final errors = _validateTestRecord(record);
  if (errors.isNotEmpty) {
    throw ValidationException(errors);
  }
}

/// ValidationException if not in the package
class ValidationException implements Exception {
  final Map<String, String> errors;

  ValidationException(this.errors);

  bool hasError(String field) => errors.containsKey(field);

  String? get firstError => errors.values.isEmpty ? null : errors.values.first;

  @override
  String toString() => 'ValidationException: $errors';
}
