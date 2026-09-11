import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum LegacyDraftStatus { missing, valid, partial, invalid }

/// A non-mutating assessment of the pre-Drift editor buffer.
final class LegacyDraftInspection {
  const LegacyDraftInspection({
    required this.status,
    required this.issueLabels,
    required this.recoverableFields,
    required this.missingFields,
    required this.unknownFields,
    required this.rawPresent,
  });

  final LegacyDraftStatus status;
  final List<String> issueLabels;
  final List<String> recoverableFields;
  final List<String> missingFields;
  final List<String> unknownFields;
  final bool rawPresent;

  bool get hasActionableIssue => issueLabels.isNotEmpty;
}

/// Inspects the old SharedPreferences buffer without importing, deleting, or
/// rewriting it. The legacy format has no company identity and never stored
/// line discount/tax/total, so those values are deliberately not inferred.
final class LegacyDraftInspector {
  const LegacyDraftInspector(this.preferences);

  final SharedPreferences preferences;

  static const _prefix = 'orbi.sale_draft.';
  static const _keys = <String>{
    'clientName',
    'partnerId',
    'note',
    'paymentTermId',
    'installments',
    'lines',
    'approval',
    'pendingAction',
    'commandId',
    'orderLocalId',
    'orderRemoteId',
    'expectedVersion',
  };
  static const _lineKeys = <String>{
    'uuid',
    'name',
    'quantity',
    'unitPrice',
    'remoteId',
    'uomId',
    'uomName',
    'taxIds',
  };

  LegacyDraftInspection inspect(String scopeKey) {
    final key = '$_prefix${Uri.encodeComponent(scopeKey)}';
    final stored = preferences.get(key);
    if (stored != null && stored is! String) {
      return const LegacyDraftInspection(
        status: LegacyDraftStatus.invalid,
        issueLabels: ['El valor legado no es texto JSON'],
        recoverableFields: [],
        missingFields: [],
        unknownFields: [],
        rawPresent: true,
      );
    }
    final raw = stored as String?;
    if (raw == null) {
      return const LegacyDraftInspection(
        status: LegacyDraftStatus.missing,
        issueLabels: [],
        recoverableFields: [],
        missingFields: [],
        unknownFields: [],
        rawPresent: false,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on Object {
      return const LegacyDraftInspection(
        status: LegacyDraftStatus.invalid,
        issueLabels: ['El borrador legado no contiene JSON válido'],
        recoverableFields: [],
        missingFields: [],
        unknownFields: [],
        rawPresent: true,
      );
    }
    if (decoded is! Map) {
      return const LegacyDraftInspection(
        status: LegacyDraftStatus.invalid,
        issueLabels: ['El borrador legado no es un objeto'],
        recoverableFields: [],
        missingFields: [],
        unknownFields: [],
        rawPresent: true,
      );
    }
    final map = Map<String, dynamic>.fromEntries(
      decoded.entries
          .where((entry) => entry.key is String)
          .map((entry) => MapEntry(entry.key as String, entry.value)),
    );
    final unknown = map.keys.where((key) => !_keys.contains(key)).toList()
      ..sort();
    final missing = _keys.where((key) => !map.containsKey(key)).toList()
      ..sort();
    final recoverable =
        map.keys
            .where((key) => _keys.contains(key) && _fieldValid(map, key))
            .toList()
          ..sort();
    final issues = <String>[];
    if (unknown.isNotEmpty) issues.add('Contiene campos no reconocidos');
    if (missing.isNotEmpty) issues.add('Faltan campos del borrador legado');
    if (!_validShape(map)) {
      issues.add('Algunos campos legados tienen formato inválido');
    }
    // This is informational, not a guessed value: the old key had no company.
    issues.add('La empresa de origen no está identificada');
    issues.add('Descuento, impuesto y total de línea no fueron almacenados');
    final invalid = !_validShape(map);
    final status = invalid
        ? LegacyDraftStatus.invalid
        : missing.isNotEmpty || unknown.isNotEmpty
        ? LegacyDraftStatus.partial
        : LegacyDraftStatus.valid;
    return LegacyDraftInspection(
      status: status,
      issueLabels: List.unmodifiable(issues),
      recoverableFields: List.unmodifiable(recoverable),
      missingFields: List.unmodifiable(missing),
      unknownFields: List.unmodifiable(unknown),
      rawPresent: true,
    );
  }

  static bool _validShape(Map<String, dynamic> map) {
    for (final key in map.keys) {
      if (_keys.contains(key) && !_fieldValid(map, key)) return false;
    }
    final lines = map['lines'];
    if (lines is List) {
      for (final value in lines) {
        if (value is! Map) return false;
        final line = Map<String, dynamic>.fromEntries(
          value.entries
              .where((entry) => entry.key is String)
              .map((entry) => MapEntry(entry.key as String, entry.value)),
        );
        if (line.keys.length != _lineKeys.length ||
            !line.keys.toSet().containsAll(_lineKeys)) {
          return false;
        }
        if (line['uuid'] is! String || line['name'] is! String) return false;
        if (line['quantity'] is! num || line['unitPrice'] is! num) return false;
        if (line['remoteId'] != null && line['remoteId'] is! num) return false;
        if (line['uomId'] != null && line['uomId'] is! num) return false;
        if (line['uomName'] != null && line['uomName'] is! String) return false;
        final taxIds = line['taxIds'];
        if (taxIds is! List || taxIds.any((value) => value is! num)) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _fieldValid(Map<String, dynamic> map, String key) {
    final value = map[key];
    return switch (key) {
      'clientName' ||
      'note' ||
      'commandId' ||
      'orderLocalId' => value is String,
      'partnerId' ||
      'paymentTermId' ||
      'orderRemoteId' => value == null || value is num,
      'installments' => value is List && value.every((item) => item is num),
      'lines' => value is List,
      'approval' =>
        value is String &&
            {'required', 'pending', 'approved', 'rejected'}.contains(value),
      'pendingAction' => value is bool,
      'expectedVersion' => value is num,
      _ => false,
    };
  }
}
