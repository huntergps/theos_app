/// Generador de claves de acceso SRI Ecuador (Algoritmo Módulo 11)
///
/// Genera claves de acceso de 49 dígitos para documentos electrónicos
/// según las especificaciones del Servicio de Rentas Internas (SRI) de Ecuador.
class SRIKeyGenerator {
  /// Genera el nombre formateado de factura (e.g., 001-001-000000001)
  ///
  /// [entity] - Código de establecimiento (3 dígitos)
  /// [emission] - Punto de emisión (3 dígitos)
  /// [sequence] - Número secuencial
  static String generateInvoiceName({
    required String entity,
    required String emission,
    required int sequence,
  }) {
    return '$entity-$emission-${sequence.toString().padLeft(9, '0')}';
  }

  /// Genera la clave de acceso de 49 dígitos
  ///
  /// [date] - Fecha de emisión
  /// [documentType] - Código de documento (01=Factura, 04=NC, 05=ND, 06=Guía, 07=Retención)
  /// [ruc] - RUC de la empresa (13 dígitos)
  /// [environment] - Ambiente (1=Pruebas, 2=Producción)
  /// [invoiceName] - Nombre de factura formateado (e.g. 001-001-000000053)
  /// [emissionType] - Tipo de emisión (1=Normal)
  ///
  /// Retorna: String de 49 dígitos numéricos
  static String generateAccessKey({
    required DateTime date,
    required String documentType,
    required String ruc,
    required String environment,
    required String invoiceName,
    required String emissionType,
  }) {
    // Parse invoice name to extract entity, emission, and sequence
    final parts = invoiceName.split('-');
    if (parts.length != 3) {
      throw ArgumentError(
        'Invalid invoice name format. Expected Ex: 001-001-000000001',
      );
    }
    final entity = parts[0];
    final emission = parts[1];
    // sequence might contain the full string "000000001"
    final sequenceStr = parts[2];

    // 1. Validar inputs básicos
    if (ruc.length != 13) {
      throw ArgumentError('RUC debe tener 13 dígitos');
    }

    // 2. Formatear componentes
    final dateToken = _formatDate(date); // 8 dígitos

    // Secuencial a 9 dígitos (ensure it's padded just in case)
    final sequentialToken = sequenceStr.padLeft(9, '0');

    // Código numérico (Relleno) - 8 dígitos
    // Odoo usa '31215214' hardcoded en algunas versiones o aleatorio.
    // Usaremos uno fijo para consistencia, similar a l10n_ec_edi
    const numFiller = '31215214';

    // 3. Construir clave base (48 dígitos)
    // Orden: Fecha(8) + TipoDoc(2) + RUC(13) + Amb(1) + Est(3) + PtoEmi(3) + Sec(9) + CodNum(8) + TipoEmi(1)
    final keyBase = dateToken +
        documentType +
        ruc +
        environment +
        entity +
        emission +
        sequentialToken +
        numFiller +
        emissionType;

    if (keyBase.length != 48) {
      throw FormatException(
        'Longitud de clave base incorrecta: ${keyBase.length}, se esperaban 48',
      );
    }

    // 4. Calcular dígito verificador
    final checkDigit = _calculateCheckDigit(keyBase);

    // 5. Retornar clave completa (49 dígitos)
    return keyBase + checkDigit.toString();
  }

  /// Formatea la fecha en formato ddmmyyyy
  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day$month$year';
  }

  /// Calcula el dígito verificador usando algoritmo módulo 11
  static int _calculateCheckDigit(String key) {
    if (key.length != 48) return 0; // Should not happen

    int sum = 0;
    int factor = 2;

    // Recorrer de derecha a izquierda
    for (int i = key.length - 1; i >= 0; i--) {
      int digit = int.parse(key[i]);
      sum += digit * factor;
      factor++;
      if (factor > 7) factor = 2;
    }

    int check = 11 - (sum % 11);

    if (check == 11) {
      check = 0;
    } else if (check == 10) {
      check = 1;
    }

    return check;
  }

  // ============================================================
  // CÓDIGOS DE DOCUMENTOS SRI
  // ============================================================

  /// Código para Factura
  static const String docTypeFactura = '01';

  /// Código para Liquidación de Compra
  static const String docTypeLiquidacion = '03';

  /// Código para Nota de Crédito
  static const String docTypeNotaCredito = '04';

  /// Código para Nota de Débito
  static const String docTypeNotaDebito = '05';

  /// Código para Guía de Remisión
  static const String docTypeGuiaRemision = '06';

  /// Código para Comprobante de Retención
  static const String docTypeRetencion = '07';

  /// Obtiene el nombre del tipo de documento por código
  static String getDocumentTypeName(String code) {
    switch (code) {
      case docTypeFactura:
        return 'Factura';
      case docTypeLiquidacion:
        return 'Liquidación de Compra';
      case docTypeNotaCredito:
        return 'Nota de Crédito';
      case docTypeNotaDebito:
        return 'Nota de Débito';
      case docTypeGuiaRemision:
        return 'Guía de Remisión';
      case docTypeRetencion:
        return 'Comprobante de Retención';
      default:
        return 'Documento Desconocido';
    }
  }
}
