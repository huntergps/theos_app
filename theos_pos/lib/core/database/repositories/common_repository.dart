import 'package:theos_pos_core/theos_pos_core.dart'
    show
        ResCountry,
        ResCountryState,
        ResLang,
        ResourceCalendar,
        Warehouse,
        resCountryManager,
        resCountryStateManager,
        resLangManager,
        resourceCalendarManager,
        warehouseManager;
import 'base_repository.dart';
// Datasources (only FieldSelection remains — no generated manager)
import '../datasources/datasources.dart';

/// Repository for common/shared data operations
///
/// Handles: Countries, States, Languages, Warehouses, Calendars, Field Selections
/// Uses generated OdooModelManagers for CRUD and [fetchWithCache] from [BaseRepository].
class CommonRepository extends BaseRepository with OfflineSupport {
  final FieldSelectionDatasource _fieldSelectionDatasource;

  CommonRepository({
    required super.odooClient,
    required super.db,
    required FieldSelectionDatasource fieldSelectionDatasource,
  }) : _fieldSelectionDatasource = fieldSelectionDatasource;

  // ============ Countries ============

  /// Get all countries (cached)
  Future<List<ResCountry>> getCountries({bool forceRefresh = false}) async {
    return fetchWithCache<ResCountry>(
      forceRefresh: forceRefresh,
      getFromCache: () => resCountryManager.searchLocal(orderBy: 'name asc'),
      fetchFromRemote: () => odooClient!.searchRead(
        model: 'res.country',
        fields: resCountryManager.odooFields,
      ),
      parseItem: (data) => resCountryManager.fromOdoo(data),
      saveToCache: (items) => resCountryManager.upsertLocalBatch(items),
      operationName: 'getCountries',
    );
  }

  // ============ States ============

  /// Get states for a country
  Future<List<ResCountryState>> getStates(int? countryId) async {
    return fetchWithCache<ResCountryState>(
      forceRefresh: false,
      getFromCache: () => countryId != null
          ? resCountryStateManager.searchLocal(
              domain: [['country_id', '=', countryId]],
              orderBy: 'name asc',
            )
          : resCountryStateManager.searchLocal(orderBy: 'name asc'),
      fetchFromRemote: () => odooClient!.searchRead(
        model: 'res.country.state',
        fields: resCountryStateManager.odooFields,
        domain: countryId != null
            ? [
                ['country_id', '=', countryId],
              ]
            : [],
      ),
      parseItem: (data) => resCountryStateManager.fromOdoo(data),
      saveToCache: (items) => resCountryStateManager.upsertLocalBatch(items),
      operationName: 'getStates($countryId)',
    );
  }

  // ============ Languages ============

  /// Get all languages (cached)
  Future<List<ResLang>> getLanguages({bool forceRefresh = false}) async {
    return fetchWithCache<ResLang>(
      forceRefresh: forceRefresh,
      getFromCache: () => resLangManager.searchLocal(
            domain: [['active', '=', true]],
            orderBy: 'name asc',
          ),
      fetchFromRemote: () => odooClient!.searchRead(
        model: 'res.lang',
        fields: resLangManager.odooFields,
        domain: [
          ['active', '=', true],
        ],
      ),
      parseItem: (data) => resLangManager.fromOdoo(data),
      saveToCache: (items) => resLangManager.upsertLocalBatch(items),
      operationName: 'getLanguages',
    );
  }

  // ============ Warehouses ============

  /// Get all warehouses (cached)
  Future<List<Warehouse>> getWarehouses({
    bool forceRefresh = false,
  }) async {
    return fetchWithCache<Warehouse>(
      forceRefresh: forceRefresh,
      getFromCache: () => warehouseManager.searchLocal(),
      fetchFromRemote: () => odooClient!.searchRead(
        model: 'stock.warehouse',
        fields: warehouseManager.odooFields,
      ),
      parseItem: (data) => warehouseManager.fromOdoo(data),
      saveToCache: (items) => warehouseManager.upsertLocalBatch(items),
      operationName: 'getWarehouses',
    );
  }

  // ============ Resource Calendars ============

  /// Get all resource calendars (cached)
  Future<List<ResourceCalendar>> getCalendars({
    bool forceRefresh = false,
  }) async {
    return fetchWithCache<ResourceCalendar>(
      forceRefresh: forceRefresh,
      getFromCache: () => resourceCalendarManager.searchLocal(orderBy: 'name asc'),
      fetchFromRemote: () => odooClient!.searchRead(
        model: 'resource.calendar',
        fields: resourceCalendarManager.odooFields,
      ),
      parseItem: (data) => resourceCalendarManager.fromOdoo(data),
      saveToCache: (items) => resourceCalendarManager.upsertLocalBatch(items),
      operationName: 'getCalendars',
    );
  }

  // ============ Field Selections ============

  /// Get field selections (e.g., timezones, notification types)
  /// Note: This uses a different pattern (call instead of searchRead)
  Future<List<dynamic>> getFieldSelection(
    String model,
    String field, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _fieldSelectionDatasource.getFieldSelection(model, field);
      if (cached != null) return cached;
    }

    // If offline, return cached data only
    if (!isOnline) {
      final cached = await _fieldSelectionDatasource.getFieldSelection(model, field);
      return cached ?? [];
    }

    try {
      final response = await odooClient!.call(
        model: model,
        method: 'fields_get',
        kwargs: {
          'allfields': [field],
          'attributes': ['selection'],
        },
      );

      if (response is Map && response.containsKey(field)) {
        final fieldData = response[field] as Map<String, dynamic>;
        if (fieldData.containsKey('selection')) {
          final selection = fieldData['selection'];
          if (selection is List) {
            await _fieldSelectionDatasource.upsertFieldSelection(model, field, selection);
            return selection;
          }
        }
      }
    } catch (e) {
      final cached = await _fieldSelectionDatasource.getFieldSelection(model, field);
      if (cached != null) return cached;
    }

    return [];
  }

  /// Get timezones
  Future<List<dynamic>> getTimezones({bool forceRefresh = false}) async {
    return await getFieldSelection(
      'res.users',
      'tz',
      forceRefresh: forceRefresh,
    );
  }

  /// Get notification types
  Future<List<dynamic>> getNotificationTypes({
    bool forceRefresh = false,
  }) async {
    return await getFieldSelection(
      'res.users',
      'notification_type',
      forceRefresh: forceRefresh,
    );
  }
}
