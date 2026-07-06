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

  /// Unknown/undetected version.
  ///
  /// IMPORTANTE — supuesto por defecto: cuando la versión es `unknown`
  /// (p.ej. `fetchVersion()` nunca se ejecutó con éxito porque el arranque
  /// ocurrió offline), todos los flags derivados (`hasBankModel`,
  /// `hasStockScrapModel`, `hasLegacyUomFields`) asumen el comportamiento de
  /// **Odoo 19.1** (el más antiguo/legacy), porque `isOdoo19_2OrLater` da
  /// `false` para major/minor = 0. Esto es una decisión consciente: es más
  /// seguro asumir el modelo "legacy" (con `res.bank`, etc.) y fallar con un
  /// error de campo inválido si el servidor real es 19.2, que asumir 19.2 y
  /// nunca pedir campos que sí existen en 19.1. Ver `OdooClient.fetchVersion`
  /// y `AppInitializer` (theos_pos) para el reintento de detección.
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

  /// In 19.2, res.bank was removed.
  /// Si la versión es [unknown], asume `true` (comportamiento 19.1) — ver [unknown].
  bool get hasBankModel => !isOdoo19_2OrLater;

  /// In 19.2, stock.scrap was removed (now stock.move with is_scrap=True)
  /// Si la versión es [unknown], asume `true` (comportamiento 19.1) — ver [unknown].
  bool get hasStockScrapModel => !isOdoo19_2OrLater;

  /// In 19.2, UOM fields renamed in stock models
  /// Si la versión es [unknown], asume `true` (comportamiento 19.1) — ver [unknown].
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
