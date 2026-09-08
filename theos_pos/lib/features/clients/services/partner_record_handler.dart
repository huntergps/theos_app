import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../core/services/handlers/model_record_handler.dart';

/// Handler for res.partner records.
class PartnerRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'res.partner';

  @override
  List<String> get defaultFields => PartnerRecordMapper.fields;

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    return PartnerRecordMapper.exists(db, odooId);
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    return PartnerRecordMapper.upsert(db, data);
  }
}
