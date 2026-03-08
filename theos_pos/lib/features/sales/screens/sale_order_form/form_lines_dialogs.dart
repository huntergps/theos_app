import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/providers.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/providers/company_config_provider.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../providers/providers.dart';
import 'edit_dialogs.dart';

/// Mixin providing dialog actions for SaleOrderFormLines
///
/// Extracts product/section/note addition logic from the main widget.
mixin SaleOrderFormDialogsMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Whether the form is in edit mode
  bool get isDialogsEnabled;

  /// The order ID for this form
  int get dialogOrderId;

  // ============================================================================
  // ADD PRODUCT DIALOG
  // ============================================================================

  Future<void> showAddProductDialog(BuildContext context) async {
    if (!isDialogsEnabled) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const SelectProductDialog(),
    );

    if (result != null) {
      await addProductLine(result);
    }
  }

  Future<void> addProductLine(Map<String, dynamic> product) async {
    final productId = product['id'] as int;
    final rawName = product['display_name'] ?? product['name'] as String;
    // Extract default_code and clean name from [code] prefix
    final productCode = product['default_code'] as String?;
    final productName = _cleanProductNameForDialog(rawName);
    final listPrice = (product['list_price'] as num?)?.toDouble() ?? 0.0;
    final uomData = product['uom_id'];
    int? uomId;
    String? uomName;
    if (uomData is List && uomData.length >= 2) {
      uomId = uomData[0] as int;
      uomName = uomData[1] as String;
    }

    final taxNames = product['tax_names'] as String?;
    final taxPercent = (product['tax_percent'] as num?)?.toDouble() ?? 0.0;
    final taxIds = product['taxes_id'];
    String? taxIdsStr;
    if (taxIds is List && taxIds.isNotEmpty) {
      taxIdsStr = taxIds.whereType<int>().join(',');
    }

    const qty = 1.0;
    double priceUnit = listPrice;
    double discount = 0.0;
    bool priceCalculated = false;
    bool isUnitProduct = true; // Default to true (most products are unit-based)

    final state = ref.read(saleOrderFormProvider);

    // Lookup local product to get isUnitProduct and other local catalog data
    final localProduct = await productManager.readLocal(productId);

    if (localProduct != null) {
      isUnitProduct = localProduct.isUnitProduct;
    }

    if (state.pricelistId != null) {
      try {
        final calculator = ref.read(pricelistCalculatorProvider);

        final productTmplId = localProduct?.productTmplId ?? productId;

        final result = await calculator.calculatePrice(
          productId: productId,
          productTmplId: productTmplId,
          pricelistId: state.pricelistId!,
          quantity: qty,
          uomId: uomId,
          productUomId: localProduct?.uomId,
          listPrice: listPrice,
        );

        if (result.ruleId != null) {
          priceUnit = result.basePrice;
          discount = result.discount;
          priceCalculated = true;

          // Validate discount against company's max
          final maxDiscount = await getMaxDiscountPercentage(ref);
          if (discount > maxDiscount) {
            logger.w(
              '[SaleOrderFormLines]',
              'Pricelist discount $discount% exceeds max $maxDiscount% - clamping',
            );
            discount = maxDiscount;
          }
        }
      } catch (e) {
        logger.w('[SaleOrderFormLines]', 'Local price calc failed: $e');
      }
    }

    if (!priceCalculated) {
      final productRepo = ref.read(productRepositoryProvider);
      if (productRepo != null) {
        final onchangeResult = await productRepo.onchangeProduct(
          orderId: dialogOrderId,
          productId: productId,
          partnerId: state.partnerId,
          pricelistId: state.pricelistId,
          qty: qty,
        );

        if (onchangeResult != null && onchangeResult['price_unit'] != null) {
          priceUnit = (onchangeResult['price_unit'] as num).toDouble();
          discount = (onchangeResult['discount'] as num?)?.toDouble() ?? 0.0;

          // Validate discount against company's max
          final maxDiscount = await getMaxDiscountPercentage(ref);
          if (discount > maxDiscount) {
            logger.w(
              '[SaleOrderFormLines]',
              'Odoo discount $discount% exceeds max $maxDiscount% - clamping',
            );
            discount = maxDiscount;
          }
        }
      }
    }

    final calc = saleOrderLineCalculator.calculateLine(
      priceUnit: priceUnit,
      quantity: qty,
      discountPercent: discount,
      taxPercent: taxPercent,
    );

    final newLine = SaleOrderLine(
      id: -DateTime.now().millisecondsSinceEpoch,
      orderId: dialogOrderId,
      sequence: 0,
      productId: productId,
      productName: productName,
      productCode: productCode,
      name: productName,
      productUomQty: qty,
      productUomId: uomId,
      productUomName: uomName,
      priceUnit: priceUnit,
      discount: discount,
      priceSubtotal: calc.priceSubtotal,
      priceTax: calc.priceTax,
      priceTotal: calc.priceTotal,
      taxIds: taxIdsStr,
      taxNames: taxNames,
      isUnitProduct: isUnitProduct,
    );

    ref.read(saleOrderFormProvider.notifier).addLine(newLine);
  }

  // ============================================================================
  // ADD SECTION / NOTE
  // ============================================================================

  Future<void> addSection(BuildContext context) async {
    if (!isDialogsEnabled) return;

    final name = await _showTextInputDialog(
      context: context,
      title: 'Agregar seccion',
      label: 'Nombre de la seccion',
      placeholder: 'Ej: Productos principales',
    );
    if (name == null || name.isEmpty) return;

    _addInfoLine(LineDisplayType.lineSection, name);
  }

  Future<void> addNote(BuildContext context) async {
    if (!isDialogsEnabled) return;

    final note = await _showTextInputDialog(
      context: context,
      title: 'Agregar nota',
      label: 'Texto de la nota',
      placeholder: 'Ej: Entrega acordada para la proxima semana',
      multiline: true,
    );
    if (note == null || note.isEmpty) return;

    _addInfoLine(LineDisplayType.lineNote, note);
  }

  void _addInfoLine(LineDisplayType displayType, String name) {
    final newLine = SaleOrderLine(
      id: DateTime.now().millisecondsSinceEpoch * -1,
      lineUuid: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      orderId: dialogOrderId,
      sequence: 0,
      displayType: displayType,
      name: name,
      productUomQty: 0.0,
      priceUnit: 0.0,
      discount: 0.0,
      priceSubtotal: 0.0,
      priceTax: 0.0,
      priceTotal: 0.0,
    );

    ref.read(saleOrderFormProvider.notifier).addLine(newLine);
  }

  // ============================================================================
  // HELPER DIALOGS
  // ============================================================================

  Future<String?> _showTextInputDialog({
    required BuildContext context,
    required String title,
    required String label,
    String? placeholder,
    String? initialValue,
    bool multiline = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final spacing = ref.read(themedSpacingProvider);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            SizedBox(height: spacing.sm),
            TextBox(
              controller: controller,
              placeholder: placeholder,
              maxLines: multiline ? 3 : 1,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Cleans product name by removing [code] prefix
  String _cleanProductNameForDialog(String name) {
    final regex = RegExp(r'^\[.*?\]\s*');
    return name.replaceFirst(regex, '');
  }
}
