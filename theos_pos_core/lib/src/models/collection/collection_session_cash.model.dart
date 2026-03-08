import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'collection_session_cash.model.freezed.dart';
part 'collection_session_cash.model.g.dart';

enum CashType {
  @JsonValue('opening')
  opening,
  @JsonValue('closing')
  closing,
}

/// Collection Session Cash migrated to @OdooModel annotation pattern.
///
/// ## Computed fields (equivalent to @api.depends in Odoo)
///
/// - [isOpening] / [isClosing] -> depends: [cashType]
/// - [bills*Total] / [billsTotal] -> depends: [bills*]
/// - [coins*Total] / [coinsTotal] -> depends: [coins*]
/// - [cashTotal] -> depends: [billsTotal, coinsTotal]
/// - [hasValues] -> depends: [cashTotal]
/// - [totalBillsCount] / [totalCoinsCount] -> depends: [bills*, coins*]
@OdooModel('collection.session.cash', tableName: 'collection_session_cash')
@freezed
abstract class CollectionSessionCash with _$CollectionSessionCash {
  const CollectionSessionCash._();

  // ═══════════════════ Validation ═══════════════════

  /// Validates the cash count before saving.
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (collectionSessionId == null || collectionSessionId == 0) {
      errors['session'] = 'La sesion es requerida';
    }
    return errors;
  }

  /// Validates for specific actions.
  Map<String, String> validateFor(String action) {
    final errors = validate();
    switch (action) {
      case 'save':
        // Validar que tenga al menos algo de efectivo si es cierre
        if (isClosing && !hasValues) {
          // Advertencia, no error - puede haber cierre sin efectivo
        }
        break;

      case 'confirm_opening':
        if (!isOpening) {
          errors['cashType'] = 'Este conteo no es de apertura';
        }
        break;

      case 'confirm_closing':
        if (!isClosing) {
          errors['cashType'] = 'Este conteo no es de cierre';
        }
        break;
    }
    return errors;
  }

  const factory CollectionSessionCash({
    // ============ Identifiers ============
    @OdooId() @Default(0) int id,
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? lastSyncDate,

    // ============ Relations ============
    @OdooMany2One('collection.session', odooName: 'collection_session_id') int? collectionSessionId,

    // ============ Type ============
    @OdooSelection(odooName: 'cash_type') @Default(CashType.opening) CashType cashType,

    // ============ Bills (quantities) ============
    @OdooInteger(odooName: 'bills_100') @Default(0) int bills100,
    @OdooInteger(odooName: 'bills_50') @Default(0) int bills50,
    @OdooInteger(odooName: 'bills_20') @Default(0) int bills20,
    @OdooInteger(odooName: 'bills_10') @Default(0) int bills10,
    @OdooInteger(odooName: 'bills_5') @Default(0) int bills5,
    @OdooInteger(odooName: 'bills_1') @Default(0) int bills1,

    // ============ Coins (quantities) ============
    @OdooInteger(odooName: 'coins_1') @Default(0) int coins1,
    @OdooInteger(odooName: 'coins_50') @Default(0) int coins50,
    @OdooInteger(odooName: 'coins_25') @Default(0) int coins25,
    @OdooInteger(odooName: 'coins_10') @Default(0) int coins10,
    @OdooInteger(odooName: 'coins_5') @Default(0) int coins5,
    @OdooInteger(odooName: 'coins_1_cent') @Default(0) int coins1Cent,

    // ============ Notes ============
    @OdooString() String? notes,
  }) = _CollectionSessionCash;

  factory CollectionSessionCash.fromJson(Map<String, dynamic> json) =>
      _$CollectionSessionCashFromJson(json);

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS - Bill Totals
  // ═══════════════════════════════════════════════════════════════════════════

  double get bills100Total => bills100 * 100.0;
  double get bills50Total => bills50 * 50.0;
  double get bills20Total => bills20 * 20.0;
  double get bills10Total => bills10 * 10.0;
  double get bills5Total => bills5 * 5.0;
  double get bills1Total => bills1 * 1.0;

  double get billsTotal =>
      bills100Total +
      bills50Total +
      bills20Total +
      bills10Total +
      bills5Total +
      bills1Total;

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS - Coin Totals
  // ═══════════════════════════════════════════════════════════════════════════

  double get coins1Total => coins1 * 1.0;
  double get coins50Total => coins50 * 0.50;
  double get coins25Total => coins25 * 0.25;
  double get coins10Total => coins10 * 0.10;
  double get coins5Total => coins5 * 0.05;
  double get coins1CentTotal => coins1Cent * 0.01;

  double get coinsTotal =>
      coins1Total +
      coins50Total +
      coins25Total +
      coins10Total +
      coins5Total +
      coins1CentTotal;

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS - Aggregates
  // ═══════════════════════════════════════════════════════════════════════════

  double get cashTotal => billsTotal + coinsTotal;

  /// Indica si es conteo de apertura
  bool get isOpening => cashType == CashType.opening;

  /// Indica si es conteo de cierre
  bool get isClosing => cashType == CashType.closing;

  /// Indica si tiene algun valor
  bool get hasValues => cashTotal > 0;

  /// Total de billetes (cantidad)
  int get totalBillsCount =>
      bills100 + bills50 + bills20 + bills10 + bills5 + bills1;

  /// Total de monedas (cantidad)
  int get totalCoinsCount =>
      coins1 + coins50 + coins25 + coins10 + coins5 + coins1Cent;

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea un conteo de apertura vacio.
  factory CollectionSessionCash.newOpening({
    required int collectionSessionId,
  }) {
    return CollectionSessionCash(
      collectionSessionId: collectionSessionId,
      cashType: CashType.opening,
      isSynced: false,
    );
  }

  /// Crea un conteo de cierre vacio.
  factory CollectionSessionCash.newClosing({
    required int collectionSessionId,
  }) {
    return CollectionSessionCash(
      collectionSessionId: collectionSessionId,
      cashType: CashType.closing,
      isSynced: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONCHANGE SIMULATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Actualiza el conteo de una denominacion especifica de billete.
  CollectionSessionCash updateBill(int denomination, int count) {
    switch (denomination) {
      case 100: return copyWith(bills100: count);
      case 50: return copyWith(bills50: count);
      case 20: return copyWith(bills20: count);
      case 10: return copyWith(bills10: count);
      case 5: return copyWith(bills5: count);
      case 1: return copyWith(bills1: count);
      default: return this;
    }
  }

  /// Actualiza el conteo de una moneda especifica.
  CollectionSessionCash updateCoin(int centValue, int count) {
    switch (centValue) {
      case 100: return copyWith(coins1: count);
      case 50: return copyWith(coins50: count);
      case 25: return copyWith(coins25: count);
      case 10: return copyWith(coins10: count);
      case 5: return copyWith(coins5: count);
      case 1: return copyWith(coins1Cent: count);
      default: return this;
    }
  }
}
