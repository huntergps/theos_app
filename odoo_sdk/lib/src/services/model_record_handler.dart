/// Model Record Handler (Generic)
///
/// Provides a registry for model-specific handlers that can fetch and upsert
/// records without hard-coding model logic in core services.
library;

import '../api/odoo_client.dart';

/// Interface for model-specific record handling.
///
/// [DB] allows host apps to pass their own database type.
abstract class ModelRecordHandler<DB> {
  /// The Odoo model name (e.g., 'product.product', 'res.partner').
  String get odooModel;

  /// Default fields to fetch from Odoo.
  List<String> get defaultFields;

  /// Check if a record exists in local database.
  Future<bool> exists(DB db, int odooId);

  /// Insert or update a record in local database.
  Future<void> upsert(DB db, Map<String, dynamic> data);

  /// Fetch records from Odoo by IDs.
  ///
  /// Default implementation uses searchRead with the handler's fields.
  /// Override for custom fetch logic.
  Future<List<Map<String, dynamic>>> fetch(
    OdooClient client,
    List<int> ids,
  ) async {
    return client.searchRead(
      model: odooModel,
      domain: [
        ['id', 'in', ids],
      ],
      fields: defaultFields,
    );
  }
}

/// Registry for model record handlers.
class ModelRecordHandlerRegistry<DB> {
  final Map<String, ModelRecordHandler<DB>> _handlers = {};

  /// Register a handler for a model.
  void register(ModelRecordHandler<DB> handler) {
    _handlers[handler.odooModel] = handler;
  }

  /// Get handler for a model (returns null if not registered).
  ModelRecordHandler<DB>? getHandler(String model) => _handlers[model];

  /// Check if a handler is registered for a model.
  bool hasHandler(String model) => _handlers.containsKey(model);

  /// Get all registered model names.
  Iterable<String> get registeredModels => _handlers.keys;

  /// Get all registered handlers.
  Iterable<ModelRecordHandler<DB>> get handlers => _handlers.values;
}
