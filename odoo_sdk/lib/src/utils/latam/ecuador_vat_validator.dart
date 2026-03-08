/// Validador de documentos de identificación para Ecuador
///
/// Implementa las mismas reglas que l10n_ec y l10n_latam_base en Odoo:
///
/// **Tipos con validación algorítmica:**
/// - Cédula: 10 dígitos, algoritmo módulo 10
/// - RUC Natural: 13 dígitos (cédula + 001), tercer dígito 0-5
/// - RUC Jurídico: 13 dígitos, tercer dígito = 9, algoritmo módulo 11
/// - RUC Público: 13 dígitos, tercer dígito = 6, algoritmo módulo 11
///
/// **Tipos sin validación algorítmica (solo formato):**
/// - Pasaporte: Alfanumérico, mínimo 5 caracteres
/// - ID Extranjero: Alfanumérico, mínimo 5 caracteres
/// - Consumidor Final: 9999999999999
class EcuadorVatValidator {
  // ============================================================
  // TIPOS DE IDENTIFICACIÓN
  // Basado en l10n_ec.ec_dni, l10n_ec.ec_ruc, l10n_latam_base.it_pass, etc.
  // ============================================================

  /// Cédula de Ciudadanía (l10n_ec.ec_dni)
  static const String typeCedula = 'cedula';

  /// RUC Persona Natural (l10n_ec.ec_ruc con tercer dígito 0-5)
  static const String typeRucNatural = 'ruc_natural';

  /// RUC Sociedad/Empresa Privada (l10n_ec.ec_ruc con tercer dígito 9)
  static const String typeRucJuridico = 'ruc_juridico';

  /// RUC Entidad Pública (l10n_ec.ec_ruc con tercer dígito 6)
  static const String typeRucPublico = 'ruc_publico';

  /// Pasaporte (l10n_latam_base.it_pass)
  static const String typePassport = 'passport';

  /// ID Extranjero (l10n_latam_base.it_fid)
  static const String typeForeignId = 'foreign_id';

  /// Consumidor Final
  static const String typeConsumidorFinal = 'consumidor_final';

  /// RUC especial para consumidor final
  static const String consumidorFinalVat = '9999999999999';

  /// Longitud mínima para pasaporte/ID extranjero
  static const int minPassportLength = 5;

  /// Longitud máxima para pasaporte/ID extranjero
  static const int maxPassportLength = 20;

  // ============================================================
  // VALIDACIÓN PRINCIPAL
  // ============================================================

  /// Valida si un VAT es válido según las reglas ecuatorianas
  ///
  /// [vat] - El número de identificación a validar
  /// [identificationType] - Tipo de identificación (opcional). Si no se proporciona,
  ///   se intenta detectar automáticamente (solo funciona para RUC/Cédula numéricos)
  ///
  /// Retorna `true` si es válido, `false` si no
  static bool isValid(String? vat, {String? identificationType}) {
    if (vat == null || vat.isEmpty) return false;

    // Limpiar el VAT de espacios y guiones
    final cleanVat = clean(vat);

    // Consumidor final siempre es válido
    if (cleanVat == consumidorFinalVat) {
      return true;
    }

    // Si se especifica tipo, validar según ese tipo
    if (identificationType != null) {
      return _validateByType(cleanVat, identificationType);
    }

    // Auto-detectar tipo basado en formato
    final type = getVatType(cleanVat);
    if (type == null) {
      // Si no es numérico de 10/13 dígitos, podría ser pasaporte/foreign
      // pero sin tipo explícito no podemos validar
      return false;
    }

    return _validateByType(cleanVat, type);
  }

  /// Valida según el tipo específico
  static bool _validateByType(String cleanVat, String type) {
    switch (type) {
      case typeCedula:
        return _validateCedula(cleanVat);
      case typeRucNatural:
        return _validateRucNatural(cleanVat);
      case typeRucJuridico:
        return _validateRucJuridico(cleanVat);
      case typeRucPublico:
        return _validateRucPublico(cleanVat);
      case typePassport:
      case typeForeignId:
        return _validatePassportOrForeignId(cleanVat);
      case typeConsumidorFinal:
        return cleanVat == consumidorFinalVat;
      default:
        return false;
    }
  }

  // ============================================================
  // DETECCIÓN DE TIPO
  // ============================================================

  /// Determina el tipo de VAT basado en su formato
  ///
  /// Solo detecta tipos ecuatorianos (Cédula, RUC) basándose en:
  /// - Longitud (10 = cédula, 13 = RUC)
  /// - Tercer dígito para RUC (0-5 = natural, 6 = público, 9 = jurídico)
  ///
  /// Retorna `null` si no se puede determinar (ej: pasaportes, IDs extranjeros)
  static String? getVatType(String? vat) {
    if (vat == null || vat.isEmpty) return null;

    final cleanVat = clean(vat);

    // Consumidor final
    if (cleanVat == consumidorFinalVat) {
      return typeConsumidorFinal;
    }

    // Solo numéricos para auto-detección de tipo ecuatoriano
    if (!RegExp(r'^\d+$').hasMatch(cleanVat)) {
      return null; // Podría ser pasaporte/foreign, pero no auto-detectamos
    }

    // Cédula: 10 dígitos
    if (cleanVat.length == 10) {
      return typeCedula;
    }

    // RUC: 13 dígitos
    if (cleanVat.length == 13) {
      final thirdDigit = int.tryParse(cleanVat[2]);
      if (thirdDigit == null) return null;

      if (thirdDigit < 6) {
        return typeRucNatural;
      } else if (thirdDigit == 6) {
        return typeRucPublico;
      } else if (thirdDigit == 9) {
        return typeRucJuridico;
      }
    }

    return null;
  }

  /// Obtiene descripción del tipo de VAT
  static String getVatTypeDescription(String? type) {
    switch (type) {
      case typeCedula:
        return 'Cédula';
      case typeRucNatural:
        return 'RUC Persona Natural';
      case typeRucJuridico:
        return 'RUC Sociedad/Empresa';
      case typeRucPublico:
        return 'RUC Entidad Pública';
      case typeConsumidorFinal:
        return 'Consumidor Final';
      case typePassport:
        return 'Pasaporte';
      case typeForeignId:
        return 'ID Extranjero';
      default:
        return 'Desconocido';
    }
  }

  /// Lista de tipos de identificación disponibles para UI
  static List<Map<String, String>> getIdentificationTypes() {
    return [
      {'code': typeCedula, 'name': 'Cédula'},
      {'code': typeRucNatural, 'name': 'RUC'},
      {'code': typePassport, 'name': 'Pasaporte'},
      {'code': typeForeignId, 'name': 'ID Extranjero'},
    ];
  }

  // ============================================================
  // VALIDACIONES ESPECÍFICAS POR TIPO
  // ============================================================

  /// Valida pasaporte o ID extranjero
  ///
  /// Reglas:
  /// - Alfanumérico (letras y números)
  /// - Longitud entre 5 y 20 caracteres
  /// - Sin validación de dígito verificador
  static bool _validatePassportOrForeignId(String value) {
    if (value.length < minPassportLength || value.length > maxPassportLength) {
      return false;
    }

    // Solo alfanumérico (sin espacios ni caracteres especiales)
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(value)) {
      return false;
    }

    return true;
  }

  /// Valida una cédula ecuatoriana (10 dígitos)
  ///
  /// Algoritmo módulo 10:
  /// 1. Los dos primeros dígitos son el código de provincia (01-24)
  /// 2. El tercer dígito debe ser menor a 6
  /// 3. Verificador con coeficientes [2,1,2,1,2,1,2,1,2]
  static bool _validateCedula(String cedula) {
    if (cedula.length != 10) return false;

    // Solo dígitos
    if (!RegExp(r'^\d{10}$').hasMatch(cedula)) return false;

    // Validar código de provincia (01-24)
    final provincia = int.tryParse(cedula.substring(0, 2));
    if (provincia == null || provincia < 1 || provincia > 24) {
      return false;
    }

    // El tercer dígito debe ser menor a 6
    final thirdDigit = int.tryParse(cedula[2]);
    if (thirdDigit == null || thirdDigit >= 6) {
      return false;
    }

    // Algoritmo de verificación módulo 10
    const coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    var suma = 0;

    for (var i = 0; i < 9; i++) {
      var digit = int.parse(cedula[i]);
      var resultado = digit * coeficientes[i];
      if (resultado > 9) {
        resultado -= 9;
      }
      suma += resultado;
    }

    final verificador = (10 - (suma % 10)) % 10;
    final digitoVerificador = int.parse(cedula[9]);

    return verificador == digitoVerificador;
  }

  /// Valida un RUC de persona natural (13 dígitos)
  ///
  /// Los primeros 10 dígitos deben ser una cédula válida
  /// Los últimos 3 dígitos deben ser 001 o mayor
  static bool _validateRucNatural(String ruc) {
    if (ruc.length != 13) return false;

    // Solo dígitos
    if (!RegExp(r'^\d{13}$').hasMatch(ruc)) return false;

    // Los primeros 10 dígitos deben ser una cédula válida
    final cedula = ruc.substring(0, 10);
    if (!_validateCedula(cedula)) {
      return false;
    }

    // Los últimos 3 dígitos deben ser el código de establecimiento (001-999)
    final establecimiento = int.tryParse(ruc.substring(10, 13));
    if (establecimiento == null || establecimiento < 1) {
      return false;
    }

    return true;
  }

  /// Valida un RUC de sociedad/empresa privada (13 dígitos)
  ///
  /// El tercer dígito debe ser 9
  /// Algoritmo módulo 11 con coeficientes [4,3,2,7,6,5,4,3,2]
  static bool _validateRucJuridico(String ruc) {
    if (ruc.length != 13) return false;

    // Solo dígitos
    if (!RegExp(r'^\d{13}$').hasMatch(ruc)) return false;

    // El tercer dígito debe ser 9
    if (ruc[2] != '9') return false;

    // Validar código de provincia (01-24)
    final provincia = int.tryParse(ruc.substring(0, 2));
    if (provincia == null || provincia < 1 || provincia > 24) {
      return false;
    }

    // Los últimos 3 dígitos deben ser el código de establecimiento (001-999)
    final establecimiento = int.tryParse(ruc.substring(10, 13));
    if (establecimiento == null || establecimiento < 1) {
      return false;
    }

    // Algoritmo módulo 11
    const coeficientes = [4, 3, 2, 7, 6, 5, 4, 3, 2];
    var suma = 0;

    for (var i = 0; i < 9; i++) {
      final digit = int.parse(ruc[i]);
      suma += digit * coeficientes[i];
    }

    final residuo = suma % 11;
    final verificador = residuo == 0 ? 0 : 11 - residuo;
    final digitoVerificador = int.parse(ruc[9]);

    return verificador == digitoVerificador;
  }

  /// Valida un RUC de entidad pública (13 dígitos)
  ///
  /// El tercer dígito debe ser 6
  /// Algoritmo módulo 11 con coeficientes [3,2,7,6,5,4,3,2]
  static bool _validateRucPublico(String ruc) {
    if (ruc.length != 13) return false;

    // Solo dígitos
    if (!RegExp(r'^\d{13}$').hasMatch(ruc)) return false;

    // El tercer dígito debe ser 6
    if (ruc[2] != '6') return false;

    // Validar código de provincia (01-24)
    final provincia = int.tryParse(ruc.substring(0, 2));
    if (provincia == null || provincia < 1 || provincia > 24) {
      return false;
    }

    // Los últimos 4 dígitos deben ser el código de establecimiento (0001-9999)
    final establecimiento = int.tryParse(ruc.substring(9, 13));
    if (establecimiento == null || establecimiento < 1) {
      return false;
    }

    // Algoritmo módulo 11
    const coeficientes = [3, 2, 7, 6, 5, 4, 3, 2];
    var suma = 0;

    for (var i = 0; i < 8; i++) {
      final digit = int.parse(ruc[i]);
      suma += digit * coeficientes[i];
    }

    final residuo = suma % 11;
    final verificador = residuo == 0 ? 0 : 11 - residuo;
    final digitoVerificador = int.parse(ruc[8]);

    return verificador == digitoVerificador;
  }

  // ============================================================
  // UTILIDADES
  // ============================================================

  /// Formatea el VAT para mostrar (agrupa dígitos)
  static String format(String? vat) {
    if (vat == null || vat.isEmpty) return '';

    final cleanVat = clean(vat);

    if (cleanVat.length == 10 && RegExp(r'^\d+$').hasMatch(cleanVat)) {
      // Cédula: XXXX-XXXX-XX
      return '${cleanVat.substring(0, 4)}-${cleanVat.substring(4, 8)}-${cleanVat.substring(8)}';
    } else if (cleanVat.length == 13 && RegExp(r'^\d+$').hasMatch(cleanVat)) {
      // RUC: XXXX-XXXX-XX-XXX
      return '${cleanVat.substring(0, 4)}-${cleanVat.substring(4, 8)}-${cleanVat.substring(8, 10)}-${cleanVat.substring(10)}';
    }

    // Pasaporte/Foreign ID: sin formato
    return cleanVat;
  }

  /// Limpia el VAT (remueve espacios y guiones)
  static String clean(String? vat) {
    if (vat == null || vat.isEmpty) return '';
    return vat.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  }

  /// Obtiene mensaje de error para un VAT inválido
  ///
  /// [vat] - El número de identificación a validar
  /// [identificationType] - Tipo de identificación (opcional)
  ///
  /// Retorna mensaje de error o `null` si es válido
  static String? getValidationError(String? vat, {String? identificationType}) {
    if (vat == null || vat.isEmpty) {
      return null; // VAT opcional
    }

    final cleanVat = clean(vat);

    // Si se especifica tipo, validar según ese tipo
    if (identificationType != null) {
      return _getErrorByType(cleanVat, identificationType);
    }

    // Auto-detectar: solo funciona con numéricos
    if (!RegExp(r'^\d+$').hasMatch(cleanVat)) {
      // No es numérico, podría ser pasaporte/foreign
      // Sin tipo explícito, no podemos validar
      return 'Especifique el tipo de identificación para documentos no numéricos';
    }

    // Longitud válida para documentos numéricos ecuatorianos
    if (cleanVat.length != 10 && cleanVat.length != 13) {
      return 'El RUC/Cédula debe tener 10 o 13 dígitos';
    }

    // Determinar tipo
    final type = getVatType(cleanVat);
    if (type == null) {
      if (cleanVat.length == 13) {
        final third = cleanVat[2];
        return 'Tercer dígito inválido ($third). Debe ser 0-5 (natural), 6 (público) o 9 (jurídico)';
      }
      return 'Formato de RUC/Cédula no reconocido';
    }

    return _getErrorByType(cleanVat, type);
  }

  /// Obtiene error específico por tipo
  static String? _getErrorByType(String cleanVat, String type) {
    switch (type) {
      case typeCedula:
        if (cleanVat.length != 10) {
          return 'La cédula debe tener 10 dígitos';
        }
        if (!RegExp(r'^\d{10}$').hasMatch(cleanVat)) {
          return 'La cédula solo debe contener dígitos';
        }
        if (!_validateCedula(cleanVat)) {
          return 'Cédula inválida. Verifique el dígito verificador';
        }
        break;

      case typeRucNatural:
      case typeRucJuridico:
      case typeRucPublico:
        if (cleanVat.length != 13) {
          return 'El RUC debe tener 13 dígitos';
        }
        if (!RegExp(r'^\d{13}$').hasMatch(cleanVat)) {
          return 'El RUC solo debe contener dígitos';
        }
        final detectedType = getVatType(cleanVat);
        if (detectedType != type &&
            type != typeRucNatural &&
            type != typeRucJuridico &&
            type != typeRucPublico) {
          return 'El formato del RUC no coincide con el tipo seleccionado';
        }
        if (!_validateByType(cleanVat, detectedType ?? type)) {
          if (detectedType == typeRucNatural) {
            return 'RUC de persona natural inválido. Los primeros 10 dígitos deben ser una cédula válida';
          } else if (detectedType == typeRucJuridico) {
            return 'RUC de sociedad inválido. Verifique el dígito verificador';
          } else if (detectedType == typeRucPublico) {
            return 'RUC de entidad pública inválido. Verifique el dígito verificador';
          }
          return 'RUC inválido. Verifique el dígito verificador';
        }
        break;

      case typePassport:
        if (cleanVat.length < minPassportLength) {
          return 'El pasaporte debe tener al menos $minPassportLength caracteres';
        }
        if (cleanVat.length > maxPassportLength) {
          return 'El pasaporte no debe exceder $maxPassportLength caracteres';
        }
        if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(cleanVat)) {
          return 'El pasaporte solo debe contener letras y números';
        }
        break;

      case typeForeignId:
        if (cleanVat.length < minPassportLength) {
          return 'El ID extranjero debe tener al menos $minPassportLength caracteres';
        }
        if (cleanVat.length > maxPassportLength) {
          return 'El ID extranjero no debe exceder $maxPassportLength caracteres';
        }
        if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(cleanVat)) {
          return 'El ID extranjero solo debe contener letras y números';
        }
        break;

      case typeConsumidorFinal:
        if (cleanVat != consumidorFinalVat) {
          return 'El VAT de consumidor final debe ser $consumidorFinalVat';
        }
        break;

      default:
        return 'Tipo de identificación no reconocido';
    }

    return null; // Sin error
  }

  /// Verifica si un tipo de identificación requiere validación algorítmica
  static bool requiresAlgorithmicValidation(String? type) {
    return type == typeCedula ||
        type == typeRucNatural ||
        type == typeRucJuridico ||
        type == typeRucPublico;
  }

  /// Verifica si un tipo de identificación es alfanumérico
  static bool isAlphanumericType(String? type) {
    return type == typePassport || type == typeForeignId;
  }

  // ============================================================
  // SRI TAXPAYER TYPES
  // Basado en l10n_ec_edi.l10n_ec.taxpayer.type (enterprise)
  // ============================================================

  /// Lista de tipos de contribuyente SRI para cálculo de retenciones
  /// Basado en /enterprise/l10n_ec_edi/data/l10n_ec.taxpayer.type.csv
  static List<Map<String, dynamic>> getSriTaxpayerTypes() {
    return [
      {'code': '01', 'name': 'Compañias - Personas Juridicas'},
      {'code': '02', 'name': 'Contribuyentes Especiales'},
      {'code': '03', 'name': 'Sector Publico y EP'},
      {'code': '04', 'name': 'Persona Natural Obligada a Llevar Contabilidad'},
      {'code': '05', 'name': 'Persona Natural No Obligada - Arriendos'},
      {'code': '06', 'name': 'Persona Natural No Obligada - Profesionales'},
      {
        'code': '07',
        'name': 'Persona Natural No Obligada - Liquidaciones Compra'
      },
      {
        'code': '08',
        'name': 'Persona Natural No Obligada - Emite Facturas o Notas'
      },
      {'code': '13', 'name': 'Contribuyente Regimen RIMPE'},
      {'code': '14', 'name': 'OTROS - Sin calculo automatico de retencion IVA'},
      {'code': '15', 'name': 'RIMPE Regimen Negocio Popular'},
    ];
  }

  /// Obtiene el nombre del tipo de contribuyente por código
  static String? getSriTaxpayerTypeName(String? code) {
    if (code == null) return null;
    final types = getSriTaxpayerTypes();
    final match = types.where((t) => t['code'] == code).firstOrNull;
    return match?['name'];
  }
}
