import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show OdooConnectionException;
import 'package:theos_pos/features/advances/services/advance_service.dart'
    show AdvanceResult, AdvanceReturnResult, AdvanceService, PartnerBank;
import 'package:theos_pos/features/banks/repositories/bank_repository.dart';
import 'package:theos_pos/core/services/odoo_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide PartnerBank;

import '../../../mocks/mock_odoo_client.dart';

// ============================================================
// Mocks
// ============================================================

class MockOdooService extends Mock implements OdooService {}

class MockBankRepository extends Mock implements BankRepository {}

/// Tests for AdvanceService — focusing on testable pure logic:
///
/// Data classes:
/// - AdvanceResult — success/failure result
/// - PartnerBank — from Odoo data parsing + displayName
///
/// Validation logic in createAdvance():
/// - Reference length validation (must be >= 30 chars)
/// - Lines not empty validation
/// - Total lines amount > 0 validation
///
/// NOTE: Methods that call Odoo API (getAvailableAdvances, postAdvance,
/// cancelAdvance, getAvailableJournals, getBanks, getCardBrands,
/// getCardDeadlines, getDefaultDueDays, getMinReferenceLength) are NOT
/// tested here since they require a live Odoo connection or complex
/// manager/database mocking with global singletons.
void main() {
  // ============================================================
  // AdvanceResult data class
  // ============================================================
  group('AdvanceResult', () {
    test('should create success result with all fields', () {
      final result = AdvanceResult(
        success: true,
        advanceId: 42,
        advanceName: 'ANT/2024/001',
        amount: 1500.0,
      );

      expect(result.success, isTrue);
      expect(result.advanceId, 42);
      expect(result.advanceName, 'ANT/2024/001');
      expect(result.amount, 1500.0);
      expect(result.errorMessage, isNull);
    });

    test('should create failure result with error message', () {
      final result = AdvanceResult(
        success: false,
        errorMessage: 'La referencia debe tener al menos 30 caracteres',
      );

      expect(result.success, isFalse);
      expect(result.advanceId, isNull);
      expect(result.advanceName, isNull);
      expect(result.amount, isNull);
      expect(result.errorMessage, contains('referencia'));
    });

    test('should create minimal success result', () {
      final result = AdvanceResult(success: true);

      expect(result.success, isTrue);
      expect(result.advanceId, isNull);
      expect(result.advanceName, isNull);
      expect(result.amount, isNull);
      expect(result.errorMessage, isNull);
    });
  });

  group('AdvanceReturnResult', () {
    test('does not report completion while approval is pending', () {
      const result = AdvanceReturnResult(
        paymentId: 91,
        completed: false,
        requiresApproval: true,
      );

      expect(result.paymentId, 91);
      expect(result.completed, isFalse);
      expect(result.requiresApproval, isTrue);
    });
  });

  // ============================================================
  // PartnerBank data class
  // ============================================================
  group('PartnerBank', () {
    group('fromOdoo()', () {
      test('should parse Odoo 19.5 textual bank without inventing an ID', () {
        final data = {
          'id': 10,
          'account_number': '2200012345',
          'bank_name': 'Banco Pichincha',
        };

        final bank = PartnerBank.fromOdoo(data);

        expect(bank.id, 10);
        expect(bank.accountNumber, '2200012345');
        expect(bank.bankId, isNull);
        expect(bank.bankName, 'Banco Pichincha');
      });

      test('should parse an unset Odoo bank name', () {
        final data = {
          'id': 11,
          'account_number': '3300098765',
          'bank_name': false,
        };

        final bank = PartnerBank.fromOdoo(data);

        expect(bank.id, 11);
        expect(bank.accountNumber, '3300098765');
        expect(bank.bankId, isNull);
        expect(bank.bankName, isNull);
      });

      test('should parse bank data with empty bank_id list', () {
        final data = {
          'id': 12,
          'account_number': '1100011111',
          'bank_id': <dynamic>[],
        };

        final bank = PartnerBank.fromOdoo(data);

        expect(bank.id, 12);
        expect(bank.accountNumber, '1100011111');
        expect(bank.bankId, isNull);
        expect(bank.bankName, isNull);
      });

      test('should parse bank data with single-element bank_id list', () {
        // Edge case: list with only ID, no name
        final data = {
          'id': 13,
          'account_number': '5500055555',
          'bank_id': [7],
        };

        final bank = PartnerBank.fromOdoo(data);

        expect(bank.id, 13);
        expect(bank.accountNumber, '5500055555');
        // List has only 1 element (length < 2), so bank info not extracted
        expect(bank.bankId, isNull);
        expect(bank.bankName, isNull);
      });
    });

    group('displayName', () {
      test('should show bank name and account number when bank is set', () {
        final bank = PartnerBank(
          id: 1,
          accountNumber: '2200012345',
          bankId: 5,
          bankName: 'Banco Pichincha',
        );

        expect(bank.displayName, 'Banco Pichincha - 2200012345');
      });

      test('should show only account number when no bank name', () {
        final bank = PartnerBank(id: 1, accountNumber: '2200012345');

        expect(bank.displayName, '2200012345');
      });

      test('should show only account number when bank name is null', () {
        final bank = PartnerBank(
          id: 1,
          accountNumber: '9900099999',
          bankId: 5,
          bankName: null,
        );

        expect(bank.displayName, '9900099999');
      });
    });

    group('constructor', () {
      test('should create with all fields', () {
        final bank = PartnerBank(
          id: 10,
          accountNumber: '2200012345',
          bankId: 5,
          bankName: 'Banco Guayaquil',
        );

        expect(bank.id, 10);
        expect(bank.accountNumber, '2200012345');
        expect(bank.bankId, 5);
        expect(bank.bankName, 'Banco Guayaquil');
      });

      test('should create with required fields only', () {
        final bank = PartnerBank(id: 1, accountNumber: '0000000000');

        expect(bank.id, 1);
        expect(bank.accountNumber, '0000000000');
        expect(bank.bankId, isNull);
        expect(bank.bankName, isNull);
      });
    });
  });

  // ============================================================
  // AdvanceService.createAdvance() — validation logic
  // ============================================================
  group('AdvanceService.createAdvance() — validation', () {
    late MockOdooService mockOdoo;
    late MockBankRepository mockBankRepo;
    late AdvanceService service;
    late AppDatabase database;

    setUp(() {
      mockOdoo = MockOdooService();
      mockBankRepo = MockBankRepository();
      service = AdvanceService(mockOdoo, mockBankRepo, null);
      // createAdvance persiste primero en Drift (offline-first): el manager
      // global necesita una BD en memoria para resolver account_advance.
      database = AppDatabase(NativeDatabase.memory());
      advanceManager.initDb(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('should fail when reference is too short', () async {
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'short ref',
        amount: 100.0,
        lines: [const AdvanceLine(id: -1, journalId: 1, amount: 100.0)],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('30 caracteres'));
      // Should not call Odoo
      verifyNever(
        () => mockOdoo.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          kwargs: any(named: 'kwargs'),
        ),
      );
    });

    test('should fail when lines are empty', () async {
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30, // Exactly 30 chars
        amount: 100.0,
        lines: const [],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('método de pago'));
    });

    test('should fail when total line amount is zero', () async {
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: 0.0,
        lines: [const AdvanceLine(id: -1, journalId: 1, amount: 0.0)],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('mayor a cero'));
    });

    test('should fail when total line amount is negative', () async {
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: -50.0,
        lines: [const AdvanceLine(id: -1, journalId: 1, amount: -50.0)],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('mayor a cero'));
    });

    test(
      'should accept reference with exactly 30 characters and valid lines',
      () async {
        // This test verifies that validation passes and the service attempts
        // to call Odoo (which we mock to return an ID).
        when(
          () => mockOdoo.call(
            model: any(named: 'model'),
            method: any(named: 'method'),
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer((_) async => [99]);

        final advance = Advance(
          date: DateTime.now(),
          dateEstimated: DateTime.now().add(const Duration(days: 30)),
          advanceType: AdvanceType.inbound,
          partnerId: 1,
          reference: 'R' * 30,
          amount: 500.0,
          lines: [const AdvanceLine(id: -1, journalId: 1, amount: 500.0)],
        );

        final result = await service.createAdvance(advance);

        expect(result.success, isTrue);
        expect(result.advanceId, 99);
        final calls = verify(
          () => mockOdoo.call(
            model: 'account.advance',
            method: 'create',
            kwargs: captureAny(named: 'kwargs'),
          ),
        ).captured;
        final payload = calls.single as Map<String, dynamic>;
        final values = (payload['vals_list'] as List).single as Map;
        final command = (values['advance_line_ids'] as List).single as List;
        expect(command.take(2), [0, 0]);
        expect(command[2], containsPair('journal_id', 1));
        expect(command[2], containsPair('amount', 500.0));
        expect(command[2], isNot(contains('id')));
      },
    );

    test('should accept reference longer than 30 characters', () async {
      when(
        () => mockOdoo.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async => 77);

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'REF-${'X' * 50}',
        amount: 200.0,
        lines: [const AdvanceLine(id: -1, journalId: 1, amount: 200.0)],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isTrue);
      expect(result.advanceId, 77);
    });

    test('should reject an invalid null create response', () async {
      when(
        () => mockOdoo.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async => null);

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: 100.0,
        lines: [const AdvanceLine(id: -1, journalId: 1, amount: 100.0)],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.advanceId, isNull);
      expect(result.errorMessage, isNotEmpty);
    });

    test(
      'should not convert an unknown server failure into offline success',
      () async {
        when(
          () => mockOdoo.call(
            model: any(named: 'model'),
            method: any(named: 'method'),
            kwargs: any(named: 'kwargs'),
          ),
        ).thenThrow(Exception('Connection refused'));

        final advance = Advance(
          date: DateTime.now(),
          dateEstimated: DateTime.now().add(const Duration(days: 30)),
          advanceType: AdvanceType.inbound,
          partnerId: 1,
          reference: 'A' * 30,
          amount: 100.0,
          lines: [const AdvanceLine(id: -1, journalId: 1, amount: 100.0)],
        );

        final result = await service.createAdvance(advance);

        expect(result.success, isFalse);
        expect(result.advanceId, isNull);
      },
    );

    test('should queue only a typed connectivity failure', () async {
      when(
        () => mockOdoo.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenThrow(const OdooConnectionException());

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: 100.0,
        lines: const [AdvanceLine(id: -1, journalId: 1, amount: 100.0)],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isTrue);
      expect(result.advanceId, isNegative);
      expect(result.errorMessage, contains('Se sincronizará'));
    });

    test('should sum multiple line amounts for validation', () async {
      when(
        () => mockOdoo.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async => [55]);

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: 300.0,
        lines: [
          const AdvanceLine(id: -1, journalId: 1, amount: 150.0),
          const AdvanceLine(id: -2, journalId: 2, amount: 150.0),
        ],
      );

      final result = await service.createAdvance(advance);

      // Total lines = 300.0 > 0, validation passes
      expect(result.success, isTrue);
    });

    test(
      'return uses the canonical wizard and keeps pending approval explicit',
      () async {
        final onlineClient = MockOdooClient.online();
        when(() => mockOdoo.client).thenReturn(onlineClient);
        await advanceManager.upsertLocal(
          Advance(
            id: 77,
            name: 'ANT/77',
            date: DateTime(2026, 8, 26),
            state: AdvanceState.posted,
            advanceType: AdvanceType.inbound,
            partnerId: 3,
            reference: 'R' * 30,
            amount: 100,
            amountAvailable: 100,
          ),
        );
        when(
          () => mockOdoo.call(
            model: 'account.advance.line',
            method: 'search_read',
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer(
          (_) async => [
            {
              'journal_id': [4, 'Banco'],
            },
          ],
        );
        when(
          () => mockOdoo.call(
            model: 'account.payment.method.line',
            method: 'search_read',
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer(
          (_) async => [
            {'id': 6, 'code': 'manual', 'name': 'Manual'},
          ],
        );
        when(
          () => mockOdoo.call(
            model: 'account.advance.return.wizard',
            method: 'create',
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer((_) async => 88);
        when(
          () => mockOdoo.call(
            model: 'account.advance.return.wizard',
            method: 'action_confirm',
            ids: [88],
          ),
        ).thenAnswer(
          (_) async => {
            'res_model': 'account.payment',
            'res_id': 99,
            'context': {'l10n_ec_pago_pendiente': true},
          },
        );
        when(
          () => mockOdoo.call(
            model: 'account.advance',
            method: 'search_read',
            kwargs: any(named: 'kwargs'),
          ),
        ).thenAnswer(
          (_) async => [
            {
              'id': 77,
              'name': 'ANT/77',
              'date': '2026-08-26',
              'state': 'posted',
              'advance_type': 'inbound',
              'partner_id': [3, 'Cliente'],
              'reference': 'R' * 30,
              'amount': 100.0,
              'amount_used': 0.0,
              'amount_available': 100.0,
              'amount_returned': 0.0,
            },
          ],
        );

        final result = await service.returnAdvance(77);

        expect(result.paymentId, 99);
        expect(result.completed, isFalse);
        expect(result.requiresApproval, isTrue);
        final create = verify(
          () => mockOdoo.call(
            model: 'account.advance.return.wizard',
            method: 'create',
            kwargs: captureAny(named: 'kwargs'),
          ),
        );
        final kwargs = create.captured.single as Map<String, dynamic>;
        final vals = (kwargs['vals_list'] as List).single as Map;
        expect(vals['advance_id'], 77);
        expect(vals['amount'], 100.0);
        expect(vals['journal_id'], 4);
        expect(vals['payment_method_line_id'], 6);
      },
    );
  });

  group('AdvanceService.getAdvance() — line snapshot', () {
    late MockBankRepository bankRepo;
    late Directory tempDir;
    late AppDatabase database;

    final header = <String, dynamic>{
      'id': 42,
      'name': 'ADV/42',
      'date': '2026-09-05',
      'advance_type': 'inbound',
      'partner_id': [7, 'Cliente'],
      'reference': 'Referencia de prueba suficientemente larga',
      'amount': 25.0,
      'amount_available': 25.0,
      'advance_line_ids': [101],
    };
    final child = <String, dynamic>{
      'id': 101,
      'journal_id': [3, 'Caja'],
      'amount': 25.0,
    };

    setUp(() async {
      bankRepo = MockBankRepository();
      tempDir = await Directory.systemTemp.createTemp('advance-lines-');
      database = AppDatabase(NativeDatabase(File('${tempDir.path}/db.sqlite')));
      advanceManager.initDb(database);
      advanceLineManager.initDb(database);
    });

    tearDown(() async {
      await database.close();
      await tempDir.delete(recursive: true);
    });

    test('loads child rows and retains them after reopening offline', () async {
      final online = MockOdooService();
      when(() => online.call(
            model: 'account.advance',
            method: 'search_read',
            kwargs: any(named: 'kwargs'),
          )).thenAnswer((_) async => [header]);
      when(() => online.call(
            model: 'account.advance.line',
            method: 'search_read',
            kwargs: any(named: 'kwargs'),
          )).thenAnswer((_) async => [child]);

      final fetched = await AdvanceService(online, bankRepo, null).getAdvance(42);
      expect(fetched?.lines.single.id, 101);

      await database.close();
      database = AppDatabase(NativeDatabase(File('${tempDir.path}/db.sqlite')));
      advanceManager.initDb(database);
      advanceLineManager.initDb(database);
      final offline = MockOdooService();
      final reopened = await AdvanceService(offline, bankRepo, null).getAdvance(42);
      expect(reopened?.lines.single.id, 101);
      expect(reopened?.lines.single.amount, 25.0);
    });

    test('replaces the complete remote line snapshot, including empty', () async {
      final online = MockOdooService();
      var headerCall = 0;
      var childCall = 0;
      when(() => online.call(model: 'account.advance', method: 'search_read', kwargs: any(named: 'kwargs')))
          .thenAnswer((_) async {
        headerCall++;
        final ids = headerCall == 1 ? [101, 102] : headerCall == 2 ? [102] : <int>[];
        return [{...header, 'advance_line_ids': ids}];
      });
      when(() => online.call(model: 'account.advance.line', method: 'search_read', kwargs: any(named: 'kwargs')))
          .thenAnswer((_) async {
        childCall++;
        return childCall == 1 ? [child, {...child, 'id': 102, 'amount': 10.0}] : [{...child, 'id': 102, 'amount': 10.0}];
      });
      final service = AdvanceService(online, bankRepo, null);
      expect((await service.getAdvance(42))!.lines.map((l) => l.id), [101, 102]);
      expect((await service.refreshAdvance(42))!.lines.map((l) => l.id), [102]);
      expect((await service.refreshAdvance(42))!.lines, isEmpty);
    });

    test('keeps the previous snapshot when child payload is incomplete', () async {
      final seed = Advance(id: 42, date: DateTime(2026, 9, 5), advanceType: AdvanceType.inbound,
          partnerId: 7, reference: 'snapshot', lines: [const AdvanceLine(id: 101, journalId: 3, amount: 25)]);
      await advanceManager.upsertLocalWithLines(seed);
      final online = MockOdooService();
      when(() => online.call(model: 'account.advance', method: 'search_read', kwargs: any(named: 'kwargs')))
          .thenAnswer((_) async => [{...header, 'advance_line_ids': [101, 102]}]);
      when(() => online.call(model: 'account.advance.line', method: 'search_read', kwargs: any(named: 'kwargs')))
          .thenAnswer((_) async => [child]);
      final result = await AdvanceService(online, bankRepo, null).refreshAdvance(42);
      expect(result?.reference, 'snapshot');
      expect(result?.lines.map((l) => l.id), [101]);
    });

    test('persists two default-id local lines for separate advances', () async {
      final online = MockOdooService();
      var created = 0;
      when(() => online.call(model: any(named: 'model'), method: any(named: 'method'), kwargs: any(named: 'kwargs')))
          .thenAnswer((_) async => [++created == 1 ? 201 : 202]);
      Advance make(int journal) => Advance(date: DateTime(2026, 9, 5), advanceType: AdvanceType.inbound,
          partnerId: 7, reference: 'R' * 30, lines: [AdvanceLine(journalId: journal, amount: 5), AdvanceLine(journalId: journal + 10, amount: 7)]);
      final service = AdvanceService(online, bankRepo, null);
      expect((await service.createAdvance(make(3))).success, isTrue);
      expect((await service.createAdvance(make(4))).success, isTrue);
      expect((await advanceManager.readLocalWithLines(201))!.lines.map((l) => l.journalId), [3, 13]);
      expect((await advanceManager.readLocalWithLines(201))!.lines.map((l) => l.amount), [5, 7]);
      expect((await advanceManager.readLocalWithLines(202))!.lines.map((l) => l.journalId), [4, 14]);
      expect((await advanceManager.readLocalWithLines(202))!.lines.map((l) => l.amount), [5, 7]);
    });

    test('keeps snapshot for malformed one2many and child rows', () async {
      final seed = Advance(id: 42, date: DateTime(2026, 9, 5), advanceType: AdvanceType.inbound,
          partnerId: 7, reference: 'snapshot', lines: [const AdvanceLine(id: 101, journalId: 3, amount: 25)]);
      await advanceManager.upsertLocalWithLines(seed);
      final online = MockOdooService();
      when(() => online.call(model: 'account.advance', method: 'search_read', kwargs: any(named: 'kwargs')))
          .thenAnswer((_) async => [{...header, 'advance_line_ids': 'not-a-list'}]);
      when(() => online.call(model: 'account.advance.line', method: 'search_read', kwargs: any(named: 'kwargs')))
          .thenAnswer((_) async => [child, 'invalid']);
      final result = await AdvanceService(online, bankRepo, null).refreshAdvance(42);
      expect(result?.reference, 'snapshot');
      expect(result?.lines.map((l) => l.id), [101]);
    });
  });
}
