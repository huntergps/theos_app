/// LocaleManager - Managers for res.country, res.country.state, res.lang models
///
/// Read-only managers for locale data synced from Odoo.
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
