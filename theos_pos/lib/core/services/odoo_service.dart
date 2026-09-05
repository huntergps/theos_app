import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import '../database/repositories/repository_providers.dart';
import '../security/transport_security.dart';

/// Facade over the single client owned by [odooClientProvider].
///
/// The facade remains for feature-specific convenience methods, but it no
/// longer owns a second client instance. This is important for auth/session
/// state: every Odoo call must use the same JSON-2/Bearer client.
final odooServiceProvider = Provider<OdooService>((ref) {
  return OdooService(
    clientReader: () => ref.read(odooClientProvider),
    clientWriter: (client) => ref.read(odooClientProvider.notifier).set(client),
  );
});

/// Servicio principal para comunicación con Odoo
///
/// Envuelve [OdooClient] del paquete odoo_offline_core para:
/// - Mantener una API compatible con el resto de la app
/// - Agregar operaciones específicas todavía usadas por la app
/// - Proporcionar el estado de conexión via [isLoggedIn]
///
/// Uso:
/// ```dart
/// final odoo = ref.watch(odooServiceProvider);
/// odoo.setCredentials(url, apiKey, database);
/// final result = await odoo.call(model: 'res.partner', method: 'search_read', kwargs: {...});
/// ```
class OdooService {
  OdooService({OdooClient? client, this._clientReader, this._clientWriter})
    : _localClient = client;

  final OdooClient? _localClient;
  final OdooClient? Function()? _clientReader;
  final void Function(OdooClient?)? _clientWriter;

  OdooClient? get _client => _clientReader?.call() ?? _localClient;

  /// Whether the service has valid credentials configured
  bool get isLoggedIn => _client?.isConfigured ?? false;

  /// Get the underlying OdooClient (for advanced use cases)
  OdooClient? get client => _client;

  /// Configure credentials for Odoo connection
  void setCredentials(String baseUrl, String apiKey, String database) {
    final normalizedUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final client = OdooClient(
      config: OdooClientConfig(
        baseUrl: normalizedUrl,
        apiKey: apiKey,
        database: database,
        allowInsecure: allowsInsecureLoopbackTransport(normalizedUrl),
      ),
    );
    _clientWriter?.call(client);

    logger.d(
      '[OdooService]',
      'Credentials set for $normalizedUrl (db: $database)',
    );
  }

  /// Test connection to Odoo server
  Future<bool> testConnection() async {
    if (_client == null) {
      logger.e('[OdooService]', 'testConnection: client not configured');
      return false;
    }

    logger.d(
      '[OdooService]',
      'Testing connection to ${_client!.config.baseUrl}',
    );

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

  /// Validates the bearer credential and returns the identity attached to it.
  /// Login reuses this UID for database scoping and user loading, avoiding
  /// repeated `context_get` calls during startup.
  Future<int> resolveCurrentUserId() async {
    if (_client == null) {
      throw StateError('OdooService not configured');
    }
    final context = await _client!.call(
      model: 'res.users',
      method: 'context_get',
    );
    final uid = context is Map ? context['uid'] : null;
    if (uid is num && uid.toInt() > 0) return uid.toInt();
    throw StateError('Odoo did not return a valid current user UID');
  }

  /// Generic Odoo method call
  ///
  /// This is the main method for calling Odoo API endpoints.
  /// Delegates to [OdooClient.call] from odoo_offline_core.
  ///
  /// [ids] construye el recordset (`self`) del método en el dispatcher
  /// JSON-2 de Odoo (`/json/2/<model>/<method>`). Para métodos de recordset
  /// (ej. `action_confirm`, `action_session_validate`) usa [ids], NO [args].
  ///
  /// [args] está deprecado: el dispatcher estándar de Odoo NO trata "args"
  /// como argumentos posicionales — cae dentro de los kwargs del método y
  /// falla salvo que el propio método tenga un parámetro llamado "args". Usa
  /// [kwargs] con los nombres reales de los parámetros de Python.
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    // ignore: deprecated_member_use
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
    final effectiveKwargs = kwargs != null
        ? Map<String, dynamic>.from(kwargs)
        : <String, dynamic>{};
    if (context != null) {
      effectiveKwargs['context'] = context;
    }

    try {
      final result = await _client!.call(
        model: model,
        method: method,
        ids: ids,
        // ignore: deprecated_member_use
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
        ids: [userId],
        kwargs: {'vals': values},
      );
      return result == true;
    } catch (e, st) {
      logger.e('[OdooService]', 'Failed to write user', e, st);
      return false;
    }
  }
}
