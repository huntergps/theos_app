import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/related_field_provider.dart';

// ============================================================================
// MANY2ONE WIDGET
// ============================================================================

/// Widget que muestra un campo Many2one de CUALQUIER modelo Odoo
///
/// Sigue el flujo:
/// 1. Busca en cache local
/// 2. Si no está y hay conexión, trae de Odoo
/// 3. Muestra fallback [id, name] si no hay conexión
///
/// Uso:
/// ```dart
/// // Para cualquier modelo
/// RelatedFieldText(
///   model: 'hr.employee',
///   id: order.responsibleId,
///   fallbackName: order.responsibleName,
/// )
///
/// // Con estilos
/// RelatedFieldText(
///   model: 'res.partner',
///   id: order.partnerId,
///   fallbackName: order.partnerName,
///   style: TextStyle(fontWeight: FontWeight.bold),
/// )
///
/// // Con builder personalizado
/// RelatedFieldText(
///   model: 'product.product',
///   id: line.productId,
///   fallbackName: line.productName,
///   builder: (name) => Chip(label: Text(name)),
/// )
/// ```
class RelatedFieldText extends ConsumerWidget {
  final String model;
  final int? id;
  final String? fallbackName;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final Widget Function(String displayName)? builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const RelatedFieldText({
    super.key,
    required this.model,
    required this.id,
    this.fallbackName,
    this.style,
    this.maxLines,
    this.overflow,
    this.builder,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id == null) {
      return _buildText(fallbackName ?? '-');
    }

    final asyncValue = ref.watch(
      relatedFieldProvider((model: model, id: id, fallbackName: fallbackName)),
    );

    return asyncValue.when(
      data: (result) => _buildText(result.displayName),
      loading: () => loadingWidget ?? _buildText(fallbackName ?? '...'),
      error: (e, s) => errorWidget ?? _buildText(fallbackName ?? 'Error'),
    );
  }

  Widget _buildText(String displayName) {
    if (builder != null) {
      return builder!(displayName);
    }

    return Text(
      displayName.isEmpty ? '-' : displayName,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

// ============================================================================
// MANY2MANY WIDGET
// ============================================================================

/// Widget que muestra múltiples campos relacionados (Many2many) de CUALQUIER modelo
///
/// Sigue el flujo para CADA registro:
/// 1. Busca en cache local
/// 2. Si no está y hay conexión, trae de Odoo
/// 3. Muestra fallback si no hay conexión
///
/// Uso:
/// ```dart
/// // Lista de impuestos
/// RelatedFieldList(
///   model: 'account.tax',
///   ids: line.taxIds,
///   fallbackNames: line.taxNames,
/// )
///
/// // Lista de journals permitidos
/// RelatedFieldList(
///   model: 'account.journal',
///   ids: config.allowedJournalIds,
/// )
///
/// // Con builder personalizado (como chips)
/// RelatedFieldList(
///   model: 'account.tax',
///   ids: line.taxIds,
///   itemBuilder: (name) => Chip(label: Text(name)),
/// )
/// ```
class RelatedFieldList extends ConsumerWidget {
  final String model;
  final List<int>? ids;
  final Map<int, String?>? fallbackNames;
  final TextStyle? style;
  final String separator;
  final Widget Function(String displayName)? itemBuilder;
  final Widget Function(List<Widget> items)? listBuilder;
  final Widget? emptyWidget;
  final Widget? loadingWidget;

  const RelatedFieldList({
    super.key,
    required this.model,
    required this.ids,
    this.fallbackNames,
    this.style,
    this.separator = ', ',
    this.itemBuilder,
    this.listBuilder,
    this.emptyWidget,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ids == null || ids!.isEmpty) {
      return emptyWidget ?? Text('-', style: style);
    }

    final asyncValue = ref.watch(
      relatedFieldBatchProvider((
        model: model,
        ids: ids!,
        fallbackNames: fallbackNames,
      )),
    );

    return asyncValue.when(
      data: (results) {
        final names = ids!.map((id) {
          final result = results[id];
          return result?.displayName ?? fallbackNames?[id] ?? 'ID: $id';
        }).toList();

        if (listBuilder != null) {
          final items = names.map((name) => _buildItem(name)).toList();
          return listBuilder!(items);
        }

        if (itemBuilder != null) {
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: names.map((name) => itemBuilder!(name)).toList(),
          );
        }

        return Text(names.join(separator), style: style);
      },
      loading: () {
        if (loadingWidget != null) return loadingWidget!;
        // Show fallbacks while loading
        if (fallbackNames != null && fallbackNames!.isNotEmpty) {
          final names = ids!.map((id) => fallbackNames![id] ?? '...').toList();
          return Text(names.join(separator), style: style);
        }
        return Text('...', style: style);
      },
      error: (e, s) {
        // Show fallbacks on error
        if (fallbackNames != null && fallbackNames!.isNotEmpty) {
          final names = ids!
              .map((id) => fallbackNames![id] ?? 'ID: $id')
              .toList();
          return Text(names.join(separator), style: style);
        }
        return Text('Error', style: style);
      },
    );
  }

  Widget _buildItem(String name) {
    if (itemBuilder != null) {
      return itemBuilder!(name);
    }
    return Text(name, style: style);
  }
}

/// Widget para mostrar Many2many como chips/badges
///
/// Uso:
/// ```dart
/// RelatedFieldChips(
///   model: 'account.tax',
///   ids: line.taxIds,
///   fallbackNames: {1: 'IVA 15%', 2: 'IVA 0%'},
/// )
/// ```
class RelatedFieldChips extends ConsumerWidget {
  final String model;
  final List<int>? ids;
  final Map<int, String?>? fallbackNames;
  final Color? chipColor;
  final TextStyle? textStyle;
  final Widget? emptyWidget;

  const RelatedFieldChips({
    super.key,
    required this.model,
    required this.ids,
    this.fallbackNames,
    this.chipColor,
    this.textStyle,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RelatedFieldList(
      model: model,
      ids: ids,
      fallbackNames: fallbackNames,
      emptyWidget: emptyWidget,
      itemBuilder: (name) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color:
              chipColor ??
              Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          name,
          style: textStyle ?? Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

// ============================================================================
// EXTENSION METHODS
// ============================================================================

/// Extension para usar campos relacionados directamente en widgets
extension RelatedFieldWidgetRef on WidgetRef {
  /// Obtiene el nombre de UN campo relacionado (Many2one) de forma reactiva
  ///
  /// ```dart
  /// // Para hr.employee
  /// final employeeName = ref.watchRelatedField(
  ///   model: 'hr.employee',
  ///   id: order.responsibleId,
  ///   fallbackName: order.responsibleName,
  /// );
  /// ```
  String watchRelatedField({
    required String model,
    required int? id,
    String? fallbackName,
  }) {
    if (id == null) return fallbackName ?? '-';

    final result = watch(
      relatedFieldProvider((model: model, id: id, fallbackName: fallbackName)),
    );

    return result.when(
      data: (r) => r.displayName,
      loading: () => fallbackName ?? '...',
      error: (e, s) => fallbackName ?? 'Error',
    );
  }

  /// Obtiene los nombres de MÚLTIPLES campos relacionados (Many2many) de forma reactiva
  ///
  /// ```dart
  /// // Para account.tax
  /// final taxNames = ref.watchRelatedFields(
  ///   model: 'account.tax',
  ///   ids: line.taxIds,
  ///   fallbackNames: {1: 'IVA 15%', 2: 'IVA 0%'},
  /// );

  /// ```
  List<String> watchRelatedFields({
    required String model,
    required List<int>? ids,
    Map<int, String?>? fallbackNames,
  }) {
    if (ids == null || ids.isEmpty) return [];

    final result = watch(
      relatedFieldBatchProvider((
        model: model,
        ids: ids,
        fallbackNames: fallbackNames,
      )),
    );

    return result.when(
      data: (results) => ids.map((id) {
        final r = results[id];
        return r?.displayName ?? fallbackNames?[id] ?? 'ID: $id';
      }).toList(),
      loading: () => ids.map((id) => fallbackNames?[id] ?? '...').toList(),
      error: (e, s) => ids.map((id) => fallbackNames?[id] ?? 'Error').toList(),
    );
  }

  /// Obtiene el resultado completo de un campo relacionado (con acceso a campos adicionales)
  ///
  /// ```dart
  /// final partnerResult = ref.watchRelatedFieldResult(
  ///   model: 'res.partner',
  ///   id: order.partnerId,
  ///   fallbackName: order.partnerName,
  /// );
  ///
  /// if (partnerResult.hasFullRecord) {

  /// }
  /// ```
  RelatedFieldResult? watchRelatedFieldResult({
    required String model,
    required int? id,
    String? fallbackName,
  }) {
    if (id == null) return null;

    final result = watch(
      relatedFieldProvider((model: model, id: id, fallbackName: fallbackName)),
    );

    return result.when(
      data: (r) => r,
      loading: () => RelatedFieldResult(id: id, fallbackName: fallbackName),
      error: (e, s) => RelatedFieldResult(id: id, fallbackName: fallbackName),
    );
  }
}
