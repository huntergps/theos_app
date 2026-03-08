import 'package:theos_pos_core/theos_pos_core.dart' show SaleOrder, SaleOrderLine;

import '../../../core/services/logger_service.dart';
import '../providers/base_order_state.dart';

/// Result of conflict detection
class ConflictDetectionResult {
  final bool hasConflicts;
  final List<ConflictDetail> conflicts;
  final String? conflictMessage;
  final Map<String, dynamic> mergeableFields;

  const ConflictDetectionResult._({
    required this.hasConflicts,
    this.conflicts = const [],
    this.conflictMessage,
    this.mergeableFields = const {},
  });

  factory ConflictDetectionResult.noConflicts({
    Map<String, dynamic> mergeableFields = const {},
  }) =>
      ConflictDetectionResult._(
        hasConflicts: false,
        mergeableFields: mergeableFields,
      );

  factory ConflictDetectionResult.withConflicts({
    required List<ConflictDetail> conflicts,
    required String conflictMessage,
    Map<String, dynamic> mergeableFields = const {},
  }) =>
      ConflictDetectionResult._(
        hasConflicts: true,
        conflicts: conflicts,
        conflictMessage: conflictMessage,
        mergeableFields: mergeableFields,
      );

  /// Get list of conflicting field names
  List<String> get conflictingFieldNames =>
      conflicts.map((c) => c.fieldName).toList();
}

/// Service for detecting conflicts between local and server changes
///
/// This service provides unified conflict detection logic for both
/// Fast Sale POS and Sale Order Form screens.
///
/// Features:
/// - Order header field conflict detection
/// - Order line conflict detection
/// - Configurable conflict sensitivity
/// - Mergeable vs conflicting field separation
///
/// Usage:
/// ```dart
/// final service = ConflictDetectionService();
/// final result = service.detectOrderConflicts(
///   localOrder: localOrder,
///   serverOrder: serverOrder,
///   changedFields: myChangedFields,
///   serverUserName: 'admin',
/// );
/// if (result.hasConflicts) {
///   // Handle conflicts
/// }
/// ```
class ConflictDetectionService {
  static const _tag = '[ConflictDetection]';

  /// Fields that are tracked for conflict detection on orders
  static const _trackableOrderFields = [
    'partner_id',
    'pricelist_id',
    'payment_term_id',
    'warehouse_id',
    'user_id',
    'date_order',
    'commitment_date',
    'note',
    'partner_phone',
    'partner_email',
    'end_customer_name',
    'end_customer_phone',
    'end_customer_email',
  ];

  /// Fields that are tracked for conflict detection on lines
  static const _trackableLineFields = [
    'product_uom_qty',
    'price_unit',
    'discount',
    'product_uom',
    'name',
  ];

  /// Detect conflicts between local and server order changes
  ///
  /// [localOrder] - Current local order state
  /// [serverOrder] - Order received from server (via WebSocket or reload)
  /// [changedFields] - Map of locally changed fields with their values
  /// [serverUserName] - Name of user who made server changes (for message)
  ///
  /// Returns [ConflictDetectionResult] with:
  /// - List of conflicts if any fields were modified both locally and on server
  /// - Mergeable fields that can be applied without conflict
  ConflictDetectionResult detectOrderConflicts({
    required SaleOrder localOrder,
    required SaleOrder serverOrder,
    required Map<String, dynamic> changedFields,
    String? serverUserName,
  }) {
    logger.d(_tag, 'Detecting order conflicts for order ${localOrder.id}');

    if (changedFields.isEmpty) {
      logger.d(_tag, 'No local changes, no conflicts possible');
      return ConflictDetectionResult.noConflicts();
    }

    final conflicts = <ConflictDetail>[];
    final mergeableFields = <String, dynamic>{};

    // Compare each trackable field
    for (final field in _trackableOrderFields) {
      final localValue = _getOrderFieldValue(localOrder, field);
      final serverValue = _getOrderFieldValue(serverOrder, field);

      // Skip if values are the same
      if (_valuesEqual(localValue, serverValue)) continue;

      // Server has different value
      if (changedFields.containsKey(field)) {
        // Field was modified locally AND on server = conflict
        final localChange = changedFields[field];
        conflicts.add(ConflictDetail(
          fieldName: _getFieldDisplayName(field),
          localValue: localChange,
          serverValue: serverValue,
          serverUserName: serverUserName,
        ));
        logger.d(_tag, 'Conflict on $field: local=$localChange, server=$serverValue');
      } else {
        // Field only modified on server = can merge
        mergeableFields[field] = serverValue;
        logger.d(_tag, 'Mergeable field $field: $serverValue');
      }
    }

    if (conflicts.isNotEmpty) {
      final conflictFieldNames = conflicts.map((c) => c.fieldName).join(', ');
      final userName = serverUserName ?? 'otro usuario';
      return ConflictDetectionResult.withConflicts(
        conflicts: conflicts,
        conflictMessage:
            'El usuario $userName modificó: $conflictFieldNames. '
            'Revisa tus cambios antes de guardar.',
        mergeableFields: mergeableFields,
      );
    }

    return ConflictDetectionResult.noConflicts(
      mergeableFields: mergeableFields,
    );
  }

  /// Detect conflicts on order lines
  ///
  /// [localLines] - Current local lines
  /// [serverLines] - Lines received from server
  /// [modifiedLineIds] - Set of locally modified line IDs
  /// [serverUserName] - Name of user who made server changes
  ///
  /// Returns map of lineId -> ConflictDetectionResult
  Map<int, ConflictDetectionResult> detectLineConflicts({
    required List<SaleOrderLine> localLines,
    required List<SaleOrderLine> serverLines,
    required Set<int> modifiedLineIds,
    String? serverUserName,
  }) {
    logger.d(_tag, 'Detecting line conflicts for ${localLines.length} lines');

    final results = <int, ConflictDetectionResult>{};

    // Build lookup map for server lines
    final serverLineMap = {for (var l in serverLines) l.id: l};

    for (final localLine in localLines) {
      // Skip new local lines (negative ID)
      if (localLine.id < 0) continue;

      // Skip lines not modified locally
      if (!modifiedLineIds.contains(localLine.id)) continue;

      final serverLine = serverLineMap[localLine.id];
      if (serverLine == null) {
        // Line was deleted on server
        results[localLine.id] = ConflictDetectionResult.withConflicts(
          conflicts: [
            ConflictDetail(
              fieldName: 'Línea',
              localValue: 'Modificada localmente',
              serverValue: 'Eliminada en servidor',
              serverUserName: serverUserName,
            ),
          ],
          conflictMessage: 'La línea fue eliminada en el servidor.',
        );
        continue;
      }

      // Compare line fields
      final conflicts = <ConflictDetail>[];
      final mergeableFields = <String, dynamic>{};

      for (final field in _trackableLineFields) {
        final localValue = _getLineFieldValue(localLine, field);
        final serverValue = _getLineFieldValue(serverLine, field);

        if (!_valuesEqual(localValue, serverValue)) {
          // Line was modified on server for this field
          conflicts.add(ConflictDetail(
            fieldName: _getFieldDisplayName(field),
            localValue: localValue,
            serverValue: serverValue,
            serverUserName: serverUserName,
          ));
        }
      }

      if (conflicts.isNotEmpty) {
        results[localLine.id] = ConflictDetectionResult.withConflicts(
          conflicts: conflicts,
          conflictMessage:
              'Línea ${localLine.productName ?? localLine.id} modificada en servidor.',
          mergeableFields: mergeableFields,
        );
      } else {
        results[localLine.id] = ConflictDetectionResult.noConflicts();
      }
    }

    return results;
  }

  /// Quick check if server data is different from local
  ///
  /// Use this for lightweight conflict pre-check before full detection.
  bool hasServerChanges({
    required SaleOrder localOrder,
    required SaleOrder serverOrder,
  }) {
    // Check write_date if available
    if (localOrder.writeDate != null && serverOrder.writeDate != null) {
      return serverOrder.writeDate!.isAfter(localOrder.writeDate!);
    }

    // Fallback: compare key fields
    return localOrder.partnerId != serverOrder.partnerId ||
        localOrder.pricelistId != serverOrder.pricelistId ||
        localOrder.paymentTermId != serverOrder.paymentTermId ||
        localOrder.amountTotal != serverOrder.amountTotal;
  }

  // Helper methods

  dynamic _getOrderFieldValue(SaleOrder order, String field) {
    switch (field) {
      case 'partner_id':
        return order.partnerId;
      case 'pricelist_id':
        return order.pricelistId;
      case 'payment_term_id':
        return order.paymentTermId;
      case 'warehouse_id':
        return order.warehouseId;
      case 'user_id':
        return order.userId;
      case 'date_order':
        return order.dateOrder;
      case 'commitment_date':
        return order.commitmentDate;
      case 'note':
        return order.note;
      case 'partner_phone':
        return order.partnerPhone;
      case 'partner_email':
        return order.partnerEmail;
      case 'end_customer_name':
        return order.endCustomerName;
      case 'end_customer_phone':
        return order.endCustomerPhone;
      case 'end_customer_email':
        return order.endCustomerEmail;
      default:
        return null;
    }
  }

  dynamic _getLineFieldValue(SaleOrderLine line, String field) {
    switch (field) {
      case 'product_uom_qty':
        return line.productUomQty;
      case 'price_unit':
        return line.priceUnit;
      case 'discount':
        return line.discount;
      case 'product_uom':
        return line.productUomId;
      case 'name':
        return line.name;
      default:
        return null;
    }
  }

  bool _valuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    // Handle numeric comparison with tolerance
    if (a is num && b is num) {
      return (a - b).abs() < 0.001;
    }

    // Handle DateTime comparison (ignore milliseconds)
    if (a is DateTime && b is DateTime) {
      return a.year == b.year &&
          a.month == b.month &&
          a.day == b.day &&
          a.hour == b.hour &&
          a.minute == b.minute;
    }

    return a == b;
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'partner_id':
        return 'Cliente';
      case 'pricelist_id':
        return 'Lista de precios';
      case 'payment_term_id':
        return 'Plazo de pago';
      case 'warehouse_id':
        return 'Almacén';
      case 'user_id':
        return 'Vendedor';
      case 'date_order':
        return 'Fecha';
      case 'commitment_date':
        return 'Fecha compromiso';
      case 'note':
        return 'Notas';
      case 'partner_phone':
        return 'Teléfono';
      case 'partner_email':
        return 'Email';
      case 'end_customer_name':
        return 'Cliente final';
      case 'end_customer_phone':
        return 'Teléfono cliente final';
      case 'end_customer_email':
        return 'Email cliente final';
      case 'product_uom_qty':
        return 'Cantidad';
      case 'price_unit':
        return 'Precio';
      case 'discount':
        return 'Descuento';
      case 'product_uom':
        return 'Unidad';
      case 'name':
        return 'Descripción';
      default:
        return field;
    }
  }
}

/// Singleton instance
final conflictDetectionService = ConflictDetectionService();
