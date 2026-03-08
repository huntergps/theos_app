import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/reactive/reactive_search_bar.dart';

/// Service for persisting list filter state across app restarts
///
/// Each list screen can have its own storage key to persist its filters independently.
/// Filters are stored as JSON in SharedPreferences.
///
/// Usage:
/// ```dart
/// // Save filters
/// await ref.read(listFilterPersistenceProvider).saveFilters(
///   'sale_orders',
///   state,
/// );
///
/// // Load filters
/// final state = await ref.read(listFilterPersistenceProvider).loadFilters(
///   'sale_orders',
/// );
/// ```
class ListFilterPersistenceService {
  static const _keyPrefix = 'list_filters_';

  /// Save filter state for a specific list
  Future<void> saveFilters(
    String storageKey,
    ReactiveSearchBarState state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$storageKey';

    final data = {
      'query': state.query,
      'facets': state.facets.map((f) => _facetToJson(f)).toList(),
    };

    await prefs.setString(key, jsonEncode(data));
  }

  /// Load filter state for a specific list
  Future<ReactiveSearchBarState?> loadFilters(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$storageKey';

    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return null;

    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final query = data['query'] as String? ?? '';
      final facetsJson = data['facets'] as List<dynamic>? ?? [];

      final facets = facetsJson
          .map((f) => _facetFromJson(f as Map<String, dynamic>))
          .toList();

      return ReactiveSearchBarState(
        query: query,
        facets: facets,
      );
    } catch (e) {
      // If parsing fails, return null (use defaults)
      return null;
    }
  }

  /// Clear filters for a specific list
  Future<void> clearFilters(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$storageKey';
    await prefs.remove(key);
  }

  /// Clear all stored filters
  Future<void> clearAllFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Convert SearchFacet to JSON-serializable map
  Map<String, dynamic> _facetToJson(SearchFacet facet) {
    return {
      'id': facet.id,
      'label': facet.label,
      'value': facet.value,
      'type': facet.type.index,
      'removable': facet.removable,
    };
  }

  // Convert JSON map to SearchFacet
  SearchFacet _facetFromJson(Map<String, dynamic> json) {
    return SearchFacet(
      id: json['id'] as String,
      label: json['label'] as String,
      value: json['value'] as String,
      type: SearchFacetType.values[json['type'] as int? ?? 0],
      removable: json['removable'] as bool? ?? true,
    );
  }
}

/// Provider for the filter persistence service
final listFilterPersistenceProvider = Provider<ListFilterPersistenceService>(
  (ref) => ListFilterPersistenceService(),
);
