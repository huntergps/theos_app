/// Typed product data used while composing an offline sale.
final class SaleCatalogProduct {
  const SaleCatalogProduct({
    required this.localId,
    required this.name,
    this.remoteId,
    this.uomId,
    this.uomName,
    this.price = 0,
    this.taxIds = const <int>[],
  });

  final String localId;
  final int? remoteId;
  final String name;
  final int? uomId;
  final String? uomName;
  final double price;
  final List<int> taxIds;

  factory SaleCatalogProduct.fromMap(Map<String, dynamic> value) {
    final id = value['localId'] ?? value['id'] ?? value['uuid'];
    final name = value['name'] ?? value['title'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('product requires a non-empty id and name');
    }
    return SaleCatalogProduct(
      localId: id,
      remoteId: _positiveInt(
        value['remoteId'] ?? value['odooId'] ?? value['id'],
      ),
      name: name,
      uomId: _positiveInt(value['uomId']),
      uomName: value['uomName'] as String?,
      price: (value['price'] as num?)?.toDouble() ?? 0,
      taxIds: (value['taxIds'] as List? ?? const <dynamic>[])
          .whereType<num>()
          .map((item) => item.toInt())
          .where((item) => item > 0)
          .toList(growable: false),
    );
  }

  static int? _positiveInt(Object? value) =>
      value is num && value > 0 ? value.toInt() : null;
}

final class SaleCatalogPartner {
  const SaleCatalogPartner({required this.remoteId, required this.name, this.vat, this.email});
  final int? remoteId;
  final String name;
  final String? vat;
  final String? email;
  factory SaleCatalogPartner.fromMap(Map<String, dynamic> value) => SaleCatalogPartner(
        remoteId: SaleCatalogProduct._positiveInt(value['remoteId'] ?? value['odooId'] ?? value['id']),
        name: (value['name'] ?? value['display_name'] ?? '').toString(),
        vat: value['vat'] as String?,
        email: value['email'] as String?,
      );
}

final class SaleDraftLineRecord {
  const SaleDraftLineRecord({
    required this.lineUuid,
    required this.product,
    required this.quantity,
    this.unitPrice,
    this.discount = 0,
    this.tax = 0,
  });

  final String lineUuid;
  final SaleCatalogProduct product;
  final double quantity;
  final double? unitPrice;
  final double discount;
  final double tax;
}

final class SaleDraftRecord {
  const SaleDraftRecord({
    required this.commandId,
    required this.name,
    required this.lines,
    this.partnerId,
    this.partnerName,
    this.note,
    this.paymentTermId,
  });

  final String commandId;
  final String name;
  final List<SaleDraftLineRecord> lines;
  final int? partnerId;
  final String? partnerName;
  final String? note;
  final int? paymentTermId;
}

abstract interface class SaleDraftRepository {
  Future<int> save(SaleDraftRecord draft);
}
