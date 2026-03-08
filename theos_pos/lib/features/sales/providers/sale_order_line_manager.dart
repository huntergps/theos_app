import 'package:theos_pos_core/theos_pos_core.dart';
import 'sale_order_form_state.dart';

/// Mixin para gestion de lineas de orden de venta
///
/// Proporciona metodos para:
/// - Agregar lineas
/// - Actualizar lineas
/// - Eliminar lineas
/// - Consultar lineas
mixin SaleOrderLineManager {
  /// Estado actual del formulario - debe ser implementado por el notifier
  SaleOrderFormState get state;

  /// Metodo para actualizar estado - debe ser implementado por el notifier
  set state(SaleOrderFormState newState);

  /// Agregar una linea a la orden
  ///
  /// Para ordenes nuevas, la linea se agrega a [newLines].
  /// Para ordenes existentes, la linea tambien se agrega a [newLines]
  /// y sera creada en el servidor al guardar.
  void addLine(SaleOrderLine line) {
    // Generar ID temporal negativo para lineas nuevas
    final tempId = -(state.newLines.length + 1);
    final lineWithTempId = line.copyWith(
      id: tempId,
      orderId: state.order?.id ?? 0,
      sequence: (state.totalLinesCount + 1) * 10,
    );

    state = state.copyWith(
      newLines: [...state.newLines, lineWithTempId],
      hasChanges: true,
    );

    logger.d(
      '[SaleOrderLineManager]',
      'Linea agregada: ${lineWithTempId.productName} '
          '(Qty: ${lineWithTempId.productUomQty}, ID temporal: $tempId)',
    );
  }

  /// Actualizar una linea existente
  ///
  /// [line] - Linea actualizada con el mismo ID
  ///
  /// Para lineas en newLines: actualiza directamente en newLines
  /// Para todas las demas lineas (incluyendo las de ordenes offline con ID < 0
  /// que estan en state.lines): las agrega/actualiza en updatedLines
  void updateLine(SaleOrderLine line) {
    // Verificar si la linea esta en newLines (agregada en esta sesión de edición)
    final isInNewLines = state.newLines.any((l) => l.id == line.id);

    if (isInNewLines) {
      // Linea agregada en esta sesión - actualizar en newLines
      final newLinesList = state.newLines.map((l) {
        return l.id == line.id ? line : l;
      }).toList();

      state = state.copyWith(newLines: newLinesList, hasChanges: true);
      logger.i(
        '[SaleOrderLineManager]',
        'updateLine (newLines): ID=${line.id}, Qty=${line.productUomQty}, Price=${line.priceUnit}, Discount=${line.discount}%, Subtotal=${line.priceSubtotal}',
      );
    } else {
      // Linea existente (de state.lines) - actualizar en updatedLines
      // Esto incluye lineas de ordenes offline (ID < 0) cargadas desde la DB
      final existingIndex = state.updatedLines.indexWhere(
        (l) => l.id == line.id,
      );

      List<SaleOrderLine> newUpdatedLines;
      if (existingIndex >= 0) {
        newUpdatedLines = List<SaleOrderLine>.from(state.updatedLines);
        newUpdatedLines[existingIndex] = line;
      } else {
        newUpdatedLines = [...state.updatedLines, line];
      }

      state = state.copyWith(updatedLines: newUpdatedLines, hasChanges: true);
      logger.i(
        '[SaleOrderLineManager]',
        'updateLine (updatedLines): ID=${line.id}, Qty=${line.productUomQty}, Price=${line.priceUnit}, Discount=${line.discount}%, Subtotal=${line.priceSubtotal}',
      );
    }
  }

  /// Eliminar una linea
  ///
  /// [lineId] - ID de la linea a eliminar
  ///
  /// Para lineas en newLines: las remueve directamente
  /// Para lineas en state.lines (existentes o offline): las marca para eliminación
  void deleteLine(int lineId) {
    // Verificar si la linea esta en newLines (agregada en esta sesión de edición)
    final isInNewLines = state.newLines.any((l) => l.id == lineId);

    if (isInNewLines) {
      // Linea nueva (agregada en esta sesión) - simplemente removerla de newLines
      state = state.copyWith(
        newLines: state.newLines.where((l) => l.id != lineId).toList(),
        hasChanges: true,
      );
      logger.d('[SaleOrderLineManager]', 'Linea nueva eliminada de newLines: ID=$lineId');
    } else {
      // Linea existente (de state.lines, puede tener ID < 0 si es offline)
      // Marcarla para eliminacion
      if (!state.deletedLineIds.contains(lineId)) {
        state = state.copyWith(
          deletedLineIds: [...state.deletedLineIds, lineId],
          // Tambien remover de updatedLines si estaba ahi
          updatedLines:
              state.updatedLines.where((l) => l.id != lineId).toList(),
          hasChanges: true,
        );
        logger.d('[SaleOrderLineManager]', 'Linea marcada para eliminacion: ID=$lineId');
      }
    }
  }

  /// Obtener linea por ID (busca en todas las listas)
  ///
  /// Para IDs negativos (lineas nuevas/offline):
  /// 1. Busca en newLines (lineas agregadas en esta sesión)
  /// 2. Busca en updatedLines (lineas modificadas)
  /// 3. Busca en lines (lineas cargadas de la base de datos local)
  ///
  /// Para IDs positivos (lineas existentes de Odoo):
  /// 1. Busca en updatedLines primero
  /// 2. Busca en lines originales
  SaleOrderLine? getLine(int lineId) {
    logger.d(
      '[SaleOrderLineManager]',
      'getLine($lineId): newLines=${state.newLines.length}, updatedLines=${state.updatedLines.length}, lines=${state.lines.length}',
    );

    // Buscar en lineas nuevas (agregadas en esta sesión)
    try {
      final newLine = state.newLines.firstWhere((l) => l.id == lineId);
      logger.d('[SaleOrderLineManager]', 'Found in newLines: ${newLine.productName}');
      return newLine;
    } catch (_) {
      // No encontrado en newLines
    }

    // Buscar en lineas actualizadas
    try {
      final updated = state.updatedLines.firstWhere((l) => l.id == lineId);
      logger.d('[SaleOrderLineManager]', 'Found in updatedLines: ${updated.productName}');
      return updated;
    } catch (_) {
      // No encontrado en updatedLines
    }

    // Buscar en lineas originales (incluye lineas de ordenes offline)
    try {
      final original = state.lines.firstWhere((l) => l.id == lineId);
      logger.d('[SaleOrderLineManager]', 'Found in lines: ${original.productName}');
      return original;
    } catch (_) {
      logger.w('[SaleOrderLineManager]', 'Line $lineId not found in any list');
      return null;
    }
  }

  /// Obtener todas las lineas visibles (no eliminadas)
  List<SaleOrderLine> getVisibleLines() {
    final result = <SaleOrderLine>[];

    // Lineas existentes no eliminadas (con actualizaciones aplicadas)
    for (final line in state.lines) {
      if (state.deletedLineIds.contains(line.id)) continue;

      final updated = state.updatedLines.firstWhere(
        (l) => l.id == line.id,
        orElse: () => line,
      );

      result.add(updated);
    }

    // Agregar lineas nuevas
    result.addAll(state.newLines);

    // Ordenar por secuencia
    result.sort((a, b) => a.sequence.compareTo(b.sequence));

    return result;
  }

  /// Obtener lineas de tipo producto solamente
  List<SaleOrderLine> getProductLines() {
    return getVisibleLines().where((l) => l.isProductLine).toList();
  }

  /// Obtener conteo de lineas de producto
  int get productLinesCount => getProductLines().length;

  /// Verificar si existe una linea con el producto dado
  bool hasProductLine(int productId) {
    return getVisibleLines().any((l) => l.productId == productId);
  }

  /// Obtener linea por producto ID
  SaleOrderLine? getLineByProduct(int productId) {
    try {
      return getVisibleLines().firstWhere((l) => l.productId == productId);
    } catch (_) {
      return null;
    }
  }
}
