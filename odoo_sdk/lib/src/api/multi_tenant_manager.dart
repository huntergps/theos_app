/// Multi-Tenant Manager
///
/// Manages multiple Odoo database connections (tenants) with easy switching.
/// Useful for applications that need to connect to multiple Odoo instances
/// or databases.
library;

import 'dart:async';

import 'client/odoo_http_client.dart';
import 'odoo_client.dart';

/// Event emitted when tenant changes.
class TenantChangedEvent {
  /// Previous tenant ID (null if this is the first tenant).
  final String? previousTenantId;

  /// New active tenant ID.
  final String newTenantId;

  /// Configuration of the new tenant.
  final OdooClientConfig newConfig;

  /// Timestamp when the change occurred.
  final DateTime timestamp;

  const TenantChangedEvent({
    this.previousTenantId,
    required this.newTenantId,
    required this.newConfig,
    required this.timestamp,
  });

  @override
  String toString() =>
      'TenantChangedEvent(${previousTenantId ?? 'none'} -> $newTenantId)';
}

/// Information about a registered tenant.
class TenantInfo {
  /// Unique identifier for this tenant.
  final String id;

  /// Human-readable name for this tenant.
  final String? name;

  /// Configuration for connecting to this tenant's Odoo instance.
  final OdooClientConfig config;

  /// When this tenant was registered.
  final DateTime registeredAt;

  /// When this tenant was last accessed.
  DateTime lastAccessedAt;

  /// Custom metadata for this tenant.
  final Map<String, dynamic> metadata;

  TenantInfo({
    required this.id,
    this.name,
    required this.config,
    DateTime? registeredAt,
    DateTime? lastAccessedAt,
    this.metadata = const {},
  })  : registeredAt = registeredAt ?? DateTime.now(),
        lastAccessedAt = lastAccessedAt ?? DateTime.now();

  /// The database name for this tenant.
  String? get database => config.database;

  /// The base URL for this tenant.
  String get baseUrl => config.baseUrl;

  @override
  String toString() => 'TenantInfo($id: ${name ?? database ?? baseUrl})';
}

/// Manages multiple Odoo database connections (tenants).
///
/// ## Usage
///
/// ```dart
/// final manager = MultiTenantManager();
///
/// // Register tenants
/// manager.registerTenant(
///   'company_a',
///   OdooClientConfig(
///     baseUrl: 'https://company-a.odoo.com',
///     apiKey: 'key-a',
///     database: 'company_a_db',
///   ),
///   name: 'Company A',
/// );
///
/// manager.registerTenant(
///   'company_b',
///   OdooClientConfig(
///     baseUrl: 'https://company-b.odoo.com',
///     apiKey: 'key-b',
///     database: 'company_b_db',
///   ),
///   name: 'Company B',
/// );
///
/// // Switch between tenants
/// manager.switchTenant('company_a');
///
/// // Get active tenant config
/// final config = manager.activeTenantConfig;
///
/// // Listen to tenant changes
/// manager.tenantChanges.listen((event) {
///   print('Switched from ${event.previousTenantId} to ${event.newTenantId}');
/// });
/// ```
///
/// ## Integration with OdooClient
///
/// ```dart
/// final manager = MultiTenantManager();
/// // ... register tenants ...
///
/// final client = OdooClient(
///   config: manager.activeTenantConfig!,
///   multiTenantManager: manager,
/// );
///
/// // When switching tenants, update the client
/// manager.tenantChanges.listen((event) {
///   client.updateConfig(event.newConfig);
/// });
/// ```
class MultiTenantManager {
  /// Registered tenants by ID.
  final Map<String, TenantInfo> _tenants = {};

  /// Currently active tenant ID.
  String? _activeTenantId;

  /// Stream controller for tenant change events.
  final StreamController<TenantChangedEvent> _tenantChangedController =
      StreamController<TenantChangedEvent>.broadcast();

  /// Callback when tenant is about to change.
  ///
  /// Return false to cancel the switch.
  Future<bool> Function(String? oldTenantId, String newTenantId)?
      onBeforeTenantSwitch;

  /// Callback after tenant has changed.
  void Function(TenantChangedEvent event)? onAfterTenantSwitch;

  /// Stream of tenant change events.
  Stream<TenantChangedEvent> get tenantChanges =>
      _tenantChangedController.stream;

  /// ID of the currently active tenant.
  String? get activeTenantId => _activeTenantId;

  /// Information about the currently active tenant.
  TenantInfo? get activeTenant =>
      _activeTenantId != null ? _tenants[_activeTenantId] : null;

  /// Configuration of the currently active tenant.
  OdooClientConfig? get activeTenantConfig => activeTenant?.config;

  /// List of all registered tenant IDs.
  List<String> get registeredTenants => _tenants.keys.toList();

  /// Number of registered tenants.
  int get tenantCount => _tenants.length;

  /// Whether any tenants are registered.
  bool get hasTenants => _tenants.isNotEmpty;

  /// Whether there is an active tenant.
  bool get hasActiveTenant => _activeTenantId != null;

  /// Registers a new tenant.
  ///
  /// [id] Unique identifier for this tenant.
  /// [config] Configuration for connecting to this tenant's Odoo.
  /// [name] Optional human-readable name.
  /// [metadata] Optional custom metadata.
  /// [setActive] If true and no tenant is active, makes this the active tenant.
  ///
  /// Throws [StateError] if a tenant with this ID is already registered.
  void registerTenant(
    String id,
    OdooClientConfig config, {
    String? name,
    Map<String, dynamic> metadata = const {},
    bool setActive = true,
  }) {
    if (_tenants.containsKey(id)) {
      throw StateError('Tenant "$id" is already registered');
    }

    _tenants[id] = TenantInfo(
      id: id,
      name: name,
      config: config,
      metadata: metadata,
    );

    // Set as active if requested and no active tenant
    if (setActive && _activeTenantId == null) {
      _activeTenantId = id;
    }
  }

  /// Updates an existing tenant's configuration.
  ///
  /// [id] ID of the tenant to update.
  /// [config] New configuration (or null to keep existing).
  /// [name] New name (or null to keep existing).
  /// [metadata] New metadata (merged with existing).
  ///
  /// Throws [StateError] if tenant is not registered.
  void updateTenant(
    String id, {
    OdooClientConfig? config,
    String? name,
    Map<String, dynamic>? metadata,
  }) {
    final existing = _tenants[id];
    if (existing == null) {
      throw StateError('Tenant "$id" is not registered');
    }

    _tenants[id] = TenantInfo(
      id: id,
      name: name ?? existing.name,
      config: config ?? existing.config,
      registeredAt: existing.registeredAt,
      lastAccessedAt: existing.lastAccessedAt,
      metadata: {...existing.metadata, ...?metadata},
    );

    // If this is the active tenant, emit change event
    if (_activeTenantId == id && config != null) {
      final event = TenantChangedEvent(
        previousTenantId: id,
        newTenantId: id,
        newConfig: config,
        timestamp: DateTime.now(),
      );
      _tenantChangedController.add(event);
      onAfterTenantSwitch?.call(event);
    }
  }

  /// Removes a registered tenant.
  ///
  /// [id] ID of the tenant to remove.
  ///
  /// If this is the active tenant, the active tenant is cleared.
  /// Throws [StateError] if tenant is not registered.
  void removeTenant(String id) {
    if (!_tenants.containsKey(id)) {
      throw StateError('Tenant "$id" is not registered');
    }

    _tenants.remove(id);

    // Clear active tenant if this was it
    if (_activeTenantId == id) {
      _activeTenantId = null;
    }
  }

  /// Gets information about a specific tenant.
  ///
  /// Returns null if tenant is not registered.
  TenantInfo? getTenant(String id) => _tenants[id];

  /// Gets the configuration for a specific tenant.
  ///
  /// Returns null if tenant is not registered.
  OdooClientConfig? getTenantConfig(String id) => _tenants[id]?.config;

  /// Checks if a tenant is registered.
  bool hasTenant(String id) => _tenants.containsKey(id);

  /// Switches to a different tenant.
  ///
  /// [id] ID of the tenant to switch to.
  ///
  /// Emits a [TenantChangedEvent] on the [tenantChanges] stream.
  /// Throws [StateError] if tenant is not registered.
  ///
  /// Returns false if the switch was cancelled by [onBeforeTenantSwitch].
  Future<bool> switchTenant(String id) async {
    if (!_tenants.containsKey(id)) {
      throw StateError('Tenant "$id" is not registered');
    }

    // Already active
    if (_activeTenantId == id) {
      return true;
    }

    // Check if switch is allowed
    if (onBeforeTenantSwitch != null) {
      final allowed = await onBeforeTenantSwitch!(_activeTenantId, id);
      if (!allowed) {
        return false;
      }
    }

    final previousId = _activeTenantId;
    _activeTenantId = id;

    // Update last accessed time
    _tenants[id]!.lastAccessedAt = DateTime.now();

    // Emit event
    final event = TenantChangedEvent(
      previousTenantId: previousId,
      newTenantId: id,
      newConfig: _tenants[id]!.config,
      timestamp: DateTime.now(),
    );

    _tenantChangedController.add(event);
    onAfterTenantSwitch?.call(event);

    return true;
  }

  /// Clears the active tenant (no tenant selected).
  void clearActiveTenant() {
    _activeTenantId = null;
  }

  /// Gets all registered tenants as a list.
  List<TenantInfo> getAllTenants() => _tenants.values.toList();

  /// Gets all tenant IDs sorted by last access time (most recent first).
  List<String> getTenantsByLastAccess() {
    final sorted = _tenants.values.toList()
      ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
    return sorted.map((t) => t.id).toList();
  }

  /// Removes all registered tenants.
  void clearAllTenants() {
    _tenants.clear();
    _activeTenantId = null;
  }

  /// Disposes the manager and closes streams.
  void dispose() {
    _tenantChangedController.close();
  }
}

/// Extension to add multi-tenant support to OdooClient.
extension MultiTenantOdooClientExtension on OdooClient {
  /// Switches to a different database within the same Odoo instance.
  ///
  /// This updates the configuration to use a different database while
  /// keeping the same base URL and API key.
  void switchDatabase(String database) {
    final newConfig = config.copyWith(database: database);
    http.updateConfig(newConfig);
  }
}
