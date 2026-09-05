/// Stable transport contract for Odoo model operations.
///
/// Feature code should depend on this interface (or on [OdooClient]) instead
/// of constructing `/json/2` URLs or depending on the HTTP implementation.
abstract interface class OdooTransport {
  /// Searches records and returns the requested fields.
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic> domain = const [],
    int? limit,
    int? offset,
    String? order,
  });

  /// Invokes an Odoo model or recordset method.
  ///
  /// [ids] selects the recordset. Named method parameters belong in [kwargs].
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  });
}
