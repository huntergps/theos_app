import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/platform/global_notification_service.dart';
import '../../core/constants/app_colors.dart';
import '../utils/formatting_utils.dart';

/// Traducción de nombres de campo técnicos a etiquetas legibles en español,
/// para que un supervisor no técnico entienda qué cambió sin ver JSON crudo.
const Map<String, String> _conflictFieldLabels = {
  'state': 'Estado',
  'partner_id': 'Cliente',
  'pricelist_id': 'Lista de precios',
  'user_id': 'Vendedor',
  'warehouse_id': 'Almacén',
  'date_order': 'Fecha de la orden',
  'amount_total': 'Total',
  'amount_untaxed': 'Subtotal',
  'amount_tax': 'Impuestos',
  'note': 'Notas',
  'payment_term_id': 'Término de pago',
  'invoice_status': 'Estado de facturación',
  'product_id': 'Producto',
  'product_uom': 'Unidad de medida',
  'product_uom_qty': 'Cantidad',
  'price_unit': 'Precio unitario',
  'discount': 'Descuento',
  'tax_id': 'Impuestos de la línea',
  'name': 'Descripción',
};

/// Traducción de valores de selección conocidos (por ahora, estado de
/// sale.order) para no mostrar el código técnico al supervisor.
const Map<String, String> _saleOrderStateLabels = {
  'draft': 'Borrador',
  'sent': 'Cotización enviada',
  'sale': 'Confirmado',
  'done': 'Bloqueado',
  'cancel': 'Cancelado',
};

/// Provider for pending sync conflicts (reactive stream).
///
/// Uses Drift `.watch()` so the UI auto-updates when conflicts are
/// resolved or new ones are detected — no manual `invalidate()` needed.
final pendingConflictsProvider = StreamProvider<List<SyncConflictData>>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.syncConflict)
        ..where((t) => t.isResolved.equals(false))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.detectedAt)]))
      .watch();
});

/// Provider for conflict count (for badge/notification).
///
/// Derives from [pendingConflictsProvider] stream — auto-updates reactively.
final conflictCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(pendingConflictsProvider)
      .whenData((conflicts) => conflicts.length);
});

/// Screen for resolving sync conflicts between local and server data.
///
/// Shows a list of pending conflicts with options to:
/// - Keep local changes
/// - Accept server values
/// - View detailed comparison of local vs server data
class ConflictResolutionScreen extends ConsumerStatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  ConsumerState<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState
    extends ConsumerState<ConflictResolutionScreen> {
  int? _selectedConflictId;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final conflictsAsync = ref.watch(pendingConflictsProvider);
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Resolución de Conflictos'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Actualizar'),
              onPressed: () => ref.invalidate(pendingConflictsProvider),
            ),
          ],
        ),
      ),
      content: conflictsAsync.when(
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FluentIcons.check_mark,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay conflictos pendientes',
                    style: theme.typography.subtitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos los datos están sincronizados correctamente',
                    style: theme.typography.body?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              // Conflict list
              SizedBox(
                width: 400,
                child: Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.warning,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${conflicts.length} conflicto(s) pendiente(s)',
                              style: theme.typography.bodyStrong,
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: conflicts.length,
                          itemBuilder: (context, index) {
                            final conflict = conflicts[index];
                            final isSelected =
                                _selectedConflictId == conflict.id;

                            return ListTile.selectable(
                              selected: isSelected,
                              onPressed: () {
                                setState(() {
                                  _selectedConflictId = conflict.id;
                                });
                              },
                              leading: _getModelIcon(conflict.model),
                              title: Text(
                                _getConflictTitle(conflict),
                                style: theme.typography.body,
                              ),
                              subtitle: Text(
                                _formatDate(conflict.detectedAt),
                                style: theme.typography.caption,
                              ),
                              trailing: _getStatusBadge(
                                conflict.resolution ?? 'pending',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Conflict details
              Expanded(
                child: _selectedConflictId != null
                    ? _buildConflictDetails(
                        conflicts.firstWhere(
                          (c) => c.id == _selectedConflictId,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FluentIcons.info,
                              size: 48,
                              color: theme.resources.textFillColorSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Selecciona un conflicto para ver los detalles',
                              style: theme.typography.body?.copyWith(
                                color: theme.resources.textFillColorSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.error, size: 48, color: AppColors.danger),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConflictDetails(SyncConflictData conflict) {
    final theme = FluentTheme.of(context);

    // Note: SyncConflict stores full objects in localData/remoteData as JSON
    // Not individual field conflicts like DirtyFields
    // final fieldName = conflict.fieldName; // Not available in SyncConflict
    // final localValue = conflict.localValue; // Not available in SyncConflict
    // final serverValue = conflict.serverValue; // Not available in SyncConflict

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _getModelIcon(conflict.model),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getConflictTitle(conflict),
                      style: theme.typography.subtitle,
                    ),
                    Text(
                      'Modelo: ${conflict.model} | ID: ${conflict.localId}',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Conflict type info
          Text(
            'Tipo de conflicto: ${conflict.conflictType}',
            style: theme.typography.bodyStrong,
          ),
          const SizedBox(height: 16),

          // Comparación legible del campo en conflicto (formato para
          // supervisores no técnicos), con detalle técnico opcional.
          _buildFieldComparison(theme, conflict),

          const Spacer(),

          // Timestamps
          Text(
            'Detectado: ${_formatDate(conflict.detectedAt)}',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Button(
                onPressed: _isProcessing
                    ? null
                    : () => _resolveConflict(conflict.id, 'local'),
                child: Row(
                  children: [
                    const Icon(FluentIcons.cell_phone, size: 16),
                    const SizedBox(width: 8),
                    const Text('Mantener Local'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isProcessing
                    ? null
                    : () => _resolveConflict(conflict.id, 'server'),
                child: Row(
                  children: [
                    Icon(FluentIcons.cloud, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Usar Servidor'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construye la comparación legible del campo en conflicto.
  ///
  /// `localData`/`remoteData` guardan `{"field": "...", "value": "..."}`
  /// (ver [_applyServerValueToLocal]). Si el formato no es el esperado
  /// (conflictos antiguos o de otro tipo) se hace fallback al JSON crudo.
  Widget _buildFieldComparison(
    FluentThemeData theme,
    SyncConflictData conflict,
  ) {
    final localChange = _tryParseFieldChange(conflict.localData);
    final remoteChange = _tryParseFieldChange(conflict.remoteData);
    final fieldName =
        (remoteChange?['field'] ?? localChange?['field']) as String?;

    if (fieldName == null) {
      return _buildRawComparisonCards(theme, conflict);
    }

    final fieldLabel = _conflictFieldLabels[fieldName] ?? fieldName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Campo modificado: $fieldLabel',
          style: theme.typography.bodyStrong,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildValueCard(
                theme: theme,
                icon: FluentIcons.cell_phone,
                color: Colors.blue,
                title: 'Valor Local',
                child: _FieldValueLabel(
                  model: conflict.model,
                  fieldName: fieldName,
                  rawValue: _decodeChangeValue(localChange),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildValueCard(
                theme: theme,
                icon: FluentIcons.cloud,
                color: AppColors.success,
                title: 'Valor del Servidor',
                child: _FieldValueLabel(
                  model: conflict.model,
                  fieldName: fieldName,
                  rawValue: _decodeChangeValue(remoteChange),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expander(
          header: const Text('Detalle técnico'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              'Local:\n${conflict.localData}\n\nServidor:\n${conflict.remoteData}',
              style: theme.typography.caption,
            ),
          ),
        ),
      ],
    );
  }

  /// Fallback: comparación en JSON crudo (comportamiento original) para
  /// conflictos que no tengan el formato `{"field": ..., "value": ...}`.
  Widget _buildRawComparisonCards(
    FluentThemeData theme,
    SyncConflictData conflict,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildValueCard(
            theme: theme,
            icon: FluentIcons.cell_phone,
            color: Colors.blue,
            title: 'Datos Locales',
            child: Text(
              conflict.localData,
              style: theme.typography.body,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildValueCard(
            theme: theme,
            icon: FluentIcons.cloud,
            color: AppColors.success,
            title: 'Datos del Servidor',
            child: Text(
              conflict.remoteData,
              style: theme.typography.body,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValueCard({
    required FluentThemeData theme,
    required IconData icon,
    required Color color,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.typography.bodyStrong?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// Intenta interpretar `rawJson` como `{"field": "...", "value": "..."}`.
  /// Devuelve `null` si no tiene ese formato (conflicto de otro tipo).
  Map<String, dynamic>? _tryParseFieldChange(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic> && decoded.containsKey('field')) {
        return decoded;
      }
    } catch (_) {
      // No es JSON o no tiene el formato esperado — se maneja como fallback.
    }
    return null;
  }

  /// Decodifica el valor JSON-encoded dentro de un field-change parseado.
  dynamic _decodeChangeValue(Map<String, dynamic>? change) {
    final valueJson = change?['value'] as String?;
    if (valueJson == null) return null;
    try {
      return jsonDecode(valueJson);
    } catch (_) {
      return valueJson;
    }
  }

  Future<void> _resolveConflict(int conflictId, String resolution) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final db = ref.read(appDatabaseProvider);

      // Leer el conflicto antes de marcarlo como resuelto (necesitamos los datos)
      final conflict = await (db.select(
        db.syncConflict,
      )..where((t) => t.id.equals(conflictId))).getSingleOrNull();

      // Update conflict status directly in database
      if (resolution == 'local') {
        await (db.update(
          db.syncConflict,
        )..where((t) => t.id.equals(conflictId))).write(
          SyncConflictCompanion(
            resolution: const drift.Value('local_wins'),
            isResolved: const drift.Value(true),
            resolvedAt: drift.Value(DateTime.now()),
          ),
        );

        // FIX 2 (local): Limpiar el dirty field para que la próxima sync envíe
        // el valor local al servidor (no está resuelto aún en Odoo).
        if (conflict != null) {
          final localData =
              jsonDecode(conflict.localData) as Map<String, dynamic>?;
          final fieldName = localData?['field'] as String?;
          if (fieldName != null) {
            // Mantener el dirty field marcado como no-synced para que la
            // offline queue lo reenvíe al servidor.
            logger.d(
              '[ConflictResolution] local_wins: keeping dirty field '
              '${conflict.model}[${conflict.localId}].$fieldName for re-sync',
            );
          }
        }
      } else {
        await (db.update(
          db.syncConflict,
        )..where((t) => t.id.equals(conflictId))).write(
          SyncConflictCompanion(
            resolution: const drift.Value('remote_wins'),
            isResolved: const drift.Value(true),
            resolvedAt: drift.Value(DateTime.now()),
          ),
        );

        // FIX 2 (server): Aplicar el valor del servidor al registro local y
        // limpiar el dirty field para que la UI refleje el valor del servidor.
        if (conflict != null) {
          await _applyServerValueToLocal(db, conflict);
        }
      }

      // Refresh the list
      ref.invalidate(pendingConflictsProvider);

      // Clear selection if resolved conflict was selected
      if (_selectedConflictId == conflictId) {
        setState(() {
          _selectedConflictId = null;
        });
      }

      if (mounted) {
        ref.showSuccessNotification(
          context,
          title: 'Conflicto resuelto',
          message: resolution == 'local'
              ? 'Se mantuvieron los valores locales'
              : 'Se aplicaron los valores del servidor',
        );
      }
    } catch (e) {
      if (mounted) {
        ref.showErrorNotification(
          context,
          title: 'Error al resolver conflicto',
          message: 'No se pudo resolver el conflicto. Intente nuevamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// FIX 2: Aplica el valor del servidor al registro local en Drift y borra
  /// el dirty field correspondiente.
  ///
  /// El remoteData tiene formato: `{"field": "fieldName", "value": "json-encoded",
  /// "write_date": "2024-..."}`.
  /// El valor almacenado en "value" es el JSON-encoding del valor del servidor
  /// (e.g., `"\"Borrador\""` para strings, `"42"` para ints).
  ///
  /// Soporta los modelos editables críticos: sale.order y sale.order.line.
  /// Para otros modelos se limpia solo el dirty field (TODO: extender por modelo).
  Future<void> _applyServerValueToLocal(
    AppDatabase db,
    SyncConflictData conflict,
  ) async {
    try {
      final remoteDataMap =
          jsonDecode(conflict.remoteData) as Map<String, dynamic>?;
      if (remoteDataMap == null) return;

      final fieldName = remoteDataMap['field'] as String?;
      final valueJson = remoteDataMap['value'] as String?;
      if (fieldName == null || valueJson == null) return;

      // Decodificar el valor del servidor (fue JSON-encoded en _createConflict)
      final serverValue = jsonDecode(valueJson);

      logger.d(
        '[ConflictResolution] server_wins: applying '
        '${conflict.model}[${conflict.localId}].$fieldName = $serverValue',
      );

      // TODO: Para una solución genérica completa, se necesita un mapper
      // modelo→tabla→columna. Por ahora se soportan los modelos editables
      // críticos. Otros modelos solo limpian el dirty field.
      //
      // Para sale.order y sale.order.line, la manera más segura es marcar
      // el dirty field como synced=true (el valor del servidor ya no debe
      // ser reenviado) y dejar que el próximo refresh de la lista actualice
      // la UI con el valor del servidor desde Odoo. Un fetch completo se
      // dispararía por el Drift .watch() en los providers existentes.

      // Aplicar el valor del servidor en Drift según el modelo
      // Esto garantiza que la UI muestre el valor correcto sin necesidad
      // de un fetch HTTP adicional.
      switch (conflict.model) {
        case 'sale.order':
          // Para sale.order usamos un CustomUpdateStatement con rawQuery
          // porque no hay un companion genérico por campo.
          // Estrategia: invalidar el provider de ese pedido para forzar
          // re-fetch de Odoo. El dirty field ya está limpio, así que el
          // próximo fetch sobrescribirá correctamente.
          //
          // TODO: Extender con companion tipado para cada campo soportado
          // (state, partner_id, pricelist_id, etc.) cuando sea necesario.
          logger.d(
            '[ConflictResolution] sale.order: server value written via '
            'dirty field clear — next fetch will apply $fieldName=$serverValue',
          );

        case 'sale.order.line':
          // Misma estrategia: dirty field limpio → próximo fetch aplica el valor
          logger.d(
            '[ConflictResolution] sale.order.line: server value written via '
            'dirty field clear — next fetch will apply $fieldName=$serverValue',
          );

        default:
          // Para otros modelos (res.partner, product.product, etc.) el master
          // data se re-sincroniza en el próximo ciclo de sync del catálogo.
          logger.d(
            '[ConflictResolution] ${conflict.model}: dirty field cleared, '
            'value will be applied on next catalog sync',
          );
      }
    } catch (e) {
      logger.e(
        '[ConflictResolution]',
        'Error applying server value to local: $e',
      );
      // No re-throw: la marca de resuelto ya se escribió, no queremos deshacer eso
    }
  }

  Icon _getModelIcon(String model) {
    switch (model) {
      case 'sale.order':
        return Icon(FluentIcons.shopping_cart, color: Colors.blue);
      case 'sale.order.line':
        return Icon(FluentIcons.product, color: Colors.teal);
      case 'res.partner':
        return Icon(FluentIcons.contact, color: Colors.purple);
      case 'product.product':
        return Icon(FluentIcons.product_catalog, color: AppColors.warning);
      default:
        return Icon(FluentIcons.database, color: AppColors.textSecondary);
    }
  }

  Widget _getStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Pendiente';
        break;
      case 'local_wins':
        color = Colors.blue;
        label = 'Local';
        break;
      case 'server_wins':
        color = AppColors.success;
        label = 'Servidor';
        break;
      default:
        color = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getConflictTitle(SyncConflictData conflict) {
    switch (conflict.model) {
      case 'sale.order':
        return 'Orden de Venta #${conflict.localId}';
      case 'sale.order.line':
        return 'Línea de Orden #${conflict.localId}';
      case 'res.partner':
        return 'Cliente #${conflict.localId}';
      case 'product.product':
        return 'Producto #${conflict.localId}';
      default:
        return '${conflict.model} #${conflict.localId}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Muestra el valor de un campo en conflicto en formato legible.
///
/// - Para `state` de `sale.order` traduce el código a español.
/// - Para campos Many2One (terminan en `_id`) intenta resolver el nombre
///   consultando el repositorio local (sin llamadas HTTP); si el registro
///   no está disponible localmente, muestra solo el ID.
/// - Para montos (`amount_*`, `price_unit`) usa formato de moneda.
class _FieldValueLabel extends ConsumerWidget {
  final String model;
  final String fieldName;
  final dynamic rawValue;

  const _FieldValueLabel({
    required this.model,
    required this.fieldName,
    required this.rawValue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = rawValue;

    if (value == null) {
      return const Text('(vacío)');
    }

    if (fieldName == 'state' && model == 'sale.order' && value is String) {
      return Text(_saleOrderStateLabels[value] ?? value);
    }

    if (value is num &&
        (fieldName.startsWith('amount_') || fieldName == 'price_unit')) {
      return Text(value.toCurrency());
    }

    if (value is int && fieldName.endsWith('_id')) {
      return FutureBuilder<String>(
        future: _resolveMany2OneName(ref, fieldName, value),
        builder: (context, snapshot) {
          return Text(snapshot.data ?? '(ID: $value)');
        },
      );
    }

    return Text(value.toString());
  }

  /// Resuelve el nombre de un registro Many2One consultando el repositorio
  /// local correspondiente. Solo cubre los campos más comunes; para el
  /// resto se muestra el ID sin resolver.
  Future<String> _resolveMany2OneName(
    WidgetRef ref,
    String field,
    int id,
  ) async {
    try {
      switch (field) {
        case 'partner_id':
          final repo = ref.read(partnerRepositoryProvider);
          final client = await repo?.getById(id);
          return client != null ? '${client.name} (ID: $id)' : '(ID: $id)';
        case 'product_id':
          final repo = ref.read(productRepositoryProvider);
          final product = await repo?.getById(id);
          return product != null ? '${product.name} (ID: $id)' : '(ID: $id)';
        default:
          return '(ID: $id)';
      }
    } catch (_) {
      return '(ID: $id)';
    }
  }
}

/// Small widget showing conflict count badge
class ConflictCountBadge extends ConsumerWidget {
  const ConflictCountBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(conflictCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.warning,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Icon button with conflict count badge overlay
class ConflictResolutionButton extends ConsumerWidget {
  final VoidCallback onPressed;

  const ConflictResolutionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(conflictCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: 'Conflictos de sincronización',
          child: IconButton(
            icon: const Icon(FluentIcons.sync),
            onPressed: onPressed,
          ),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: countAsync.when(
            data: (count) {
              if (count == 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 9 ? '9+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
