/// Represents an Odoo server version (e.g., 19.1, 19.2)
class OdooVersion implements Comparable<OdooVersion> {
  final int major;
  final int minor;
  final String raw;

  const OdooVersion({
    required this.major,
    required this.minor,
    required this.raw,
  });

  /// Parse from server_version string like "saas-19.2", "19.1", "19.0"
  factory OdooVersion.parse(String versionString) {
    final raw = versionString;
    // Remove "saas-" prefix if present
    var cleaned = versionString.replaceFirst(RegExp(r'^saas-'), '');
    // Extract major.minor from patterns like "19.2", "19.1+e"
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(cleaned);
    if (match != null) {
      return OdooVersion(
        major: int.parse(match.group(1)!),
        minor: int.parse(match.group(2)!),
        raw: raw,
      );
    }
    // Fallback: try just major
    final majorMatch = RegExp(r'(\d+)').firstMatch(cleaned);
    if (majorMatch != null) {
      return OdooVersion(
        major: int.parse(majorMatch.group(1)!),
        minor: 0,
        raw: raw,
      );
    }
    return OdooVersion(major: 0, minor: 0, raw: raw);
  }

  /// Unknown/undetected version
  static const unknown = OdooVersion(major: 0, minor: 0, raw: 'unknown');

  bool get isUnknown => major == 0 && minor == 0;

  /// Check if this version is at least the given version
  bool isAtLeast(int major, [int minor = 0]) {
    if (this.major != major) return this.major > major;
    return this.minor >= minor;
  }

  /// Common version checks
  bool get isOdoo19_2OrLater => isAtLeast(19, 2);
  bool get isOdoo19_1OrLater => isAtLeast(19, 1);

  /// In 19.2, res.bank was removed
  bool get hasBankModel => !isOdoo19_2OrLater;

  /// In 19.2, stock.scrap was removed (now stock.move with is_scrap=True)
  bool get hasStockScrapModel => !isOdoo19_2OrLater;

  /// In 19.2, UOM fields renamed in stock models
  bool get hasLegacyUomFields => !isOdoo19_2OrLater;

  @override
  int compareTo(OdooVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is OdooVersion && major == other.major && minor == other.minor;

  @override
  int get hashCode => Object.hash(major, minor);

  bool operator <(OdooVersion other) => compareTo(other) < 0;
  bool operator <=(OdooVersion other) => compareTo(other) <= 0;
  bool operator >(OdooVersion other) => compareTo(other) > 0;
  bool operator >=(OdooVersion other) => compareTo(other) >= 0;

  @override
  String toString() => '$major.$minor';
}
