import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../features/banks/repositories/bank_repository.dart';
import '../../../core/services/odoo_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import 'payment_service_models.dart';

const _uuid = Uuid();

/// Servicio para bancos, marcas de tarjeta, plazos y lotes de tarjetas
/// (sync-on-demand contra Odoo cuando falta info local).
///
/// Extraído tal cual de `payment_service.dart` como parte de la
/// descomposición sin cambio de comportamiento (Fase E2, sección 3 del plan
/// de descomposición). `PaymentService` delega aquí (facade).
///
/// NOTA (del plan de descomposición): hay overlap conceptual con el sync de
/// cards en `catalog_sync_repository.dart` — NO consolidar en este refactor,
/// queda señalado para auditoría aparte con integration-engineer.
class CardPaymentSyncService {
  final OdooService _odoo;
  final BankRepository _bankRepo;
  final AppDatabase _db;

  CardPaymentSyncService(this._odoo, this._bankRepo, this._db);

  /// Obtiene los bancos disponibles (delegado a BankRepository)
  ///
  /// Lee de la tabla local `res_bank` (offline-first). NOTA: pese al
  /// comentario histórico, el código actual no sincroniza on-demand desde
  /// Odoo si la tabla está vacía — `res_bank` se llena vía el flujo general
  /// de sync de catálogo, no acá.
  Future<List<AvailableBank>> getBanks() async {
    try {
      final banks = await _bankRepo.getBanks();
      return banks
          .map((b) => AvailableBank(id: b.odooId, name: b.name))
          .toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting banks', e, st);
      return [];
    }
  }

  /// Reactive stream of available banks — mismo dato que [getBanks] pero
  /// reactivo, usando [BankRepository.watchBanks].
  Stream<List<AvailableBank>> watchBanks() {
    return _bankRepo.watchBanks().map(
          (banks) =>
              banks.map((b) => AvailableBank(id: b.odooId, name: b.name)).toList(),
        );
  }

  /// Obtiene las marcas de tarjeta configuradas para un diario (sync-on-demand)
  /// Si las marcas no están en local, sincroniza desde Odoo primero
  Future<List<CardBrand>> getCardBrands(int journalId) async {
    try {
      logger.d('[PaymentService]', 'getCardBrands($journalId) START');

      // 1. Obtener el diario de la base local por odooId
      final journal = await (_db.select(_db.accountJournal)
            ..where((t) => t.odooId.equals(journalId)))
          .getSingleOrNull();

      if (journal == null) {
        logger.w('[PaymentService]', 'Journal $journalId not found locally');
        return [];
      }

      logger.d('[PaymentService]', 'Journal found: ${journal.name}, cardBrandIds raw: ${journal.cardBrandIds}');

      // Decodificar IDs de marcas del JSON
      final brandIds = decodeCsvIntList(journal.cardBrandIds);
      logger.d('[PaymentService]', 'Decoded brandIds: $brandIds');

      // Si el diario NO tiene marcas configuradas, retornar lista vacía
      if (brandIds.isEmpty) {
        logger.d('[PaymentService]', 'Journal $journalId has no configured card brands');
        return [];
      }

      // 2. Obtener las marcas de la base local
      var brands = await (_db.select(_db.accountCreditCardBrand)
            ..where((t) => t.odooId.isIn(brandIds))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

      logger.d('[PaymentService]', 'Brands from DB (filtered): ${brands.map((b) => '${b.odooId}:${b.name}').join(', ')}');

      // 3. Si faltan marcas, sincronizar desde Odoo
      if (brands.isEmpty || brands.length < brandIds.length) {
        logger.d('[PaymentService]', 'Card brands incomplete locally, syncing from Odoo...');
        await _syncCardBrandsFromOdoo(brandIds);

        // Recargar desde local
        brands = await (_db.select(_db.accountCreditCardBrand)
              ..where((t) => t.odooId.isIn(brandIds))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
      }

      final result = brands.map((b) => CardBrand(id: b.odooId, name: b.name)).toList();
      logger.d('[PaymentService]', 'getCardBrands returning ${result.length} brands: ${result.map((b) => b.name).join(', ')}');
      return result;
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting card brands', e, st);
      return [];
    }
  }

  /// Reactive stream de marcas de tarjeta configuradas para un diario.
  ///
  /// Ítem 1, Grupo B del plan de reactividad (`d-flutter.md`): no se
  /// promovió `AccountCreditCardBrand` a `@OdooModel` (fuera de alcance) —
  /// en su lugar, se combina el `.watch()` del diario (que trae
  /// `cardBrandIds` JSON-encoded) con el `.watch()` de la tabla de marcas,
  /// usando el mismo criterio de decodificación/filtrado que [getCardBrands]
  /// (`decodeCsvIntList` + `isIn` + orden por nombre).
  ///
  /// Se re-suscribe a la tabla de marcas cada vez que cambia el diario (o la
  /// lista de IDs configurados) vía [_switchMap] — evita agregar `rxdart`
  /// como dependencia directa solo para esto (hoy solo llega transitivamente,
  /// no está declarado en `pubspec.yaml`).
  ///
  /// NOTA: esto NO reemplaza el sync-on-demand de [getCardBrands] — sigue
  /// siendo el camino de sync inicial cuando faltan marcas localmente. Este
  /// stream solo refleja lo que ya hay en local.
  Stream<List<CardBrand>> watchCardBrandsByJournal(int journalId) {
    final journalStream = (_db.select(_db.accountJournal)
          ..where((t) => t.odooId.equals(journalId)))
        .watchSingleOrNull();

    return _switchMap(journalStream, (journal) {
      if (journal == null) return Stream.value(<CardBrand>[]);

      final brandIds = decodeCsvIntList(journal.cardBrandIds);
      if (brandIds.isEmpty) return Stream.value(<CardBrand>[]);

      return (_db.select(_db.accountCreditCardBrand)
            ..where((t) => t.odooId.isIn(brandIds))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch()
          .map((brands) =>
              brands.map((b) => CardBrand(id: b.odooId, name: b.name)).toList());
    });
  }

  /// Sincroniza marcas de tarjeta desde Odoo
  Future<void> _syncCardBrandsFromOdoo(List<int> brandIds) async {
    try {
      final result = await _odoo.call(
        model: 'account.credit.card.brand',
        method: 'search_read',
        kwargs: {
          'domain': [['id', 'in', brandIds]],
          'fields': ['id', 'name', 'code', 'credit', 'debit', 'active', 'company_id'],
        },
      );

      if (result == null || result is! List) return;

      for (final b in result) {
        final odooId = b['id'] as int;

        final companion = AccountCreditCardBrandCompanion(
          odooId: Value(odooId),
          name: Value(b['name'] as String? ?? ''),
          code: Value(b['code'] as String?),
          active: Value(b['active'] as bool? ?? true),
        );

        final existing = await (_db.select(_db.accountCreditCardBrand)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_db.update(_db.accountCreditCardBrand)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _db.into(_db.accountCreditCardBrand).insert(companion);
        }
      }
      logger.d('[PaymentService]', 'Synced ${result.length} card brands from Odoo');
    } catch (e) {
      logger.w('[PaymentService]', 'Could not sync card brands from Odoo: $e');
    }
  }

  /// Obtiene los plazos de tarjeta configurados para un diario (sync-on-demand)
  /// Si los plazos no están en local, sincroniza desde Odoo primero
  Future<List<CardDeadline>> getCardDeadlines(int journalId, CardType cardType) async {
    try {
      // 1. Obtener el diario de la base local
      final journal = await (_db.select(_db.accountJournal)
            ..where((t) => t.odooId.equals(journalId)))
          .getSingleOrNull();

      if (journal == null) {
        logger.w('[PaymentService]', 'Journal $journalId not found locally');
        return [];
      }

      // Decodificar IDs de plazos según el tipo de tarjeta
      final deadlineIds = cardType == CardType.credit
          ? decodeCsvIntList(journal.cardDeadlineCreditIds)
          : decodeCsvIntList(journal.cardDeadlineDebitIds);

      // Si no hay plazos configurados, retornar lista vacía
      if (deadlineIds.isEmpty) {
        logger.d('[PaymentService]', 'Journal $journalId has no configured ${cardType.name} deadlines');
        return [];
      }

      // 2. Obtener los plazos de la base local
      var deadlines = await (_db.select(_db.accountCreditCardDeadline)
            ..where((t) => t.odooId.isIn(deadlineIds))
            ..orderBy([
              (t) => OrderingTerm.asc(t.name),
            ]))
          .get();

      // 3. Si faltan plazos, sincronizar desde Odoo
      if (deadlines.isEmpty || deadlines.length < deadlineIds.length) {
        logger.d('[PaymentService]', 'Card deadlines incomplete locally, syncing from Odoo...');
        await _syncCardDeadlinesFromOdoo(deadlineIds);

        // Recargar desde local
        deadlines = await (_db.select(_db.accountCreditCardDeadline)
              ..where((t) => t.odooId.isIn(deadlineIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.name),
              ]))
            .get();
      }

      return deadlines.map((d) => CardDeadline(
        id: d.odooId,
        name: d.name,
        deadlineDays: d.deadlineDays,
        percentage: d.percentage,
      )).toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting card deadlines', e, st);
      return [];
    }
  }

  /// Reactive stream de plazos de tarjeta configurados para un diario, según
  /// el tipo de tarjeta (crédito/débito).
  ///
  /// Mismo patrón y mismos criterios de decodificación/filtrado que
  /// [getCardDeadlines] (ver [watchCardBrandsByJournal] para el detalle del
  /// enfoque de reactividad manual sin `rxdart`).
  Stream<List<CardDeadline>> watchCardDeadlines(int journalId, CardType cardType) {
    final journalStream = (_db.select(_db.accountJournal)
          ..where((t) => t.odooId.equals(journalId)))
        .watchSingleOrNull();

    return _switchMap(journalStream, (journal) {
      if (journal == null) return Stream.value(<CardDeadline>[]);

      final deadlineIds = cardType == CardType.credit
          ? decodeCsvIntList(journal.cardDeadlineCreditIds)
          : decodeCsvIntList(journal.cardDeadlineDebitIds);
      if (deadlineIds.isEmpty) return Stream.value(<CardDeadline>[]);

      return (_db.select(_db.accountCreditCardDeadline)
            ..where((t) => t.odooId.isIn(deadlineIds))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch()
          .map((deadlines) => deadlines
              .map((d) => CardDeadline(
                    id: d.odooId,
                    name: d.name,
                    deadlineDays: d.deadlineDays,
                    percentage: d.percentage,
                  ))
              .toList());
    });
  }

  /// Sincroniza plazos de tarjeta desde Odoo
  Future<void> _syncCardDeadlinesFromOdoo(List<int> deadlineIds) async {
    try {
      final result = await _odoo.call(
        model: 'account.credit.card.deadline',
        method: 'search_read',
        kwargs: {
          'domain': [['id', 'in', deadlineIds]],
          'fields': ['id', 'name', 'code', 'credit', 'debit', 'meses', 'interes', 'sequence', 'active', 'company_id'],
        },
      );

      if (result == null || result is! List) return;

      for (final d in result) {
        final odooId = d['id'] as int;

        final companion = AccountCreditCardDeadlineCompanion(
          odooId: Value(odooId),
          name: Value(d['name'] as String? ?? ''),
          deadlineDays: Value(d['meses'] as int? ?? d['deadline_days'] as int? ?? 0),
          percentage: Value((d['percentage'] as num? ?? 0.0).toDouble()),
          active: Value(d['active'] as bool? ?? true),
        );

        final existing = await (_db.select(_db.accountCreditCardDeadline)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_db.update(_db.accountCreditCardDeadline)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _db.into(_db.accountCreditCardDeadline).insert(companion);
        }
      }
      logger.d('[PaymentService]', 'Synced ${result.length} card deadlines from Odoo');
    } catch (e) {
      logger.w('[PaymentService]', 'Could not sync card deadlines from Odoo: $e');
    }
  }

  /// Obtiene los lotes abiertos para un diario (sync-on-demand)
  /// Si no hay lotes locales, sincroniza desde Odoo primero
  Future<List<CardLote>> getOpenLotes(int journalId) async {
    try {
      // 1. Obtener lotes abiertos de la base local
      var lotes = await (_db.select(_db.accountCardLote)
            ..where((t) => t.journalId.equals(journalId))
            ..where((t) => t.state.equals('open'))
            ..orderBy([(t) => OrderingTerm.desc(t.dateFrom)]))
          .get();

      // 2. Si no hay lotes locales, sincronizar desde Odoo
      if (lotes.isEmpty) {
        logger.d('[PaymentService]', 'No local lotes for journal $journalId, syncing from Odoo...');
        await _syncLotesFromOdoo(journalId);

        // Recargar desde local
        lotes = await (_db.select(_db.accountCardLote)
              ..where((t) => t.journalId.equals(journalId))
              ..where((t) => t.state.equals('open'))
              ..orderBy([(t) => OrderingTerm.desc(t.dateFrom)]))
            .get();
      }

      // Convertir objetos Drift a CardLote
      return lotes.map((l) => CardLote(
        id: l.odooId,
        localId: l.id,
        name: l.name,
        journalId: l.journalId,
        journalName: l.journalName,
        state: l.state,
        date: l.dateFrom,
        numeroLote: l.code,
        amountTotal: l.totalAmount,
        amountBalance: 0.0, // Field doesn't exist in table
        paymentCount: l.transactionCount,
        isPosLote: false, // Field doesn't exist in table
      )).toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting open lotes', e, st);
      return [];
    }
  }

  /// Sincroniza lotes desde Odoo para un diario
  Future<void> _syncLotesFromOdoo(int journalId) async {
    try {
      final result = await _odoo.call(
        model: 'account.card.lote',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['journal_id', '=', journalId],
            ['state', '=', 'open'],
          ],
          'fields': [
            'id', 'name', 'journal_id', 'state', 'date',
            'numero_lote', 'amount_total', 'amount_balance',
            'payment_count', 'is_pos_lote', 'start_at', 'stop_at',
            'cashier_id', 'company_id',
          ],
          'order': 'date desc',
          'limit': 50,
        },
      );

      if (result == null || result is! List) return;

      for (final l in result) {
        final odooId = l['id'] as int;

        // Extraer journal
        int journalIdVal = journalId;
        final journalData = l['journal_id'];
        if (journalData is List && journalData.isNotEmpty) {
          journalIdVal = journalData[0] as int;
        }

        // Parsear fecha
        DateTime? date;
        final dateStr = l['date'];
        if (dateStr is String && dateStr.isNotEmpty) {
          date = DateTime.tryParse(dateStr);
        }

        final companion = AccountCardLoteCompanion(
          odooId: Value(odooId),
          name: Value(l['name'] as String? ?? ''),
          code: Value(l['numero_lote'] as String? ?? ''),
          journalId: Value(journalIdVal),
          journalName: Value(l['journal_id'] is List && (l['journal_id'] as List).length > 1
              ? (l['journal_id'] as List)[1] as String?
              : null),
          dateFrom: Value(date ?? DateTime.now()),
          dateTo: Value((date ?? DateTime.now()).add(const Duration(days: 1))),
          totalAmount: Value((l['amount_total'] as num?)?.toDouble() ?? 0.0),
          transactionCount: Value(l['payment_count'] as int? ?? 0),
          state: Value(l['state'] as String? ?? 'open'),
          active: const Value(true),
          writeDate: Value(DateTime.now()),
        );

        final existing = await (_db.select(_db.accountCardLote)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_db.update(_db.accountCardLote)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _db.into(_db.accountCardLote).insert(companion);
        }
      }
      logger.d('[PaymentService]', 'Synced ${result.length} lotes from Odoo');
    } catch (e) {
      logger.w('[PaymentService]', 'Could not sync lotes from Odoo: $e');
    }
  }

  /// Crea un nuevo lote de tarjetas para un diario
  ///
  /// [journalId]: ID del diario de tarjetas (odooId)
  /// [isPosLote]: Si es un lote de POS (punto de venta)
  ///
  /// El número de lote se calcula automáticamente basándose en los lotes
  /// existentes para el diario y fecha.
  ///
  /// Crea primero en la base local con un UUID para tracking offline.
  /// Si hay conexión, sincroniza inmediatamente a Odoo.
  ///
  /// Retorna el lote creado o null si falla
  Future<CardLote?> createLote(int journalId, {bool isPosLote = true}) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final loteUuid = _uuid.v4();

      // 1. Calcular el siguiente número de lote basándose en los lotes locales
      // Buscar lotes existentes para el diario y fecha actual
      final tomorrow = today.add(const Duration(days: 1));
      final existingLotes = await (_db.select(_db.accountCardLote)
            ..where((t) => t.journalId.equals(journalId))
            ..where((t) => t.dateFrom.isBiggerOrEqualValue(today))
            ..where((t) => t.dateFrom.isSmallerThanValue(tomorrow))
            ..orderBy([(t) => OrderingTerm.desc(t.name)]))
          .get();

      // Calcular el siguiente número
      int nextNumber = 1;
      for (final lote in existingLotes) {
        final num = int.tryParse(lote.name);
        if (num != null && num >= nextNumber) {
          nextNumber = num + 1;
        }
      }

      final loteName = nextNumber.toString();

      // 2. Crear el lote en la base local primero
      final localId = await _db.into(_db.accountCardLote).insert(
        AccountCardLoteCompanion.insert(
          odooId: 0, // Sin odooId todavía
          name: loteName,
          code: const Value(''), // Se actualizará cuando se sincronice con Odoo
          journalId: journalId,
          dateFrom: Value(today),
          dateTo: Value(today.add(const Duration(days: 1))),
          state: const Value('open'),
        ),
      );

      logger.i('[PaymentService]', 'Lote created locally: $loteName (localId: $localId, uuid: $loteUuid)');

      // 3. Intentar sincronizar a Odoo si hay conexión
      try {
        final result = await _odoo.call(
          model: 'account.card.lote',
          method: 'create',
          kwargs: {
            'vals_list': [
              {
                'name': loteName, // Solo dígitos, requerido
                'journal_id': journalId,
                'is_pos_lote': isPosLote,
                'date': today.toIso8601String().split('T')[0],
              }
            ],
          },
        );

        if (result != null) {
          final odooId = result is List ? result[0] as int : result as int;

          // Obtener datos completos del lote de Odoo
          final odooLotes = await _odoo.call(
            model: 'account.card.lote',
            method: 'search_read',
            kwargs: {
              'domain': [['id', '=', odooId]],
              'fields': [
                'id', 'name', 'journal_id', 'state', 'date',
                'numero_lote', 'amount_total', 'amount_balance',
                'payment_count', 'is_pos_lote',
              ],
              'limit': 1,
            },
          );

          String? numeroLote;
          if (odooLotes is List && odooLotes.isNotEmpty) {
            numeroLote = odooLotes[0]['numero_lote'] as String?;
          }

          // Actualizar el registro local con el odooId
          await (_db.update(_db.accountCardLote)
                ..where((t) => t.id.equals(localId)))
              .write(AccountCardLoteCompanion(
            odooId: Value(odooId),
            code: Value(numeroLote ?? ''),
          ));

          logger.i('[PaymentService]', 'Lote synced to Odoo: $loteName (odooId: $odooId, numero_lote: $numeroLote)');

          return CardLote(
            id: odooId,
            localId: localId,
            loteUuid: loteUuid,
            name: loteName,
            journalId: journalId,
            state: 'open',
            date: today,
            numeroLote: numeroLote,
            amountTotal: 0.0,
            amountBalance: 0.0,
            paymentCount: 0,
            isPosLote: isPosLote,
          );
        }
      } catch (syncError) {
        // Si falla la sincronización, retornar el lote local sin odooId
        logger.w('[PaymentService]', 'Failed to sync lote to Odoo, will sync later: $syncError');
      }

      // Retornar el lote local (sin odooId si no se sincronizó)
      return CardLote(
        id: 0, // Sin odooId todavía
        localId: localId,
        loteUuid: loteUuid,
        name: loteName,
        journalId: journalId,
        state: 'open',
        date: today,
        numeroLote: null,
        amountTotal: 0.0,
        amountBalance: 0.0,
        paymentCount: 0,
        isPosLote: isPosLote,
      );
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error creating lote', e, st);
      return null;
    }
  }
}

/// switchMap manual (Dart puro, sin `rxdart`): por cada valor emitido por
/// [source], se suscribe al stream que retorna [mapper], cancelando la
/// suscripción interna anterior si `source` emite un nuevo valor antes de
/// que la interna termine.
///
/// Usado por [CardPaymentSyncService.watchCardBrandsByJournal] y
/// [CardPaymentSyncService.watchCardDeadlines] para combinar el `.watch()`
/// del diario con el `.watch()` de la tabla de marcas/plazos, sin agregar
/// `rxdart` como dependencia directa (hoy solo llega transitivamente al
/// proyecto, no está declarada en `pubspec.yaml`).
Stream<R> _switchMap<T, R>(
  Stream<T> source,
  Stream<R> Function(T value) mapper,
) {
  return Stream.multi((controller) {
    StreamSubscription<T>? outerSub;
    StreamSubscription<R>? innerSub;

    outerSub = source.listen(
      (value) {
        innerSub?.cancel();
        innerSub = mapper(value).listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onError: controller.addError,
      onDone: () {
        innerSub?.cancel();
        controller.close();
      },
    );

    controller.onCancel = () {
      outerSub?.cancel();
      innerSub?.cancel();
    };
  });
}
