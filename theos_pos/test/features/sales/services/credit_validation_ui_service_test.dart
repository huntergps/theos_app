import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/features/clients/clients.dart';
import 'package:theos_pos/features/sales/services/credit_validation_ui_service.dart';

// ============================================================
// Mocks
// ============================================================

class MockClientRepository extends Mock implements ClientRepository {}

class MockClientCreditService extends Mock implements ClientCreditService {}

/// Tests for CreditValidationUIService pure business logic:
///
/// - Bypass flag handling
/// - Null client ID handling
/// - Client not found handling
/// - Client without credit limit
/// - Client with credit limit (valid/invalid)
/// - Online refresh behavior
/// - Error handling
/// - hasClientCreditLimit() helper
///
/// NOTE: Methods that require live Odoo connection (refreshCreditData with
/// real HTTP calls) are not tested. We mock ClientRepository.refreshCreditData
/// to return a Client instead.
void main() {
  late MockClientRepository mockClientRepo;
  late MockClientCreditService mockCreditService;
  late CreditValidationUIService service;

  setUpAll(() {
    registerFallbackValue(
      const Client(
        id: 0,
        name: '',
        active: true,
      ),
    );
  });

  setUp(() {
    mockClientRepo = MockClientRepository();
    mockCreditService = MockClientCreditService();
    service = CreditValidationUIService(
      clientRepo: mockClientRepo,
      creditService: mockCreditService,
    );
  });

  // ============================================================
  // UnifiedCreditResult factories
  // ============================================================
  group('UnifiedCreditResult', () {
    test('proceed() should allow proceeding without dialog', () {
      final result = UnifiedCreditResult.proceed();
      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isTrue);
      expect(result.client, isNull);
      expect(result.validationResult, isNull);
      expect(result.errorMessage, isNull);
    });

    test('notRequired() should allow proceeding without dialog', () {
      final result = UnifiedCreditResult.notRequired();
      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isTrue);
    });

    test('error() should block with error message', () {
      final result = UnifiedCreditResult.error('Test error');
      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isFalse);
      expect(result.errorMessage, 'Test error');
    });

    test('showDialog() should require dialog with details', () {
      final client = const Client(
        id: 1,
        name: 'Test Client',
        active: true,
        creditLimit: 1000,
      );
      const validationResult = CreditValidationResult(
        type: CreditCheckType.creditLimitExceeded,
        isValid: false,
        message: 'Credit limit exceeded',
      );
      final result = UnifiedCreditResult.showDialog(
        client: client,
        validationResult: validationResult,
        orderAmount: 500.0,
        isOnline: true,
      );
      expect(result.requiresDialog, isTrue);
      expect(result.canProceed, isFalse);
      expect(result.client, client);
      expect(result.validationResult, validationResult);
      expect(result.orderAmount, 500.0);
      expect(result.isOnline, isTrue);
    });

    test('default values should be correct', () {
      const result = UnifiedCreditResult(
        requiresDialog: false,
        canProceed: true,
      );
      expect(result.orderAmount, 0);
      expect(result.isOnline, isFalse);
      expect(result.client, isNull);
      expect(result.validationResult, isNull);
      expect(result.errorMessage, isNull);
    });
  });

  // ============================================================
  // validateCredit() — bypass flag
  // ============================================================
  group('validateCredit() — bypass', () {
    test('should return notRequired when bypassed and skipIfBypassed is true',
        () async {
      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
        isBypassed: true,
        skipIfBypassed: true,
      );

      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isTrue);
      // Should not call any repo methods
      verifyNever(() => mockClientRepo.getById(any()));
    });

    test('should NOT skip when isBypassed is true but skipIfBypassed is false',
        () async {
      // Need to set up mock since it will proceed with validation
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => null);

      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
        isBypassed: true,
        skipIfBypassed: false,
      );

      // It should proceed to look up the client
      verify(() => mockClientRepo.getById(1)).called(1);
      // Client not found -> notRequired
      expect(result.canProceed, isTrue);
    });
  });

  // ============================================================
  // validateCredit() — null client ID
  // ============================================================
  group('validateCredit() — null clientId', () {
    test('should return notRequired when clientId is null', () async {
      final result = await service.validateCredit(
        clientId: null,
        orderAmount: 500.0,
      );

      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isTrue);
      verifyNever(() => mockClientRepo.getById(any()));
    });
  });

  // ============================================================
  // validateCredit() — client not found
  // ============================================================
  group('validateCredit() — client not found', () {
    test('should return notRequired when client not found in local DB',
        () async {
      when(() => mockClientRepo.getById(99)).thenAnswer((_) async => null);

      final result = await service.validateCredit(
        clientId: 99,
        orderAmount: 500.0,
      );

      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isTrue);
    });
  });

  // ============================================================
  // validateCredit() — client without credit limit
  // ============================================================
  group('validateCredit() — no credit limit', () {
    test('should return proceed when client has no credit limit', () async {
      const client = Client(
        id: 1,
        name: 'No Credit Client',
        active: true,
        creditLimit: 0,
      );
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => client);

      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
      );

      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isTrue);
      // Should not call credit validation
      verifyNever(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: any(named: 'orderAmount'),
            isOnline: any(named: 'isOnline'),
            bypassCheck: any(named: 'bypassCheck'),
          ));
    });
  });

  // ============================================================
  // validateCredit() — credit validation passes
  // ============================================================
  group('validateCredit() — validation passes', () {
    test('should return proceed when credit validation is valid', () async {
      const client = Client(
        id: 1,
        name: 'Credit Client',
        active: true,
        creditLimit: 5000,
        usePartnerCreditLimit: true,
      );
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => client);
      when(() => mockClientRepo.isOnline).thenReturn(false);
      when(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: any(named: 'orderAmount'),
            isOnline: any(named: 'isOnline'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => CreditValidationResult.ok());

      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
      );

      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isTrue);
    });
  });

  // ============================================================
  // validateCredit() — credit validation fails
  // ============================================================
  group('validateCredit() — validation fails', () {
    test('should return showDialog when credit validation fails', () async {
      const client = Client(
        id: 1,
        name: 'Over-limit Client',
        active: true,
        creditLimit: 1000,
        usePartnerCreditLimit: true,
      );
      const failResult = CreditValidationResult(
        type: CreditCheckType.creditLimitExceeded,
        isValid: false,
        message: 'Credit limit exceeded',
      );
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => client);
      when(() => mockClientRepo.isOnline).thenReturn(false);
      when(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: any(named: 'orderAmount'),
            isOnline: any(named: 'isOnline'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => failResult);

      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 2000.0,
      );

      expect(result.requiresDialog, isTrue);
      expect(result.canProceed, isFalse);
      expect(result.client?.id, 1);
      expect(result.validationResult?.isValid, isFalse);
      expect(result.orderAmount, 2000.0);
    });
  });

  // ============================================================
  // validateCredit() — online refresh
  // ============================================================
  group('validateCredit() — online refresh', () {
    test('should attempt refresh when online and data is stale', () async {
      const staleClient = Client(
        id: 1,
        name: 'Stale Client',
        active: true,
        creditLimit: 5000,
        usePartnerCreditLimit: true,
        // creditLastSyncDate is null -> isCreditDataStale returns true
      );
      const freshClient = Client(
        id: 1,
        name: 'Stale Client',
        active: true,
        creditLimit: 5000,
        usePartnerCreditLimit: true,
        credit: 100,
      );
      when(() => mockClientRepo.getById(1))
          .thenAnswer((_) async => staleClient);
      when(() => mockClientRepo.isOnline).thenReturn(true);
      when(() => mockClientRepo.refreshCreditData(1))
          .thenAnswer((_) async => freshClient);
      when(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: any(named: 'orderAmount'),
            isOnline: any(named: 'isOnline'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => CreditValidationResult.ok());

      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
      );

      verify(() => mockClientRepo.refreshCreditData(1)).called(1);
      expect(result.canProceed, isTrue);
    });

    test('should continue with local data when refresh fails', () async {
      const staleClient = Client(
        id: 1,
        name: 'Stale Client',
        active: true,
        creditLimit: 5000,
        usePartnerCreditLimit: true,
      );
      when(() => mockClientRepo.getById(1))
          .thenAnswer((_) async => staleClient);
      when(() => mockClientRepo.isOnline).thenReturn(true);
      when(() => mockClientRepo.refreshCreditData(1))
          .thenThrow(Exception('Network error'));
      when(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: any(named: 'orderAmount'),
            isOnline: any(named: 'isOnline'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => CreditValidationResult.ok());

      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
      );

      // Should still succeed using local data
      expect(result.canProceed, isTrue);
    });
  });

  // ============================================================
  // validateCredit() — error handling
  // ============================================================
  group('validateCredit() — error handling', () {
    test('should return error when repository throws', () async {
      when(() => mockClientRepo.getById(1))
          .thenThrow(Exception('Database error'));

      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
      );

      expect(result.requiresDialog, isFalse);
      expect(result.canProceed, isFalse);
      expect(result.errorMessage, contains('Error al validar'));
    });

    test('should return error when credit service throws', () async {
      const client = Client(
        id: 1,
        name: 'Client',
        active: true,
        creditLimit: 5000,
        usePartnerCreditLimit: true,
      );
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => client);
      when(() => mockClientRepo.isOnline).thenReturn(false);
      when(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: any(named: 'orderAmount'),
            isOnline: any(named: 'isOnline'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenThrow(Exception('Credit service failure'));

      final result = await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
      );

      expect(result.canProceed, isFalse);
      expect(result.errorMessage, contains('Error al validar'));
    });
  });

  // ============================================================
  // validateCredit() — passes bypassCheck=false to credit service
  // ============================================================
  group('validateCredit() — credit service parameters', () {
    test('should pass bypassCheck=false to credit service', () async {
      const client = Client(
        id: 1,
        name: 'Client',
        active: true,
        creditLimit: 5000,
        usePartnerCreditLimit: true,
      );
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => client);
      when(() => mockClientRepo.isOnline).thenReturn(false);
      when(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: any(named: 'orderAmount'),
            isOnline: any(named: 'isOnline'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => CreditValidationResult.ok());

      await service.validateCredit(
        clientId: 1,
        orderAmount: 500.0,
      );

      verify(() => mockCreditService.validateOrderCreditForClient(
            client: client,
            orderAmount: 500.0,
            isOnline: false,
            bypassCheck: false,
          )).called(1);
    });

    test('should pass correct isOnline value to credit service', () async {
      const client = Client(
        id: 1,
        name: 'Client',
        active: true,
        creditLimit: 5000,
        usePartnerCreditLimit: true,
        // Non-stale data to avoid refresh attempt
        creditLastSyncDate: null,
      );
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => client);
      when(() => mockClientRepo.isOnline).thenReturn(true);
      when(() => mockClientRepo.refreshCreditData(1))
          .thenAnswer((_) async => client);
      when(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: any(named: 'orderAmount'),
            isOnline: any(named: 'isOnline'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => CreditValidationResult.ok());

      await service.validateCredit(
        clientId: 1,
        orderAmount: 100.0,
      );

      verify(() => mockCreditService.validateOrderCreditForClient(
            client: any(named: 'client'),
            orderAmount: 100.0,
            isOnline: true,
            bypassCheck: false,
          )).called(1);
    });
  });

  // ============================================================
  // hasClientCreditLimit()
  // ============================================================
  group('hasClientCreditLimit()', () {
    test('should return true when client has credit limit', () async {
      const client = Client(
        id: 1,
        name: 'Credit Client',
        active: true,
        creditLimit: 5000,
        usePartnerCreditLimit: true,
      );
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => client);

      final hasLimit = await service.hasClientCreditLimit(1);

      expect(hasLimit, isTrue);
    });

    test('should return false when client has no credit limit', () async {
      const client = Client(
        id: 1,
        name: 'No Credit Client',
        active: true,
        creditLimit: 0,
      );
      when(() => mockClientRepo.getById(1)).thenAnswer((_) async => client);

      final hasLimit = await service.hasClientCreditLimit(1);

      expect(hasLimit, isFalse);
    });

    test('should return false when client not found', () async {
      when(() => mockClientRepo.getById(99)).thenAnswer((_) async => null);

      final hasLimit = await service.hasClientCreditLimit(99);

      expect(hasLimit, isFalse);
    });

    test('should return false when repository throws', () async {
      when(() => mockClientRepo.getById(1))
          .thenThrow(Exception('Database error'));

      final hasLimit = await service.hasClientCreditLimit(1);

      expect(hasLimit, isFalse);
    });
  });
}
