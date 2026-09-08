import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../core/services/handlers/model_record_handler.dart';


/// Handler for product.pricelist records
class PricelistRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'product.pricelist';

  @override
  List<String> get defaultFields => PricelistRecordMapper.fields;

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    return PricelistRecordMapper.exists(db, odooId);
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    return PricelistRecordMapper.upsert(db, data);
  }
}
