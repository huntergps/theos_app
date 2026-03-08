import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'resource_calendar.model.freezed.dart';
part 'resource_calendar.model.g.dart';

/// Odoo model: resource.calendar (Work Schedules)
@OdooModel('resource.calendar', tableName: 'resource_calendar')
@freezed
abstract class ResourceCalendar with _$ResourceCalendar {
  const ResourceCalendar._();

  const factory ResourceCalendar({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _ResourceCalendar;

  String get displayName => name;
}
