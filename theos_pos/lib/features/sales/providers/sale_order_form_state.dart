import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/providers/base_feature_state.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

part 'sale_order_form_state.freezed.dart';

/// Detalle de un conflicto de campo entre valor local y servidor
class ConflictDetail {
  final String fieldName;
  final dynamic localValue;
  final dynamic serverValue;
  final String? serverUserName; // Usuario que hizo el cambio en el servidor

  const ConflictDetail({
    required this.fieldName,
    required this.localValue,
    required this.serverValue,
    this.serverUserName,
  });
}

/// Estado unificado para vista y edición de orden de venta
///
/// Maneja ambos modos (vista/edición) en un solo provider para:
/// - Evitar sincronización entre providers
/// - Transiciones instantáneas entre modos
/// - Datos siempre consistentes
///
/// Utiliza Freezed para generar copyWith, ==, hashCode automaticamente.
/// Implements [BaseFeatureState] for standardized loading/error handling.
@freezed
abstract class SaleOrderFormState
    with _$SaleOrderFormState
    implements BaseFeatureState {
  const SaleOrderFormState._();

  const factory SaleOrderFormState({
    // ---- Estado de modo ----
    /// Si es true, está en modo edición. Si es false, modo vista.
    @Default(false) bool isEditing,

    // ---- Estado de carga/guardado ----
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    @Default(false) bool isLoadingSelectionData,

    // ---- Orden actual (null si es nueva orden) ----
    SaleOrder? order,

    // ---- Lineas de la orden ----
    @Default([]) List<SaleOrderLine> lines,

    // ---- Campos del formulario (solo relevantes en modo edición) ----
    int? partnerId,
    String? partnerName,
    String? partnerVat,
    String? partnerStreet,
    String? partnerPhone,
    String? partnerEmail,
    String? partnerAvatar,
    int? paymentTermId,
    String? paymentTermName,

    /// True if payment term is cash/immediate payment
    @Default(true) bool isCash,

    /// True if payment term is credit (has payment days > 0)
    @Default(false) bool isCredit,

    int? pricelistId,
    String? pricelistName,
    int? warehouseId,
    String? warehouseName,
    int? userId,
    String? userName,
    DateTime? dateOrder,
    DateTime? validityDate,
    DateTime? commitmentDate,
    String? clientOrderRef,
    String? note,

    // ---- Campos de consumidor final (l10n_ec_sale_base) ----
    /// Indica si el partner es consumidor final (RUC 9999999999999)
    @Default(false) bool isFinalConsumer,

    /// Nombre del cliente final (obligatorio si isFinalConsumer es true)
    String? endCustomerName,

    /// Teléfono del cliente final
    String? endCustomerPhone,

    /// Email del cliente final
    String? endCustomerEmail,

    // ---- Campos de facturación postfechada (l10n_ec_sale_base) ----
    /// Indica si se emitirá factura en fecha posterior
    @Default(false) bool emitirFacturaFechaPosterior,

    /// Fecha en la que se emitirá la factura
    DateTime? fechaFacturar,

    /// Días máximos permitidos para facturación postfechada (del partner)
    @Default(7) int diasMaxFacturaPosterior,

    // ---- Campos de referidor (l10n_ec_sale_base) ----
    /// ID del referidor
    int? referrerId,

    /// Nombre del referidor
    String? referrerName,

    // ---- Campos de tipo/canal cliente (l10n_ec_sale_base) ----
    /// Tipo de cliente (consumo, corporativo, profesional, etc.)
    String? tipoCliente,

    /// Canal de comunicación (local, email, whatsapp, etc.)
    String? canalCliente,

    // ---- Configuraciones de la empresa (l10n_ec_sale_base) ----
    /// Si la empresa requiere datos de consumidor final (nombre, tel, email)
    @Default(false) bool companyRequiresEndCustomerData,

    /// Si la empresa requiere referidor en ventas
    @Default(false) bool companyRequiresReferrer,

    /// Si la empresa requiere tipo y canal de cliente
    @Default(false) bool companyRequiresTipoCanalCliente,

    /// Límite de facturación para consumidor final (SRI Ecuador)
    @Default(0.0) double saleCustomerInvoiceLimitSri,

    // ---- Datos adicionales del partner ----
    @Default([]) List<int> partnerPaymentTermIds,

    /// ID del referidor por defecto del partner
    int? partnerReferrerId,

    /// Nombre del referidor por defecto del partner
    String? partnerReferrerName,

    /// Si el partner tiene facturación postfechada habilitada
    @Default(false) bool partnerEmitirFacturaFechaPosterior,

    /// Días máx factura posterior del partner
    @Default(7) int partnerDiasMaxFacturaPosterior,

    // ---- Datos de seleccion cacheados (listas desplegables) ----
    @Default([]) List<Map<String, dynamic>> paymentTerms,
    @Default([]) List<Map<String, dynamic>> pricelists,
    @Default([]) List<Map<String, dynamic>> warehouses,
    @Default([]) List<Map<String, dynamic>> salespeople,

    // ---- Estado de error ----
    String? errorMessage,

    // ---- Rastreo de cambios (solo relevante en modo edición) ----
    @Default(false) bool hasChanges,
    @Default({}) Map<String, dynamic> changedFields,

    // ---- Lineas modificadas (para sincronizacion) ----
    @Default([]) List<int> deletedLineIds,
    @Default([]) List<SaleOrderLine> newLines,
    @Default([]) List<SaleOrderLine> updatedLines,

    // ---- Last sync timestamp ----
    DateTime? lastSyncAt,

    // ---- Version counter for forcing UI rebuilds on WebSocket updates ----
    /// Incrementado cada vez que llega una actualización WebSocket de líneas.
    /// Esto fuerza a los providers que observan este valor a reconstruirse.
    @Default(0) int linesVersion,

    // ---- Conflict resolution state ----
    /// Indica si hay un conflicto detectado con el servidor
    @Default(false) bool hasConflict,

    /// Detalles de los conflictos por campo
    Map<String, ConflictDetail>? conflicts,

    /// Mensaje de conflicto para el usuario
    String? conflictMessage,

    // ---- Credit control state ----
    /// Indica si la verificación de crédito fue omitida (aprobación obtenida)
    @Default(false) bool creditCheckBypassed,

    /// Mensaje de advertencia de crédito (cuando hay warning pero se permite)
    String? creditWarningMessage,

    // ---- Server update pending (Phase 3 - Step 2) ----
    /// True when a stream update arrived while in edit mode.
    /// The user sees a subtle indicator and can choose to apply the update.
    @Default(false) bool serverUpdatePending,

    /// The pending server order (stored until user applies or exits edit mode)
    SaleOrder? pendingServerOrder,

    /// The pending server lines (stored until user applies or exits edit mode)
    @Default(null) List<SaleOrderLine>? pendingServerLines,
  }) = _SaleOrderFormState;

  /// Backwards compatibility alias for errorMessage
  String? get error => errorMessage;

  @override
  bool get hasError => errorMessage != null;

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIFIED GETTERS - Prefer local edits, fall back to order values
  // These getters provide a single source of truth for reading field values.
  // When editing: returns local edit value if set, otherwise order value
  // When viewing: returns order value directly
  // ═══════════════════════════════════════════════════════════════════════════

  /// Effective partner ID (edit value > order value)
  int? get effectivePartnerId => partnerId ?? order?.partnerId;

  /// Effective partner name (edit value > order value)
  String? get effectivePartnerName => partnerName ?? order?.partnerName;

  /// Effective partner VAT (edit value > order value)
  String? get effectivePartnerVat => partnerVat ?? order?.partnerVat;

  /// Effective partner street (edit value > order value)
  String? get effectivePartnerStreet => partnerStreet ?? order?.partnerStreet;

  /// Effective partner phone (edit value > order value)
  String? get effectivePartnerPhone => partnerPhone ?? order?.partnerPhone;

  /// Effective partner email (edit value > order value)
  String? get effectivePartnerEmail => partnerEmail ?? order?.partnerEmail;

  /// Effective partner avatar (edit value > order value)
  String? get effectivePartnerAvatar => partnerAvatar ?? order?.partnerAvatar;

  /// Effective payment term ID (edit value > order value)
  int? get effectivePaymentTermId => paymentTermId ?? order?.paymentTermId;

  /// Effective payment term name (edit value > order value)
  String? get effectivePaymentTermName =>
      paymentTermName ?? order?.paymentTermName;

  /// Effective pricelist ID (edit value > order value)
  int? get effectivePricelistId => pricelistId ?? order?.pricelistId;

  /// Effective pricelist name (edit value > order value)
  String? get effectivePricelistName => pricelistName ?? order?.pricelistName;

  /// Effective warehouse ID (edit value > order value)
  int? get effectiveWarehouseId => warehouseId ?? order?.warehouseId;

  /// Effective warehouse name (edit value > order value)
  String? get effectiveWarehouseName => warehouseName ?? order?.warehouseName;

  /// Effective user/salesperson ID (edit value > order value)
  int? get effectiveUserId => userId ?? order?.userId;

  /// Effective user/salesperson name (edit value > order value)
  String? get effectiveUserName => userName ?? order?.userName;

  /// Effective order date (edit value > order value)
  DateTime? get effectiveDateOrder => dateOrder ?? order?.dateOrder;

  /// Effective validity date (edit value > order value)
  DateTime? get effectiveValidityDate => validityDate ?? order?.validityDate;

  /// Effective commitment date (edit value > order value)
  DateTime? get effectiveCommitmentDate =>
      commitmentDate ?? order?.commitmentDate;

  /// Effective client order reference (edit value > order value)
  String? get effectiveClientOrderRef => clientOrderRef ?? order?.clientOrderRef;

  /// Effective note (edit value > order value)
  String? get effectiveNote => note ?? order?.note;

  /// Effective final consumer flag
  bool get effectiveIsFinalConsumer =>
      isEditing ? isFinalConsumer : (order?.isFinalConsumer ?? false);

  /// Effective end customer name
  String? get effectiveEndCustomerName =>
      endCustomerName ?? order?.endCustomerName;

  /// Effective end customer phone
  String? get effectiveEndCustomerPhone =>
      endCustomerPhone ?? order?.endCustomerPhone;

  /// Effective end customer email
  String? get effectiveEndCustomerEmail =>
      endCustomerEmail ?? order?.endCustomerEmail;

  /// Effective cash payment flag
  bool get effectiveIsCash => isEditing ? isCash : (order?.isCash ?? true);

  /// Effective credit payment flag
  bool get effectiveIsCredit =>
      isEditing ? isCredit : (order?.isCredit ?? false);

  /// Effective referrer ID
  int? get effectiveReferrerId => referrerId ?? order?.referrerId;

  /// Effective referrer name
  String? get effectiveReferrerName => referrerName ?? order?.referrerName;

  // ═══════════════════════════════════════════════════════════════════════════
  // ORDER TOTALS - Derived from order or calculated from lines
  // ═══════════════════════════════════════════════════════════════════════════

  /// Amount untaxed from order (or calculated)
  double get amountUntaxed => order?.amountUntaxed ?? calculatedSubtotal;

  /// Amount tax from order
  double get amountTax => order?.amountTax ?? 0.0;

  /// Amount total from order
  double get amountTotal => order?.amountTotal ?? calculatedSubtotal;

  /// Order state
  String get orderState => order?.state.name ?? 'draft';

  /// Order name/number
  String get orderName => order?.name ?? 'Nuevo';

  /// Whether order can be edited (draft state)
  bool get canEdit => order?.canEdit ?? true;

  /// Whether order can be confirmed
  bool get canConfirm => order?.canConfirm ?? (effectivePartnerId != null && totalLinesCount > 0);

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all effective lines (existing + new - deleted)
  List<SaleOrderLine> get effectiveLines {
    final result = <SaleOrderLine>[];

    // Add existing lines that weren't deleted, applying updates
    for (final line in lines) {
      if (!deletedLineIds.contains(line.id)) {
        // Check if there's an updated version
        final updated = updatedLines.firstWhere(
          (l) => l.id == line.id,
          orElse: () => line,
        );
        result.add(updated);
      }
    }

    // Add new lines
    result.addAll(newLines);

    // Sort by sequence
    result.sort((a, b) => a.sequence.compareTo(b.sequence));

    return result;
  }

  @override
  bool get isProcessing => isLoading || isSaving || isLoadingSelectionData;

  /// Si tiene una orden cargada (existente o guardada)
  bool get hasOrder => order != null;

  /// Indica si el formulario esta en modo edicion de orden existente
  /// Una orden es existente si ya fue cargada (order != null)
  /// Esto incluye ordenes offline (ID < 0) que ya estan en la DB local
  bool get isEditMode => order != null && isEditing;

  /// Indica si el formulario esta en modo creacion (nueva orden)
  /// Una orden es nueva SOLO si no ha sido cargada/creada todavia
  bool get isNewMode => order == null && isEditing;

  /// Indica si esta en modo vista (solo lectura)
  bool get isViewMode => order != null && !isEditing;

  /// Indica si el formulario puede ser guardado
  bool get canSave =>
      !isLoading && !isSaving && partnerId != null && hasChanges;

  /// Indica si hay datos de seleccion cargados
  bool get hasSelectionData =>
      paymentTerms.isNotEmpty ||
      pricelists.isNotEmpty ||
      warehouses.isNotEmpty ||
      salespeople.isNotEmpty;

  /// Obtiene el total de lineas (incluyendo nuevas, excluyendo eliminadas)
  int get totalLinesCount {
    final existingNotDeleted = lines
        .where((l) => !deletedLineIds.contains(l.id))
        .length;
    return existingNotDeleted + newLines.length;
  }

  /// Calcula el subtotal de todas las lineas
  double get calculatedSubtotal {
    double total = 0.0;

    // Lineas existentes no eliminadas
    for (final line in lines) {
      if (!deletedLineIds.contains(line.id) && line.isProductLine) {
        // Verificar si tiene actualizacion
        final updated = updatedLines.firstWhere(
          (l) => l.id == line.id,
          orElse: () => line,
        );
        total += updated.priceSubtotal;
      }
    }

    // Nuevas lineas
    for (final line in newLines) {
      if (line.isProductLine) {
        // Usar priceSubtotal que ya incluye el descuento calculado
        total += line.priceSubtotal;
      }
    }

    return total;
  }

  /// Indica si excede el límite de facturación para consumidor final
  /// Solo aplica cuando isFinalConsumer es true y hay un límite configurado > 0
  bool get exceedsFinalConsumerLimit {
    if (!isFinalConsumer || saleCustomerInvoiceLimitSri <= 0) {
      return false;
    }
    return calculatedSubtotal > saleCustomerInvoiceLimitSri;
  }
}
