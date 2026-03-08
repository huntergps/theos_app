export '../../core/services/handlers/related_field_service.dart' show RelatedFieldResult;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/handlers/related_field_service.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/managers/manager_providers.dart' show appDatabaseProvider;

/// Provider para RelatedFieldService
///
/// Resuelve campos relacionados (Many2one, Many2many) de CUALQUIER modelo Odoo
/// siguiendo el flujo:
/// 1. Busca en cache local (SQLite)
/// 2. Si no está y hay conexión, trae de Odoo y guarda en cache
/// 3. Si no hay conexión, usa el fallback [id, name]
final relatedFieldServiceProvider = Provider<RelatedFieldService?>((ref) {
  final odooClient = ref.watch(odooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);

  if (dbHelper == null) return null;

  return RelatedFieldService(
    odooClient: odooClient,
    cacheStore: DriftRelatedRecordCacheStore(db: ref.watch(appDatabaseProvider)),
  );
});

/// Provider para obtener UN registro relacionado de cualquier modelo
///
/// Uso:
/// ```dart
/// final result = ref.watch(relatedFieldProvider((
///   model: 'hr.employee',
///   id: order.responsibleId,
///   fallbackName: order.responsibleName,
/// )));
///
/// result.when(
///   data: (r) => Text(r.displayName),
///   loading: () => Text('...'),
///   error: (e, s) => Text('Error'),
/// );
/// ```
final relatedFieldProvider =
    FutureProvider.family<
      RelatedFieldResult,
      ({String model, int? id, String? fallbackName})
    >((ref, params) async {
      final service = ref.watch(relatedFieldServiceProvider);
      if (service == null) {
        return RelatedFieldResult(
          id: params.id,
          fallbackName: params.fallbackName,
        );
      }
      return service.get(
        model: params.model,
        id: params.id,
        fallbackName: params.fallbackName,
      );
    });

/// Provider para obtener MÚLTIPLES registros en batch
///
/// Uso:
/// ```dart
/// final results = ref.watch(relatedFieldBatchProvider((
///   model: 'product.product',
///   ids: lines.map((l) => l.productId).whereType<int>().toList(),
///   fallbackNames: {for (var l in lines) if (l.productId != null) l.productId!: l.productName ?? ''},
/// )));
/// ```
final relatedFieldBatchProvider =
    FutureProvider.family<
      Map<int, RelatedFieldResult>,
      ({String model, List<int> ids, Map<int, String?>? fallbackNames})
    >((ref, params) async {
      final service = ref.watch(relatedFieldServiceProvider);
      if (service == null) {
        return {
          for (final id in params.ids)
            id: RelatedFieldResult(
              id: id,
              fallbackName: params.fallbackNames?[id],
            ),
        };
      }
      return service.getBatch(
        model: params.model,
        ids: params.ids,
        fallbackNames: params.fallbackNames,
      );
    });
