import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('Many2one Extraction', () {
    test('extractMany2oneId returns id from [id, name] tuple', () {
      expect(extractMany2oneId([42, 'Partner Name']), 42);
    });

    test('extractMany2oneId returns id from plain int', () {
      expect(extractMany2oneId(42), 42);
    });

    test('extractMany2oneId returns null for false', () {
      expect(extractMany2oneId(false), null);
    });

    test('extractMany2oneId returns null for null', () {
      expect(extractMany2oneId(null), null);
    });

    test('extractMany2oneId returns null for empty list', () {
      expect(extractMany2oneId([]), null);
    });

    test('extractMany2oneName returns name from [id, name] tuple', () {
      expect(extractMany2oneName([42, 'Partner Name']), 'Partner Name');
    });

    test('extractMany2oneName returns null for false', () {
      expect(extractMany2oneName(false), null);
    });

    test('extractMany2oneName returns null for short list', () {
      expect(extractMany2oneName([42]), null);
    });

    test('extractMany2one returns both id and name', () {
      final (id, name) = extractMany2one([42, 'Partner']);
      expect(id, 42);
      expect(name, 'Partner');
    });
  });

  group('Many2many Extraction', () {
    test('extractMany2manyIds returns list from plain int list', () {
      expect(extractMany2manyIds([1, 2, 3]), [1, 2, 3]);
    });

    test('extractMany2manyIds returns list from nested tuples', () {
      expect(
        extractMany2manyIds([
          [1, 'Tag A'],
          [2, 'Tag B'],
          [3, 'Tag C'],
        ]),
        [1, 2, 3],
      );
    });

    test('extractMany2manyIds returns empty list for false', () {
      expect(extractMany2manyIds(false), []);
    });

    test('extractMany2manyIds returns empty list for null', () {
      expect(extractMany2manyIds(null), []);
    });

    test('extractMany2manyIds handles mixed format', () {
      expect(
        extractMany2manyIds([
          1,
          [2, 'Name'],
          3,
        ]),
        [1, 2, 3],
      );
    });

    test('extractMany2manyIdsAsString returns comma-separated', () {
      expect(extractMany2manyIdsAsString([1, 2, 3]), '1,2,3');
    });

    test('extractMany2manyIdsAsString returns null for empty', () {
      expect(extractMany2manyIdsAsString([]), null);
    });

    test('extractMany2manyToJson returns JSON array string', () {
      expect(extractMany2manyToJson([1, 2, 3]), '[1,2,3]');
    });
  });

  group('DateTime Parsing', () {
    test('parseOdooDateTime parses datetime string', () {
      final dt = parseOdooDateTime('2024-03-15 14:30:00');
      expect(dt, isNotNull);
      expect(dt!.year, 2024);
      expect(dt.month, 3);
      expect(dt.day, 15);
      expect(dt.hour, 14);
      expect(dt.minute, 30);
    });

    test('parseOdooDateTime returns null for false', () {
      expect(parseOdooDateTime(false), null);
    });

    test('parseOdooDateTime returns null for null', () {
      expect(parseOdooDateTime(null), null);
    });

    test('parseOdooDateTime handles date-only string', () {
      final dt = parseOdooDateTime('2024-03-15');
      expect(dt, isNotNull);
      expect(dt!.year, 2024);
      expect(dt.month, 3);
      expect(dt.day, 15);
    });

    test('parseOdooDateTime passes through DateTime', () {
      final original = DateTime(2024, 3, 15, 14, 30);
      expect(parseOdooDateTime(original), original);
    });

    test('parseOdooDate parses date string', () {
      final dt = parseOdooDate('2024-03-15');
      expect(dt, isNotNull);
      expect(dt!.year, 2024);
      expect(dt.month, 3);
      expect(dt.day, 15);
    });

    test('parseOdooDate strips time from datetime string', () {
      final dt = parseOdooDate('2024-03-15 14:30:00');
      expect(dt, isNotNull);
      expect(dt!.hour, 0);
      expect(dt.minute, 0);
    });

    test('formatOdooDateTime formats to Odoo format', () {
      final dt = DateTime.utc(2024, 3, 15, 14, 30, 45);
      expect(formatOdooDateTime(dt), '2024-03-15 14:30:45');
    });

    test('formatOdooDateTime returns null for null', () {
      expect(formatOdooDateTime(null), null);
    });

    test('formatOdooDate formats date only', () {
      final dt = DateTime(2024, 3, 15, 14, 30);
      expect(formatOdooDate(dt), '2024-03-15');
    });
  });

  group('Type Conversions', () {
    test('parseOdooBool handles true', () {
      expect(parseOdooBool(true), true);
    });

    test('parseOdooBool handles false', () {
      expect(parseOdooBool(false), false);
    });

    test('parseOdooBool handles int 1', () {
      expect(parseOdooBool(1), true);
    });

    test('parseOdooBool handles int 0', () {
      expect(parseOdooBool(0), false);
    });

    test('parseOdooBool handles string "true"', () {
      expect(parseOdooBool('true'), true);
    });

    test('parseOdooBool handles string "false"', () {
      expect(parseOdooBool('false'), false);
    });

    test('parseOdooBool uses default for null', () {
      expect(parseOdooBool(null, defaultValue: true), true);
      expect(parseOdooBool(null, defaultValue: false), false);
    });

    test('parseOdooDouble handles double', () {
      expect(parseOdooDouble(19.99), 19.99);
    });

    test('parseOdooDouble handles int', () {
      expect(parseOdooDouble(20), 20.0);
    });

    test('parseOdooDouble handles string', () {
      expect(parseOdooDouble('19.99'), 19.99);
    });

    test('parseOdooDouble uses default for false', () {
      expect(parseOdooDouble(false, defaultValue: 0.0), 0.0);
    });

    test('parseOdooInt handles int', () {
      expect(parseOdooInt(42), 42);
    });

    test('parseOdooInt handles double', () {
      expect(parseOdooInt(42.7), 42);
    });

    test('parseOdooInt handles string', () {
      expect(parseOdooInt('42'), 42);
    });

    test('parseOdooInt uses default for false', () {
      expect(parseOdooInt(false, defaultValue: 0), 0);
    });

    test('parseOdooString handles string', () {
      expect(parseOdooString('hello'), 'hello');
    });

    test('parseOdooString returns null for false', () {
      expect(parseOdooString(false), null);
    });

    test('parseOdooString returns null for empty string', () {
      expect(parseOdooString(''), null);
    });

    test('parseOdooStringRequired returns default for null', () {
      expect(parseOdooStringRequired(null, defaultValue: 'default'), 'default');
    });
  });

  group('Case Conversion', () {
    test('toSnakeCase converts camelCase', () {
      expect(toSnakeCase('partnerId'), 'partner_id');
    });

    test('toSnakeCase handles multiple capitals', () {
      expect(toSnakeCase('partnerShippingAddressId'), 'partner_shipping_address_id');
    });

    test('toSnakeCase handles already snake_case', () {
      expect(toSnakeCase('partner_id'), 'partner_id');
    });

    test('toCamelCase converts snake_case', () {
      expect(toCamelCase('partner_id'), 'partnerId');
    });

    test('toCamelCase handles multiple underscores', () {
      expect(toCamelCase('partner_shipping_address_id'), 'partnerShippingAddressId');
    });
  });

  group('Many2many Command Building', () {
    test('buildMany2manyReplace creates replace command', () {
      expect(buildMany2manyReplace([1, 2, 3]), [
        [6, 0, [1, 2, 3]]
      ]);
    });

    test('buildMany2manyAdd creates add commands', () {
      expect(buildMany2manyAdd([1, 2]), [
        [4, 1, 0],
        [4, 2, 0],
      ]);
    });

    test('buildMany2manyRemove creates remove commands', () {
      expect(buildMany2manyRemove([1, 2]), [
        [3, 1, 0],
        [3, 2, 0],
      ]);
    });

    test('buildMany2manyClear creates clear command', () {
      expect(buildMany2manyClear(), [
        [5, 0, 0]
      ]);
    });
  });

  group('One2many Command Building', () {
    test('buildOne2manyCreate creates create command', () {
      expect(
        buildOne2manyCreate({'name': 'Line 1', 'quantity': 5}),
        [0, 0, {'name': 'Line 1', 'quantity': 5}],
      );
    });

    test('buildOne2manyUpdate creates update command', () {
      expect(
        buildOne2manyUpdate(42, {'quantity': 10}),
        [1, 42, {'quantity': 10}],
      );
    });

    test('buildOne2manyDelete creates delete command', () {
      expect(buildOne2manyDelete(42), [2, 42, 0]);
    });

    test('buildOne2manyUnlink creates unlink command', () {
      expect(buildOne2manyUnlink(42), [3, 42, 0]);
    });

    test('buildOne2manyLink creates link command', () {
      expect(buildOne2manyLink(42), [4, 42, 0]);
    });
  });

  group('toOdooValue', () {
    test('converts null to false', () {
      expect(toOdooValue(null), false);
    });

    test('formats DateTime', () {
      final dt = DateTime.utc(2024, 3, 15, 14, 30, 45);
      expect(toOdooValue(dt), '2024-03-15 14:30:45');
    });

    test('passes through int list', () {
      expect(toOdooValue([1, 2, 3]), [1, 2, 3]);
    });

    test('passes through other values', () {
      expect(toOdooValue('hello'), 'hello');
      expect(toOdooValue(42), 42);
    });
  });

  group('buildMany2oneValue', () {
    test('returns id when set', () {
      expect(buildMany2oneValue(42), 42);
    });

    test('returns false when null', () {
      expect(buildMany2oneValue(null), false);
    });
  });

  group('extractInt', () {
    test('extracts int from int', () {
      expect(extractInt(42), 42);
    });

    test('extracts int from list', () {
      expect(extractInt([42, 'Name']), 42);
    });

    test('extracts int from string', () {
      expect(extractInt('42'), 42);
    });

    test('returns null for false', () {
      expect(extractInt(false), null);
    });
  });
}
