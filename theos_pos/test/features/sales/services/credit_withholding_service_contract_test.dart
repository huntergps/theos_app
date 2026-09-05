import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/services/odoo_service.dart';
import 'package:theos_pos/features/sales/services/credit_withholding_service.dart';

void main() {
  test('partner credit request only uses fields available in ERP2', () async {
    final odoo = _RecordingOdooService();
    final service = CreditWithholdingService(odoo);

    final result = await service.getPartnerCreditInfo(42);

    expect(result, isNotNull);
    expect(result!.unpaidInvoicesCount, 0);
    final fields = (odoo.kwargs!['fields'] as List).cast<String>();
    expect(
      fields,
      containsAll(<String>[
        'credit_limit',
        'credit',
        'credit_to_invoice',
        'total_overdue',
        'credit_available',
        'allow_over_credit',
      ]),
    );
    expect(fields, isNot(contains('unpaid_invoices_count')));
  });
}

class _RecordingOdooService extends OdooService {
  Map<String, dynamic>? kwargs;

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  }) async {
    this.kwargs = kwargs;
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'credit_limit': 1000,
        'credit': 100,
        'credit_to_invoice': 50,
        'total_overdue': 0,
        'credit_available': 850,
        'allow_over_credit': false,
      },
    ];
  }
}
