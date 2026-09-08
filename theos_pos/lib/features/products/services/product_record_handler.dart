import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../core/services/handlers/model_record_handler.dart';

/// Handler for product.product records
class ProductRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'product.product';

  @override
  List<String> get defaultFields => ProductRecordMapper.fields;

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    return ProductRecordMapper.exists(db, odooId);
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    return ProductRecordMapper.upsert(db, data);
  }
}

/// Handler for uom.uom records
class UomRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'uom.uom';

  @override
  List<String> get defaultFields => UomRecordMapper.fields;

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    return UomRecordMapper.exists(db, odooId);
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    return UomRecordMapper.upsert(db, data);
  }
}
