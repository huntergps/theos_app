import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../core/services/handlers/model_record_handler.dart';

/// Handler for stock.warehouse records
class WarehouseRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'stock.warehouse';

  @override
  List<String> get defaultFields => WarehouseRecordMapper.fields;

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    return WarehouseRecordMapper.exists(db, odooId);
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    return WarehouseRecordMapper.upsert(db, data);
  }
}
