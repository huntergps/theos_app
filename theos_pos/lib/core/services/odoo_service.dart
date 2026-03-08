import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Allow insecure HTTP connections in debug mode or for local addresses.
bool _shouldAllowInsecure(String url) {
  if (kDebugMode) return true;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}

final odooServiceProvider = Provider((ref) => OdooService());

/// Servicio principal para comunicación con Odoo
///
/// Envuelve [OdooClient] del paquete odoo_offline_core para:
/// - Mantener una API compatible con el resto de la app
/// - Agregar métodos específicos de la app (writeUser, getLanguages, etc.)
/// - Proporcionar el estado de conexión via [isLoggedIn]
///
/// Uso:
/// ```dart
/// final odoo = ref.watch(odooServiceProvider);
/// odoo.setCredentials(url, apiKey, database);
/// final result = await odoo.call(model: 'res.partner', method: 'search_read', kwargs: {...});
/// ```
class OdooService {
  OdooClient? _client;

  /// Whether the service has valid credentials configured
  bool get isLoggedIn => _client?.isConfigured ?? false;

  /// Get the underlying OdooClient (for advanced use cases)
  OdooClient? get client => _client;

  /// Current base URL
  String? get baseUrl => _client?.config.baseUrl;

  /// Current API key
  String? get apiKey => _client?.apiKey;

  /// Current database
  String? get database => _client?.config.database;

  /// Configure credentials for Odoo connection
  void setCredentials(String baseUrl, String apiKey, String database) {
    final normalizedUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    _client = OdooClient(
      config: OdooClientConfig(
        baseUrl: normalizedUrl,
        apiKey: apiKey,
        database: database,
        allowInsecure: _shouldAllowInsecure(normalizedUrl),
        isWeb: kIsWeb,
      ),
    );

    logger.d('[OdooService]', 'Credentials set for $normalizedUrl (db: $database)');
  }

  /// Test connection to Odoo server
  Future<bool> testConnection() async {
    if (_client == null) {
      logger.e('[OdooService]', 'testConnection: client not configured');
      return false;
    }

    logger.d('[OdooService]', 'Testing connection to ${_client!.config.baseUrl}');

    try {
      final response = await _client!.searchRead(
        model: 'res.users',
        fields: ['name', 'login'],
        limit: 1,
      );

      logger.i('[OdooService]', 'Connection successful');
      return response.isNotEmpty;
    } catch (e, st) {
      logger.e('[OdooService]', 'Connection failed', e, st);
      rethrow;
    }
  }

  /// Generic Odoo method call
  ///
  /// This is the main method for calling Odoo API endpoints.
  /// Delegates to [OdooClient.call] from odoo_offline_core.
  Future<dynamic> call({
    required String model,
    required String method,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  }) async {
    if (_client == null) {
      logger.e('[OdooService]', 'call: client not configured');
      throw Exception('OdooService not configured. Call setCredentials first.');
    }

    logger.d('[OdooService]', 'POST /$model/$method');

    // Merge context into kwargs if provided
    final effectiveKwargs = kwargs != null ? Map<String, dynamic>.from(kwargs) : <String, dynamic>{};
    if (context != null) {
      effectiveKwargs['context'] = context;
    }

    try {
      final result = await _client!.call(
        model: model,
        method: method,
        args: args,
        kwargs: effectiveKwargs.isNotEmpty ? effectiveKwargs : null,
      );

      logger.d('[OdooService]', 'Response type: ${result.runtimeType}');
      return result;
    } catch (e, st) {
      logger.e('[OdooService]', 'Call failed: $model/$method', e, st);
      rethrow;
    }
  }

  // ============================================================
  // App-specific convenience methods
  // ============================================================

  /// Write values to a user record
  Future<bool> writeUser(int userId, Map<String, dynamic> values) async {
    if (!isLoggedIn) return false;

    try {
      final result = await call(
        model: 'res.users',
        method: 'write',
        kwargs: {
          'ids': [userId],
          'vals': values,
        },
      );
      return result == true;
    } catch (e, st) {
      logger.e('[OdooService]', 'Failed to write user', e, st);
      return false;
    }
  }

  /// Get available languages
  Future<List<Map<String, dynamic>>> getLanguages() async {
    if (!isLoggedIn) return [];

    try {
      final response = await call(
        model: 'res.lang',
        method: 'search_read',
        kwargs: {
          'domain': [],
          'fields': ['code', 'name'],
        },
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e, st) {
      logger.e('[OdooService]', 'Failed to get languages', e, st);
    }
    return [];
  }

  /// Get model field definitions
  Future<Map<String, dynamic>> getModelFields(
    String model,
    List<String> fields,
  ) async {
    if (!isLoggedIn) return {};

    try {
      final response = await call(
        model: model,
        method: 'fields_get',
        kwargs: {
          'allfields': fields,
          'attributes': ['selection', 'string'],
        },
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e, st) {
      logger.e('[OdooService]', 'Failed to get model fields for $model', e, st);
    }
    return {};
  }

  /// Get available work schedules
  Future<List<Map<String, dynamic>>> getWorkSchedules() async {
    if (!isLoggedIn) return [];

    try {
      final response = await call(
        model: 'resource.calendar',
        method: 'search_read',
        kwargs: {
          'domain': [],
          'fields': ['id', 'name'],
        },
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e, st) {
      logger.e('[OdooService]', 'Failed to get work schedules', e, st);
    }
    return [];
  }

  /// Get available warehouses
  Future<List<Map<String, dynamic>>> getWarehouses() async {
    if (!isLoggedIn) return [];

    try {
      final response = await call(
        model: 'stock.warehouse',
        method: 'search_read',
        kwargs: {
          'domain': [],
          'fields': ['id', 'name'],
        },
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e, st) {
      logger.e('[OdooService]', 'Failed to get warehouses', e, st);
    }
    return [];
  }

  /// Get available countries
  Future<List<Map<String, dynamic>>> getCountries() async {
    if (!isLoggedIn) return [];

    try {
      final response = await call(
        model: 'res.country',
        method: 'search_read',
        kwargs: {
          'domain': [],
          'fields': ['id', 'name'],
        },
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e, st) {
      logger.e('[OdooService]', 'Failed to get countries', e, st);
    }
    return [];
  }

  /// Get states for a country
  Future<List<Map<String, dynamic>>> getStates(int? countryId) async {
    if (!isLoggedIn) return [];

    try {
      final domain = countryId != null
          ? [['country_id', '=', countryId]]
          : [];

      final response = await call(
        model: 'res.country.state',
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': ['id', 'name', 'country_id'],
        },
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e, st) {
      logger.e('[OdooService]', 'Failed to get states', e, st);
    }
    return [];
  }
}
