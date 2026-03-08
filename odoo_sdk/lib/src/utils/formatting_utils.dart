import 'package:intl/intl.dart';

/// Centralized utilities for formatting numbers, currency, and dates.
///
/// Example:
/// ```dart
/// final formatted = FormattingUtils.formatCurrency(1234.56); // '$1,234.56'
/// final date = FormattingUtils.formatDate(DateTime.now()); // '12/01/2025'
///
/// // Using extensions
/// final price = 99.99.toCurrency(); // '$99.99'
/// final dateStr = DateTime.now().toFormattedDate(); // '12/01/2025'
/// ```
class FormattingUtils {
  FormattingUtils._();

  // ===========================================================================
  // CURRENCY FORMATTING
  // ===========================================================================

  /// Formats a value as currency with symbol.
  ///
  /// [value] - The value to format
  /// [symbol] - Currency symbol (default: '$')
  /// [decimals] - Number of decimal places (default: 2)
  static String formatCurrency(
    num value, {
    String symbol = '\$',
    int decimals = 2,
  }) {
    final format = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: decimals,
    );
    return format.format(value);
  }

  /// Formats a value as currency without symbol (numbers only).
  /// Useful for input fields.
  static String formatCurrencyValue(num value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals);
  }

  /// Formats a value as currency with explicit sign.
  /// Positive values show '+', negative show '-'.
  static String formatCurrencyWithSign(
    num value, {
    String symbol = '\$',
    int decimals = 2,
  }) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${formatCurrency(value, symbol: symbol, decimals: decimals)}';
  }

  // ===========================================================================
  // NUMBER FORMATTING
  // ===========================================================================

  /// Formats a number with thousands separators.
  static String formatNumber(num value, {int? decimals}) {
    if (decimals != null) {
      final format = NumberFormat.decimalPatternDigits(decimalDigits: decimals);
      return format.format(value);
    }

    // Auto-detect: integer or decimal
    if (value is int || value == value.roundToDouble()) {
      return NumberFormat.decimalPattern().format(value);
    }
    return NumberFormat.decimalPatternDigits(decimalDigits: 2).format(value);
  }

  /// Formats a value as percentage.
  static String formatPercent(num value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Formats a number with fixed decimals without separators.
  static String formatDecimal(num value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals);
  }

  /// Formats quantity (integer without decimals if whole number).
  static String formatQuantity(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return formatNumber(value, decimals: 2);
  }

  // ===========================================================================
  // DATE FORMATTING
  // ===========================================================================

  /// Formats a date with the specified pattern.
  ///
  /// [date] - The date to format
  /// [pattern] - Format pattern (e.g., 'dd/MM/yyyy', 'yyyy-MM-dd')
  /// [locale] - Locale for formatting (default: 'es')
  static String formatDate(
    DateTime date, {
    String pattern = 'dd/MM/yyyy',
    String locale = 'es',
  }) {
    return DateFormat(pattern, locale).format(date.toLocal());
  }

  /// Formats a date with time.
  static String formatDateTime(
    DateTime date, {
    String pattern = 'dd/MM/yyyy HH:mm',
    String locale = 'es',
  }) {
    return DateFormat(pattern, locale).format(date.toLocal());
  }

  /// Formats a date relative to today.
  /// Returns 'Hoy'/'Today', 'Ayer'/'Yesterday', 'Mañana'/'Tomorrow'
  /// or the formatted date, depending on [locale].
  ///
  /// If [today], [yesterday], or [tomorrow] are provided explicitly,
  /// those labels take precedence over locale-based defaults.
  static String formatRelativeDate(
    DateTime date, {
    String pattern = 'dd/MM/yyyy',
    String locale = 'es',
    String? today,
    String? yesterday,
    String? tomorrow,
  }) {
    final isSpanish = locale.startsWith('es');
    final todayLabel = today ?? (isSpanish ? 'Hoy' : 'Today');
    final yesterdayLabel = yesterday ?? (isSpanish ? 'Ayer' : 'Yesterday');
    final tomorrowLabel = tomorrow ?? (isSpanish ? 'Mañana' : 'Tomorrow');

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    final difference = dateOnly.difference(todayDate).inDays;

    if (difference == 0) return todayLabel;
    if (difference == -1) return yesterdayLabel;
    if (difference == 1) return tomorrowLabel;

    return formatDate(date, pattern: pattern, locale: locale);
  }

  /// Formats only the time from a date.
  static String formatTime(
    DateTime date, {
    bool use24Hour = true,
    String locale = 'es',
  }) {
    final pattern = use24Hour ? 'HH:mm' : 'h:mm a';
    return DateFormat(pattern, locale).format(date.toLocal());
  }

  /// Builds a date-time format from a base date format.
  /// Useful to convert 'dd/MM/yyyy' to 'dd/MM/yyyy HH:mm'.
  static String buildDateTimeFormat(String baseFormat) {
    // If it already has time, return as-is
    if (baseFormat.contains('H') ||
        baseFormat.contains('h') ||
        (baseFormat.contains('m') && baseFormat.contains('a'))) {
      return baseFormat;
    }

    // Add time based on base format
    switch (baseFormat) {
      case 'dd/MM/yyyy':
        return 'dd/MM/yyyy HH:mm';
      case 'MM/dd/yyyy':
        return 'MM/dd/yyyy h:mm a';
      case 'yyyy-MM-dd':
        return 'yyyy-MM-dd HH:mm';
      case 'd MMM, yyyy':
        return 'd MMM, yyyy h:mm a';
      default:
        return '$baseFormat HH:mm';
    }
  }

  // ===========================================================================
  // COMPACT FORMATTING (for limited space)
  // ===========================================================================

  /// Formats currency compactly (1.2K, 1.5M).
  static String formatCurrencyCompact(num value, {String symbol = '\$'}) {
    if (value.abs() >= 1000000) {
      return '$symbol${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '$symbol${(value / 1000).toStringAsFixed(1)}K';
    }
    return formatCurrency(value, symbol: symbol);
  }

  /// Formats date compactly.
  static String formatDateCompact(DateTime date, {String locale = 'es'}) {
    return DateFormat('dd/MM', locale).format(date.toLocal());
  }

  // ===========================================================================
  // PARSING
  // ===========================================================================

  /// Tries to parse a string as number, returns null on failure.
  static double? tryParseNumber(String? value) {
    if (value == null || value.isEmpty) return null;

    // Remove currency symbols and thousands separators
    final cleaned = value
        .replaceAll('\$', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();

    return double.tryParse(cleaned);
  }

  /// Parses a currency string to double.
  static double parseCurrency(String value, {double defaultValue = 0.0}) {
    return tryParseNumber(value) ?? defaultValue;
  }
}

/// Extension for quick number formatting.
extension NumberFormattingExtension on num {
  /// Formats as currency: 1234.56.toCurrency() => '$1,234.56'
  String toCurrency({String symbol = '\$', int decimals = 2}) =>
      FormattingUtils.formatCurrency(this, symbol: symbol, decimals: decimals);

  /// Formats as percentage: 15.5.toPercent() => '15.5%'
  String toPercent({int decimals = 1}) =>
      FormattingUtils.formatPercent(this, decimals: decimals);

  /// Formats with fixed decimals: 15.5.toFixed(2) => '15.50'
  String toFixed(int decimals) =>
      FormattingUtils.formatDecimal(this, decimals: decimals);

  /// Formats with thousands separators.
  String toFormatted({int? decimals}) =>
      FormattingUtils.formatNumber(this, decimals: decimals);
}

/// Extension for quick date formatting.
extension DateFormattingExtension on DateTime {
  /// Formats date: DateTime.now().toFormattedDate() => '12/01/2025'
  String toFormattedDate({String pattern = 'dd/MM/yyyy', String locale = 'es'}) =>
      FormattingUtils.formatDate(this, pattern: pattern, locale: locale);

  /// Formats date and time.
  String toFormattedDateTime({String pattern = 'dd/MM/yyyy HH:mm', String locale = 'es'}) =>
      FormattingUtils.formatDateTime(this, pattern: pattern, locale: locale);

  /// Formats only time.
  String toFormattedTime({bool use24Hour = true, String locale = 'es'}) =>
      FormattingUtils.formatTime(this, use24Hour: use24Hour, locale: locale);

  /// Formats as relative date.
  String toRelativeDate({String pattern = 'dd/MM/yyyy', String locale = 'es'}) =>
      FormattingUtils.formatRelativeDate(this, pattern: pattern, locale: locale);

  // ===========================================================================
  // ALIASES FOR COMPATIBILITY
  // ===========================================================================

  /// Alias for toFormattedDate - Format as date only (dd/MM/yyyy)
  String toDateString() => toFormattedDate();

  /// Alias for toFormattedTime - Format as time only (HH:mm)
  String toTimeString() => toFormattedTime();

  /// Alias for toFormattedDateTime - Format as date and time (dd/MM/yyyy HH:mm)
  String toDateTimeString() => toFormattedDateTime();

  /// Format as ISO 8601 string
  String toIsoString() => toIso8601String();

  /// Format for Odoo (yyyy-MM-dd HH:mm:ss)
  String toOdooFormat() => DateFormat('yyyy-MM-dd HH:mm:ss').format(this);
}

/// Extension on int for formatting
extension IntFormattingExtension on int {
  /// Format with thousand separators
  String toFormattedNumber() => FormattingUtils.formatNumber(this);
}
