import '../../api/odoo_client.dart';
import '../../api/odoo_exception.dart';
import '../interfaces/i_odoo_database.dart';

/// Base repository class providing common functionality for all repositories
///
/// Implements offline-first pattern with local cache and Odoo sync.
/// OdooClient is OPTIONAL - repositories can work fully offline when null.
///
/// Example:
/// ```dart
/// class MyRepository extends BaseRepository<MyDatabase> with OfflineSupport<MyDatabase> {
///   MyRepository({super.odooClient, required super.db});
///
///   Future<List<Item>> getItems() => fetchWithCache(...);
/// }
/// ```
abstract class BaseRepository<DB extends IOdooDatabase> {
  /// Odoo client for remote operations (nullable for offline-first support)
  final OdooClient? odooClient;

  /// Local database for cache and offline storage
  final DB db;

  BaseRepository({this.odooClient, required this.db});

  /// Check if online (OdooClient available and configured)
  bool get isOnline => odooClient?.isConfigured ?? false;

  /// Execute an operation with error handling
  /// Returns cached data on failure if available
  Future<T> executeWithFallback<T>({
    required Future<T> Function() remoteOperation,
    required Future<T> Function() localFallback,
    String? operationName,
  }) async {
    if (!isOnline) {
      return localFallback();
    }

    try {
      return await remoteOperation();
    } catch (e) {
      return localFallback();
    }
  }

  /// Execute a remote operation with exception mapping
  /// Throws OdooException if offline or operation fails
  Future<T> executeRemote<T>({
    required Future<T> Function() operation,
    String? operationName,
  }) async {
    if (!isOnline) {
      throw const OdooException(message: 'Offline: No OdooClient available');
    }

    try {
      return await operation();
    } on OdooException {
      rethrow;
    } catch (e) {
      throw OdooException(message: e.toString());
    }
  }

  /// Queue operation for offline sync
  Future<void> queueOfflineOperation(
    String model,
    String method,
    int recordId,
    Map<String, dynamic> values,
  ) async {
    await db.queueOfflineOperation(model, method, recordId, values);
  }
}

// ============================================================
// GENERIC SYNC PATTERNS
// ============================================================

/// Generic method for offline-first fetch with cache pattern
///
/// This pattern is used throughout repositories:
/// 1. Check local cache if not forced refresh
/// 2. Fetch from remote if online
/// 3. Upsert to local cache
/// 4. Return results (or fallback to cache on error)
///
/// Example usage in repository:
/// ```dart
/// Future<List<ResCountry>> getCountries({bool forceRefresh = false}) async {
///   return fetchWithCache<ResCountry>(
///     forceRefresh: forceRefresh,
///     getFromCache: () => db.getCountries(),
///     fetchFromRemote: () => odooClient!.searchRead(
///       model: 'res.country',
///       fields: ResCountry.odooFields,
///     ),
///     parseItem: (data) => ResCountry.fromOdoo(data),
///     saveToCache: (items) => db.upsertCountries(items),
///   );
/// }
/// ```
extension GenericSyncExtension<DB extends IOdooDatabase> on BaseRepository<DB> {
  /// Fetch list of items with offline-first pattern
  ///
  /// If offline, returns cached data only.
  /// If online, fetches from remote and updates cache.
  Future<List<T>> fetchWithCache<T>({
    required bool forceRefresh,
    required Future<List<T>> Function() getFromCache,
    required Future<List<Map<String, dynamic>>> Function() fetchFromRemote,
    required T Function(Map<String, dynamic>) parseItem,
    required Future<void> Function(List<T>) saveToCache,
    String? operationName,
  }) async {
    // 1. Check cache first (unless forced refresh)
    if (!forceRefresh) {
      final cached = await getFromCache();
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    // 2. If offline, can only return cache
    if (!isOnline) {
      return await getFromCache();
    }

    // 3. Fetch from remote
    try {
      final data = await fetchFromRemote();
      final items = data.map((e) => parseItem(e)).toList();

      // 4. Save to cache
      await saveToCache(items);

      return items;
    } catch (e) {
      // 5. Fallback to cache on error
      return await getFromCache();
    }
  }

  /// Fetch single item with offline-first pattern
  Future<T?> fetchSingleWithCache<T>({
    required int id,
    required bool forceRefresh,
    required Future<T?> Function() getFromCache,
    required Future<List<Map<String, dynamic>>> Function() fetchFromRemote,
    required T Function(Map<String, dynamic>) parseItem,
    required Future<void> Function(T) saveToCache,
    String? operationName,
  }) async {
    // 1. Check cache first (unless forced refresh)
    if (!forceRefresh) {
      final cached = await getFromCache();
      if (cached != null) {
        return cached;
      }
    }

    // 2. If offline, can only return cache
    if (!isOnline) {
      return await getFromCache();
    }

    // 3. Fetch from remote
    try {
      final data = await fetchFromRemote();
      if (data.isEmpty) return null;

      final item = parseItem(data.first);

      // 4. Save to cache
      await saveToCache(item);

      return item;
    } catch (e) {
      // 5. Fallback to cache on error
      return await getFromCache();
    }
  }
}

// ============================================================
// CREATE/UPDATE WITH OFFLINE SUPPORT
// ============================================================

/// Extension for create/update operations with offline support
extension OfflineWriteExtension<DB extends IOdooDatabase> on BaseRepository<DB> {
  /// Create a record with offline fallback
  ///
  /// 1. If online, try to create in remote (Odoo)
  /// 2. If offline or fails, create locally with negative ID and queue for sync
  ///
  /// Returns the record ID (positive if synced, negative if offline)
  Future<int> createWithOfflineFallback({
    required String model,
    required Map<String, dynamic> values,
    required Future<int> Function(Map<String, dynamic> values) createLocally,
    String? operationName,
  }) async {
    // If online, try remote first
    if (isOnline) {
      try {
        final remoteId = await odooClient!.create(model: model, values: values);
        if (remoteId != null) {
          return remoteId;
        }
      } catch (e) {
        // Fall through to local creation
      }
    }

    // Fallback to local creation
    final localId = await createLocally(values);

    // Queue for sync when online
    await queueOfflineOperation(model, 'create', localId, values);

    return localId;
  }

  /// Update a record with offline fallback
  ///
  /// 1. Update locally first (optimistic)
  /// 2. If online, try to sync to remote
  /// 3. If offline or fails, queue for later sync
  Future<bool> updateWithOfflineFallback({
    required String model,
    required int recordId,
    required Map<String, dynamic> values,
    required Future<void> Function(int id, Map<String, dynamic> values)
        updateLocally,
    String? operationName,
  }) async {
    // 1. Update locally first (optimistic update)
    await updateLocally(recordId, values);

    // 2. If online, try remote sync
    if (isOnline) {
      try {
        final success = await odooClient!.write(
          model: model,
          ids: [recordId],
          values: values,
        );

        if (success) {
          return true;
        }
      } catch (e) {
        // Fall through to queue
      }
    }

    // 3. Queue for later sync
    await queueOfflineOperation(model, 'write', recordId, values);
    return true; // Local update was successful
  }

  /// Delete a record with offline fallback
  Future<bool> deleteWithOfflineFallback({
    required String model,
    required int recordId,
    required Future<void> Function(int id) deleteLocally,
    String? operationName,
  }) async {
    // 1. Delete locally first
    await deleteLocally(recordId);

    // For offline records (negative ID), don't need to sync
    if (recordId < 0) {
      return true;
    }

    // 2. If online, try remote delete
    if (isOnline) {
      try {
        final success = await odooClient!.unlink(model: model, ids: [recordId]);

        if (success) {
          return true;
        }
      } catch (e) {
        // Fall through to queue
      }
    }

    // 3. Queue for later sync
    await queueOfflineOperation(model, 'unlink', recordId, {});
    return true; // Local delete was successful
  }
}

// ============================================================
// OFFLINE SUPPORT MIXIN
// ============================================================

/// Mixin for repositories that support offline operations
mixin OfflineSupport<DB extends IOdooDatabase> on BaseRepository<DB> {
  /// Check if we should try remote first or use cache
  bool get preferRemote => true; // Can be made configurable

  /// Sync pending offline operations for this repository
  ///
  /// Returns number of successfully synced operations.
  /// Only works if online, otherwise returns 0.
  Future<int> syncPendingOperations(String model) async {
    if (!isOnline) return 0;

    final pending = await db.getPendingOperations();
    final modelOps = pending.where((op) => op['model'] == model).toList();

    int successCount = 0;
    for (final op in modelOps) {
      try {
        bool success = false;

        if (op['method'] == 'write') {
          success = await odooClient!.write(
            model: op['model'],
            ids: [op['record_id']],
            values: op['values'],
          );
        } else if (op['method'] == 'create') {
          final id = await odooClient!.create(
            model: op['model'],
            values: op['values'],
          );
          success = id != null;
        } else if (op['method'] == 'unlink') {
          success = await odooClient!.unlink(
            model: op['model'],
            ids: [op['record_id']],
          );
        }

        if (success) {
          await db.removeOperation(op['id']);
          successCount++;
        }
      } catch (e) {
        // Failed to sync operation - will retry later
      }
    }

    return successCount;
  }
}

/// Mixin for repositories with session info caching
mixin SessionInfoCache<DB extends IOdooDatabase> on BaseRepository<DB> {
  static Map<String, dynamic>? _cachedSessionInfo;
  static DateTime? _sessionInfoCacheTime;
  static const _sessionInfoCacheDuration = Duration(minutes: 5);

  /// Get session_info from cache or fetch from Odoo
  ///
  /// Returns null if offline or fetch fails.
  Future<Map<String, dynamic>?> getSessionInfoCached() async {
    // Check cache first
    if (_cachedSessionInfo != null &&
        _sessionInfoCacheTime != null &&
        DateTime.now().difference(_sessionInfoCacheTime!) <
            _sessionInfoCacheDuration) {
      return _cachedSessionInfo;
    }

    // Can't fetch if offline
    if (!isOnline) {
      return _cachedSessionInfo; // Return stale cache or null
    }

    try {
      final sessionInfo = await odooClient!.call(
        model: 'ir.http',
        method: 'session_info',
        kwargs: {},
      );

      if (sessionInfo is Map<String, dynamic>) {
        _cachedSessionInfo = sessionInfo;
        _sessionInfoCacheTime = DateTime.now();
        return sessionInfo;
      }
    } catch (e) {
      // Return stale cache on error
    }

    return _cachedSessionInfo;
  }

  /// Clear session_info cache (instance method)
  void clearSessionInfoCache() {
    _cachedSessionInfo = null;
    _sessionInfoCacheTime = null;
  }

  /// Clear session_info cache (static method for global access)
  static void clearCache() {
    _cachedSessionInfo = null;
    _sessionInfoCacheTime = null;
  }
}
