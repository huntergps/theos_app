/// Registry for WebSocket model mappings, channels, and notification types.
///
/// Eliminates hardcoded Odoo model names from WebSocket infrastructure.
/// Register only the models your app uses via [registerNotification],
/// [registerChannel], [registerFieldMapping], and [registerNotificationPrefix].
///
/// Example:
/// ```dart
/// final registry = WebSocketModelRegistry.instance;
/// registry.registerNotification(
///   'sale_order_updated',
///   WebSocketNotificationMapping(
///     model: 'sale.order',
///     idField: 'order_id',
///     nameField: 'order_name',
///   ),
/// );
/// registry.registerChannel('sale.order');
/// registry.registerFieldMapping('sale.order', const WebSocketFieldMapping(
///   idField: 'order_id', nameField: 'order_name',
/// ));
/// ```
library;

/// Mapping for a WebSocket notification type to its model and field names.
class WebSocketNotificationMapping {
  /// Odoo model name (e.g., 'sale.order')
  final String model;

  /// Payload field containing the record ID (e.g., 'order_id')
  final String idField;

  /// Payload field containing the record display name (e.g., 'order_name')
  final String nameField;

  /// Whether this is a catalog/price-type event (uses OdooCatalogEvent)
  final bool isCatalogEvent;

  /// Whether this is an order-line-type event (uses OdooOrderLineEvent)
  final bool isOrderLineEvent;

  /// Catalog type identifier (e.g., 'product_price') — only used when [isCatalogEvent] is true
  final String? catalogType;

  const WebSocketNotificationMapping({
    required this.model,
    required this.idField,
    required this.nameField,
    this.isCatalogEvent = false,
    this.isOrderLineEvent = false,
    this.catalogType,
  });
}

/// Field mapping for extracting ID and name from payloads for a given model.
class WebSocketFieldMapping {
  /// Payload field containing the record ID
  final String idField;

  /// Payload field containing the record display name
  final String nameField;

  const WebSocketFieldMapping({
    required this.idField,
    required this.nameField,
  });
}

/// Singleton registry for WebSocket model configuration.
///
/// Stores notification type mappings, channel templates, and field mappings
/// that were previously hardcoded across multiple files.
class WebSocketModelRegistry {
  static final instance = WebSocketModelRegistry._();
  WebSocketModelRegistry._();

  /// WebSocket protocol version. Defaults to '19.0-2'.
  String wsVersion = '19.0-2';

  /// Notification type → mapping (e.g., 'sale_order_updated' → model info)
  final Map<String, WebSocketNotificationMapping> _notificationMappings = {};

  /// Channel templates without database prefix (e.g., 'sale.order', 'partner_updated')
  final List<String> _channelTemplates = [];

  /// Model → field mapping for extractRecordId/extractRecordName
  final Map<String, WebSocketFieldMapping> _fieldMappings = {};

  /// Notification prefix → Odoo model name (e.g., 'sale_order' → 'sale.order')
  /// Used by DataLayerBridge for generic notification parsing.
  final Map<String, String> _notificationPrefixToModel = {};

  // ---------------------------------------------------------------------------
  // Registration API
  // ---------------------------------------------------------------------------

  /// Register a notification type mapping.
  void registerNotification(String type, WebSocketNotificationMapping mapping) {
    _notificationMappings[type] = mapping;
  }

  /// Register a channel template (without database prefix).
  void registerChannel(String templateWithoutDatabase) {
    if (!_channelTemplates.contains(templateWithoutDatabase)) {
      _channelTemplates.add(templateWithoutDatabase);
    }
  }

  /// Register field mapping for a model (used by extractRecordId/extractRecordName).
  void registerFieldMapping(String model, WebSocketFieldMapping mapping) {
    _fieldMappings[model] = mapping;
  }

  /// Register a notification prefix → model mapping.
  void registerNotificationPrefix(String prefix, String odooModel) {
    _notificationPrefixToModel[prefix] = odooModel;
  }

  // ---------------------------------------------------------------------------
  // Query API
  // ---------------------------------------------------------------------------

  /// Build channels list for a given database and optional partnerId.
  List<String> buildChannels(String database, int? partnerId) {
    final channels = _channelTemplates
        .map((t) => '$database.$t')
        .toList();

    if (partnerId != null) {
      channels.add('$database.odoo-presence-res.partner_$partnerId');
      channels.add('$database.odoo-activity-res.partner_$partnerId');
    }

    return channels;
  }

  /// Get the notification mapping for a given type, or null if not registered.
  WebSocketNotificationMapping? getMapping(String notificationType) {
    return _notificationMappings[notificationType];
  }

  /// Get the ID field for a model, or 'id' as default.
  String getIdField(String model) {
    return _fieldMappings[model]?.idField ?? 'id';
  }

  /// Get the name field for a model, or 'name' as default.
  String getNameField(String model) {
    return _fieldMappings[model]?.nameField ?? 'name';
  }

  /// Get the ID field for a catalog type, or 'id' as default.
  String getCatalogIdField(String catalogType) {
    for (final mapping in _notificationMappings.values) {
      if (mapping.isCatalogEvent && mapping.catalogType == catalogType) {
        return mapping.idField;
      }
    }
    return 'id';
  }

  /// Get notification prefix → model map.
  Map<String, String> get notificationPrefixToModel =>
      Map.unmodifiable(_notificationPrefixToModel);

  /// Whether any defaults have been registered.
  bool get hasRegistrations =>
      _notificationMappings.isNotEmpty ||
      _channelTemplates.isNotEmpty ||
      _fieldMappings.isNotEmpty;

  /// Clear all registrations (useful for testing).
  void clear() {
    _notificationMappings.clear();
    _channelTemplates.clear();
    _fieldMappings.clear();
    _notificationPrefixToModel.clear();
    wsVersion = '19.0-2';
  }

}
