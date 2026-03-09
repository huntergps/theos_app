import 'package:dio/dio.dart' show CancelToken;

import 'client/odoo_http_client.dart';
import 'client/odoo_crud_api.dart';
import 'odoo_version.dart';
import 'session/odoo_session_manager.dart';
import 'auth/odoo_auth_strategy.dart';

/// Unified Odoo client for JSON-2 API (Odoo 19.0+).
///
/// This is the **main entry point** for all Odoo operations, providing:
/// - **CRUD operations** via [crud] or convenience methods
/// - **Session management** via [session]
/// - **HTTP client access** via [http] (for advanced use cases)
///
/// ## Basic Usage
///
/// ```dart
/// final client = OdooClient(
///   config: OdooClientConfig(
///     baseUrl: 'https://odoo.example.com',
///     apiKey: 'your-api-key',
///     database: 'your-db',
///   ),
/// );
///
/// // Search and read records
/// final partners = await client.searchRead(
///   model: 'res.partner',
///   fields: ['name', 'email', 'phone'],
///   domain: [['customer_rank', '>', 0]],
///   limit: 50,
///   order: 'name asc',
/// );
///
/// // Create a new record
/// final newId = await client.create(
///   model: 'res.partner',
///   values: {'name': 'New Customer', 'email': 'new@example.com'},
/// );
///
/// // Update existing records
/// await client.write(
///   model: 'res.partner',
///   ids: [newId!],
///   values: {'phone': '+1234567890'},
/// );
///
/// // Delete records
/// await client.unlink(model: 'res.partner', ids: [newId]);
/// ```
///
/// ## Batch Operations
///
/// For better performance when handling multiple records:
///
/// ```dart
/// // Create multiple records in one call
/// final ids = await client.crud.createBatch(
///   model: 'product.product',
///   valuesList: [
///     {'name': 'Product A', 'list_price': 10.0},
///     {'name': 'Product B', 'list_price': 20.0},
///     {'name': 'Product C', 'list_price': 30.0},
///   ],
/// );
///
/// // Execute mixed operations
/// final result = await client.crud.executeBatch(
///   model: 'res.partner',
///   creates: [{'name': 'New Partner'}],
///   updates: [BatchUpdate(ids: [1, 2], values: {'active': true})],
///   deletes: [99, 100],
/// );
/// print('Created: ${result.createdIds}, Success: ${result.success}');
/// ```
///
/// ## Custom Method Calls
///
/// For calling custom Odoo methods:
///
/// ```dart
/// // Call a model method
/// final result = await client.call(
///   model: 'sale.order',
///   method: 'action_confirm',
///   ids: [orderId],
/// );
///
/// // Call with keyword arguments
/// final report = await client.call(
///   model: 'ir.actions.report',
///   method: 'render_qweb_pdf',
///   kwargs: {'report_name': 'sale.report_saleorder', 'res_ids': [orderId]},
/// );
/// ```
///
/// ## Session Management
///
/// For WebSocket connections and browser session:
///
/// ```dart
/// // Authenticate for WebSocket
/// final session = await client.authenticateSession();
/// print('User ID: ${session?.uid}');
///
/// // Get session info
/// final info = await client.getSessionInfo();
/// print('Company: ${info?['company_id']}');
/// ```
///
/// ## Configuration Options
///
/// ```dart
/// final client = OdooClient(
///   config: OdooClientConfig(
///     baseUrl: 'https://odoo.example.com',
///     apiKey: 'your-api-key',
///     database: 'production',
///     timeout: Duration(seconds: 30),
///     enableRetry: true,
///     retryConfig: RetryConfig(
///       maxRetries: 3,
///       initialDelay: Duration(seconds: 1),
///       onRetry: (attempt, delay, error) {
///         print('Retry $attempt after $delay');
///       },
///     ),
///   ),
/// );
/// ```
///
/// ## Error Handling
///
/// ```dart
/// try {
///   await client.searchRead(model: 'invalid.model', fields: ['id']);
/// } on OdooAuthenticationException {
///   print('Invalid API key');
/// } on OdooAccessDeniedException {
///   print('No permission for this model');
/// } on OdooNotFoundException {
///   print('Model not found');
/// } on OdooConnectionException {
///   print('Network error - consider offline mode');
/// } on OdooException catch (e) {
///   print('Odoo error: ${e.message}');
/// }
/// ```
class OdooClient {
  final OdooHttpClient _httpClient;
  final OdooCrudApi _crudApi;
  final OdooSessionManager _sessionManager;
  OdooVersion _version = OdooVersion.unknown;

  OdooClient._({
    required OdooHttpClient httpClient,
    required OdooCrudApi crudApi,
    required OdooSessionManager sessionManager,
  }) : _httpClient = httpClient,
       _crudApi = crudApi,
       _sessionManager = sessionManager;

  /// Create a new OdooClient with the given configuration
  factory OdooClient({required OdooClientConfig config}) {
    final httpClient = OdooHttpClient(config: config);
    final crudApi = OdooCrudApi(httpClient: httpClient);
    final sessionManager = OdooSessionManager(
      httpClient: httpClient,
      crudApi: crudApi,
    );

    return OdooClient._(
      httpClient: httpClient,
      crudApi: crudApi,
      sessionManager: sessionManager,
    );
  }

  /// Low-level HTTP client (for advanced use cases)
  OdooHttpClient get http => _httpClient;

  /// CRUD operations (search_read, read, write, create, unlink)
  OdooCrudApi get crud => _crudApi;

  /// Session management (authentication, web session)
  OdooSessionManager get session => _sessionManager;

  /// The detected Odoo server version. Call [fetchVersion] first.
  OdooVersion get version => _version;

  /// Detect the Odoo server version by reading the base module version.
  /// Returns the detected version and caches it.
  Future<OdooVersion> fetchVersion() async {
    try {
      final result = await searchRead(
        model: 'ir.module.module',
        fields: ['latest_version'],
        domain: [
          ['name', '=', 'base']
        ],
        limit: 1,
      );
      if (result.isNotEmpty) {
        final versionStr =
            result.first['latest_version']?.toString() ?? '';
        _version = OdooVersion.parse(versionStr);
      }
    } catch (_) {
      // If we can't detect, leave as unknown
    }
    return _version;
  }

  /// Current configuration
  OdooClientConfig get config => _httpClient.config;

  /// Whether the client has valid credentials
  bool get isConfigured => _httpClient.isConfigured;

  /// API key (for external use like WebSocket)
  String get apiKey => _httpClient.config.apiKey;

  /// Update client credentials
  void setCredentials(String baseUrl, String apiKey, String? database) {
    _httpClient.updateConfig(
      OdooClientConfig(baseUrl: baseUrl, apiKey: apiKey, database: database),
    );
  }

  // ============================================================
  // Convenience methods that delegate to components
  // These maintain API compatibility with the original OdooProvider
  // All methods support optional CancelToken for request cancellation
  // ============================================================

  /// Generic Odoo method call.
  ///
  /// Pass a [cancelToken] to allow cancelling long-running operations.
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    CancelToken? cancelToken,
  }) => _crudApi.call(
    model: model,
    method: method,
    ids: ids,
    args: args,
    kwargs: kwargs,
    cancelToken: cancelToken,
  );

  /// Search and read records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
    CancelToken? cancelToken,
  }) => _crudApi.searchRead(
    model: model,
    fields: fields,
    domain: domain,
    limit: limit,
    offset: offset,
    order: order,
    cancelToken: cancelToken,
  );

  /// Count records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<int?> searchCount({
    required String model,
    List<dynamic>? domain,
    CancelToken? cancelToken,
  }) => _crudApi.searchCount(
    model: model,
    domain: domain,
    cancelToken: cancelToken,
  );

  /// Get modified records since timestamp.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> getModifiedSince({
    required String model,
    required List<String> fields,
    required DateTime lastSync,
    List<dynamic>? additionalDomain,
    CancelToken? cancelToken,
  }) => _crudApi.getModifiedSince(
    model: model,
    fields: fields,
    lastSync: lastSync,
    additionalDomain: additionalDomain,
    cancelToken: cancelToken,
  );

  /// Read records by IDs.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> read({
    required String model,
    required List<int> ids,
    required List<String> fields,
    CancelToken? cancelToken,
  }) => _crudApi.read(
    model: model,
    ids: ids,
    fields: fields,
    cancelToken: cancelToken,
  );

  /// Update records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<bool> write({
    required String model,
    required List<int> ids,
    required Map<String, dynamic> values,
    CancelToken? cancelToken,
  }) => _crudApi.write(
    model: model,
    ids: ids,
    values: values,
    cancelToken: cancelToken,
  );

  /// Create a record.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<int?> create({
    required String model,
    required Map<String, dynamic> values,
    CancelToken? cancelToken,
  }) => _crudApi.create(
    model: model,
    values: values,
    cancelToken: cancelToken,
  );

  /// Delete records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<bool> unlink({
    required String model,
    required List<int> ids,
    CancelToken? cancelToken,
  }) => _crudApi.unlink(
    model: model,
    ids: ids,
    cancelToken: cancelToken,
  );

  /// Get field metadata.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    List<String>? fields,
    List<String>? attributes,
    CancelToken? cancelToken,
  }) => _crudApi.fieldsGet(
    model: model,
    fields: fields,
    attributes: attributes,
    cancelToken: cancelToken,
  );

  /// Create web session cookies
  Future<void> createWebSession() => _sessionManager.createWebSession();

  /// Authenticate for WebSocket
  Future<OdooSessionResult?> authenticateSession({
    String? login,
    String? password,
  }) => _sessionManager.authenticateSession(login: login, password: password);

  /// Get session info from Odoo (cached)
  ///
  /// Returns uid, partner_id, company info, im_status_access_token, etc.
  Future<Map<String, dynamic>?> getSessionInfo({bool forceRefresh = false}) =>
      _sessionManager.getSessionInfo(forceRefresh: forceRefresh);

  /// Call JSON-RPC endpoint
  Future<dynamic> callJsonRpc({
    required String endpoint,
    Map<String, dynamic>? params,
  }) => _sessionManager.callJsonRpc(endpoint: endpoint, params: params);
}
