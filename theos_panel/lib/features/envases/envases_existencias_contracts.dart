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
    this.imageFieldCache,
  });

  final EnvasesExistenciasCache cache;
  final EnvasesExistenciasReader Function() readerFactory;

  /// Dónde se recuerda si `product.product.image_128` existe en este
  /// servidor+base, para sondearlo con `fields_get` UNA sola vez — nunca en
  /// cada refresco. `null` conserva el camino anterior (sondea siempre);
  /// la composición real (`envases_composition.dart`) siempre pasa uno.
  final EnvasesImageFieldCache? imageFieldCache;

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
      final imagenes = await _resolveImages(currentReader, ids);
      if (imagenes.isEmpty) return;
      await cache.mergeImages(imagenes);
    } catch (_) {
      // Las fotos son una mejora visual: nunca deben romper la pantalla ni
      // dejar el refresco de existencias en un estado de error.
    }
  }

  /// Sin caché persistente (compatibilidad): sondea `fields_get` en cada
  /// refresco, como antes. Con caché: sondea sólo mientras el estado sea
  /// `unknown`, y a partir de ahí lee (o se abstiene) directo — un "no
  /// existe" se trata igual que hoy, sin foto y sin romper nada, sólo que
  /// ahora se recuerda en vez de volver a preguntar.
  Future<Map<int, String?>> _resolveImages(
    EnvasesExistenciasReader currentReader,
    Set<int> ids,
  ) async {
    final fieldCache = imageFieldCache;
    if (fieldCache == null) return currentReader.readImages(ids);

    switch (fieldCache.read()) {
      case EnvasesImageFieldState.unavailable:
        return const {};
      case EnvasesImageFieldState.available:
        return currentReader.readImagesKnownAvailable(ids);
      case EnvasesImageFieldState.unknown:
        final available = await currentReader.probeImageFieldAvailable();
        await fieldCache.write(
          available
              ? EnvasesImageFieldState.available
              : EnvasesImageFieldState.unavailable,
        );
        if (!available) return const {};
        return currentReader.readImagesKnownAvailable(ids);
    }
  }
}
