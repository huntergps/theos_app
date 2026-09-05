import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/invoices/repositories/invoice_repository.dart';

void main() {
  test(
    'offline invoice IDs remain negative for local and remote order IDs',
    () {
      expect(InvoiceRepository.offlineMoveIdForOrder(25), -25);
      expect(InvoiceRepository.offlineMoveIdForOrder(-25), -25);
      expect(
        () => InvoiceRepository.offlineMoveIdForOrder(0),
        throwsArgumentError,
      );
    },
  );
}
