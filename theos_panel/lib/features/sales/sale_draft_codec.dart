import 'sale_editor.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Strict, versioned serialization for editable sale drafts.
abstract final class SaleDraftCodec {
  static const int _payloadVersion = 1;
  static const Set<String> _snapshotKeys = {
    'payloadVersion',
    'scopeKey',
    'clientName',
    'partnerId',
    'note',
    'lines',
    'installments',
    'paymentTermId',
    'baseRevision',
    'approval',
    'pendingAction',
    'commandId',
    'orderLocalId',
    'orderRemoteId',
    'expectedVersion',
  };
  static const Set<String> _lineKeys = {
    'uuid',
    'name',
    'quantity',
    'unitPrice',
    'discount',
    'tax',
    'total',
    'remoteId',
    'uomId',
    'uomName',
    'taxIds',
  };
  static const Set<String> _installmentKeys = {'dueDays'};

  static Map<String, dynamic> encode(SaleDraftSnapshot draft) {
    _finite(draft.lines);
    return <String, dynamic>{
      'payloadVersion': _payloadVersion,
      'scopeKey': draft.scopeKey,
      'clientName': draft.clientName,
      'partnerId': draft.partnerId,
      'note': draft.note,
      'lines': draft.lines.map(_encodeLine).toList(growable: false),
      'installments': draft.installments
          .map((i) => <String, dynamic>{'dueDays': i.dueDays})
          .toList(growable: false),
      'paymentTermId': draft.paymentTermId,
      'baseRevision': draft.baseRevision,
      'approval': draft.approval.name,
      'pendingAction': draft.pendingAction,
      'commandId': draft.commandId,
      'orderLocalId': draft.orderLocalId,
      'orderRemoteId': draft.orderRemoteId,
      'expectedVersion': draft.expectedVersion,
    };
  }

  static SaleDraftSnapshot decode(Map<String, dynamic> map) {
    _keys(map, _snapshotKeys, 'draft');
    final version = _int(map, 'payloadVersion');
    if (version != _payloadVersion) {
      throw FormatException('unsupported payloadVersion: $version');
    }
    final rawLines = _list(map, 'lines');
    final rawInstallments = _list(map, 'installments');
    final approvalName = _string(map, 'approval');
    final SaleApprovalState approval = _enumValue<SaleApprovalState>(
      SaleApprovalState.values,
      approvalName,
      'approval',
    );
    try {
      return SaleDraftSnapshot(
        scopeKey: _string(map, 'scopeKey'),
        clientName: _string(map, 'clientName'),
        partnerId: _nullableInt(map, 'partnerId'),
        note: _string(map, 'note'),
        lines: rawLines.map(_decodeLine).toList(growable: false),
        installments: rawInstallments
            .map(_decodeInstallment)
            .toList(growable: false),
        paymentTermId: _nullableInt(map, 'paymentTermId'),
        baseRevision: _int(map, 'baseRevision'),
        approval: approval,
        pendingAction: _bool(map, 'pendingAction'),
        commandId: _string(map, 'commandId'),
        orderLocalId: _string(map, 'orderLocalId'),
        orderRemoteId: _nullableInt(map, 'orderRemoteId'),
        expectedVersion: _int(map, 'expectedVersion'),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('invalid sale draft: $error');
    }
  }

  static Map<String, dynamic> _encodeLine(SaleDraftLine line) {
    _finiteNumber(line.quantity, 'quantity');
    _finiteNumber(line.unitPrice, 'unitPrice');
    _finiteNumber(line.discount, 'discount');
    _finiteNumber(line.tax, 'tax');
    _finiteNumber(line.total, 'total');
    return <String, dynamic>{
      'uuid': line.uuid,
      'name': line.name,
      'quantity': line.quantity,
      'unitPrice': line.unitPrice,
      'discount': line.discount,
      'tax': line.tax,
      'total': line.total,
      'remoteId': line.remoteId,
      'uomId': line.uomId,
      'uomName': line.uomName,
      'taxIds': line.taxIds,
    };
  }

  static SaleDraftLine _decodeLine(dynamic value) {
    final map = _object(value, 'line');
    _keys(map, _lineKeys, 'line');
    final taxIds = _list(map, 'taxIds');
    return SaleDraftLine(
      uuid: _string(map, 'uuid'),
      name: _string(map, 'name'),
      quantity: _double(map, 'quantity'),
      unitPrice: _double(map, 'unitPrice'),
      discount: _double(map, 'discount'),
      tax: _double(map, 'tax'),
      total: _double(map, 'total'),
      remoteId: _nullableInt(map, 'remoteId'),
      uomId: _nullableInt(map, 'uomId'),
      uomName: _nullableString(map, 'uomName'),
      taxIds: taxIds
          .map((v) => _intValue(v, 'taxIds item'))
          .toList(growable: false),
    );
  }

  static PaymentTermInstallment _decodeInstallment(dynamic value) {
    final map = _object(value, 'installment');
    _keys(map, _installmentKeys, 'installment');
    return PaymentTermInstallment(dueDays: _int(map, 'dueDays'));
  }

  static void _finite(List<SaleDraftLine> lines) {
    for (final line in lines) {
      _finiteNumber(line.quantity, 'quantity');
      _finiteNumber(line.unitPrice, 'unitPrice');
      _finiteNumber(line.discount, 'discount');
      _finiteNumber(line.tax, 'tax');
      _finiteNumber(line.total, 'total');
    }
  }

  static void _finiteNumber(num value, String field) {
    if (!value.isFinite) throw FormatException('$field must be finite');
  }

  static Map<String, dynamic> _object(dynamic value, String field) {
    if (value is! Map) throw FormatException('$field must be an object');
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$field has non-string key');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static List<dynamic> _list(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! List) throw FormatException('$field must be a list');
    return value;
  }

  static void _keys(
    Map<String, dynamic> map,
    Set<String> expected,
    String field,
  ) {
    final actual = map.keys.toSet();
    if (actual.length != expected.length || !actual.containsAll(expected)) {
      throw FormatException('invalid $field fields');
    }
  }

  static String _string(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! String) throw FormatException('$field must be a string');
    return value;
  }

  static String? _nullableString(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value != null && value is! String) {
      throw FormatException('$field must be a string or null');
    }
    return value as String?;
  }

  static bool _bool(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! bool) throw FormatException('$field must be a bool');
    return value;
  }

  static int _int(Map<String, dynamic> map, String field) =>
      _intValue(map[field], field);

  static int _intValue(dynamic value, String field) {
    if (value is! int) throw FormatException('$field must be an int');
    return value;
  }

  static int? _nullableInt(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value != null && value is! int) {
      throw FormatException('$field must be an int or null');
    }
    return value as int?;
  }

  static double _double(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! num) throw FormatException('$field must be a number');
    _finiteNumber(value, field);
    return value.toDouble();
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    String name,
    String field,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('invalid $field: $name');
  }
}
