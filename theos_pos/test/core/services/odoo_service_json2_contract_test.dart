import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/services/odoo_service.dart';

void main() {
  test('writeUser separates recordset ids from method kwargs', () async {
    final service = _RecordingOdooService(result: true);

    final success = await service.writeUser(42, {'name': 'Ada'});

    expect(success, isTrue);
    expect(service.model, 'res.users');
    expect(service.method, 'write');
    expect(service.ids, [42]);
    expect(service.kwargs, {
      'vals': {'name': 'Ada'},
    });
    expect(service.kwargs, isNot(contains('ids')));
  });
}

class _RecordingOdooService extends OdooService {
  _RecordingOdooService({required this.result});

  final dynamic result;

  String? model;
  String? method;
  List<int>? ids;
  Map<String, dynamic>? kwargs;

  @override
  bool get isLoggedIn => true;

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  }) async {
    this.model = model;
    this.method = method;
    this.ids = ids;
    this.kwargs = kwargs;
    return result;
  }
}
