/// Related Field Service (Generic)
///
/// Resolves Many2one/Many2many display data with the flow:
/// Local Cache -> Remote (if online) -> Fallback [id, name]
library;

import '../api/odoo_client.dart';
import '../utils/related_field_result.dart';

/// Cache entry for related records.
class RelatedRecordCacheEntry {
  final String model;
  final int odooId;
  final String name;
  final Map<String, dynamic>? data;
  final DateTime cachedAt;
  final DateTime? writeDate;

  const RelatedRecordCacheEntry({
    required this.model,
    required this.odooId,
    required this.name,
    required this.data,
    required this.cachedAt,
    this.writeDate,
  });
}

/// Cache store interface for related record cache implementations.
abstract class RelatedRecordCacheStore {
  Future<RelatedRecordCacheEntry?> get(String model, int odooId);
  Future<void> upsert(RelatedRecordCacheEntry entry);
  Future<int> deleteByModel(String model);
  Future<int> deleteRecord(String model, int odooId);
  Future<int> deleteOlderThan(DateTime cutoff);
}

/// Service to resolve related fields for any Odoo model.
class RelatedFieldService {
  final OdooClient? _odooClient;
  final RelatedRecordCacheStore _cacheStore;

  RelatedFieldService({
    OdooClient? odooClient,
    required RelatedRecordCacheStore cacheStore,
  }) : _odooClient = odooClient,
       _cacheStore = cacheStore;

  /// Verifies if online and can fetch from Odoo.
  bool get isOnline => _odooClient != null;

  /// Resolve a single record (Many2one, Many2many) for any Odoo model.
  Future<RelatedFieldResult> get({
    required String model,
    required int? id,
    String? fallbackName,
    List<String>? fields,
    int maxCacheAge = 24,
  }) async {
    if (id == null) {
      return RelatedFieldResult(fallbackName: fallbackName);
    }

    // 1) Cache lookup
    final cached = await _cacheStore.get(model, id);
    if (cached != null) {
      final cacheAge = DateTime.now().difference(cached.cachedAt).inHours;
      if (cacheAge < maxCacheAge) {
        return RelatedFieldResult(
          record: _cacheEntryToMap(cached),
          id: id,
          fallbackName: fallbackName,
          fromCache: true,
        );
      }
    }

    // 2) Remote fetch if online
    if (isOnline) {
      try {
        final data = await _searchRead(
          model: model,
          domain: [
            ['id', '=', id],
          ],
          fields: fields ?? ['id', 'name', 'display_name', 'write_date'],
          limit: 1,
        );

        if (data.isNotEmpty) {
          await _saveToCache(model, id, data.first);
          return RelatedFieldResult(
            record: data.first,
            id: id,
            fallbackName: fallbackName,
            fromRemote: true,
          );
        }
      } catch (_) {
        // Ignore remote errors, fallback to cache/fallback below.
      }
    }

    // 3) Use stale cache if available
    if (cached != null) {
      return RelatedFieldResult(
        record: _cacheEntryToMap(cached),
        id: id,
        fallbackName: fallbackName,
        fromCache: true,
      );
    }

    // 4) Final fallback
    return RelatedFieldResult(id: id, fallbackName: fallbackName);
  }

  /// Resolve multiple records in batch.
  Future<Map<int, RelatedFieldResult>> getBatch({
    required String model,
    required List<int> ids,
    Map<int, String?>? fallbackNames,
    List<String>? fields,
    int maxCacheAge = 24,
  }) async {
    if (ids.isEmpty) return {};

    final results = <int, RelatedFieldResult>{};
    final missingIds = <int>[];

    // 1) Cache lookup for all
    for (final id in ids) {
      final cached = await _cacheStore.get(model, id);
      if (cached != null) {
        final cacheAge = DateTime.now().difference(cached.cachedAt).inHours;
        if (cacheAge < maxCacheAge) {
          results[id] = RelatedFieldResult(
            record: _cacheEntryToMap(cached),
            id: id,
            fallbackName: fallbackNames?[id],
            fromCache: true,
          );
          continue;
        }
      }
      missingIds.add(id);
    }

    // 2) Fetch missing if online
    if (missingIds.isNotEmpty && isOnline) {
      try {
        final data = await _searchRead(
          model: model,
          domain: [
            ['id', 'in', missingIds],
          ],
          fields: fields ?? ['id', 'name', 'display_name', 'write_date'],
        );

        for (final record in data) {
          final recordId = record['id'] as int;
          await _saveToCache(model, recordId, record);
          results[recordId] = RelatedFieldResult(
            record: record,
            id: recordId,
            fallbackName: fallbackNames?[recordId],
            fromRemote: true,
          );
          missingIds.remove(recordId);
        }
      } catch (_) {
        // Ignore remote errors, fallback to cache/fallback below.
      }
    }

    // 3) Fallback for remaining missing IDs
    for (final id in missingIds) {
      final cached = await _cacheStore.get(model, id);
      if (cached != null) {
        results[id] = RelatedFieldResult(
          record: _cacheEntryToMap(cached),
          id: id,
          fallbackName: fallbackNames?[id],
          fromCache: true,
        );
      } else {
        results[id] = RelatedFieldResult(
          id: id,
          fallbackName: fallbackNames?[id],
        );
      }
    }

    return results;
  }

  /// Clean old cache entries by age.
  Future<int> cleanOldCache({int maxAgeHours = 168}) async {
    final cutoff = DateTime.now().subtract(Duration(hours: maxAgeHours));
    return _cacheStore.deleteOlderThan(cutoff);
  }

  /// Invalidate all cache for a model.
  Future<int> invalidateCache(String model) =>
      _cacheStore.deleteByModel(model);

  /// Invalidate a single record.
  Future<int> invalidateRecord(String model, int id) =>
      _cacheStore.deleteRecord(model, id);

  // ========================================================================
  // Odoo API
  // ========================================================================

  Future<List<Map<String, dynamic>>> _searchRead({
    required String model,
    required List<dynamic> domain,
    required List<String> fields,
    int? limit,
  }) async {
    final client = _odooClient;
    if (client == null) return [];
    return client.searchRead(
      model: model,
      domain: domain,
      fields: fields,
      limit: limit,
    );
  }

  // ========================================================================
  // Cache helpers
  // ========================================================================

  Future<void> _saveToCache(
    String model,
    int id,
    Map<String, dynamic> record,
  ) async {
    final name =
        record['display_name']?.toString() ?? record['name']?.toString() ?? '';

    await _cacheStore.upsert(RelatedRecordCacheEntry(
      model: model,
      odooId: id,
      name: name,
      data: record,
      cachedAt: DateTime.now(),
      writeDate: _parseDate(record['write_date']),
    ));
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> _cacheEntryToMap(RelatedRecordCacheEntry cached) {
    return {
      'id': cached.odooId,
      'name': cached.name,
      'display_name': cached.name,
      if (cached.data != null) ...cached.data!,
    };
  }
}
