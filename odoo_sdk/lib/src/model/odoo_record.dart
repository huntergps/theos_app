/// OdooRecord<T> - Smart Model Base Class
///
/// Base class that encapsulates all model behavior:
/// - Identity (id, odooId, uuid)
/// - Sync status tracking
/// - CRUD operations delegated to manager
/// - Action calls to Odoo
/// - Validation
///
/// ## Usage
///
/// ```dart
/// @OdooModel('sale.order')
/// @freezed
/// class SaleOrder extends OdooRecord<SaleOrder> with _$SaleOrder {
///   const SaleOrder._();
///
///   const factory SaleOrder({
///     @OdooId() required int id,
///     @OdooString() required String name,
///     // ...
///   }) = _SaleOrder;
///
///   // Computed fields
///   bool get canConfirm => state.isDraft && lines.isNotEmpty;
///
///   // Actions
///   Future<SaleOrder> confirm() async {
///     if (!canConfirm) throw StateError('Cannot confirm');
///     await callAction('action_confirm');
///     return (await refresh())!;
///   }
/// }
/// ```
library;

import 'dart:async';

import 'odoo_model_manager.dart';

/// Global registry of managers by Dart model type.
///
/// Maps Dart types (e.g. `Product`, `SaleOrder`) to their
/// [OdooModelManager] instances. This allows [OdooRecord] and
/// [SmartOdooModel] mixins to locate their manager without explicit
/// dependency injection.
///
/// ## Role in the Registry Architecture
///
/// - **[OdooRecordRegistry]** (this) - lookup by `Type` (for model mixins)
/// - **[ModelRegistry]** - lookup by Odoo model name (for sync/WebSocket)
/// - **[DataContext]** - high-level container combining all registries
///
/// ## Typical Registration
///
/// ```dart
/// // At app startup, register each manager:
/// OdooRecordRegistry.register<Product>(productManager);
/// ModelRegistry.register(productManager);
///
/// // Then a model mixin can find its manager:
/// final mgr = OdooRecordRegistry.get<Product>();
/// ```
class OdooRecordRegistry {
  static final Map<Type, OdooModelManager> _managers = {};

  /// Register a manager for a model type.
  static void register<T>(OdooModelManager<T> manager) {
    _managers[T] = manager;
  }

  /// Get the manager for a model type.
  static OdooModelManager<T>? get<T>() {
    return _managers[T] as OdooModelManager<T>?;
  }

  /// Register a manager by runtime [Type] (for context-based registration).
  static void registerByType(Type type, OdooModelManager manager) {
    _managers[type] = manager;
  }

  /// Check if a manager is registered for a type.
  static bool has<T>() => _managers.containsKey(T);

  /// Clear all registered managers.
  static void clear() => _managers.clear();
}

/// Base class for all Odoo models.
///
/// Provides:
/// - Identity management (id, odooId, uuid)
/// - Sync status tracking
/// - CRUD operations via manager
/// - Odoo action calls
/// - Validation framework
///
/// Subclasses should use Freezed for immutability and code generation.
abstract mixin class OdooRecord<T extends OdooRecord<T>> {
  // ═══════════════════════════════════════════════════════════════════════════
  // Identity - Override in subclass
  // ═══════════════════════════════════════════════════════════════════════════

  /// Local database ID (auto-increment).
  int get id;

  /// Odoo server ID. May be 0 or negative for unsynced records.
  int get odooId => id; // Default: same as id. Override if separate.

  /// UUID for tracking offline-created records.
  String? get uuid => null;

  /// Sync status. True if record matches server.
  bool get isSynced => true;

  // ═══════════════════════════════════════════════════════════════════════════
  // Identity Computed Properties
  // ═══════════════════════════════════════════════════════════════════════════

  /// True if record is new (not saved to local DB).
  bool get isNew => id <= 0;

  /// True if record exists only locally (not synced to Odoo).
  bool get isLocalOnly => odooId <= 0;

  /// True if record was created offline.
  bool get isOfflineCreated => uuid != null && odooId <= 0;

  /// True if record has pending changes to sync.
  bool get hasPendingSync => !isSynced;

  // ═══════════════════════════════════════════════════════════════════════════
  // Conversion - Override in subclass
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convert to Odoo API format for create/write operations.
  ///
  /// Should only include writable fields.
  Map<String, dynamic> toOdoo();

  /// Create from Odoo API response.
  ///
  /// Factory constructor in subclass:
  /// ```dart
  /// factory SaleOrder.fromOdoo(Map<String, dynamic> data) { ... }
  /// ```
  // static T fromOdoo(Map<String, dynamic> data); // Implemented by subclass

  /// Create from Drift database row.
  ///
  /// Factory constructor in subclass:
  /// ```dart
  /// factory SaleOrder.fromDatabase(SaleOrderData data) { ... }
  /// ```
  // static T fromDatabase(dynamic row); // Implemented by subclass

  // ═══════════════════════════════════════════════════════════════════════════
  // Manager Access
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the manager for this model type.
  ///
  /// Throws if manager not registered.
  OdooModelManager<T> get _manager {
    final manager = OdooRecordRegistry.get<T>();
    if (manager == null) {
      throw StateError(
        'No manager registered for ${T.toString()}. '
        'Call OdooRecordRegistry.register<$T>(manager) first.',
      );
    }
    return manager;
  }

  /// Check if manager is available.
  bool get hasManager => OdooRecordRegistry.has<T>();

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save this record (create or update).
  ///
  /// Returns the saved record with updated ID (if new) and sync status.
  ///
  /// ```dart
  /// final savedOrder = await order.save();
  /// print(savedOrder.id); // Now has real ID
  /// ```
  Future<T> save() async {
    // Validate first
    final errors = validate();
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }

    if (isNew || isLocalOnly) {
      // Create
      final newId = await _manager.create(this as T);
      return (await _manager.readLocal(newId))!;
    } else {
      // Update
      await _manager.update(this as T);
      return (await _manager.readLocal(odooId))!;
    }
  }

  /// Delete this record.
  ///
  /// Deletes locally and queues server deletion if offline.
  Future<void> delete() async {
    if (!isNew && !isLocalOnly) {
      await _manager.delete(odooId);
    } else if (id > 0) {
      await _manager.deleteLocal(id);
    }
  }

  /// Refresh this record from local database.
  ///
  /// Returns updated record or null if deleted.
  Future<T?> refresh() async {
    if (isNew) return this as T;
    return _manager.readLocal(odooId > 0 ? odooId : id);
  }

  /// Sync this record with Odoo server.
  ///
  /// Fetches latest data from server and updates local copy.
  /// Returns updated record or null if not found on server.
  Future<T?> syncFromServer() async {
    if (!_manager.isOnline || isLocalOnly) return this as T;

    final data = await _manager.client.read(
      model: _manager.odooModel,
      ids: [odooId],
      fields: _manager.odooFields,
    );

    if (data.isEmpty) return null;

    final record = _manager.fromOdoo(data.first);
    final synced = _manager.withSyncStatus(record, true);
    await _manager.upsertLocal(synced);
    return synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Odoo Actions
  // ═══════════════════════════════════════════════════════════════════════════

  /// Call an Odoo action method on this record.
  ///
  /// ```dart
  /// await order.callAction('action_confirm');
  /// await order.callAction('action_cancel');
  /// ```
  Future<dynamic> callAction(String actionName, {Map<String, dynamic>? kwargs}) async {
    if (isLocalOnly) {
      throw StateError('Cannot call Odoo action on local-only record');
    }

    if (!_manager.isOnline) {
      throw StateError('Cannot call Odoo action while offline');
    }

    return _manager.callOdooAction(odooId, actionName, kwargs: kwargs);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Validation
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validate this record before saving.
  ///
  /// Returns map of field -> error message.
  /// Empty map means valid.
  ///
  /// Override in subclass:
  /// ```dart
  /// @override
  /// Map<String, String> validate() {
  ///   final errors = <String, String>{};
  ///   if (partnerId == null) errors['partner'] = 'Customer required';
  ///   if (lines.isEmpty) errors['lines'] = 'Add at least one line';
  ///   return errors;
  /// }
  /// ```
  Map<String, String> validate() => {};

  /// Check if record is valid.
  bool get isValid => validate().isEmpty;

  /// Validate this record for a specific action.
  ///
  /// Override in subclass to add action-specific validation:
  /// ```dart
  /// @override
  /// Map<String, String> validateFor(String action) {
  ///   final errors = validate();
  ///   if (action == 'confirm' && lines.isEmpty) {
  ///     errors['lines'] = 'Add at least one line to confirm';
  ///   }
  ///   return errors;
  /// }
  /// ```
  Map<String, String> validateFor(String action) => validate();

  /// Check if record is valid for a specific action.
  bool isValidFor(String action) => validateFor(action).isEmpty;

  /// Ensure record is valid, throwing [ValidationException] if not.
  ///
  /// If [forAction] is provided, uses action-specific validation.
  void ensureValid({String? forAction}) {
    final errors =
        forAction != null ? validateFor(forAction) : validate();
    if (errors.isNotEmpty) {
      throw ValidationException(errors, action: forAction);
    }
  }

  /// Call an Odoo action and refresh the record.
  ///
  /// Returns the refreshed record after the action completes.
  /// Throws [StateError] if the record is not found after the action.
  ///
  /// ```dart
  /// final confirmed = await order.callActionAndRefresh('action_confirm');
  /// ```
  Future<T> callActionAndRefresh(
    String actionName, {
    Map<String, dynamic>? kwargs,
  }) async {
    await callAction(actionName, kwargs: kwargs);
    final refreshed = await refresh();
    if (refreshed == null) {
      throw StateError('Record not found after action "$actionName"');
    }
    return refreshed;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Copy With (Freezed generates this)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a copy with modified fields.
  ///
  /// Implemented by Freezed:
  /// ```dart
  /// final updated = order.copyWith(name: 'New Name');
  /// ```
  // T copyWith({...}); // Generated by Freezed

  // ═══════════════════════════════════════════════════════════════════════════
  // Equality (Freezed generates this)
  // ═══════════════════════════════════════════════════════════════════════════

  // bool operator ==(Object other); // Generated by Freezed
  // int get hashCode; // Generated by Freezed
}

/// Exception thrown when validation fails.
class ValidationException implements Exception {
  /// Map of field name -> error message.
  final Map<String, String> errors;

  /// Optional action context (e.g., 'confirm', 'save').
  final String? action;

  const ValidationException(this.errors, {this.action});

  /// Create a single-field validation error.
  factory ValidationException.single(
    String field,
    String message, {
    String? action,
  }) {
    return ValidationException({field: message}, action: action);
  }

  @override
  String toString() {
    final errorList = errors.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    final actionSuffix = action != null ? ' for action "$action"' : '';
    return 'ValidationException$actionSuffix: $errorList';
  }

  /// Get error for a specific field.
  String? operator [](String field) => errors[field];

  /// Check if there's an error for a field.
  bool hasError(String field) => errors.containsKey(field);

  /// Number of validation errors.
  int get count => errors.length;

  /// All error messages joined.
  String get message => errors.values.join(', ');

  /// All field names with errors.
  Iterable<String> get fields => errors.keys;

  /// First error message, or null if empty.
  String? get firstError => errors.values.isEmpty ? null : errors.values.first;

  /// First field name with an error, or null if empty.
  String? get firstField => errors.keys.isEmpty ? null : errors.keys.first;
}

/// Extension methods for lists of OdooRecords.
extension OdooRecordListExtension<T extends OdooRecord<T>> on List<T> {
  /// Get only synced records.
  List<T> get synced => where((r) => r.isSynced).toList();

  /// Get only unsynced records.
  List<T> get unsynced => where((r) => !r.isSynced).toList();

  /// Get only local-only records.
  List<T> get localOnly => where((r) => r.isLocalOnly).toList();

  /// Find by ID.
  T? findById(int id) {
    try {
      return firstWhere((r) => r.id == id || r.odooId == id);
    } catch (_) {
      return null;
    }
  }

  /// Find by UUID.
  T? findByUuid(String uuid) {
    try {
      return firstWhere((r) => r.uuid == uuid);
    } catch (_) {
      return null;
    }
  }
}
