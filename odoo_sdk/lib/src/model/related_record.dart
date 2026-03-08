/// RelatedRecord<T> - Lazy-Loading Many2One Wrapper
///
/// Wraps Many2One relationships to provide:
/// - Immediate access to ID and display name (without DB lookup)
/// - Lazy loading of full related record when needed
/// - Memory-efficient (doesn't load related data by default)
///
/// ## Usage
///
/// ```dart
/// class SaleOrder {
///   @OdooMany2One('res.partner')
///   final RelatedRecord<Partner>? partner;
///
///   // Quick access (no DB lookup)
///   int? get partnerId => partner?.id;
///   String? get partnerName => partner?.displayName;
///
///   // Full record (lazy loaded)
///   Future<Partner?> getPartner() => partner?.load();
/// }
/// ```
library;

import 'dart:async';

import 'odoo_record.dart';

/// Wrapper for Many2One relational fields.
///
/// Stores the ID and display name from Odoo's [id, name] tuple format.
/// Can lazy-load the full related record when needed.
class RelatedRecord<T extends OdooRecord<T>> {
  /// The ID of the related record.
  final int? id;

  /// The display name of the related record.
  final String? displayName;

  /// Cached full record (populated after load()).
  T? _cached;

  /// Create a related record reference.
  RelatedRecord({
    this.id,
    this.displayName,
  });

  /// Create from Odoo's Many2One format: [id, name] or false.
  factory RelatedRecord.fromOdoo(dynamic value) {
    if (value == null || value == false) {
      return RelatedRecord();
    }
    if (value is int) {
      return RelatedRecord(id: value);
    }
    if (value is List && value.isNotEmpty) {
      return RelatedRecord(
        id: value[0] as int,
        displayName: value.length > 1 ? value[1]?.toString() : null,
      );
    }
    return RelatedRecord();
  }

  /// Create from separate ID and name fields.
  factory RelatedRecord.fromIdName(int? id, String? name) {
    return RelatedRecord(id: id, displayName: name);
  }

  /// Check if this reference has a value.
  bool get hasValue => id != null && id! > 0;

  /// Check if the full record is loaded.
  bool get isLoaded => _cached != null;

  /// Get the cached record (may be null if not loaded).
  T? get cached => _cached;

  /// Load the full related record.
  ///
  /// Returns cached record if already loaded.
  /// Returns null if no ID or record not found.
  Future<T?> load({bool forceRefresh = false}) async {
    if (id == null || id! <= 0) return null;

    if (_cached != null && !forceRefresh) {
      return _cached;
    }

    final manager = OdooRecordRegistry.get<T>();
    if (manager == null) {
      throw StateError(
        'No manager registered for ${T.toString()}. '
        'Cannot load related record.',
      );
    }

    _cached = await manager.readLocal(id!);
    return _cached;
  }

  /// Clear the cached record.
  void clearCache() {
    _cached = null;
  }

  /// Convert to Odoo write format.
  ///
  /// Returns just the ID for create/write operations.
  dynamic toOdoo() => id;

  /// Convert to JSON for serialization.
  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
      };

  /// Create from JSON.
  factory RelatedRecord.fromJson(Map<String, dynamic> json) {
    return RelatedRecord(
      id: json['id'] as int?,
      displayName: json['displayName'] as String?,
    );
  }

  @override
  String toString() => displayName ?? (id != null ? 'ID: $id' : 'Empty');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelatedRecord<T> && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Extension to easily create RelatedRecord from Odoo data.
extension RelatedRecordParsing on Map<String, dynamic> {
  /// Extract a Many2One field as RelatedRecord.
  ///
  /// ```dart
  /// final partner = data.getRelated<Partner>('partner_id');
  /// ```
  RelatedRecord<T> getRelated<T extends OdooRecord<T>>(String field) {
    return RelatedRecord<T>.fromOdoo(this[field]);
  }

  /// Extract Many2One ID only.
  int? getRelatedId(String field) {
    final value = this[field];
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is List && value.isNotEmpty) return value[0] as int;
    return null;
  }

  /// Extract Many2One display name only.
  String? getRelatedName(String field) {
    final value = this[field];
    if (value == null || value == false) return null;
    if (value is List && value.length > 1) return value[1]?.toString();
    return null;
  }
}

/// Collection of related records for One2Many/Many2Many fields.
///
/// Provides lazy loading of related records in batches.
class RelatedRecordList<T extends OdooRecord<T>> {
  /// IDs of related records.
  final List<int> ids;

  /// Cached loaded records.
  final List<T> _cached = [];

  /// Whether all records have been loaded.
  bool _allLoaded = false;

  RelatedRecordList(this.ids);

  /// Create from Odoo's One2Many/Many2Many format: list of IDs.
  factory RelatedRecordList.fromOdoo(dynamic value) {
    if (value == null || value == false) {
      return RelatedRecordList([]);
    }
    if (value is List) {
      return RelatedRecordList(value.whereType<int>().toList());
    }
    return RelatedRecordList([]);
  }

  /// Check if there are any related records.
  bool get isEmpty => ids.isEmpty;
  bool get isNotEmpty => ids.isNotEmpty;

  /// Number of related records.
  int get length => ids.length;

  /// Whether all records have been loaded.
  bool get isLoaded => _allLoaded;

  /// Get cached records (may be incomplete).
  List<T> get cached => List.unmodifiable(_cached);

  /// Load all related records.
  Future<List<T>> loadAll({bool forceRefresh = false}) async {
    if (_allLoaded && !forceRefresh) {
      return List.unmodifiable(_cached);
    }

    final manager = OdooRecordRegistry.get<T>();
    if (manager == null) {
      throw StateError('No manager registered for ${T.toString()}');
    }

    _cached.clear();
    for (final id in ids) {
      final record = await manager.readLocal(id);
      if (record != null) {
        _cached.add(record);
      }
    }

    _allLoaded = true;
    return List.unmodifiable(_cached);
  }

  /// Load a single record by ID.
  Future<T?> loadOne(int id) async {
    if (!ids.contains(id)) return null;

    // Check cache first
    try {
      return _cached.firstWhere((r) => r.id == id || r.odooId == id);
    } catch (_) {
      // Not in cache, load it
      final manager = OdooRecordRegistry.get<T>();
      if (manager == null) return null;

      final record = await manager.readLocal(id);
      if (record != null) {
        _cached.add(record);
      }
      return record;
    }
  }

  /// Clear cached records.
  void clearCache() {
    _cached.clear();
    _allLoaded = false;
  }

  /// Convert to Odoo write format.
  ///
  /// Returns list of IDs or special command format for modifications.
  dynamic toOdoo() => ids;

  /// Create Odoo command to set (replace all) related records.
  static List<dynamic> setCommand(List<int> ids) => [
        [6, 0, ids]
      ];

  /// Create Odoo command to add a record.
  static List<dynamic> addCommand(int id) => [
        [4, id, 0]
      ];

  /// Create Odoo command to remove a record (unlink relation, not delete).
  static List<dynamic> removeCommand(int id) => [
        [3, id, 0]
      ];

  /// Create Odoo command to delete a record.
  static List<dynamic> deleteCommand(int id) => [
        [2, id, 0]
      ];

  /// Create Odoo command to create a new related record.
  static List<dynamic> createCommand(Map<String, dynamic> values) => [
        [0, 0, values]
      ];

  /// Create Odoo command to update a related record.
  static List<dynamic> updateCommand(int id, Map<String, dynamic> values) => [
        [1, id, values]
      ];

  @override
  String toString() => 'RelatedRecordList(${ids.length} items)';
}
