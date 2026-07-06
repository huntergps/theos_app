import 'dart:isolate';

/// Native/IO implementation: parses a page of raw Odoo records into typed
/// models on a SEPARATE isolate, offloading the calling isolate (usually
/// the UI isolate, since `syncModel()` typically runs there) from CPU-bound
/// conversion work — Freezed construction, date/decimal/many2one parsing,
/// selection field mapping, etc.
///
/// [parser] MUST be a `static` or top-level function. A bound instance
/// method (e.g. `productManager.fromOdoo`) closes over its receiver, which
/// typically holds an `OdooClient` (HTTP) and/or `GeneratedDatabase`
/// (Drift/SQLite connection) — neither is safely transferable to another
/// isolate. `ProductManager.fromOdooMap`-style static tear-offs (generated
/// alongside the instance `fromOdoo`) are the intended input here. See
/// `ModelSyncConfig.isolateParser` doc for the full rationale.
Future<List<T>> parseInIsolate<T>(
  List<Map<String, dynamic>> pages,
  T Function(Map<String, dynamic>) parser,
) {
  return Isolate.run(() => pages.map(parser).toList());
}
