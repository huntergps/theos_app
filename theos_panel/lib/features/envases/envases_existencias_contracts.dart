import 'dart:async';

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

  /// Publica las cifras primero (esto es lo único que se espera) y sólo
  /// DESPUÉS completa las fotos de producto, sin bloquear ni retrasar nada
  /// — orden del dueño. `unawaited` a propósito: una foto lenta, o un
  /// servidor sin `image_128`, nunca debe alargar ni romper este refresco.
  @override
  Future<void> refresh() async {
    final currentReader = readerFactory();
    final snapshot = await cache.refresh(currentReader);
    unawaited(_completeImages(currentReader, snapshot.data));
  }

  Future<void> _completeImages(
    EnvasesExistenciasReader currentReader,
    EnvasesExistenciasData data,
  ) async {
    try {
      final ids = data.filas.map((fila) => fila.id).toSet();
      if (ids.isEmpty) return;
      final imagenes = await currentReader.readImages(ids);
      if (imagenes.isEmpty) return;
      await cache.mergeImages(imagenes);
    } catch (_) {
      // Las fotos son una mejora visual: nunca deben romper la pantalla ni
      // dejar el refresco de existencias en un estado de error.
    }
  }
}
