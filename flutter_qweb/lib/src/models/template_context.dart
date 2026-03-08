/// Context for template rendering
///
/// Contains the data and configuration for rendering a QWeb template.
class TemplateContext {
  /// Main data map (accessible as root variables in template)
  final Map<String, dynamic> data;

  /// Company information for header/footer
  final CompanyInfo? company;

  /// Locale for formatting (default: 'en_US')
  final String locale;

  /// Currency symbol (default: '$')
  final String currencySymbol;

  /// Date format pattern (default: 'dd/MM/yyyy')
  final String dateFormat;

  /// Datetime format pattern (default: 'dd/MM/yyyy HH:mm')
  final String datetimeFormat;

  /// Number of decimal places for currency (default: 2)
  final int currencyDecimals;

  /// Custom functions available in expressions
  final Map<String, Function>? customFunctions;

  const TemplateContext({
    required this.data,
    this.company,
    this.locale = 'en_US',
    this.currencySymbol = '\$',
    this.dateFormat = 'dd/MM/yyyy',
    this.datetimeFormat = 'dd/MM/yyyy HH:mm',
    this.currencyDecimals = 2,
    this.customFunctions,
  });

  /// Create context with a single document
  factory TemplateContext.withDoc(
    Map<String, dynamic> doc, {
    CompanyInfo? company,
    String locale = 'en_US',
  }) {
    return TemplateContext(
      data: {'doc': doc},
      company: company,
      locale: locale,
    );
  }

  /// Create context with multiple documents (for batch reports)
  factory TemplateContext.withDocs(
    List<Map<String, dynamic>> docs, {
    CompanyInfo? company,
    String locale = 'en_US',
  }) {
    return TemplateContext(
      data: {'docs': docs},
      company: company,
      locale: locale,
    );
  }

  /// Get the full context map for expression evaluation
  Map<String, dynamic> toEvaluationContext() {
    final context = Map<String, dynamic>.from(data);

    if (company != null) {
      context['company'] = company!.toMap();
      context['res_company'] = company!.toMap();
    }

    // Add locale info
    context['_locale'] = locale;
    context['_currency_symbol'] = currencySymbol;
    context['_date_format'] = dateFormat;
    context['_datetime_format'] = datetimeFormat;

    // Odoo-compatible boolean literals
    context['true'] = true;
    context['false'] = false;
    context['True'] = true;
    context['False'] = false;
    context['None'] = null;

    // Odoo-compatible math helpers
    context['floor'] = (num x) => x.floor();
    context['ceil'] = (num x) => x.ceil();
    context['round'] = (num x, [int? decimals]) => decimals != null
        ? (x * 10 * decimals).round() / (10 * decimals)
        : x.round();
    context['abs'] = (num x) => x.abs();

    // Odoo-compatible utility functions
    context['len'] = (dynamic x) {
      if (x == null) return 0;
      if (x is String) return x.length;
      if (x is List) return x.length;
      if (x is Map) return x.length;
      return 0;
    };
    context['str'] = (dynamic x) => x?.toString() ?? '';
    context['int'] = (dynamic x) =>
        x is num ? x.toInt() : int.tryParse(x?.toString() ?? '') ?? 0;
    context['float'] = (dynamic x) =>
        x is num ? x.toDouble() : double.tryParse(x?.toString() ?? '') ?? 0.0;

    // === NEW ODOO-COMPATIBLE PYTHON BUILTINS ===

    // Boolean/logic functions
    context['bool'] = (dynamic x) {
      if (x == null) return false;
      if (x is bool) return x;
      if (x is num) return x != 0;
      if (x is String) return x.isNotEmpty;
      if (x is List) return x.isNotEmpty;
      if (x is Map) return x.isNotEmpty;
      return true;
    };

    context['any'] = (List? items) {
      if (items == null) return false;
      return items.any((e) {
        if (e == null) return false;
        if (e is bool) return e;
        if (e is num) return e != 0;
        if (e is String) return e.isNotEmpty;
        return true;
      });
    };

    context['all'] = (List? items) {
      if (items == null) return true;
      return items.every((e) {
        if (e == null) return false;
        if (e is bool) return e;
        if (e is num) return e != 0;
        if (e is String) return e.isNotEmpty;
        return true;
      });
    };

    // Range function
    context['range'] = ([dynamic stopOrStart, dynamic stop, dynamic step]) {
      int start = 0;
      int end = 0;
      int s = 1;

      if (stop == null && step == null) {
        end = (stopOrStart as num?)?.toInt() ?? 0;
      } else {
        start = (stopOrStart as num?)?.toInt() ?? 0;
        end = (stop as num?)?.toInt() ?? 0;
        s = (step as num?)?.toInt() ?? 1;
      }

      if (s == 0) return <int>[];
      final result = <int>[];
      if (s > 0) {
        for (int i = start; i < end; i += s) {
          result.add(i);
        }
      } else {
        for (int i = start; i > end; i += s) {
          result.add(i);
        }
      }
      return result;
    };

    // Math/aggregate functions
    context['min'] = (dynamic a, [dynamic b]) {
      if (b != null) return (a as Comparable).compareTo(b) < 0 ? a : b;
      if (a is List && a.isNotEmpty) {
        return a.reduce((x, y) => (x as Comparable).compareTo(y) < 0 ? x : y);
      }
      return a;
    };

    context['max'] = (dynamic a, [dynamic b]) {
      if (b != null) return (a as Comparable).compareTo(b) > 0 ? a : b;
      if (a is List && a.isNotEmpty) {
        return a.reduce((x, y) => (x as Comparable).compareTo(y) > 0 ? x : y);
      }
      return a;
    };

    context['sum'] = (List? items) {
      if (items == null) return 0;
      num total = 0;
      for (final item in items) {
        if (item is num) total += item;
      }
      return total;
    };

    // List functions
    context['sorted'] =
        (List? items) => items == null ? [] : (List.from(items)..sort());

    context['reversed'] =
        (List? items) => items == null ? [] : items.reversed.toList();

    context['list'] = (dynamic x) {
      if (x is List) return List.from(x);
      if (x is String) return x.split('');
      if (x is Map) return x.keys.toList();
      return [];
    };

    context['enumerate'] = (List? items) {
      if (items == null) return [];
      return items.asMap().entries.map((e) => [e.key, e.value]).toList();
    };

    context['zip'] = (List a, List b) {
      final len = a.length < b.length ? a.length : b.length;
      return List.generate(len, (i) => [a[i], b[i]]);
    };

    // === ODOO-SPECIFIC HELPERS ===

    // is_html_empty - checks if HTML content is empty
    context['is_html_empty'] = (dynamic html) {
      if (html == null) return true;
      if (html is! String) return true;
      // Remove HTML tags and check if empty
      final stripped = html
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      return stripped.isEmpty;
    };

    // image_data_uri - convert base64 to data URI
    context['image_data_uri'] = (dynamic imageData) {
      if (imageData == null || imageData == '') return '';
      if (imageData is String) {
        if (imageData.startsWith('data:')) return imageData;
        return 'data:image/png;base64,$imageData';
      }
      return '';
    };

    // Fake env for template compatibility
    context['env'] = {
      'context': {
        'lang': locale,
        'proforma': false,
      },
    };

    // Report type (html vs pdf)
    context['report_type'] = 'pdf';

    // is_pro_forma flag
    context['is_pro_forma'] = false;

    // Add custom functions if provided
    if (customFunctions != null) {
      context.addAll(customFunctions!);
    }

    return context;
  }
}

/// Company information for reports
class CompanyInfo {
  final String name;
  final String? vat;
  final String? street;
  final String? street2;
  final String? city;
  final String? state;
  final String? zip;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final String? logo; // Base64 or URL

  // Document layout configuration (from base.document.layout)
  final String? comercialName; // Nombre comercial (Ecuador)
  final String? reportHeaderImage; // Imagen cabecera (base64)
  final String? reportFooter; // Pie de página HTML
  final String? primaryColor; // Color primario hex (#875A7B)
  final String? secondaryColor; // Color secundario hex
  final String? font; // Fuente del documento (Lato, Roboto, etc.)
  final String? layoutBackground; // Fondo: Blank, Geometric, Custom
  final String?
      externalReportLayoutId; // Layout: web.external_layout_boxed, etc.

  const CompanyInfo({
    required this.name,
    this.vat,
    this.street,
    this.street2,
    this.city,
    this.state,
    this.zip,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.logo,
    // Document layout fields
    this.comercialName,
    this.reportHeaderImage,
    this.reportFooter,
    this.primaryColor,
    this.secondaryColor,
    this.font,
    this.layoutBackground,
    this.externalReportLayoutId,
  });

  /// Create from a map (e.g., from Odoo res.company)
  factory CompanyInfo.fromMap(Map<String, dynamic> map) {
    return CompanyInfo(
      name: map['name']?.toString() ?? '',
      vat: map['vat']?.toString(),
      street: map['street']?.toString(),
      street2: map['street2']?.toString(),
      city: map['city']?.toString(),
      state: map['state_id'] is List
          ? map['state_id'][1]?.toString()
          : map['state']?.toString(),
      zip: map['zip']?.toString(),
      country: map['country_id'] is List
          ? map['country_id'][1]?.toString()
          : map['country']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      website: map['website']?.toString(),
      logo: map['logo']?.toString(),
      // Document layout fields
      comercialName: map['comercial_name']?.toString() ??
          map['l10n_ec_comercial_name']?.toString(),
      reportHeaderImage: map['report_header_image']?.toString(),
      reportFooter: map['report_footer']?.toString(),
      primaryColor: map['primary_color']?.toString(),
      secondaryColor: map['secondary_color']?.toString(),
      font: map['font']?.toString(),
      layoutBackground: map['layout_background']?.toString(),
      externalReportLayoutId: map['external_report_layout_id']?.toString(),
    );
  }

  /// Convert to map for template context
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'vat': vat,
      'street': street,
      'street2': street2,
      'city': city,
      'state': state,
      'zip': zip,
      'country': country,
      'phone': phone,
      'email': email,
      'website': website,
      'logo': logo,
      // Document layout fields
      'comercial_name': comercialName,
      'report_header_image': reportHeaderImage,
      'report_footer': reportFooter,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'font': font,
      'layout_background': layoutBackground,
      'external_report_layout_id': externalReportLayoutId,
    };
  }

  /// Get the display name (comercial name or regular name)
  String get displayName => comercialName ?? name;

  /// Get formatted address
  String get formattedAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (street2 != null && street2!.isNotEmpty) parts.add(street2!);
    final cityLine =
        [city, state, zip].where((s) => s != null && s.isNotEmpty).join(', ');
    if (cityLine.isNotEmpty) parts.add(cityLine);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join('\n');
  }
}
