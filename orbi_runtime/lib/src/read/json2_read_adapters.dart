import 'dart:convert';

import 'package:odoo_sdk/odoo_sdk.dart'
    show
        OdooException,
        OdooNotFoundException,
        OdooMethodNotFoundException,
        OdooAccessDeniedException,
        extractMany2oneId;
import 'package:theos_pos_core/theos_pos_core.dart';

import '../contracts.dart';
import '../session/session_runtime.dart';
import '../sync/catalog_sync.dart';

/// The only JSON-2 read surface used by runtime catalog/order adapters.
/// It deliberately returns raw records: concrete local stores own models/schema.
abstract interface class Json2ReadPort {
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  });
}

/// Optional metadata surface used to validate read contracts before a runtime
/// reader is enabled against a new Odoo deployment.  Keeping it separate from
/// [Json2ReadPort] preserves small in-memory readers used by offline tests.
abstract interface class Json2FieldsGetPort {
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  });
}

/// Optional generic-call surface used by the catalog loader to ask
/// `sync.deleted.record.get_deleted_since`. Kept separate from
/// [Json2ReadPort] for the same reason as [Json2FieldsGetPort]: small
/// in-memory readers used by tests need not implement it, and a loader that
/// only has [Json2ReadPort] simply falls back to id reconciliation (see
/// [RuntimeCatalogLoader]).
abstract interface class Json2CallPort {
  Future<dynamic> call({
    required String model,
    required String method,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  });
}

final class OdooJson2ReadPort
    implements Json2ReadPort, Json2FieldsGetPort, Json2CallPort {
  final OdooClient client;
  const OdooJson2ReadPort(this.client);

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) => client.searchRead(
    model: model,
    fields: fields,
    domain: domain,
    limit: limit,
    offset: offset,
    order: order,
  );

  @override
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    required List<String> fields,
  }) => client.fieldsGet(model: model, fields: fields);

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  }) => client.call(
    model: model,
    method: method,
    kwargs: kwargs,
    context: context,
  );
}

/// Binds reads to the currently activated scope/epoch. A stale lease cannot
/// publish records into a newly activated company or user scope.
final class SessionJson2Reader {
  final SessionRuntime sessions;
  const SessionJson2Reader(this.sessions);

  Future<List<Map<String, dynamic>>> searchRead({
    required SessionLease lease,
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    final activation = sessions.active;
    if (activation == null || !sessions.accepts(lease)) {
      throw StateError('Session lease is no longer active');
    }
    final client = activation.client;
    if (client == null) throw StateError('Online session is not authenticated');
    return OdooJson2ReadPort(client).searchRead(
      model: model,
      fields: fields,
      domain: domain,
      limit: limit,
      offset: offset,
      order: order,
    );
  }
}

final class RuntimeCatalogDescriptor {
  const RuntimeCatalogDescriptor({
    required this.key,
    required this.model,
    required this.fields,
    this.domain = const [],
    this.order = 'id asc',
    this.optionalFields = const [],
    this.optionalFilterFields = const [],
  });
  final String key;
  final String model;
  final List<String> fields;
  final List<dynamic> domain;
  final String order;

  /// Subconjunto de [fields] que, si el servidor no lo tiene, no impide que
  /// el catálogo corra: `RuntimeCatalogAvailability` lo sincroniza sin ese
  /// campo (decisión E02, punto 2 — ej. `taxes_id` en `products`). Todo lo
  /// demás en [fields] se trata como obligatorio: su ausencia deja el
  /// catálogo en `unsupported`. Vacío por defecto — no cambia el
  /// comportamiento de un descriptor usado directo contra
  /// [RuntimeCatalogLoader], sin pasar por la disponibilidad (`fields`/
  /// `domain` siguen siendo exactamente lo que se pide).
  final List<String> optionalFields;

  /// Nombres de campo cuya cláusula en [domain] (con forma `[campo,
  /// operador, valor]`) se omite si el servidor no tiene ese campo, en vez
  /// de tumbar el catálogo entero (E02, punto 2 — ej. `customer_rank` en
  /// `customers`). Igual que [optionalFields]: vacío por defecto, y
  /// [RuntimeCatalogLoader] nunca lo lee — sólo lo usa
  /// `RuntimeCatalogAvailability` para construir el descriptor efectivo.
  final List<String> optionalFilterFields;
}

/// Essential catalog reads. The local store decides which generated model to
/// parse and persist; no runtime schema or bank model is introduced here.
abstract final class RuntimeCatalogs {
  static const cardBrands = RuntimeCatalogDescriptor(
    key: 'card_brands',
    // El modelo lleva «credit» en el nombre. Sin esa palabra el servidor
    // responde que no existe, y este catálogo llevaba así desde que se
    // escribió. Ojo: `account.card.lote`, justo debajo, SÍ va sin «credit» —
    // el addon de Odoo nombra los tres de dos formas distintas.
    model: 'account.credit.card.brand',
    fields: PaymentConfigRecordMapper.cardBrandFields,
    order: 'name asc,id asc',
  );
  static const cardDeadlines = RuntimeCatalogDescriptor(
    key: 'card_deadlines',
    model: 'account.credit.card.deadline',
    fields: PaymentConfigRecordMapper.cardDeadlineFields,
    order: 'name asc,id asc',
  );
  static const cardLotes = RuntimeCatalogDescriptor(
    key: 'card_lotes',
    model: 'account.card.lote',
    fields: PaymentConfigRecordMapper.cardLoteFields,
    order: 'id asc',
  );
  static const paymentMethodLines = RuntimeCatalogDescriptor(
    key: 'payment_method_lines',
    model: 'account.payment.method.line',
    fields: PaymentConfigRecordMapper.paymentMethodLineFields,
    order: 'id asc',
  );
  static const customers = RuntimeCatalogDescriptor(
    key: 'customers',
    model: 'res.partner',
    // `write_date` habilita el cursor incremental (`RuntimeCatalogLoader`):
    // sin él este catálogo vuelve a recargar todo cada ciclo.
    fields: [
      'id',
      'name',
      'vat',
      'email',
      'phone',
      'company_id',
      'active',
      'write_date',
    ],
    domain: [
      ['customer_rank', '>', 0],
      ['active', '=', true],
    ],
    // Mepriga (`stock` + `l10n_ec_stock_envases`, sin `sale`) no tiene
    // `customer_rank` en `res.partner` — ver E02. Sin este campo el filtro
    // se omite (todos los partners activos cuentan como "clientes" en ese
    // servidor) en vez de tumbar el catálogo entero con un 500.
    optionalFilterFields: ['customer_rank'],
    order: 'name asc,id asc',
  );
  static const products = RuntimeCatalogDescriptor(
    key: 'products',
    model: 'product.product',
    // `write_date` habilita el cursor incremental; ver la nota en `customers`.
    fields: [
      'id',
      'name',
      'default_code',
      'barcode',
      'list_price',
      'uom_id',
      'taxes_id',
      'active',
      'write_date',
    ],
    domain: [
      ['sale_ok', '=', true],
      ['active', '=', true],
    ],
    // `taxes_id` viene de `account`; Mepriga (`stock`-only) no lo tiene —
    // ver E02. Sin él, productos se sincroniza igual, sin ese campo.
    optionalFields: ['taxes_id'],
    order: 'name asc,id asc',
  );
  static const paymentTerms = RuntimeCatalogDescriptor(
    key: 'payment_terms',
    model: 'account.payment.term',
    fields: ['id', 'name', 'line_ids', 'active', 'write_date'],
    order: 'name asc,id asc',
  );
  static const uoms = RuntimeCatalogDescriptor(
    key: 'uoms',
    model: 'uom.uom',
    // `rounding` era un campo de `uom.uom` hasta las series viejas de Odoo y
    // ya no existe: el servidor rechazaba la lectura entera por pedirlo. El
    // lector local ya traía su propio valor por defecto, así que no se pierde
    // nada al dejar de pedirlo.
    fields: ['id', 'name', 'factor', 'active', 'write_date'],
    domain: [
      ['active', '=', true],
    ],
    order: 'name asc,id asc',
  );
  static const collectionConfigs = RuntimeCatalogDescriptor(
    key: 'collection_configs',
    model: 'collection.config',
    fields: [
      'id',
      'name',
      'code',
      'active',
      'company_id',
      'journal_id',
      'cash_journal_id',
      'allowed_journal_ids',
      'cash_difference_account_id',
      'set_maximum_difference',
      'amount_authorized_diff',
      'user_ids',
      'current_session_id',
      'current_session_state',
      'current_session_name',
      'number_of_opened_session',
      'last_session_closing_date',
      'last_session_closing_cash',
      'collection_session_username',
      'current_session_state_display',
      'number_of_rescue_session',
      'write_date',
    ],
    order: 'id asc',
  );
  static const collectionSessions = RuntimeCatalogDescriptor(
    key: 'collection_sessions',
    model: 'collection.session',
    fields: [
      'id',
      'session_uuid',
      'name',
      'state',
      'config_id',
      'company_id',
      'user_id',
      'currency_id',
      // `currency_symbol` nunca existió en `collection.session`. El símbolo se
      // resuelve desde `currency_id`, no es un campo del propio registro.
      // Pedirlo tumbaba la lectura completa de las sesiones de caja.
      'cash_journal_id',
      'start_at',
      'stop_at',
      'cash_register_balance_start',
      'cash_register_balance_end_real',
      'cash_register_balance_end',
      'cash_register_difference',
      'total_payments_amount',
      'write_date',
    ],
    order: 'id asc',
  );
  static const taxes = RuntimeCatalogDescriptor(
    key: 'taxes',
    model: 'account.tax',
    fields: [
      'id',
      'name',
      'amount',
      'amount_type',
      'price_include',
      'company_id',
      'active',
      'write_date',
    ],
    domain: [
      ['active', '=', true],
    ],
    order: 'sequence asc,id asc',
  );
  static const pricelists = RuntimeCatalogDescriptor(
    key: 'pricelists',
    model: 'product.pricelist',
    fields: ['id', 'name', 'currency_id', 'company_id', 'active', 'write_date'],
    order: 'name asc,id asc',
  );
  static const warehouses = RuntimeCatalogDescriptor(
    key: 'warehouses',
    model: 'stock.warehouse',
    fields: ['id', 'name', 'code', 'company_id', 'active', 'write_date'],
    order: 'name asc,id asc',
  );
  static const journals = RuntimeCatalogDescriptor(
    key: 'journals',
    model: 'account.journal',
    fields: ['id', 'name', 'type', 'company_id', 'active', 'write_date'],
    domain: [
      [
        'type',
        'in',
        ['cash', 'bank'],
      ],
      ['active', '=', true],
    ],
    order: 'name asc,id asc',
  );

  /// `res.lang`/`res.country`/`res.country.state` son campos base garantizados
  /// (verificado contra `odoo/odoo/addons/base/models/res_lang.py` y
  /// `res_country.py` en `dev_odoo20`): sin módulo que los quite ni versión
  /// que los renombre, así que van con lista de campos fija — a diferencia de
  /// `res.groups`/`res.users`/`res.partner` (ver [RuntimeCatalogLoader] y
  /// [RuntimeAccountLoader]), que SÍ dependen de qué módulos están instalados
  /// y por eso se resuelven con `fields_get`.
  static const languages = RuntimeCatalogDescriptor(
    key: 'languages',
    model: 'res.lang',
    fields: ['id', 'name', 'code', 'active', 'write_date'],
    domain: [
      ['active', '=', true],
    ],
    order: 'name asc,id asc',
  );

  /// `res.country` no tiene campo `active` (confirmado en el modelo base): a
  /// diferencia de la mayoría de catálogos, aquí no hay dominio que filtrar.
  static const countries = RuntimeCatalogDescriptor(
    key: 'countries',
    model: 'res.country',
    fields: ['id', 'name', 'code', 'write_date'],
    order: 'name asc,id asc',
  );

  /// Igual que `countries`: `res.country.state` tampoco tiene `active`.
  static const countryStates = RuntimeCatalogDescriptor(
    key: 'countryStates',
    model: 'res.country.state',
    fields: ['id', 'name', 'code', 'country_id', 'write_date'],
    order: 'name asc,id asc',
  );

  /// Los diecisiete estáticos, para poder recorrerlos.
  ///
  /// Existe porque los descriptores se escribieron todos de una vez y **nadie
  /// los comprobó contra un servidor real**: cuatro pedían modelos o campos
  /// que no existen, y el fallo no se vio hasta once meses después. Una lista
  /// enumerable permite que una prueba los recorra y los valide de golpe, en
  /// vez de descubrirlos de uno en uno cuando la sincronización falla.
  ///
  /// `res.groups` NO está aquí: sus campos se resuelven con `fields_get` en
  /// tiempo de ejecución (ver [RuntimeCatalogLoader.selfDescribingLoader]),
  /// así que no tiene un [RuntimeCatalogDescriptor] estático que enumerar.
  static const all = <RuntimeCatalogDescriptor>[
    cardBrands,
    cardDeadlines,
    cardLotes,
    paymentMethodLines,
    customers,
    products,
    paymentTerms,
    uoms,
    collectionConfigs,
    collectionSessions,
    taxes,
    pricelists,
    warehouses,
    journals,
    languages,
    countries,
    countryStates,
  ];
}

enum _CatalogMode { full, since }

/// Opaque cursor persisted through [CatalogBatch.cursor]/`sync_metadata`.
///
/// Two shapes coexist on purpose:
/// - A bare integer string is the LEGACY cursor (full paginated load only,
///   offset-based, restarting from scratch — `null` — once it reaches the
///   last page). Decoding still accepts it so a device upgrading mid-full-load
///   does not lose its offset.
/// - The JSON shape below is what every catalog uses from here on: it keeps
///   full-load's own offset while it runs, then switches to incremental
///   (`since`) once the table has been read in full.
final class _CatalogCursor {
  const _CatalogCursor({
    required this.mode,
    required this.offset,
    this.since,
    this.pendingWatermark,
    this.cycle = 0,
  });

  final _CatalogMode mode;
  final int offset;

  /// Fixed lower bound (`write_date >=`) used by every page of the CURRENT
  /// incremental pass. Only set once [mode] is [_CatalogMode.since].
  final DateTime? since;

  /// Captured at the moment the current pass's FIRST page was requested.
  /// Persisted across pages of the same pass so a multi-page pass does not
  /// lose it; becomes the next pass's [since] (minus the overlap) once this
  /// pass reaches its last page.
  final DateTime? pendingWatermark;

  /// How many incremental passes have completed. Only meaningful without
  /// `sync.deleted.record`: it paces the expensive full id reconciliation
  /// (see [RuntimeCatalogLoader._resolveDeletions]).
  final int cycle;

  static const _CatalogCursor initial = _CatalogCursor(
    mode: _CatalogMode.full,
    offset: 0,
  );

  static _CatalogCursor decode(String? raw) {
    if (raw == null || raw.isEmpty) return initial;
    final legacyOffset = int.tryParse(raw);
    if (legacyOffset != null) {
      return _CatalogCursor(
        mode: _CatalogMode.full,
        offset: legacyOffset < 0 ? 0 : legacyOffset,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return initial;
      final mode = decoded['mode'] == 'since'
          ? _CatalogMode.since
          : _CatalogMode.full;
      final offset = decoded['offset'] is int ? decoded['offset'] as int : 0;
      final since = _parseDate(decoded['since']);
      if (mode == _CatalogMode.since && since == null) {
        // Cursor corrupto o de una versión anterior: no hay forma segura de
        // saber desde cuándo faltan cambios. Se documenta reiniciando la
        // carga completa en vez de arriesgar un hueco silencioso.
        return initial;
      }
      final cycle = decoded['cycle'] is int ? decoded['cycle'] as int : 0;
      return _CatalogCursor(
        mode: mode,
        offset: offset < 0 ? 0 : offset,
        since: since,
        pendingWatermark: _parseDate(decoded['pendingWatermark']),
        cycle: cycle < 0 ? 0 : cycle,
      );
    } catch (_) {
      return initial;
    }
  }

  String encode() => jsonEncode({
    'mode': mode == _CatalogMode.since ? 'since' : 'full',
    'offset': offset,
    if (since != null) 'since': since!.toIso8601String(),
    if (pendingWatermark != null)
      'pendingWatermark': pendingWatermark!.toIso8601String(),
    'cycle': cycle,
  });

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

final class _CatalogDeletionOutcome {
  const _CatalogDeletionOutcome({
    this.deletedIds = const <int>[],
    this.remoteActiveIds,
  });
  final List<int> deletedIds;
  final Set<int>? remoteActiveIds;
}

/// Loads one page per call, exactly like `CatalogSyncJob.run()` expects (one
/// `SyncCoordinatorImpl` drain cycle runs every job once — see
/// `sync_coordinator_impl.dart:159`). A catalog's full table can therefore
/// take several sync cycles to finish loading; once it does, this switches to
/// asking Odoo only for what changed since the last pass — see
/// `docs/orbi_panel/reports/TIEMPO_REAL_Y_GLOBAL_REFERENCIA_2026_09_13.md`
/// («Recuperar lo perdido al reconectar»), which measured that this loader
/// used to always reload everything and never reflected server-side
/// deletions.
///
/// Known gap, intentionally NOT covered here (documented instead of
/// papered over): a record that stops matching [RuntimeCatalogDescriptor]'s
/// own `domain` (e.g. a product turning `active=false`) is a "domain exit",
/// not an unlink — `sync.deleted.record` never reports it, and the
/// incremental `write_date` scan re-applies the SAME domain, so it will not
/// be re-fetched either. theos_pos solves this with a dedicated reverse-domain
/// scan (`catalog_sync_repository.dart:_syncRecordsLeavingDomain`); porting
/// that is future work, not part of this change.
final class RuntimeCatalogLoader {
  RuntimeCatalogLoader(
    this.reader, {
    this.pageSize = 100,
    this.incrementalOverlap = const Duration(minutes: 10),
    this.reconcileEveryNCycles = 20,
    DateTime Function()? clock,
  }) : _now = clock ?? _defaultClock;

  final Json2ReadPort reader;
  final int pageSize;

  /// Clock seam, only for tests: production always uses the real wall clock
  /// (`_defaultClock`). Letting a test inject its own clock is what makes
  /// [incrementalOverlap] actually verifiable — the scenario it exists for
  /// needs minutes of separation between two passes, and a test cannot
  /// afford to `sleep()` for real minutes.
  final DateTime Function() _now;
  static DateTime _defaultClock() => DateTime.now().toUtc();

  /// Safety margin subtracted from the watermark of a finished pass before it
  /// becomes the next pass's `since`, so a record written while the pass was
  /// in flight cannot be missed.
  ///
  /// 🔴 Sized for a specific, confirmed Odoo behavior, not an arbitrary
  /// round number: `write_date` is stamped from `cr.now()`, the time the
  /// DATABASE TRANSACTION STARTED — not when it commits
  /// (`odoo/odoo/sql_db.py:339`, `odoo/orm/models.py:3841,3984,4268` in
  /// Odoo 20). A transaction that opens at T0 and commits at T10 writes
  /// `write_date = T0`. If some other, faster transaction commits in
  /// between and this loader advances its cursor past T0 before T10, the
  /// T0 row's `write_date` falls BEHIND the cursor and is never fetched
  /// again — the old 60s value only protected against a transaction that
  /// finishes within 60s of starting. 10 minutes is chosen to comfortably
  /// cover ordinary Odoo crons/batch writes; it is a judgment call, not a
  /// proven bound — no finite margin is safe against an arbitrarily long
  /// transaction, and this deployment's actual longest write transaction
  /// has not been measured. The cost of a wider margin is bounded: every
  /// pass re-reads up to [incrementalOverlap] worth of already-seen rows,
  /// which the id-keyed upsert absorbs without duplicating anything.
  final Duration incrementalOverlap;

  /// Only used when the server has no `sync.deleted.record` (Mepriga): full
  /// id reconciliation reads every id in the table (no other fields), so
  /// running it every cycle would multiply traffic per catalog. Paying that
  /// cost once every N cycles keeps deletions bounded-stale instead of never
  /// reflected at all.
  final int reconcileEveryNCycles;

  /// Cached for the lifetime of this loader (effectively "once per active
  /// scope": composition builds one loader per [SessionActivation]), and
  /// shared by every catalog on it — `sync.deleted.record` support is a
  /// server-wide fact, never per-catalog.
  ///
  /// `null`: not determined yet. `true`/`false`: outcome of the last actual
  /// `get_deleted_since` attempt — NOT a separate `ir.model` metadata probe.
  /// Measured against ERP2 on 13-sep-2026: a plain vendedor gets `403 POST
  /// /json/2/ir.model/search_read` (`ir.model` needs `base.group_no_one`),
  /// while the SAME vendedor can call `sync.deleted.record.get_deleted_since`
  /// directly and successfully. So the only reliable probe is the real call.
  bool? _deletedRecordSupported;

  CatalogLoader<Map<String, dynamic>> loader(
    RuntimeCatalogDescriptor descriptor,
  ) =>
      (scope, cursorRaw) => _run(descriptor, scope, cursorRaw);

  /// Descriptores resueltos por `fields_get`, memoizados por [key] — una
  /// llamada por catálogo durante toda la vida de este loader (uno por
  /// activación, igual que [_deletedRecordSupported]).
  final Map<String, Future<RuntimeCatalogDescriptor>> _resolvedDescriptors =
      {};

  /// Loader para un catálogo cuyos campos NO se pueden fijar en tiempo de
  /// compilación porque dependen de qué módulos de Odoo están instalados
  /// (p. ej. `res.groups.category_id`, que en Odoo 19/20 fue reemplazado por
  /// `privilege_id` — confirmado contra `res_groups.py` en `dev_odoo20`).
  /// Pide `fields_get` UNA sola vez con [candidateFields], se queda solo con
  /// los que el servidor confirma que existen, y reutiliza el mismo camino de
  /// paginación/cursor/borrado que [loader] mediante [_run].
  ///
  /// `xml_id` deliberadamente NUNCA se pide aquí: no es un campo de ningún
  /// modelo de Odoo (se resuelve vía `ir.model.data`, no por `search_read`),
  /// así que ni `fields_get` lo va a confirmar — pedirlo tumbaría la lectura.
  CatalogLoader<Map<String, dynamic>> selfDescribingLoader({
    required String key,
    required String model,
    required List<String> candidateFields,
    List<dynamic> domain = const [],
    String order = 'id asc',
  }) {
    Future<RuntimeCatalogDescriptor> resolve() =>
        _resolvedDescriptors.putIfAbsent(key, () async {
          final present = await _resolvePresentFields(model, candidateFields);
          return RuntimeCatalogDescriptor(
            key: key,
            model: model,
            fields: ['id', ...present],
            domain: domain,
            order: order,
          );
        });
    return (scope, cursorRaw) async {
      final descriptor = await resolve();
      return _run(descriptor, scope, cursorRaw);
    };
  }

  /// Filtra [candidateFields] a los que el servidor confirma vía `fields_get`.
  /// Requiere que [reader] también sea [Json2FieldsGetPort] — igual que
  /// [RuntimeOrderReader.validateRemoteContract], que ya exige lo mismo para
  /// probar el contrato de lectura antes de activar un scope nuevo.
  Future<List<String>> _resolvePresentFields(
    String model,
    List<String> candidateFields,
  ) async {
    if (reader is! Json2FieldsGetPort) {
      throw StateError('Odoo reader does not expose fields_get');
    }
    final metadata = await (reader as Json2FieldsGetPort).fieldsGet(
      model: model,
      fields: candidateFields,
    );
    return candidateFields.where(metadata.containsKey).toList(
      growable: false,
    );
  }

  Future<CatalogBatch<Map<String, dynamic>>> _run(
    RuntimeCatalogDescriptor descriptor,
    AppScope scope,
    String? cursorRaw,
  ) {
    final cursor = _CatalogCursor.decode(cursorRaw);
    return cursor.mode == _CatalogMode.since
        ? _runSincePage(descriptor, scope, cursor)
        : _runFullPage(descriptor, scope, cursor);
  }

  Future<CatalogBatch<Map<String, dynamic>>> _runFullPage(
    RuntimeCatalogDescriptor descriptor,
    AppScope scope,
    _CatalogCursor cursor,
  ) async {
    final attemptStart = _now();
    final rows = await reader.searchRead(
      model: descriptor.model,
      fields: descriptor.fields,
      domain: descriptor.domain,
      limit: pageSize,
      offset: cursor.offset,
      order: descriptor.order,
    );
    final records = _toRecords(scope, descriptor, rows);
    if (rows.length >= pageSize) {
      final next = _CatalogCursor(
        mode: _CatalogMode.full,
        offset: cursor.offset + rows.length,
      );
      return CatalogBatch(records: records, cursor: next.encode());
    }
    if (!descriptor.fields.contains('write_date')) {
      // El descriptor no pide `write_date`: no hay forma de saber qué cambió
      // después sin releer todo. Se documenta aquí (ver la nota de la clase)
      // en vez de fingir un cursor incremental que no puede sostenerse; la
      // próxima sincronización repite la carga completa, igual que hoy.
      return CatalogBatch(records: records, cursor: null);
    }
    final since = _CatalogCursor(
      mode: _CatalogMode.since,
      offset: 0,
      since: attemptStart.subtract(incrementalOverlap),
      pendingWatermark: attemptStart,
    );
    return CatalogBatch(records: records, cursor: since.encode());
  }

  Future<CatalogBatch<Map<String, dynamic>>> _runSincePage(
    RuntimeCatalogDescriptor descriptor,
    AppScope scope,
    _CatalogCursor cursor,
  ) async {
    final since = cursor.since!;
    final startOfPass = cursor.pendingWatermark ?? _now();
    final domain = [
      ...descriptor.domain,
      ['write_date', '>=', _formatOdooDateTime(since)],
    ];
    final rows = await reader.searchRead(
      model: descriptor.model,
      fields: descriptor.fields,
      domain: domain,
      limit: pageSize,
      offset: cursor.offset,
      order: 'write_date asc,id asc',
    );
    final records = _toRecords(scope, descriptor, rows);
    if (rows.length >= pageSize) {
      final next = _CatalogCursor(
        mode: _CatalogMode.since,
        offset: cursor.offset + rows.length,
        since: since,
        pendingWatermark: startOfPass,
        cycle: cursor.cycle,
      );
      return CatalogBatch(records: records, cursor: next.encode());
    }

    // Última página de esta pasada: aquí, y sólo aquí, se resuelven las
    // bajas — una vez por pasada, no una vez por página.
    final deletion = await _resolveDeletions(descriptor, since, cursor.cycle);
    final next = _CatalogCursor(
      mode: _CatalogMode.since,
      offset: 0,
      since: startOfPass.subtract(incrementalOverlap),
      cycle: cursor.cycle + 1,
    );
    return CatalogBatch(
      records: records,
      cursor: next.encode(),
      deletedIds: deletion.deletedIds,
      remoteActiveIds: deletion.remoteActiveIds,
    );
  }

  Future<_CatalogDeletionOutcome> _resolveDeletions(
    RuntimeCatalogDescriptor descriptor,
    DateTime since,
    int cycle,
  ) async {
    final deletedIds = <int>{};
    Set<int>? remoteActiveIds;

    if (reader is Json2CallPort && _deletedRecordSupported != false) {
      try {
        final outcome = await _fetchDeletedSince(
          reader as Json2CallPort,
          descriptor,
          since,
        );
        _deletedRecordSupported = true;
        deletedIds.addAll(outcome.deletedIds);
      } on OdooException catch (error) {
        if (!_meansDeletedRecordUnsupported(error)) rethrow;
        // El modelo no existe en este servidor (sin actualizar, o sin el
        // módulo todavía), o existe pero esta sesión no tiene permiso para
        // leerlo — en ambos casos se cachea para no reintentar cada pasada,
        // y se cae a la reconciliación por ids de abajo.
        _deletedRecordSupported = false;
      }
    }

    if (_deletedRecordSupported != true) {
      // Sin `sync.deleted.record` usable (p. ej. Mepriga antes del
      // despliegue, o un servidor viejo): sólo cada [reconcileEveryNCycles]
      // pasadas se reconstruye el conjunto COMPLETO de ids activos remotos
      // — ver la nota de costo en el campo. El resto de las pasadas no hace
      // ninguna llamada extra. Esto TAMBIÉN cubre, de rebote, los registros
      // que salieron del dominio (ver más abajo), porque un id que dejó de
      // cumplir el dominio simplemente no aparece en el conjunto fresco.
      if (cycle % reconcileEveryNCycles == 0) {
        remoteActiveIds = await _fetchAllActiveIds(descriptor);
      }
    }

    // Registros que SALIERON del dominio del catálogo (p. ej. `active=false`
    // al archivar, o `sale_ok=false`) sin que nadie los borre: un `write()`
    // no es un `unlink()`, así que `sync.deleted.record` nunca los reporta,
    // y el propio scan incremental de arriba sigue exigiendo el MISMO
    // dominio, así que tampoco los vuelve a traer. Este escaneo aparte pide
    // el dominio NEGADO del catálogo (con `active_test: false` para que
    // Odoo no vuelva a filtrar por `active` por su cuenta) y trata sus ids
    // igual que una baja — pasan por la misma guarda de `offline_queue`.
    // Corre en TODAS las pasadas (está acotado por `write_date`, no es un
    // barrido completo) sin importar si `sync.deleted.record` existe.
    //
    // Límite conocido, sin resolver aquí: un registro que pasó a una
    // empresa/regla de registro que esta sesión no puede leer no aparece en
    // NINGUNO de los dos escaneos (las reglas de registro lo ocultan por
    // completo, incluso del dominio negado) — lo recoge, con el retraso de
    // [reconcileEveryNCycles], la reconciliación completa de arriba.
    if (reader is Json2CallPort) {
      final exitIds = await _fetchDomainExitIds(
        reader as Json2CallPort,
        descriptor,
        since,
      );
      deletedIds.addAll(exitIds);
    }

    return _CatalogDeletionOutcome(
      deletedIds: deletedIds.toList(growable: false),
      remoteActiveIds: remoteActiveIds,
    );
  }

  /// `sync.deleted.record`/`get_deleted_since` no es usable en este servidor
  /// para esta sesión: el modelo o el método no existen (servidor sin el
  /// módulo, o una versión vieja sin `get_deleted_since`), o existen pero el
  /// usuario no tiene permiso de lectura sobre `sync.deleted.record`. Otra
  /// excepción (red, timeout, 500, sesión caducada) NO se interpreta como
  /// "no soportado" — se propaga como el fallo real que es.
  static bool _meansDeletedRecordUnsupported(OdooException error) =>
      error is OdooNotFoundException ||
      error is OdooMethodNotFoundException ||
      error is OdooAccessDeniedException;

  Future<_CatalogDeletionOutcome> _fetchDeletedSince(
    Json2CallPort callPort,
    RuntimeCatalogDescriptor descriptor,
    DateTime since,
  ) async {
    final response = await callPort.call(
      model: 'sync.deleted.record',
      method: 'get_deleted_since',
      kwargs: {
        'model_name': descriptor.model,
        'since_date': _formatOdooDateTime(since),
      },
    );
    if (response is! List) {
      throw FormatException(
        'sync.deleted.record returned ${response.runtimeType} '
        'for ${descriptor.model}',
      );
    }
    final ids = response
        .whereType<Map>()
        .map((row) => row['record_id'])
        .whereType<int>()
        .toList(growable: false);
    return _CatalogDeletionOutcome(deletedIds: ids);
  }

  Future<Set<int>> _fetchAllActiveIds(
    RuntimeCatalogDescriptor descriptor,
  ) async {
    const idPageSize = 500;
    final ids = <int>{};
    var offset = 0;
    while (true) {
      final rows = await reader.searchRead(
        model: descriptor.model,
        fields: const ['id'],
        domain: descriptor.domain,
        limit: idPageSize,
        offset: offset,
        order: 'id asc',
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final id = row['id'];
        if (id is int) ids.add(id);
      }
      if (rows.length < idPageSize) break;
      offset += rows.length;
    }
    return ids;
  }

  /// Ids que hoy DEJARON de cumplir [RuntimeCatalogDescriptor.domain] (p. ej.
  /// `active=false` al archivar) desde [since]. Usa `active_test: false`
  /// (contexto, no dominio) para que Odoo no filtre `active` por su cuenta
  /// sobre el resultado — igual que ya valida
  /// `theos_pos/sync_counts_repository.dart:_syncRecordsLeavingDomain`, y
  /// confirmado contra el propio ORM: `search()` sólo añade el `active=true`
  /// implícito cuando NINGUNA condición del dominio menciona ya ese campo
  /// (`odoo/orm/models.py:_search`, líneas ~4855-4863 en Odoo 20).
  ///
  /// Un dominio vacío no tiene de qué "salir": devuelve `[]` sin llamar al
  /// servidor.
  Future<List<int>> _fetchDomainExitIds(
    Json2CallPort callPort,
    RuntimeCatalogDescriptor descriptor,
    DateTime since,
  ) async {
    final negatedDomain = _negateDomain(descriptor.domain);
    if (negatedDomain == null) return const [];

    const idPageSize = 500;
    final ids = <int>{};
    var offset = 0;
    while (true) {
      final response = await callPort.call(
        model: descriptor.model,
        method: 'search_read',
        kwargs: {
          'domain': [
            '&',
            ['write_date', '>=', _formatOdooDateTime(since)],
            ...negatedDomain,
          ],
          'fields': const ['id'],
          'limit': idPageSize,
          'offset': offset,
          'order': 'id asc',
        },
        context: const {'active_test': false},
      );
      if (response is! List) {
        throw FormatException(
          '${descriptor.model}.search_read (domain exit) returned '
          '${response.runtimeType}',
        );
      }
      if (response.isEmpty) break;
      for (final row in response) {
        if (row is Map) {
          final id = row['id'];
          if (id is int) ids.add(id);
        }
      }
      if (response.length < idPageSize) break;
      offset += response.length;
    }
    return ids.toList(growable: false);
  }

  /// Niega un dominio de Odoo escrito como una lista PLANA de condiciones en
  /// AND implícito (la forma que usan todos los [RuntimeCatalogDescriptor] de
  /// hoy: nunca traen su propio `'&'`/`'|'` al nivel superior). Hace el AND
  /// explícito antes de negar — `['!', A, B]` NO es `NOT(A AND B)`, es
  /// `(NOT A) AND B`, porque `'!'` sólo consume el término que le sigue
  /// (`odoo/orm/domains.py`, docstring del módulo: "'!' is a unary 'not'").
  /// `null` para un dominio vacío (nada que negar).
  static List<dynamic>? _negateDomain(List<dynamic> domain) {
    if (domain.isEmpty) return null;
    final explicitAnd = [
      for (var i = 0; i < domain.length - 1; i++) '&',
      ...domain,
    ];
    return ['!', ...explicitAnd];
  }

  static List<CatalogRecord<Map<String, dynamic>>> _toRecords(
    AppScope scope,
    RuntimeCatalogDescriptor descriptor,
    List<Map<String, dynamic>> rows,
  ) => rows
      .map((row) {
        final id = row['id'];
        if (id is! int || id <= 0) {
          throw FormatException('Invalid ${descriptor.key} id');
        }
        return CatalogRecord(
          uuid: '${scope.scopeKey}:${descriptor.key}:$id',
          value: row,
        );
      })
      .toList(growable: false);

  static String _formatOdooDateTime(DateTime value) =>
      value.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 19);
}

/// Campos candidatos de `res.users` para "Mis preferencias". Varios dependen
/// de qué módulos están instalados — confirmado contra el código fuente de
/// Odoo 19/20 en `dev_odoo20`, no supuesto: `mobile_phone`/`work_email`/
/// `work_phone` los trae el módulo `hr` (no están en `base`/`mail`),
/// `property_warehouse_id` lo trae `sale_stock` (no está en `res.users` sin
/// él, ver `dev_odoo20/odoo/addons/sale_stock/models/res_users.py`). El resto
/// (`lang`, `tz`, `signature`, `name`, `login`, `partner_id`, `company_id`,
/// `group_ids`, `write_date`) es de `base` y siempre está, pero pasa por el
/// mismo `fields_get` que los demás: un solo mecanismo, sin casos especiales
/// que mantener.
const _currentUserCandidateFields = <String>[
  'name',
  'login',
  'lang',
  'tz',
  'signature',
  'notification_type',
  'property_warehouse_id',
  'mobile_phone',
  'work_email',
  'work_phone',
  'avatar_128',
  'group_ids',
  'partner_id',
  'company_id',
  'write_date',
];

/// Lee el usuario y el partner de la sesión activa (`AppScope.userId`) para
/// que "Mis preferencias" tenga de dónde leer en Drift sin conexión.
///
/// A diferencia de [RuntimeCatalogLoader]: cada catálogo es UN solo registro,
/// así que no pagina y siempre vuelve a pedirlo entero (`cursor` siempre
/// `null`) — el costo de releer una fila en cada ciclo de sync es
/// despreciable frente a la complejidad de un cursor para un id fijo.
final class RuntimeAccountLoader {
  RuntimeAccountLoader(this.reader);

  final Json2ReadPort reader;

  Future<(List<String>, Map<String, dynamic>)>? _userFieldsAndMetadataFuture;
  Future<List<String>>? _partnerFieldsFuture;

  /// Carga el usuario actual. El registro trae, además de los campos de
  /// `res.users` que el servidor confirmó tener, `is_current_user: true` y,
  /// bajo la clave reservada `_field_selections`, las opciones vivas de los
  /// campos `Selection` que interesan a la UI (`tz`, `notification_type`) —
  /// extraídas de la MISMA respuesta de `fields_get` que ya resolvió los
  /// campos, sin una llamada aparte. El escritor (`writeCurrentUserRecords`
  /// en `local_catalog_adapters.dart`) separa esa clave antes de armar la
  /// fila de `res_users` y la vuelca en la caché de selecciones.
  CatalogLoader<Map<String, dynamic>> get userLoader =>
      (scope, cursorRaw) => _runUser(scope);

  /// Carga el partner del usuario actual. Resuelve su id con una lectura
  /// propia y mínima de `res.users` (`id`, `partner_id`) en vez de depender
  /// de que [userLoader] haya corrido antes en el mismo ciclo: el orden de
  /// los `SyncJob` en `RuntimeCatalogComposition` no está garantizado por
  /// catálogo.
  CatalogLoader<Map<String, dynamic>> get partnerLoader =>
      (scope, cursorRaw) => _runPartner(scope);

  Future<CatalogBatch<Map<String, dynamic>>> _runUser(AppScope scope) async {
    final (present, metadata) = await _resolveUserFieldsAndMetadata();
    final rows = await reader.searchRead(
      model: 'res.users',
      fields: ['id', ...present],
      domain: [
        ['id', '=', scope.userId],
      ],
      limit: 1,
    );
    if (rows.isEmpty) return const CatalogBatch(records: [], cursor: null);
    final selections = <String, dynamic>{};
    for (final field in const ['tz', 'notification_type']) {
      final selection = _extractSelection(metadata, field);
      if (selection != null) selections[field] = selection;
    }
    // `mobile_phone` (`hr`) y `property_warehouse_id` (`sale_stock`): los dos
    // campos de `res.users` que `FieldAvailabilityCache`
    // (`orbi_runtime/lib/src/account/user_preferences.dart`) necesita saber
    // si existen, sin red, para no ofrecer en el formulario un campo que el
    // servidor no tiene. El escritor (`writeCurrentUserRecords` en
    // `local_catalog_adapters.dart`) es quien conoce esa clase; aquí sólo se
    // reporta el hecho (presente o no en `fields_get`).
    final availability = <String, bool>{
      for (final field in const ['mobile_phone', 'property_warehouse_id'])
        field: present.contains(field),
    };
    final row = rows.first;
    final record = CatalogRecord<Map<String, dynamic>>(
      uuid: '${scope.scopeKey}:currentUser:${row['id']}',
      value: {
        ...row,
        'is_current_user': true,
        '_field_selections': selections,
        '_field_availability': availability,
      },
    );
    return CatalogBatch(records: [record], cursor: null);
  }

  Future<CatalogBatch<Map<String, dynamic>>> _runPartner(
    AppScope scope,
  ) async {
    final partnerId = await _resolveCurrentPartnerId(scope);
    if (partnerId == null) {
      return const CatalogBatch(records: [], cursor: null);
    }
    final present = await _resolvePartnerFields();
    final rows = await reader.searchRead(
      model: 'res.partner',
      fields: ['id', ...present],
      domain: [
        ['id', '=', partnerId],
      ],
      limit: 1,
    );
    final records = rows
        .map(
          (row) => CatalogRecord<Map<String, dynamic>>(
            uuid: '${scope.scopeKey}:currentUserPartner:${row['id']}',
            value: row,
          ),
        )
        .toList(growable: false);
    return CatalogBatch(records: records, cursor: null);
  }

  Future<int?> _resolveCurrentPartnerId(AppScope scope) async {
    final rows = await reader.searchRead(
      model: 'res.users',
      fields: const ['id', 'partner_id'],
      domain: [
        ['id', '=', scope.userId],
      ],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return extractMany2oneId(rows.first['partner_id']);
  }

  Future<(List<String>, Map<String, dynamic>)>
  _resolveUserFieldsAndMetadata() =>
      _userFieldsAndMetadataFuture ??= _fetchUserFieldsAndMetadata();

  Future<(List<String>, Map<String, dynamic>)>
  _fetchUserFieldsAndMetadata() async {
    if (reader is! Json2FieldsGetPort) {
      throw StateError('Odoo reader does not expose fields_get');
    }
    final metadata = await (reader as Json2FieldsGetPort).fieldsGet(
      model: 'res.users',
      fields: _currentUserCandidateFields,
    );
    final present = _currentUserCandidateFields
        .where(metadata.containsKey)
        .toList(growable: false);
    return (present, metadata);
  }

  Future<List<String>> _resolvePartnerFields() =>
      _partnerFieldsFuture ??= _fetchPartnerFields();

  /// Reutiliza [PartnerRecordMapper.fields] — el mismo contrato que ya usa el
  /// catálogo `customers` — en vez de mantener una segunda lista de campos de
  /// `res.partner` con el riesgo de que diverjan.
  Future<List<String>> _fetchPartnerFields() async {
    if (reader is! Json2FieldsGetPort) {
      throw StateError('Odoo reader does not expose fields_get');
    }
    final candidates = PartnerRecordMapper.fields
        .where((field) => field != 'id')
        .toList(growable: false);
    final metadata = await (reader as Json2FieldsGetPort).fieldsGet(
      model: 'res.partner',
      fields: candidates,
    );
    return candidates.where(metadata.containsKey).toList(growable: false);
  }

  static List<List<String>>? _extractSelection(
    Map<String, dynamic> metadata,
    String field,
  ) {
    final fieldMeta = metadata[field];
    if (fieldMeta is! Map) return null;
    final selection = fieldMeta['selection'];
    if (selection is! List) return null;
    final pairs = <List<String>>[];
    for (final entry in selection) {
      if (entry is List && entry.length >= 2) {
        pairs.add([entry[0].toString(), entry[1].toString()]);
      }
    }
    return pairs.isEmpty ? null : pairs;
  }
}

/// Fields that are real on the deployed sale/order and accounting models.
///
/// `payment_state` belongs to `account.move`, not `sale.order`.  Likewise,
/// `amount_to_invoice` is a readable but non-stored sale-order compute and
/// therefore must never be placed in a remote domain.  The remaining summary
/// fields used by the local cache are derived by [RuntimeOrderRemoteState].
abstract final class RuntimeOrderRemoteFields {
  static const saleOrder = [
    'id',
    'name',
    'client_order_ref',
    'state',
    'locked',
    'user_id',
    'partner_id',
    'amount_total',
    'amount_untaxed',
    'amount_tax',
    'invoice_status',
    'amount_to_invoice',
    'invoice_ids',
    'picking_ids',
    'date_order',
    'company_id',
  ];

  static const invoice = ['id', 'state', 'payment_state', 'amount_residual'];

  static const paymentLine = [
    'id',
    'sale_id',
    // This is a computed, non-stored field on the native payment-line model.
    // It is intentionally read and filtered locally, never used in a domain.
    'state',
    'move_id',
    'amount',
  ];

  /// Validates the exact fields requested by the reader against a JSON-2
  /// `fields_get` response.  The server may return extra metadata, but every
  /// requested field must be present before the reader can rely on it.
  static void assertReadable(
    String model,
    List<String> requested,
    Map<String, dynamic> metadata,
  ) {
    final missing = requested
        .where((field) => !metadata.containsKey(field))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw StateError(
        'Odoo read contract for $model is missing: ${missing.join(', ')}',
      );
    }
  }
}

/// Enriches sale orders from native invoices/payment lines without pretending
/// that local summary columns are searchable Odoo fields.  The returned
/// summary keys intentionally retain the local-cache contract so callers do
/// not need a second representation of an order.
final class RuntimeOrderRemoteState {
  const RuntimeOrderRemoteState(this.reader);

  final Json2ReadPort reader;

  Future<List<Map<String, dynamic>>> enrich(
    List<Map<String, dynamic>> orders, {
    // `l10n_ec_collection_box.sale.order.payment` is only readable by the
    // Cajero/Supervisor de Caja groups (`ir.model.access`); a plain seller's
    // session gets a 403 from Odoo when this is requested for them. The
    // caller must state whether the active session actually carries that
    // capability — defaulting to false means "do not ask" rather than
    // guessing and catching the resulting error.
    bool canReadCollectionPayments = false,
  }) async {
    if (orders.isEmpty) return const [];
    final orderIds = <int>{};
    for (final order in orders) {
      final id = _positiveInt(order['id']);
      if (id != null) orderIds.add(id);
    }
    final invoiceIds = <int>{};
    for (final order in orders) {
      invoiceIds.addAll(_manyIds(order['invoice_ids']));
    }
    final invoices = invoiceIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _readAll(
            model: 'account.move',
            fields: RuntimeOrderRemoteFields.invoice,
            domain: [
              ['id', 'in', invoiceIds.toList()..sort()],
            ],
          );
    final paymentLines = orderIds.isEmpty || !canReadCollectionPayments
        ? const <Map<String, dynamic>>[]
        : await _readAll(
            model: 'l10n_ec_collection_box.sale.order.payment',
            fields: RuntimeOrderRemoteFields.paymentLine,
            domain: [
              ['sale_id', 'in', orderIds.toList()..sort()],
            ],
          );
    final invoicesById = <int, Map<String, dynamic>>{};
    for (final invoice in invoices) {
      final id = _positiveInt(invoice['id']);
      if (id != null) invoicesById[id] = invoice;
    }
    final paymentsBySale = <int, List<Map<String, dynamic>>>{};
    for (final payment in paymentLines) {
      final saleId = _positiveInt(_many2oneId(payment['sale_id']));
      if (saleId == null) continue;
      (paymentsBySale[saleId] ??= []).add(payment);
    }
    return [
      for (final source in orders)
        _withDerivedState(
          source,
          invoicesById,
          paymentsBySale[_positiveInt(source['id'])] ?? const [],
        ),
    ];
  }

  static Map<String, dynamic> _withDerivedState(
    Map<String, dynamic> source,
    Map<int, Map<String, dynamic>> invoicesById,
    List<Map<String, dynamic>> paymentLines,
  ) {
    final invoices = <Map<String, dynamic>>[];
    for (final id in _manyIds(source['invoice_ids'])) {
      final invoice = invoicesById[id];
      if (invoice != null) invoices.add(invoice);
    }
    var amountUnpaid = 0.0;
    final paymentStates = <String>{};
    for (final invoice in invoices) {
      if (invoice['state'] == 'cancel') continue;
      final residual = _number(invoice['amount_residual']);
      if (residual > 0) amountUnpaid += residual;
      final state = invoice['payment_state'];
      if (state is String && state.isNotEmpty) paymentStates.add(state);
    }
    final paymentState = _aggregatePaymentState(paymentStates);
    final hasNativePendingPayment = paymentLines.any((line) {
      final state = line['state'];
      // A posted line is already accounted for. Only a draft line without
      // its native move is still pending; cancelled and posted lines must not
      // make a fully paid order appear in the cashier queue.
      return state == 'draft' &&
          _many2oneId(line['move_id']) == null &&
          _number(line['amount']) > 0;
    });
    final amountToInvoice = _number(source['amount_to_invoice']);
    final invoiceStatus = source['invoice_status'];
    final pendingCollection =
        amountUnpaid > 0.01 ||
        const {'not_paid', 'partial', 'in_payment'}.contains(paymentState) ||
        hasNativePendingPayment;
    final pendingInvoicing =
        amountToInvoice > 0.01 ||
        invoiceStatus == 'to invoice' ||
        invoiceStatus == 'upselling';
    return {
      ...source,
      'payment_state': paymentState,
      'amount_unpaid': amountUnpaid,
      // No server field exists for this local queue marker. Preserve it when
      // a caller enriches an already-local row; refreshOnline also omits this
      // column from the conflict update so remote reads cannot clear it.
      'has_queued_invoice': source['has_queued_invoice'] == true,
      '_runtime_pending_collection': pendingCollection,
      '_runtime_pending_invoicing': pendingInvoicing,
    };
  }

  static bool isCashierPending(Map<String, dynamic> row) =>
      row['_runtime_pending_collection'] == true ||
      row['_runtime_pending_invoicing'] == true;

  static String? _aggregatePaymentState(Set<String> states) {
    if (states.contains('in_payment')) return 'in_payment';
    if (states.contains('partial')) return 'partial';
    if (states.contains('not_paid')) return 'not_paid';
    if (states.contains('paid')) return 'paid';
    return null;
  }

  Future<List<Map<String, dynamic>>> _readAll({
    required String model,
    required List<String> fields,
    required List<dynamic> domain,
  }) async {
    const pageSize = 200;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await reader.searchRead(
        model: model,
        fields: fields,
        domain: domain,
        limit: pageSize,
        offset: offset,
        order: 'id asc',
      );
      if (page.isEmpty) break;
      rows.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }
    return rows;
  }

  static double _number(Object? value) =>
      value is num && value.isFinite ? value.toDouble() : 0;

  static int? _positiveInt(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value.isFinite && value > 0) return value.toInt();
    return null;
  }

  static int? _many2oneId(Object? value) {
    if (value is List && value.isNotEmpty) return _positiveInt(value.first);
    return _positiveInt(value);
  }

  static Set<int> _manyIds(Object? value) {
    if (value is! List) return const {};
    final ids = <int>{};
    for (final item in value) {
      final directId = _positiveInt(item);
      if (directId != null) {
        ids.add(directId);
      } else if (item is List && item.isNotEmpty) {
        final pairId = _positiveInt(item.first);
        if (pairId != null) ids.add(pairId);
      }
    }
    return ids;
  }
}

final class RuntimeOrderReader {
  final Json2ReadPort reader;
  const RuntimeOrderReader(this.reader);

  /// Performs the read-only JSON-2 contract probe used when activating a new
  /// Odoo scope. This is intentionally explicit (rather than on every page)
  /// because `fields_get` is metadata I/O and the SDK/client owns its cache.
  ///
  /// Deliberately excludes `l10n_ec_collection_box.sale.order.payment`: that
  /// model is only readable by the Cajero/Supervisor de Caja groups, so
  /// probing it here would ask Odoo about a model most sessions can never
  /// touch. See [validateCollectionPaymentContract] for that gated probe.
  Future<void> validateRemoteContract() => _validateContracts(const {
    'sale.order': RuntimeOrderRemoteFields.saleOrder,
    'account.move': RuntimeOrderRemoteFields.invoice,
  });

  /// Same probe as [validateRemoteContract], but for the collection-payment
  /// model. Callers must only invoke this for a session that actually holds
  /// the `cashier` capability — Odoo answers everyone else with a 403.
  Future<void> validateCollectionPaymentContract() => _validateContracts(const {
    'l10n_ec_collection_box.sale.order.payment':
        RuntimeOrderRemoteFields.paymentLine,
  });

  Future<void> _validateContracts(Map<String, List<String>> contracts) async {
    if (reader is! Json2FieldsGetPort) {
      throw StateError('Odoo reader does not expose fields_get');
    }
    final metadataReader = reader as Json2FieldsGetPort;
    for (final entry in contracts.entries) {
      final metadata = await metadataReader.fieldsGet(
        model: entry.key,
        fields: entry.value,
      );
      RuntimeOrderRemoteFields.assertReadable(entry.key, entry.value, metadata);
    }
  }

  Future<List<Map<String, dynamic>>> read(
    OrderQuery query, {
    bool canReadCollectionPayments = false,
  }) async {
    final domain = _domain(query);
    final state = RuntimeOrderRemoteState(reader);
    if (query.workQueue != OrderWorkQueue.cashierPending) {
      final rows = await reader.searchRead(
        model: 'sale.order',
        fields: RuntimeOrderRemoteFields.saleOrder,
        domain: domain,
        limit: query.limit,
        order: query.stableOrder,
      );
      return state.enrich(
        rows,
        canReadCollectionPayments: canReadCollectionPayments,
      );
    }

    // Cashier state is derived from native account.move/payment rows. Keep
    // fetching stable pages until the requested number of pending orders is
    // found or Odoo proves that there are no more orders.
    const pageSize = 100;
    final pending = <Map<String, dynamic>>[];
    var offset = 0;
    while (pending.length < query.limit) {
      final page = await reader.searchRead(
        model: 'sale.order',
        fields: RuntimeOrderRemoteFields.saleOrder,
        domain: domain,
        limit: pageSize,
        offset: offset,
        order: query.stableOrder,
      );
      if (page.isEmpty) break;
      final enriched = await state.enrich(
        page,
        canReadCollectionPayments: canReadCollectionPayments,
      );
      pending.addAll(enriched.where(RuntimeOrderRemoteState.isCashierPending));
      if (page.length < pageSize) break;
      offset += page.length;
    }
    return pending.take(query.limit).toList(growable: false);
  }

  static List<dynamic> _domain(OrderQuery query) {
    final domain = <dynamic>[
      ['company_id', '=', query.companyId],
    ];
    if (query.workQueue == OrderWorkQueue.cashierPending) {
      // The cashier predicate is derived after reading native invoices and
      // payment lines. These local summary fields are not remote fields.
      domain.add(['state', '=', SaleOrderState.sale.code]);
    }
    if (query.states.isNotEmpty) {
      domain.add([
        'state',
        'in',
        query.states.map((state) => state.code).toList(growable: false),
      ]);
    }
    if (query.workQueue != OrderWorkQueue.cashierPending &&
        query.authorFilter != null) {
      domain.add(['user_id', '=', query.authorFilter]);
    }
    if (query.text case final text? when text.trim().isNotEmpty) {
      domain.add('|');
      domain.add(['name', 'ilike', text.trim()]);
      domain.add(['client_order_ref', 'ilike', text.trim()]);
    }
    if (query.dateFrom != null) {
      domain.add(['date_order', '>=', query.dateFrom!.toIso8601String()]);
    }
    if (query.dateTo != null) {
      domain.add(['date_order', '<=', query.dateTo!.toIso8601String()]);
    }
    if (query.afterId != null) domain.add(['id', '<', query.afterId]);
    return domain;
  }
}
