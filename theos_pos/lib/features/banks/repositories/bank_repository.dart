import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Provider for BankRepository
final bankRepositoryProvider = Provider<BankRepository?>((ref) {
  // This will be initialized when the app database is ready
  // For now, return null and let features handle null checks
  return null;
});

/// Repository for Bank-related operations using theos_pos_core database
///
/// Follows offline-first pattern: all CUD operations save locally first,
/// then queue for Odoo sync via OfflineQueueDataSource.
class BankRepository {
  final AppDatabase _db;
  final OdooClient? _odooClient;
  final OfflineQueueDataSource? _offlineQueue;

  BankRepository({
    required AppDatabase db,
    OdooClient? odooClient,
    OfflineQueueDataSource? offlineQueue,
  })  : _db = db,
        _odooClient = odooClient,
        _offlineQueue = offlineQueue;

  // ════════════════════════════════════════════════════════════════════════════
  // PartnerBank Operations
  // ════════════════════════════════════════════════════════════════════════════

  /// Get partner banks by partner ID
  /// Returns ResPartnerBankData records from the database
  Future<List<ResPartnerBankData>> getPartnerBanks(int partnerId) async {
    final query = _db.select(_db.resPartnerBank)
      ..where((t) => t.partnerId.equals(partnerId) & t.active.equals(true))
      ..orderBy([
        (t) => drift.OrderingTerm(
              expression: t.sequence,
              mode: drift.OrderingMode.asc,
            ),
      ]);

    return await query.get();
  }

  /// Reactive stream of partner banks by partner ID — mismo query que
  /// [getPartnerBanks] pero con `.watch()`.
  ///
  /// NOTA: `res_partner_bank` ya tiene `bank_name` como columna
  /// desnormalizada (cacheada al sincronizar) — no hace falta ningún join
  /// manual con una tabla/manager de `res.bank` para resolver el nombre del
  /// banco, el dato ya está en la misma fila.
  Stream<List<ResPartnerBankData>> watchPartnerBanks(int partnerId) {
    final query = _db.select(_db.resPartnerBank)
      ..where((t) => t.partnerId.equals(partnerId) & t.active.equals(true))
      ..orderBy([
        (t) => drift.OrderingTerm(
              expression: t.sequence,
              mode: drift.OrderingMode.asc,
            ),
      ]);

    return query.watch();
  }

  /// Resuelve el nombre del banco desde la tabla local res_bank.
  ///
  /// En 19.2/19.5 res.partner.bank ya no tiene bank_id (Many2one) — el banco
  /// viaja como texto plano en bank_name, así que el nombre se resuelve
  /// localmente antes de encolar la operación.
  Future<String?> _resolveBankName(int? bankId) async {
    if (bankId == null) return null;
    final bank = await (_db.select(_db.resBank)
          ..where((t) => t.odooId.equals(bankId)))
        .getSingleOrNull();
    return bank?.name;
  }

  /// Create a new partner bank account
  Future<ResPartnerBankData?> createPartnerBank({
    required int partnerId,
    required String accNumber,
    int? bankId,
    String? accHolderName,
  }) async {
    try {
      // Generate a temporary negative ID for offline creation
      final tempId = DateTime.now().millisecondsSinceEpoch * -1;

      final companion = ResPartnerBankCompanion.insert(
        odooId: tempId,
        partnerId: partnerId,
        accNumber: accNumber,
        bankId: drift.Value(bankId),
        accHolderName: drift.Value(accHolderName),
        active: const drift.Value(true),
        isSynced: const drift.Value(false), // Mark as needing sync
        writeDate: drift.Value(DateTime.now()),
      );

      final id = await _db.into(_db.resPartnerBank).insert(companion);

      // Queue for offline sync
      if (_offlineQueue != null) {
        // Campos verificados contra el servidor (19.2/19.5, julio 2026):
        // acc_number → account_number (renombrado); bank_id y acc_holder_name
        // YA NO existen en res.partner.bank — el banco viaja como texto plano
        // en bank_name (se resuelve el nombre desde la tabla local res_bank).
        final bankName = await _resolveBankName(bankId);
        await _offlineQueue.queueOperation(
          model: 'res.partner.bank',
          method: 'create',
          recordId: tempId,
          values: {
            'partner_id': partnerId,
            'account_number': accNumber,
            'bank_name': ?bankName,
          },
        );
      }

      // Retrieve the inserted record
      final query = _db.select(_db.resPartnerBank)
        ..where((t) => t.id.equals(id));
      return await query.getSingleOrNull();
    } catch (e) {
      return null;
    }
  }

  /// Update a partner bank account
  Future<bool> updatePartnerBank({
    required int id,
    String? accNumber,
    int? bankId,
    String? accHolderName,
  }) async {
    try {
      final companion = ResPartnerBankCompanion(
        accNumber: accNumber != null ? drift.Value(accNumber) : const drift.Value.absent(),
        bankId: bankId != null ? drift.Value(bankId) : const drift.Value.absent(),
        accHolderName: accHolderName != null ? drift.Value(accHolderName) : const drift.Value.absent(),
        isSynced: const drift.Value(false),
        writeDate: drift.Value(DateTime.now()),
      );

      final stmt = _db.update(_db.resPartnerBank)
        ..where((t) => t.id.equals(id));

      final count = await stmt.write(companion);

      if (count > 0 && _offlineQueue != null) {
        // Get the odoo_id for this record to queue the operation
        final record = await (_db.select(_db.resPartnerBank)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (record != null) {
          // Mismos campos verificados que en createPartnerBank (19.2/19.5):
          // account_number (renombrado) + bank_name (texto plano).
          final values = <String, dynamic>{};
          if (accNumber != null) values['account_number'] = accNumber;
          if (bankId != null) {
            final bankName = await _resolveBankName(bankId);
            if (bankName != null) values['bank_name'] = bankName;
          }

          await _offlineQueue.queueOperation(
            model: 'res.partner.bank',
            method: 'write',
            recordId: record.odooId,
            values: values,
          );
        }
      }

      return count > 0;
    } catch (e) {
      return false;
    }
  }

  /// Delete a partner bank account (soft delete by setting active=false)
  Future<bool> deletePartnerBank(int id) async {
    try {
      // Get odoo_id before soft-deleting
      final record = await (_db.select(_db.resPartnerBank)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      final stmt = _db.update(_db.resPartnerBank)
        ..where((t) => t.id.equals(id));

      final count = await stmt.write(
        const ResPartnerBankCompanion(
          active: drift.Value(false),
          isSynced: drift.Value(false),
        ),
      );

      if (count > 0 && _offlineQueue != null && record != null && record.odooId > 0) {
        await _offlineQueue.queueOperation(
          model: 'res.partner.bank',
          method: 'write',
          recordId: record.odooId,
          values: {'active': false},
        );
      }

      return count > 0;
    } catch (e) {
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Bank Operations
  // ════════════════════════════════════════════════════════════════════════════

  /// Get all active banks
  Future<List<ResBankData>> getAllBanks() async {
    final query = _db.select(_db.resBank)
      ..where((t) => t.active.equals(true))
      ..orderBy([
        (t) => drift.OrderingTerm(expression: t.name),
      ]);

    return await query.get();
  }

  /// Get bank by ID
  Future<ResBankData?> getBank(int odooId) async {
    final query = _db.select(_db.resBank)
      ..where((t) => t.odooId.equals(odooId));

    return await query.getSingleOrNull();
  }

  /// Search banks by name or BIC
  Future<List<ResBankData>> searchBanks(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return [];

    final lowerQuery = searchTerm.toLowerCase();
    final query = _db.select(_db.resBank)
      ..where((t) =>
          t.active.equals(true) &
          (t.name.lower().contains(lowerQuery) |
              t.bic.lower().contains(lowerQuery)))
      ..limit(50);

    return await query.get();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Sync Operations
  // ════════════════════════════════════════════════════════════════════════════

  /// Get all partner banks that need to be synced to Odoo
  Future<List<ResPartnerBankData>> getUnsyncedPartnerBanks() async {
    final query = _db.select(_db.resPartnerBank)
      ..where((t) => t.isSynced.equals(false));

    return await query.get();
  }

  /// Mark a partner bank as synced and update its Odoo ID
  Future<bool> markPartnerBankAsSynced(int localId, int odooId) async {
    try {
      final stmt = _db.update(_db.resPartnerBank)
        ..where((t) => t.id.equals(localId));

      final count = await stmt.write(
        ResPartnerBankCompanion(
          odooId: drift.Value(odooId),
          isSynced: const drift.Value(true),
        ),
      );

      return count > 0;
    } catch (e) {
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Bank Operations
  // ════════════════════════════════════════════════════════════════════════════

  /// Get all banks from the database
  Future<List<ResBankData>> getBanks() async {
    return await (_db.select(_db.resBank)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Reactive stream of all active banks from the local database.
  ///
  /// Mismo query que [getBanks] pero con `.watch()` — la UI se actualiza
  /// sola cuando la tabla `res_bank` cambia (ej. tras sincronizar catálogo),
  /// sin necesitar `ref.invalidate()` manual.
  ///
  /// NOTA: no existe un `bankManager` generado para el modelo `Bank`
  /// (`res.bank` no tiene `.odoo.g.dart` — el `@OdooModel` no se ha
  /// regenerado para este modelo), así que este método usa `.watch()` de
  /// Drift directo sobre la misma tabla `res_bank`, en vez de
  /// `bankManager.watchLocalSearch()` (que hoy no compila). Mismo resultado
  /// reactivo, sin depender de código generado inexistente.
  Stream<List<ResBankData>> watchBanks() {
    return (_db.select(_db.resBank)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Sync banks from Odoo (res.bank was removed in Odoo 19.2)
  Future<int> syncBanks({int limit = 100}) async {
    if (_odooClient == null) return 0;
    // res.bank doesn't exist in Odoo 19.2+
    if (!_odooClient.version.hasBankModel) return 0;

    try {
      final banks = await _odooClient.searchRead(
        model: 'res.bank',
        domain: [],
        fields: ['name', 'bic', 'active'],
        limit: limit,
      );

      int syncCount = 0;
      for (final bank in banks) {
        final id = bank['id'] as int;
        final name = bank['name'] as String? ?? '';
        final bic = bank['bic'] as String?;
        final active = bank['active'] as bool? ?? true;

        await _db.into(_db.resBank).insert(
          ResBankCompanion.insert(
            odooId: id,
            name: name,
            bic: drift.Value(bic),
            active: drift.Value(active),
            writeDate: drift.Value(DateTime.now()),
          ),
          onConflict: drift.DoUpdate(
            (old) => ResBankCompanion(
              name: drift.Value(name),
              bic: drift.Value(bic),
              active: drift.Value(active),
              writeDate: drift.Value(DateTime.now()),
            ),
          ),
        );
        syncCount++;
      }

      return syncCount;
    } catch (e) {
      return 0;
    }
  }
}
