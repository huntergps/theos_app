import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/database/repositories/repository_providers.dart';
import 'package:theos_pos/core/managers/manager_providers.dart'
    show appDatabaseProvider;
import 'package:theos_pos/core/services/odoo_service.dart';
import 'package:theos_pos/features/advances/providers/advance_providers.dart';
import 'package:theos_pos/features/advances/services/advance_service.dart';
import 'package:theos_pos/features/banks/providers/bank_providers.dart';
import 'package:theos_pos/features/banks/repositories/bank_repository.dart';
import 'package:theos_pos/features/sales/providers/service_providers.dart';
import 'package:theos_pos/features/sales/services/payment_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        odooServiceProvider.overrideWithValue(OdooService()),
        offlineQueueDataSourceProvider.overrideWithValue(
          OfflineQueueDataSource(database),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('bank repository is constructed from configured app dependencies', () {
    final repository = container.read(bankRepositoryProvider);

    expect(repository, isA<BankRepository>());
    expect(container.read(bankRepositoryProvider), same(repository));
  });

  test('payment and advance services are readable without nullable stubs', () {
    expect(container.read(paymentServiceProvider), isA<PaymentService>());
    expect(container.read(advanceServiceProvider), isA<AdvanceService>());
  });
}
