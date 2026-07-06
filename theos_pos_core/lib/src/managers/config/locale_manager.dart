/// LocaleManager - Managers for res.country, res.country.state, res.lang models
///
/// Read-only managers for locale data synced from Odoo.
///
/// @deprecated Use generated managers instead:
/// - resCountryManager (from res_country.model.g.dart)
/// - resCountryStateManager (from res_country_state.model.g.dart)
/// - resLangManager (from res_lang.model.g.dart)
/// These manual managers are kept for backward compatibility but should be
/// migrated to the generated OdooModelManager equivalents.
library;

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Country
// ═══════════════════════════════════════════════════════════════════════════

/// Lightweight data class for country
class Country {
  final int odooId;
  final String name;
  final String code;
  final DateTime? writeDate;

  const Country({
    required this.odooId,
    required this.name,
    required this.code,
    this.writeDate,
  });
}

/// Manager for res.country model
class CountryManager {
  final AppDatabase _db;

  CountryManager(this._db);

  String get odooModel => 'res.country';

  List<String> get odooFields => [
        'id',
        'name',
        'code',
        'write_date',
      ];

  /// Convert Odoo data to domain model
  Country fromOdoo(Map<String, dynamic> data) {
    return Country(
      odooId: data['id'] as int,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      writeDate: odoo.parseOdooDateTime(data['write_date']),
    );
  }

  /// Upsert country to local database
  Future<void> upsertLocal(Country record) async {
    final companion = ResCountryCompanion(
      odooId: Value(record.odooId),
      name: Value(record.name),
      code: Value(record.code),
      writeDate: Value(record.writeDate),
    );

    final existing = await (_db.select(_db.resCountry)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.resCountry)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.resCountry).insert(companion);
    }
  }

  /// Batch upsert de países — UNA sola transacción Drift para todo el lote,
  /// en vez de 2 queries (select + update/insert) POR REGISTRO como hace
  /// [upsertLocal]. Ver comentario equivalente en
  /// `CountryStateManager.upsertLocalBatch` (mismo patrón).
  Future<void> upsertLocalBatch(List<Country> records) async {
    if (records.isEmpty) return;

    await _db.batch((batch) {
      for (final record in records) {
        final companion = ResCountryCompanion(
          odooId: Value(record.odooId),
          name: Value(record.name),
          code: Value(record.code),
          writeDate: Value(record.writeDate),
        );

        batch.insert(
          _db.resCountry,
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [_db.resCountry.odooId],
          ),
        );
      }
    });
  }

  /// Get country by Odoo ID
  Future<ResCountryData?> getById(int odooId) async {
    return (_db.select(_db.resCountry)..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
  }

  /// Get country by code
  Future<ResCountryData?> getByCode(String code) async {
    return (_db.select(_db.resCountry)..where((t) => t.code.equals(code)))
        .getSingleOrNull();
  }

  /// Get all countries
  Future<List<ResCountryData>> getAll() async {
    return (_db.select(_db.resCountry)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Country State
// ═══════════════════════════════════════════════════════════════════════════

/// Lightweight data class for country state
class CountryState {
  final int odooId;
  final String name;
  final String code;
  final int countryId;
  final DateTime? writeDate;

  const CountryState({
    required this.odooId,
    required this.name,
    required this.code,
    required this.countryId,
    this.writeDate,
  });
}

/// Manager for res.country.state model
class CountryStateManager {
  final AppDatabase _db;

  CountryStateManager(this._db);

  String get odooModel => 'res.country.state';

  List<String> get odooFields => [
        'id',
        'name',
        'code',
        'country_id',
        'write_date',
      ];

  /// Convert Odoo data to domain model
  CountryState fromOdoo(Map<String, dynamic> data) {
    final countryId = odoo.extractMany2oneId(data['country_id']);

    return CountryState(
      odooId: data['id'] as int,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      countryId: countryId ?? 0,
      writeDate: odoo.parseOdooDateTime(data['write_date']),
    );
  }

  /// Upsert country state to local database
  Future<void> upsertLocal(CountryState record) async {
    if (record.countryId == 0) return;

    final companion = ResCountryStateCompanion(
      odooId: Value(record.odooId),
      name: Value(record.name),
      code: Value(record.code),
      countryId: Value(record.countryId),
      writeDate: Value(record.writeDate),
    );

    final existing = await (_db.select(_db.resCountryState)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.resCountryState)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.resCountryState).insert(companion);
    }
  }

  /// Batch upsert de country states — UNA sola transacción Drift
  /// (`database.batch()`) para todo el lote, en vez de 2 queries
  /// (select + update/insert) POR REGISTRO como hace [upsertLocal]. Pensado
  /// para el sync inicial de catálogo (~500 registros en Odoo).
  ///
  /// A diferencia de `GenericDriftOperations.upsertLocalBatch` (usado por
  /// managers generados), acá SÍ hay un `XxxCompanion` tipado real
  /// (`ResCountryStateCompanion`) porque este manager es hand-written —
  /// no hace falta el SQL crudo / `RawValuesInsertable` que existe para
  /// managers genéricos. Usa la misma lógica de conflicto (`ON CONFLICT
  /// (odoo_id) DO UPDATE`) que [upsertLocal], vía la API pública de Drift
  /// (`DoUpdate` + `target:`).
  Future<void> upsertLocalBatch(List<CountryState> records) async {
    final valid = records.where((r) => r.countryId != 0).toList();
    if (valid.isEmpty) return;

    await _db.batch((batch) {
      for (final record in valid) {
        final companion = ResCountryStateCompanion(
          odooId: Value(record.odooId),
          name: Value(record.name),
          code: Value(record.code),
          countryId: Value(record.countryId),
          writeDate: Value(record.writeDate),
        );

        batch.insert(
          _db.resCountryState,
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [_db.resCountryState.odooId],
          ),
        );
      }
    });
  }

  /// Get states by country
  Future<List<ResCountryStateData>> getByCountryId(int countryId) async {
    return (_db.select(_db.resCountryState)
          ..where((t) => t.countryId.equals(countryId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Get all states
  Future<List<ResCountryStateData>> getAll() async {
    return (_db.select(_db.resCountryState)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Language
// ═══════════════════════════════════════════════════════════════════════════

/// Lightweight data class for language
class Language {
  final int odooId;
  final String name;
  final String code;
  final bool active;
  final DateTime? writeDate;

  const Language({
    required this.odooId,
    required this.name,
    required this.code,
    this.active = true,
    this.writeDate,
  });
}

/// Manager for res.lang model
class LanguageManager {
  final AppDatabase _db;

  LanguageManager(this._db);

  String get odooModel => 'res.lang';

  List<String> get odooFields => [
        'id',
        'name',
        'code',
        'active',
        'write_date',
      ];

  /// Convert Odoo data to domain model
  Language fromOdoo(Map<String, dynamic> data) {
    return Language(
      odooId: data['id'] as int,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      writeDate: odoo.parseOdooDateTime(data['write_date']),
    );
  }

  /// Upsert language to local database
  Future<void> upsertLocal(Language record) async {
    final companion = ResLangCompanion(
      odooId: Value(record.odooId),
      name: Value(record.name),
      code: Value(record.code),
      active: Value(record.active),
      writeDate: Value(record.writeDate),
    );

    final existing = await (_db.select(_db.resLang)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.resLang)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.resLang).insert(companion);
    }
  }

  /// Get language by code
  Future<ResLangData?> getByCode(String code) async {
    return (_db.select(_db.resLang)..where((t) => t.code.equals(code)))
        .getSingleOrNull();
  }

  /// Get all active languages
  Future<List<ResLangData>> getAll() async {
    return (_db.select(_db.resLang)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }
}
