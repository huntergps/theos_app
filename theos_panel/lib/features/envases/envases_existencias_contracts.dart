import 'package:orbi_runtime/orbi_runtime.dart';

/// ENV-01 (Existencias de envases) reads through this boundary only. [watch]
/// must be the same local-first, reactive read `EnvasesExistenciasCache`
/// already provides — a `null` snapshot means "not fetched yet", never
/// "empty". [refresh] is the only place this screen ever reaches Odoo.
abstract interface class EnvasesExistenciasRepository {
  Stream<EnvasesExistenciasSnapshot?> watch();
  Future<void> refresh();
}

/// Default composition-layer adapter: a thin pass-through to the already
/// lease-bound, company-scoped `EnvasesExistenciasCache`/`EnvasesExistenciasReader`
/// in `orbi_runtime`. `readerFactory` is a factory (not a stored reader)
/// because a fresh reader must be built for every refresh — the cache
/// rejects a reader captured before a session/company change, and the
/// client can legitimately be absent (offline) at refresh time.
final class RuntimeEnvasesExistenciasRepository
    implements EnvasesExistenciasRepository {
  const RuntimeEnvasesExistenciasRepository({
    required this.cache,
    required this.readerFactory,
  });

  final EnvasesExistenciasCache cache;
  final EnvasesExistenciasReader Function() readerFactory;

  @override
  Stream<EnvasesExistenciasSnapshot?> watch() => cache.watch();

  @override
  Future<void> refresh() => cache.refresh(readerFactory());
}
