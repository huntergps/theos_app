/// Renovación proactiva de la clave API antes de que caduque.
///
/// Diseño decidido por el dueño (13-sep-2026): con la app en línea y la clave
/// a menos del 25 % de su vida restante (o a menos de 6 horas, lo que ocurra
/// primero en el tiempo), el runtime llama
/// `res.users.apikeys.generate(key, scope, name, expiration_date)` con la
/// clave ACTUAL, guarda la nueva en el mismo almacén cifrado y SÓLO DESPUÉS
/// revoca la vieja. La vida nueva es la que de verdad da el servidor — nunca
/// se cablea aquí.
library;

/// Lo que devuelve `res.users.apikeys.generate` ya interpretado: el secreto
/// nuevo y, cuando el servidor lo informa, la fecha de caducidad real —
/// puede diferir de la que se pidió.
final class ApiKeyRenewalResult {
  const ApiKeyRenewalResult({required this.apiKey, this.expiresAt});

  final String apiKey;

  /// `null` sólo cuando el servidor no devolvió una fecha interpretable; en
  /// ese caso el llamador asume la MISMA duración total que tenía la clave
  /// anterior, nunca una inventada.
  final DateTime? expiresAt;
}

/// El servidor respondió explícitamente que las claves API programáticas
/// están desactivadas (`base.enable_programmatic_api_keys` apagado). Esto NO
/// es un error de sesión: la clave actual sigue sirviendo con normalidad
/// hasta que caduque por sí sola, momento en el que el mecanismo reactivo
/// (un 401 del sondeo o de un RPC) toma el control.
final class ApiKeyRenewalUnsupportedException implements Exception {
  const ApiKeyRenewalUnsupportedException([
    this.message = 'Programmatic API keys are not enabled',
  ]);

  final String message;

  @override
  String toString() => 'ApiKeyRenewalUnsupportedException($message)';
}

/// `res.users.apikeys.generate` en sí mismo vive como método de
/// [AuthBootstrapPort] (ver `native_auth_service.dart`), implementado por
/// `NativeAuthBootstrapAdapter` mediante un `OdooClient` con bearer = la
/// clave vigente — el mismo patrón que ya usa `revokeOwnApiKey`, porque
/// `generate`, igual que `.revoke`, es un método público que se autentica
/// con la propia clave (a diferencia de `.remove`, que exige
/// `@check_identity`). No hay aquí una interfaz separada para eso: todo
/// `AuthBootstrapPort` ya la trae.
///
/// Pura, sin red ni reloj propio: decide CUÁNDO conviene renovar a partir de
/// cuándo se emitió la clave actual, cuándo caduca, y el momento presente.
final class ApiKeyRenewalDecision {
  const ApiKeyRenewalDecision._();

  /// El umbral mínimo absoluto, sea cual sea la vida total de la clave.
  static const minAbsoluteRemaining = Duration(hours: 6);

  /// La fracción mínima de vida restante, sobre la vida TOTAL de la clave.
  static const minFractionRemaining = 0.25;

  /// «Lo que llegue antes» se traduce en tomar el umbral MÁS GENEROSO de los
  /// dos (el que, contando desde la emisión, se alcanza primero en el
  /// tiempo — con más vida restante): una clave de 90 días se renueva ya a
  /// los 22,5 días de vida restante (25 % de 90 días, mucho antes que las 6
  /// horas absolutas); una clave de 1 día se renueva a las 6 horas restantes,
  /// porque ahí coinciden ambos criterios.
  static Duration thresholdFor(Duration totalLife) {
    final byFraction = Duration(
      microseconds: (totalLife.inMicroseconds * minFractionRemaining).round(),
    );
    return byFraction > minAbsoluteRemaining ? byFraction : minAbsoluteRemaining;
  }

  /// `false` cuando la clave ya caducó: en ese punto no hay nada que
  /// renovar proactivamente — es el mecanismo reactivo (401) el que debe
  /// actuar, nunca este.
  static bool shouldRenew({
    required DateTime issuedAt,
    required DateTime expiresAt,
    required DateTime now,
  }) {
    final remaining = expiresAt.difference(now);
    if (remaining.isNegative || remaining == Duration.zero) return false;
    final totalLife = expiresAt.difference(issuedAt);
    if (totalLife <= Duration.zero) return false;
    return remaining <= thresholdFor(totalLife);
  }
}
