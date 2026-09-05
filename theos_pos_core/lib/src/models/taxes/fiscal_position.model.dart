import 'package:drift/drift.dart'
    show GeneratedDatabase, RawValuesInsertable, TableInfo, Value, Variable;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import '../../database/database.dart';

part 'fiscal_position.model.freezed.dart';
part 'fiscal_position.model.g.dart';

/// Fiscal Position model representing account.fiscal.position in Odoo
///
/// Fiscal positions are used to map taxes based on customer location or type.
///
/// **Computed fields:**
/// - [displayName] → formatted name with country
/// - [hasCountryFilter] → whether filtered by country
/// - [isAutoApply] → whether auto-apply is enabled
@OdooModel('account.fiscal.position', tableName: 'account_fiscal_position')
@freezed
abstract class FiscalPosition with _$FiscalPosition {
  const FiscalPosition._();

  const factory FiscalPosition({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooBoolean() @Default(true) bool active,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooInteger() @Default(10) int sequence,
    @OdooString() String? note,
    @OdooBoolean(odooName: 'auto_apply') @Default(false) bool autoApply,
    @OdooMany2One('res.country', odooName: 'country_id') int? countryId,
    @OdooMany2OneName(sourceField: 'country_id') String? countryName,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _FiscalPosition;

  // ============ Computed Fields ============

  /// Display name with country if applicable
  String get displayName {
    if (countryName != null && countryName!.isNotEmpty) {
      return '$name ($countryName)';
    }
    return name;
  }

  /// Check if has country filter
  bool get hasCountryFilter => countryId != null && countryId! > 0;

  /// Check if is auto-apply position
  bool get isAutoApply => autoApply;
}

/// NOTE: FiscalPositionTax intentionally does NOT use @OdooModel.
/// Uses an explicit local/remote ID mapping with manual
/// fromOdoo()/toCompanion().
/// Managed by FiscalPositionTaxManager without code generation.
///
/// Fiscal Position Tax Mapping model — filas LOCALES SINTETIZADAS que
/// representan el mapeo de un impuesto fuente a un impuesto destino bajo una
/// posición fiscal dada (ej. IVA 12% -> IVA 0% para exportaciones).
///
/// ## Compatibilidad Odoo >= 18.3 (hallazgo verificado en vivo, julio 2026)
///
/// El modelo `account.fiscal.position.tax` fue ELIMINADO del core de Odoo
/// desde la 18.3 — confirmado con `fields_get` en Odoo 19.5a1+e: "the model
/// does not exist". Esto
/// significa que este modelo NO EXISTE ni en Odoo 19.1 ni en 19.2 ni en
/// 19.5 — la sync de este mapeo llevaba meses fallando en silencio dejando
/// la tabla local `account_fiscal_position_tax` permanentemente vacía (ver
/// `tax_calculator_service.dart:239-268`, que la lee para resolver
/// sustituciones de impuestos por posición fiscal — siempre caía al
/// `orElse` sin mapeo).
///
/// El reemplazo real vive en `account.tax` (idéntico en account/models/
/// account_tax.py de 19.1/19.2/19.5, líneas 111/117):
/// - `fiscal_position_ids` (M2M account.fiscal.position) — bajo qué
///   posiciones fiscales este tax actúa como DESTINO de una sustitución.
/// - `original_tax_ids` (M2M account.tax) — qué taxes FUENTE se sustituyen
///   por este tax bajo esas posiciones.
///
/// Verificado en vivo (read-only, Odoo 19.5a1+e, julio 2026): los
/// campos M2M llegan como lista PLANA de enteros — ej.
/// `fiscal_position_ids: [4]`, `original_tax_ids: [5, 6, 14, 15]`, o `[]`
/// si está vacío — NUNCA como pares `[id, name]` (eso es sólo
/// comportamiento de Many2one). Ejemplo real: tax id=19 ("VAT 0% EX G") con
/// `fiscal_position_ids=[4]` y `original_tax_ids=[5,6,14,15]` produce 4
/// filas sintéticas: (posición=4, fuente=5, destino=19),
/// (4, 6, 19), (4, 14, 19), (4, 15, 19).
///
/// Por lo tanto ya NO existe una llamada 1:1 `fromOdoo()` desde un registro
/// remoto — [synthesizeFromAccountTax] reemplaza esa función, tomando UN
/// registro `account.tax` y devolviendo 0..N filas [FiscalPositionTax]
/// (producto cartesiano de `fiscal_position_ids` × `original_tax_ids`). El
/// contrato de LECTURA de `tax_calculator_service.dart` NO cambia (misma
/// tabla `account_fiscal_position_tax`, mismas columnas `position_id`/
/// `tax_src_id`/`tax_dest_id`).
@freezed
abstract class FiscalPositionTax with _$FiscalPositionTax {
  const FiscalPositionTax._();

  const factory FiscalPositionTax({
    required int id,
    required int odooId,
    required int positionId,
    required int taxSrcId,
    String? taxSrcName,
    int? taxDestId,
    String? taxDestName,
    DateTime? writeDate,
  }) = _FiscalPositionTax;

  // ============ Computed Fields ============

  /// Check if this mapping exempts the tax (no destination tax)
  bool get isExemption => taxDestId == null;

  /// Display text for the mapping
  String get displayMapping {
    final src = taxSrcName ?? 'Tax $taxSrcId';
    if (isExemption) {
      return '$src → Exempt';
    }
    final dest = taxDestName ?? 'Tax $taxDestId';
    return '$src → $dest';
  }

  // ============ Factory Methods ============

  /// Create from Drift database row
  factory FiscalPositionTax.fromDatabase(dynamic data) {
    return FiscalPositionTax(
      id: data.id,
      odooId: data.odooId,
      positionId: data.positionId,
      taxSrcId: data.taxSrcId,
      taxSrcName: data.taxSrcName,
      taxDestId: data.taxDestId,
      taxDestName: data.taxDestName,
      writeDate: data.writeDate,
    );
  }

  /// Sintetiza 0..N filas [FiscalPositionTax] a partir de UN registro
  /// `account.tax` (ver nota de compatibilidad de la clase para el porqué).
  ///
  /// [json] debe traer al menos los campos de [odooFields]: `id`,
  /// `fiscal_position_ids`, `original_tax_ids`, `write_date`.
  ///
  /// Retorna lista vacía si el tax no tiene `fiscal_position_ids` NI
  /// `original_tax_ids` (no participa en ninguna sustitución fiscal — el
  /// caso común, la sync ya filtra por dominio
  /// `fiscal_position_ids != false` así que esto rara vez ocurre en
  /// práctica salvo datos inconsistentes).
  static List<FiscalPositionTax> synthesizeFromAccountTax(
    Map<String, dynamic> json,
  ) {
    final taxDestId = json['id'] as int;
    final positionIds = _parseM2mIds(json['fiscal_position_ids']);
    final sourceTaxIds = _parseM2mIds(json['original_tax_ids']);

    if (positionIds.isEmpty || sourceTaxIds.isEmpty) return const [];

    final writeDate = json['write_date'] != null && json['write_date'] != false
        ? DateTime.tryParse('${json['write_date']}Z')
        : null;

    final rows = <FiscalPositionTax>[];
    for (final positionId in positionIds) {
      for (final taxSrcId in sourceTaxIds) {
        final syntheticId = syntheticOdooId(positionId, taxSrcId, taxDestId);
        if (syntheticId == null)
          continue; // fuera de rango, ver syntheticOdooId
        rows.add(
          FiscalPositionTax(
            id: 0, // lo asigna Drift (autoincrement) al insertar
            odooId: syntheticId,
            positionId: positionId,
            taxSrcId: taxSrcId,
            taxSrcName: null,
            taxDestId: taxDestId,
            taxDestName: null,
            writeDate: writeDate,
          ),
        );
      }
    }
    return rows;
  }

  /// Parsea un campo Many2many de la respuesta JSON-2 de Odoo.
  ///
  /// Verificado en vivo (Odoo 19.5a1+e, julio 2026): los
  /// M2M llegan como lista plana de enteros (`[3]`, `[5, 6, 14, 15]`, `[]`
  /// si vacío) — nunca como pares `[id, name]` anidados (eso es sólo
  /// Many2one).
  static List<int> _parseM2mIds(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<int>().toList();
  }

  /// Bits reservados por componente para el ID sintético — ver
  /// [syntheticOdooId]. positionId usa 12 bits (0..4095 — de sobra para
  /// cualquier catálogo real de posiciones fiscales, normalmente unas
  /// pocas), taxSrcId/taxDestId usan 20 bits cada uno (0..1,048,575, de
  /// sobra para IDs reales de account.tax). Total: 52 bits — se mantiene
  /// bajo el límite de entero seguro en JS/dart2js (2^53) usado en builds
  /// Flutter Web, donde `int` se representa como double de 64 bits IEEE-754
  /// con 53 bits de mantisa.
  static const int _positionBits = 12;
  static const int _taxBits = 20;
  static const int _positionMask = (1 << _positionBits) - 1; // 4,095
  static const int _taxMask = (1 << _taxBits) - 1; // 1,048,575

  /// Genera un `odooId` determinístico y NEGATIVO para una fila sintetizada
  /// de mapeo fiscal-position→tax.
  ///
  /// ## Por qué se necesita un ID sintético
  ///
  /// Estas filas NO existen como registros reales en el servidor (no hay
  /// modelo `account.fiscal.position.tax` del cual traer un ID — ver nota
  /// de compatibilidad de la clase). Sin embargo la tabla local
  /// `account_fiscal_position_tax` requiere un `odooId` NOT NULL/único
  /// (target del `ON CONFLICT` en
  /// `FiscalPositionTaxManager.upsertLocalBatch`), así que se sintetiza uno.
  ///
  /// ## Diseño
  ///
  /// Empaqueta los 3 componentes de la terna (positionId, taxSrcId,
  /// taxDestId) en un único entero mediante bit-packing determinístico:
  ///
  /// ```
  /// combined = (positionId << 40) | (taxSrcId << 20) | taxDestId
  /// odooId   = -combined - 1
  /// ```
  ///
  /// Es determinístico: la MISMA terna (P, S, D) SIEMPRE produce el MISMO
  /// `odooId`, sin importar cuántas veces se re-sincronice — esto es lo que
  /// permite que el upsert por `odooId` (`ON CONFLICT ... DO UPDATE`) sea
  /// idempotente (actualiza la fila existente, ej. refresca `write_date`)
  /// en vez de duplicarla en cada sync.
  ///
  /// Se usa signo NEGATIVO por convención del codebase para IDs "sin ID de
  /// servidor real" (ej. IDs locales de `sale.order` antes de crear en
  /// Odoo) — aquí no hay riesgo de colisión con esos IDs locales porque la
  /// unicidad de `odooId` es POR TABLA (Drift), y esta tabla nunca recibe
  /// filas "pendientes de sync" creadas por el usuario (es 100% derivada de
  /// datos del servidor).
  ///
  /// Retorna `null` (se omite esa fila, con warning en log) si algún
  /// componente excede su rango de bits — extremadamente improbable con
  /// datos reales de Odoo, pero se prefiere omitir una fila y loguear antes
  /// que arriesgar una colisión silenciosa de IDs (los `assert()` se
  /// eliminan en builds release, así que la validación es un check
  /// explícito, no un `assert`).
  static int? syntheticOdooId(int positionId, int taxSrcId, int taxDestId) {
    if (positionId < 0 ||
        taxSrcId < 0 ||
        taxDestId < 0 ||
        positionId > _positionMask ||
        taxSrcId > _taxMask ||
        taxDestId > _taxMask) {
      logger.w(
        '[FiscalPositionTax] ID fuera de rango al sintetizar mapeo '
        '(position=$positionId, src=$taxSrcId, dest=$taxDestId) — se omite '
        'esta fila. Rango soportado: position 0..$_positionMask, '
        'src/dest 0..$_taxMask.',
      );
      return null;
    }
    final combined =
        (positionId << (2 * _taxBits)) | (taxSrcId << _taxBits) | taxDestId;
    return -combined - 1;
  }

  /// Convert to Drift database companion for insert/update
  AccountFiscalPositionTaxCompanion toCompanion() {
    return AccountFiscalPositionTaxCompanion(
      odooId: Value(odooId),
      positionId: Value(positionId),
      taxSrcId: Value(taxSrcId),
      taxSrcName: Value(taxSrcName),
      taxDestId: Value(taxDestId ?? 0),
      taxDestName: Value(taxDestName),
      writeDate: Value(writeDate),
    );
  }

  /// Odoo model a consultar para sintetizar el mapeo (Odoo >= 18.3 compat —
  /// ver nota de la clase). NO es el modelo antiguo
  /// `account.fiscal.position.tax` (eliminado desde Odoo 18.3).
  static const String odooModel = 'account.tax';

  /// Campos a pedir de account.tax para la síntesis.
  static const List<String> odooFields = [
    'id',
    'fiscal_position_ids',
    'original_tax_ids',
    'write_date',
  ];
}
