import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theos_panel/features/sales/legacy_draft_inspector.dart';

Map<String, dynamic> _line() => {
  'uuid': 'line-1',
  'name': 'Producto',
  'quantity': 2,
  'unitPrice': 4.5,
  'remoteId': 3,
  'uomId': 1,
  'uomName': 'Unidad',
  'taxIds': [1],
};

Map<String, dynamic> _valid() => {
  'clientName': 'Cliente',
  'partnerId': 4,
  'note': 'Nota',
  'paymentTermId': 2,
  'installments': [30],
  'lines': [_line()],
  'approval': 'required',
  'pendingAction': false,
  'commandId': 'command-1',
  'orderLocalId': 'order-1',
  'orderRemoteId': null,
  'expectedVersion': 0,
};

void main() {
  const scope = 'orbi-panel|test-installation|https://erp.test|erp|1';
  final key = 'orbi.sale_draft.${Uri.encodeComponent(scope)}';

  test('reports missing legacy draft without writing preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final result = LegacyDraftInspector(prefs).inspect(scope);
    expect(result.status, LegacyDraftStatus.missing);
    expect(result.rawPresent, isFalse);
    expect(result.hasActionableIssue, isFalse);
    expect(prefs.getKeys(), isEmpty);
  });

  test(
    'recognizes exact legacy payload and reports unrecoverable fields',
    () async {
      final payload = jsonEncode(_valid());
      SharedPreferences.setMockInitialValues({key: payload});
      final prefs = await SharedPreferences.getInstance();
      final result = LegacyDraftInspector(prefs).inspect(scope);
      expect(result.status, LegacyDraftStatus.valid);
      expect(result.recoverableFields, containsAll(['lines', 'clientName']));
      expect(
        result.issueLabels,
        contains('La empresa de origen no está identificada'),
      );
      expect(
        result.issueLabels,
        contains('Descuento, impuesto y total de línea no fueron almacenados'),
      );
      expect(prefs.getString(key), payload);
    },
  );

  test('reports partial known payload and preserves its raw value', () async {
    final partial = _valid()
      ..remove('note')
      ..remove('expectedVersion');
    final payload = jsonEncode(partial);
    SharedPreferences.setMockInitialValues({key: payload});
    final prefs = await SharedPreferences.getInstance();
    final result = LegacyDraftInspector(prefs).inspect(scope);
    expect(result.status, LegacyDraftStatus.partial);
    expect(result.missingFields, containsAll(['note', 'expectedVersion']));
    expect(prefs.getString(key), payload);
  });

  test('reports malformed JSON and invalid field types safely', () async {
    SharedPreferences.setMockInitialValues({key: '{not-json'});
    final prefs = await SharedPreferences.getInstance();
    expect(
      LegacyDraftInspector(prefs).inspect(scope).status,
      LegacyDraftStatus.invalid,
    );
    final typed = _valid()..['lines'] = 'not-a-list';
    final typedRaw = jsonEncode(typed);
    SharedPreferences.setMockInitialValues({key: typedRaw});
    final typedPrefs = await SharedPreferences.getInstance();
    final result = LegacyDraftInspector(typedPrefs).inspect(scope);
    expect(result.status, LegacyDraftStatus.invalid);
    expect(typedPrefs.getString(key), typedRaw);

    SharedPreferences.setMockInitialValues({key: 42});
    final intPrefs = await SharedPreferences.getInstance();
    final intResult = LegacyDraftInspector(intPrefs).inspect(scope);
    expect(intResult.status, LegacyDraftStatus.invalid);
    expect(intPrefs.get(key), 42);
  });
}
