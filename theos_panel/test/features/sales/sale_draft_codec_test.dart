import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_panel/features/sales/sale_draft_codec.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';

void main() {
  test('round trips every snapshot and line field', () {
    final draft = SaleDraftSnapshot(
      scopeKey: 'scope-a',
      clientName: 'Cliente',
      partnerId: 12,
      note: 'Nota',
      lines: const [
        SaleDraftLine(
          uuid: 'line-1',
          name: 'Producto',
          quantity: 2.5,
          unitPrice: 10.25,
          discount: 3.5,
          tax: 15,
          total: 26.8,
          amountsCalculated: true,
          remoteId: 44,
          uomId: 7,
          uomName: 'Unidad',
          taxIds: [1, 2],
        ),
      ],
      installments: [
        PaymentTermInstallment(dueDays: 0),
        PaymentTermInstallment(dueDays: 30),
      ],
      paymentTermId: 9,
      baseRevision: 4,
      approval: SaleApprovalState.approved,
      pendingAction: true,
      commandId: 'command-1',
      orderLocalId: 'order-local',
      orderRemoteId: 99,
      expectedVersion: 8,
    );

    final encoded = SaleDraftCodec.encode(draft);
    expect(encoded['payloadVersion'], 2);
    expect(SaleDraftCodec.decode(encoded), isA<SaleDraftSnapshot>());
    final restored = SaleDraftCodec.decode(encoded);
    expect(restored.scopeKey, draft.scopeKey);
    expect(restored.clientName, draft.clientName);
    expect(restored.partnerId, draft.partnerId);
    expect(restored.note, draft.note);
    expect(restored.paymentTermId, draft.paymentTermId);
    expect(restored.baseRevision, draft.baseRevision);
    expect(restored.approval, draft.approval);
    expect(restored.pendingAction, draft.pendingAction);
    expect(restored.commandId, draft.commandId);
    expect(restored.orderLocalId, draft.orderLocalId);
    expect(restored.orderRemoteId, draft.orderRemoteId);
    expect(restored.expectedVersion, draft.expectedVersion);
    expect(restored.installments.map((i) => i.dueDays), [0, 30]);
    expect(restored.lines.single.uuid, 'line-1');
    expect(restored.lines.single.discount, 3.5);
    expect(restored.lines.single.tax, 15);
    expect(restored.lines.single.total, 26.8);
    expect(restored.lines.single.taxIds, [1, 2]);
  });

  test('rejects legacy and incomplete payloads without defaults', () {
    final payload = <String, dynamic>{
      'payloadVersion': 1,
      'scopeKey': 'scope',
      'clientName': '',
      'partnerId': null,
      'note': '',
      'lines': <dynamic>[],
      'installments': [
        <String, dynamic>{'dueDays': 0},
      ],
      'paymentTermId': null,
      'baseRevision': 0,
      'approval': 'required',
      'pendingAction': false,
      'commandId': '',
      'orderLocalId': 'draft',
      'orderRemoteId': null,
      'expectedVersion': 0,
    };
    payload.remove('discount');
    payload.remove('tax');
    expect(
      () => SaleDraftCodec.decode({...payload}..remove('note')),
      throwsFormatException,
    );
    expect(
      () => SaleDraftCodec.decode({...payload, 'payloadVersion': 0}),
      throwsFormatException,
    );
  });

  test('decodes v1 lines as unresolved and requires v2 provenance flag', () {
    final v2 = SaleDraftCodec.encode(
      SaleDraftSnapshot(
        lines: const [
          SaleDraftLine(
            uuid: 'l',
            name: 'P',
            quantity: 1,
            amountsCalculated: true,
          ),
        ],
      ),
    );
    final v1 = <String, dynamic>{...v2, 'payloadVersion': 1};
    v1['lines'] = [
      Map<String, dynamic>.from(v2['lines'].first)..remove('amountsCalculated'),
    ];
    expect(SaleDraftCodec.decode(v1).lines.single.amountsCalculated, isFalse);
    final missingFlag = <String, dynamic>{...v2};
    missingFlag['lines'] = [
      Map<String, dynamic>.from(v2['lines'].first)..remove('amountsCalculated'),
    ];
    expect(() => SaleDraftCodec.decode(missingFlag), throwsFormatException);
  });

  test(
    'rejects invalid types, enum values, extra fields, and nonfinite numbers',
    () {
      final line = <String, dynamic>{
        'uuid': 'line',
        'name': 'Product',
        'quantity': 1.0,
        'unitPrice': 2.0,
        'discount': 0.0,
        'tax': 0.0,
        'total': 2.0,
        'remoteId': null,
        'uomId': null,
        'uomName': null,
        'taxIds': <dynamic>[],
      };
      final map = SaleDraftCodec.encode(SaleDraftSnapshot(lines: const []));
      map['lines'] = [line];
      expect(
        () => SaleDraftCodec.decode({...map, 'approval': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => SaleDraftCodec.decode({...map, 'unexpected': true}),
        throwsFormatException,
      );
      expect(
        () => SaleDraftCodec.decode({...map, 'pendingAction': 'false'}),
        throwsFormatException,
      );
      expect(
        () => SaleDraftCodec.decode({
          ...map,
          'lines': [
            {...line, 'discount': double.nan},
          ],
        }),
        throwsFormatException,
      );
    },
  );
}
