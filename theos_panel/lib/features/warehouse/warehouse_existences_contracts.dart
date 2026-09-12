import 'package:orbi_runtime/orbi_runtime.dart';

/// BOD-01 (inventario de existencias) reads through this boundary only.
/// [watch] must be the same local-first, reactive read `StockQuantCache`
/// already provides — a `null` snapshot means "not fetched yet", never
/// "empty". [refresh] is the only place this screen ever reaches Odoo.
abstract interface class WarehouseExistencesRepository {
  Stream<StockQuantSnapshot?> watch();
  Future<void> refresh();
}

/// Default composition-layer adapter: a thin pass-through to the already
/// lease-bound, company-scoped `StockQuantCache`/`StockQuantReader` in
/// `orbi_runtime`. `readerFactory` is a factory (not a stored reader)
/// because a fresh reader must be built for every refresh — the cache
/// rejects a reader captured before a session/company change.
final class RuntimeWarehouseExistencesRepository
    implements WarehouseExistencesRepository {
  const RuntimeWarehouseExistencesRepository({
    required this.cache,
    required this.readerFactory,
  });

  final StockQuantCache cache;
  final StockQuantReader Function() readerFactory;

  @override
  Stream<StockQuantSnapshot?> watch() => cache.watch();

  @override
  Future<void> refresh() => cache.refresh(readerFactory());
}

/// Client-side narrowing over an already-local snapshot. This never issues a
/// new Odoo read: BOD-01's "Almacén"/búsqueda filters only narrow what
/// `refresh()` already brought down, exactly like the rest of this screen's
/// local-first reading.
final class WarehouseExistencesFilter {
  const WarehouseExistencesFilter({this.warehouseId, this.text = ''});

  final int? warehouseId;
  final String text;

  bool get isEmpty => warehouseId == null && text.trim().isEmpty;

  WarehouseExistencesFilter copyWith({int? Function()? warehouseId, String? text}) =>
      WarehouseExistencesFilter(
        warehouseId: warehouseId == null ? this.warehouseId : warehouseId(),
        text: text ?? this.text,
      );

  List<StockQuantRow> apply(List<StockQuantRow> rows) {
    final needle = text.trim().toLowerCase();
    return rows
        .where((row) {
          if (warehouseId != null && row.warehouseId != warehouseId) {
            return false;
          }
          if (needle.isEmpty) return true;
          return row.productName.toLowerCase().contains(needle) ||
              row.locationName.toLowerCase().contains(needle);
        })
        .toList(growable: false);
  }

  /// Distinct (id, name) warehouse pairs actually present in [rows], sorted
  /// by name. The "Almacén" filter only ever offers warehouses this
  /// company's existences actually reference — never an invented list.
  static List<(int, String)> warehousesIn(List<StockQuantRow> rows) {
    final byId = <int, String>{};
    for (final row in rows) {
      final id = row.warehouseId;
      final name = row.warehouseName;
      if (id != null && name != null) byId[id] = name;
    }
    final entries = byId.entries.map((e) => (e.key, e.value)).toList();
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    return entries;
  }
}
