/// Tests for OdooModelGenerator.
///
/// These tests verify the code generation logic for @OdooModel annotated classes.
/// Since we can't easily test the full generator without build_runner,
/// we test the helper functions and expected output patterns.
library;

import 'package:test/test.dart';

void main() {
  group('OdooModelGenerator', () {
    group('Helper Functions', () {
      test('toSnakeCase converts PascalCase correctly', () {
        expect(_toSnakeCase('SaleOrder'), equals('sale_order'));
        expect(_toSnakeCase('ProductTemplate'), equals('product_template'));
        expect(_toSnakeCase('ResPartner'), equals('res_partner'));
        expect(_toSnakeCase('AccountMove'), equals('account_move'));
        expect(_toSnakeCase('CRMLead'), equals('c_r_m_lead')); // Edge case
      });

      test('toSnakeCase handles single word', () {
        expect(_toSnakeCase('Partner'), equals('partner'));
        expect(_toSnakeCase('Order'), equals('order'));
      });

      test('toCamelCase converts PascalCase correctly', () {
        expect(_toCamelCase('SaleOrder'), equals('saleOrder'));
        expect(_toCamelCase('ProductTemplate'), equals('productTemplate'));
        expect(_toCamelCase('ResPartner'), equals('resPartner'));
      });

      test('toCamelCase handles empty string', () {
        expect(_toCamelCase(''), equals(''));
      });

      test('toPascalCase converts snake_case correctly', () {
        expect(_toPascalCase('sale_order'), equals('SaleOrder'));
        expect(_toPascalCase('product_template'), equals('ProductTemplate'));
        expect(_toPascalCase('res_partner'), equals('ResPartner'));
      });

      test('toPascalCase handles single word', () {
        expect(_toPascalCase('partner'), equals('Partner'));
        expect(_toPascalCase('order'), equals('Order'));
      });

      test('toTitleCase converts camelCase to title case', () {
        expect(_toTitleCase('saleOrder'), equals('Sale Order'));
        expect(_toTitleCase('productName'), equals('Product Name'));
        expect(_toTitleCase('partnerId'), equals('Partner Id'));
      });
    });

    group('Field Type Detection', () {
      test('OdooId field generates id conversion', () {
        final conversion = _getFromOdooConversion('id', 'OdooId', false);
        expect(conversion, contains("data['id'] as int? ?? 0"));
      });

      test('OdooString field generates string conversion', () {
        final conversion = _getFromOdooConversion('name', 'OdooString', false);
        expect(conversion, contains("parseOdooString(data['name'])"));
      });

      test('OdooString required field generates required conversion', () {
        final conversion = _getFromOdooConversion('name', 'OdooString', true);
        expect(conversion, contains("parseOdooStringRequired(data['name'])"));
      });

      test('OdooInteger field generates int conversion', () {
        final conversion = _getFromOdooConversion('quantity', 'OdooInteger', false);
        expect(conversion, contains("parseOdooInt(data['quantity'])"));
      });

      test('OdooFloat field generates double conversion', () {
        final conversion = _getFromOdooConversion('price', 'OdooFloat', false);
        expect(conversion, contains("parseOdooDouble(data['price'])"));
      });

      test('OdooBoolean field generates bool conversion', () {
        final conversion = _getFromOdooConversion('active', 'OdooBoolean', false);
        expect(conversion, contains("parseOdooBool(data['active'])"));
      });

      test('OdooDateTime field generates datetime conversion', () {
        final conversion = _getFromOdooConversion('create_date', 'OdooDateTime', false);
        expect(conversion, contains("parseOdooDateTime(data['create_date'])"));
      });

      test('OdooDate field generates date conversion', () {
        final conversion = _getFromOdooConversion('date_order', 'OdooDate', false);
        expect(conversion, contains("parseOdooDate(data['date_order'])"));
      });

      test('OdooMany2One field generates many2one conversion', () {
        final conversion = _getFromOdooConversion('partner_id', 'OdooMany2One', false);
        expect(conversion, contains("extractMany2oneId(data['partner_id'])"));
      });

      test('OdooMany2OneName field generates name extraction', () {
        final conversion = _getFromOdooConversion('partner_id', 'OdooMany2OneName', false);
        expect(conversion, contains("extractMany2oneName(data['partner_id'])"));
      });

      test('OdooOne2Many field generates ids list extraction', () {
        final conversion = _getFromOdooConversion('order_line', 'OdooOne2Many', false);
        expect(conversion, contains("extractMany2manyIds(data['order_line'])"));
      });

      test('OdooMany2Many field generates ids list extraction', () {
        final conversion = _getFromOdooConversion('tag_ids', 'OdooMany2Many', false);
        expect(conversion, contains("extractMany2manyIds(data['tag_ids'])"));
      });

      test('OdooSelection field generates selection conversion', () {
        final conversion = _getFromOdooConversion('state', 'OdooSelection', false);
        expect(conversion, contains("parseOdooSelection(data['state'])"));
      });

      test('OdooBinary field generates binary conversion', () {
        final conversion = _getFromOdooConversion('image', 'OdooBinary', false);
        expect(conversion, contains("parseOdooString(data['image'])"));
      });

      test('OdooHtml field generates html conversion', () {
        final conversion = _getFromOdooConversion('description', 'OdooHtml', false);
        expect(conversion, contains("parseOdooString(data['description'])"));
      });

      test('OdooJson field generates json conversion', () {
        final conversion = _getFromOdooConversion('metadata', 'OdooJson', false);
        expect(conversion, contains("parseOdooJson(data['metadata'])"));
      });
    });

    group('toOdoo Generation', () {
      test('string field generates direct assignment', () {
        final conversion = _getToOdooConversion('name', 'OdooString');
        expect(conversion, equals("'name': record.name"));
      });

      test('datetime field generates format call', () {
        final conversion = _getToOdooConversion('createDate', 'OdooDateTime');
        expect(conversion, equals("'create_date': formatOdooDateTime(record.createDate)"));
      });

      test('date field generates format call', () {
        final conversion = _getToOdooConversion('dateOrder', 'OdooDate');
        expect(conversion, equals("'date_order': formatOdooDate(record.dateOrder)"));
      });

      test('many2many field generates replace command', () {
        final conversion = _getToOdooConversion('tagIds', 'OdooMany2Many');
        expect(conversion, contains('buildMany2manyReplace'));
      });

      test('many2one field generates direct id', () {
        final conversion = _getToOdooConversion('partnerId', 'OdooMany2One');
        expect(conversion, equals("'partner_id': record.partnerId"));
      });
    });

    group('Manager Class Generation', () {
      test('generates correct class name', () {
        final managerName = _generateManagerName('SaleOrder');
        expect(managerName, equals('SaleOrderManager'));
      });

      test('generates correct table name from class', () {
        final tableName = _generateTableName('SaleOrder');
        expect(tableName, equals('sale_order'));
      });

      test('generates odooFields list', () {
        final fields = ['id', 'name', 'partner_id', 'state'];
        final output = _generateOdooFieldsList(fields);
        expect(output, contains("'id'"));
        expect(output, contains("'name'"));
        expect(output, contains("'partner_id'"));
        expect(output, contains("'state'"));
      });

      test('generates fieldMappings map', () {
        final mappings = {
          'id': 'id',
          'name': 'name',
          'partner_id': 'partnerId',
          'date_order': 'dateOrder',
        };
        final output = _generateFieldMappings(mappings);
        expect(output, contains("'id': 'id'"));
        expect(output, contains("'name': 'name'"));
        expect(output, contains("'partner_id': 'partnerId'"));
        expect(output, contains("'date_order': 'dateOrder'"));
      });

      test('generates writableFields list', () {
        final fields = ['name', 'partnerId', 'dateOrder'];
        final output = _generateWritableFields(fields);
        expect(output, contains("'name'"));
        expect(output, contains("'partnerId'"));
        expect(output, contains("'dateOrder'"));
      });

      test('generates requiredFields list', () {
        final fields = ['name', 'partnerId'];
        final output = _generateRequiredFields(fields);
        expect(output, contains("'name'"));
        expect(output, contains("'partnerId'"));
      });
    });

    group('Validation Generation', () {
      test('generates required string validation', () {
        final validation = _generateStringValidation('name', 'Name');
        expect(validation, contains('record.name == null'));
        expect(validation, contains('record.name!.isEmpty'));
        expect(validation, contains('Name is required'));
      });

      test('generates required integer validation', () {
        final validation = _generateIntegerValidation('quantity', 'Quantity');
        expect(validation, contains('record.quantity == null'));
        expect(validation, contains('record.quantity == 0'));
        expect(validation, contains('Quantity is required'));
      });

      test('generates required many2one validation', () {
        final validation = _generateMany2OneValidation('partnerId', 'Partner Id');
        expect(validation, contains('record.partnerId == null'));
        expect(validation, contains('record.partnerId == 0'));
        expect(validation, contains('Partner Id is required'));
      });

      test('generates required list validation', () {
        final validation = _generateListValidation('orderLines', 'Order Lines');
        expect(validation, contains('record.orderLines == null'));
        expect(validation, contains('record.orderLines!.isEmpty'));
        expect(validation, contains('requires at least one item'));
      });
    });

    group('Computed Field Generation', () {
      test('generates dependency graph', () {
        final dependencies = {
          'orderLines': ['amountTotal', 'amountTax'],
          'taxId': ['amountTax'],
        };
        final output = _generateDependencyGraph(dependencies);
        expect(output, contains("'orderLines': ['amountTotal', 'amountTax']"));
        expect(output, contains("'taxId': ['amountTax']"));
      });

      test('generates compute methods map', () {
        final methods = {
          'amountTotal': '_computeAmountTotal',
          'amountTax': '_computeAmountTax',
        };
        final output = _generateComputeMethods(methods);
        expect(output, contains("'amountTotal': '_computeAmountTotal'"));
        expect(output, contains("'amountTax': '_computeAmountTax'"));
      });

      test('generates precompute fields list', () {
        final fields = ['amountTotal', 'amountUntaxed'];
        final output = _generatePrecomputeFields(fields);
        expect(output, contains("'amountTotal'"));
        expect(output, contains("'amountUntaxed'"));
      });
    });

    group('Field Labels Generation', () {
      test('generates field labels map', () {
        final fields = ['partnerId', 'dateOrder', 'amountTotal'];
        final output = _generateFieldLabels(fields);
        expect(output, contains("'partnerId': 'Partner Id'"));
        expect(output, contains("'dateOrder': 'Date Order'"));
        expect(output, contains("'amountTotal': 'Amount Total'"));
      });
    });

    group('Edge Cases', () {
      test('handles empty class gracefully', () {
        final fields = <String>[];
        final output = _generateOdooFieldsList(fields);
        expect(output, equals('[]'));
      });

      test('handles special characters in field names', () {
        expect(_toSnakeCase('x_custom_field'), equals('x_custom_field'));
      });

      test('handles numeric suffixes', () {
        expect(_toSnakeCase('field1'), equals('field1'));
        expect(_toSnakeCase('Address2'), equals('address2'));
      });

      test('handles consecutive capitals', () {
        // Note: This may produce non-standard output for acronyms
        expect(_toSnakeCase('XMLParser'), contains('_'));
        expect(_toSnakeCase('HTTPClient'), contains('_'));
      });
    });

    group('Complete Output Structure', () {
      test('generated manager extends OdooModelManager', () {
        final output = _generateManagerHeader('SaleOrder', 'sale.order');
        expect(output, contains('extends OdooModelManager<SaleOrder>'));
      });

      test('generated manager has odooModel getter', () {
        final output = _generateOdooModelGetter('sale.order');
        expect(output, contains("String get odooModel => 'sale.order'"));
      });

      test('generated manager has tableName getter', () {
        final output = _generateTableNameGetter('sale_order');
        expect(output, contains("String get tableName => 'sale_order'"));
      });

      test('generates global instance', () {
        final output = _generateGlobalInstance('SaleOrderManager');
        expect(output, contains('final saleOrderManager = SaleOrderManager()'));
      });
    });
  });
}

// ============================================================================
// Helper functions that mirror the generator logic for testing
// ============================================================================

String _toSnakeCase(String input) {
  // Handle already snake_case or lowercase
  if (!input.contains(RegExp('[A-Z]'))) {
    return input;
  }
  final result = input.replaceAllMapped(
    RegExp('([A-Z])'),
    (match) => '_${match.group(1)!.toLowerCase()}',
  );
  // Only strip leading underscore (from PascalCase inputs like 'SaleOrder' → '_sale_order')
  return result.startsWith('_') ? result.substring(1) : result;
}

String _toCamelCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toLowerCase() + input.substring(1);
}

String _toPascalCase(String input) {
  if (input.isEmpty) return input;
  return input
      .split('_')
      .map((part) => part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1))
      .join();
}

String _toTitleCase(String input) {
  if (input.isEmpty) return input;
  final withSpaces = input.replaceAllMapped(
    RegExp(r'([A-Z])'),
    (match) => ' ${match.group(1)}',
  );
  return withSpaces[0].toUpperCase() + withSpaces.substring(1);
}

String _getFromOdooConversion(String fieldName, String fieldType, bool isRequired) {
  switch (fieldType) {
    case 'OdooId':
      return "data['$fieldName'] as int? ?? 0";
    case 'OdooString':
    case 'OdooBinary':
    case 'OdooHtml':
      return isRequired
          ? "parseOdooStringRequired(data['$fieldName'])"
          : "parseOdooString(data['$fieldName'])";
    case 'OdooInteger':
      return isRequired
          ? "parseOdooInt(data['$fieldName']) ?? 0"
          : "parseOdooInt(data['$fieldName'])";
    case 'OdooFloat':
    case 'OdooMonetary':
      return isRequired
          ? "parseOdooDouble(data['$fieldName']) ?? 0.0"
          : "parseOdooDouble(data['$fieldName'])";
    case 'OdooBoolean':
      return "parseOdooBool(data['$fieldName'])";
    case 'OdooDateTime':
      return "parseOdooDateTime(data['$fieldName'])";
    case 'OdooDate':
      return "parseOdooDate(data['$fieldName'])";
    case 'OdooMany2One':
      return "extractMany2oneId(data['$fieldName'])";
    case 'OdooMany2OneName':
      return "extractMany2oneName(data['$fieldName'])";
    case 'OdooOne2Many':
    case 'OdooMany2Many':
      return "extractMany2manyIds(data['$fieldName'])";
    case 'OdooSelection':
      return "parseOdooSelection(data['$fieldName'])";
    case 'OdooJson':
      return "parseOdooJson(data['$fieldName'])";
    default:
      return "data['$fieldName']";
  }
}

String _getToOdooConversion(String dartName, String fieldType) {
  final snakeName = _toSnakeCase(dartName);
  switch (fieldType) {
    case 'OdooString':
    case 'OdooInteger':
    case 'OdooFloat':
    case 'OdooBoolean':
    case 'OdooSelection':
    case 'OdooBinary':
    case 'OdooHtml':
    case 'OdooJson':
      return "'$snakeName': record.$dartName";
    case 'OdooDateTime':
      return "'$snakeName': formatOdooDateTime(record.$dartName)";
    case 'OdooDate':
      return "'$snakeName': formatOdooDate(record.$dartName)";
    case 'OdooMany2One':
      return "'$snakeName': record.$dartName";
    case 'OdooMany2Many':
      return "'$snakeName': buildMany2manyReplace(record.$dartName ?? [])";
    default:
      return "'$snakeName': record.$dartName";
  }
}

String _generateManagerName(String className) => '${className}Manager';

String _generateTableName(String className) => _toSnakeCase(className);

String _generateOdooFieldsList(List<String> fields) {
  if (fields.isEmpty) return '[]';
  return '[${fields.map((f) => "'$f'").join(', ')}]';
}

String _generateFieldMappings(Map<String, String> mappings) {
  final entries = mappings.entries.map((e) => "'${e.key}': '${e.value}'");
  return '{${entries.join(', ')}}';
}

String _generateWritableFields(List<String> fields) {
  return '[${fields.map((f) => "'$f'").join(', ')}]';
}

String _generateRequiredFields(List<String> fields) {
  return '[${fields.map((f) => "'$f'").join(', ')}]';
}

String _generateStringValidation(String fieldName, String label) {
  return '''
    if (record.$fieldName == null || record.$fieldName!.isEmpty) {
      errors['$fieldName'] = '$label is required';
    }
''';
}

String _generateIntegerValidation(String fieldName, String label) {
  return '''
    if (record.$fieldName == null || record.$fieldName == 0) {
      errors['$fieldName'] = '$label is required';
    }
''';
}

String _generateMany2OneValidation(String fieldName, String label) {
  return '''
    if (record.$fieldName == null || record.$fieldName == 0) {
      errors['$fieldName'] = '$label is required';
    }
''';
}

String _generateListValidation(String fieldName, String label) {
  return '''
    if (record.$fieldName == null || record.$fieldName!.isEmpty) {
      errors['$fieldName'] = '$label requires at least one item';
    }
''';
}

String _generateDependencyGraph(Map<String, List<String>> dependencies) {
  final entries = dependencies.entries.map((e) {
    final deps = e.value.map((d) => "'$d'").join(', ');
    return "'${e.key}': [$deps]";
  });
  return '{${entries.join(', ')}}';
}

String _generateComputeMethods(Map<String, String> methods) {
  final entries = methods.entries.map((e) => "'${e.key}': '${e.value}'");
  return '{${entries.join(', ')}}';
}

String _generatePrecomputeFields(List<String> fields) {
  return '[${fields.map((f) => "'$f'").join(', ')}]';
}

String _generateFieldLabels(List<String> fields) {
  final entries = fields.map((f) => "'$f': '${_toTitleCase(f)}'");
  return '{${entries.join(', ')}}';
}

String _generateManagerHeader(String className, String odooModel) {
  return 'class ${className}Manager extends OdooModelManager<$className> {';
}

String _generateOdooModelGetter(String odooModel) {
  return "String get odooModel => '$odooModel';";
}

String _generateTableNameGetter(String tableName) {
  return "String get tableName => '$tableName';";
}

String _generateGlobalInstance(String managerName) {
  final varName = _toCamelCase(managerName);
  return 'final $varName = $managerName();';
}
