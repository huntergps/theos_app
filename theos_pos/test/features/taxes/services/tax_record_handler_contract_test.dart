import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/taxes/services/tax_record_handler.dart';

void main() {
  test('fiscal positions request their own Odoo fields', () {
    final fields = FiscalPositionRecordHandler().defaultFields;

    expect(fields, containsAll(<String>['auto_apply', 'country_id']));
  });
}
