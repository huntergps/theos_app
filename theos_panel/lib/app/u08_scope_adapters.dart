import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_qweb/flutter_qweb.dart' show RenderOptions;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/activities/activity_center.dart';
import '../features/auth/auth_controller.dart';
import '../features/home/home_center.dart';
import '../features/home/home_dashboard_view.dart' show homeCurrencyLabel;
import '../features/home/home_resume_status.dart';
import '../features/reports/document_view.dart';
import '../features/reports/offline_qweb_report.dart';
import 'envases_composition.dart' show envasesPorRecibirControllerProvider;
import 'notification_scope_adapter.dart';

final scopeHomeResumePortProvider = Provider<HomeResumePort?>((ref) {
  final sessions = ref.watch(runtimeSessionProvider);
  if (sessions == null) return null;
  final port = ScopeHomeResumePort(
    sessions,
    ref.watch(capabilitySnapshotProvider),
  );
  unawaited(port.load());
  return port;
});

final scopeActivityPortProvider = Provider<ActivityPort?>((ref) {
  final sessions = ref.watch(runtimeSessionProvider);
  if (sessions == null) return null;
  final port = ScopeActivityPort(
    sessions,
    ref.watch(capabilitySnapshotProvider),
    producer: ScopeU08SyncProducer(
      sessions,
      ref.watch(capabilitySnapshotProvider),
    ),
  );
  final active = sessions.active;
  if (active != null && port.producer != null) {
    unawaited(port.producer!.syncActivities(lease: active.lease));
  }
  unawaited(port.load());
  return port;
});

final scopeDocumentRenderPortProvider = Provider<DocumentRenderPort?>((ref) {
  final sessions = ref.watch(runtimeSessionProvider);
  if (sessions == null) return null;
  return ScopeDocumentRenderPort(sessions);
});

/// Local U08 adapters. They only read metadata written by real producers and
/// reject writes/reads after the active session lease changes.
final class ScopeHomeResumePort implements HomeResumePort {
  ScopeHomeResumePort(this.sessions, this.capabilities);
  final SessionRuntime sessions;
  final CapabilitySnapshot? capabilities;
  final _changes = StreamController<HomeResumeSnapshot>.broadcast();
  HomeResumeSnapshot _snapshot = const HomeResumeSnapshot(
    HomeResumeState.loading,
  );

  @override
  HomeResumeSnapshot get snapshot => _snapshot;
  @override
  Stream<HomeResumeSnapshot> get changes => _changes.stream;

  @override
  Future<void> resume(HomeResumeItem item) async {
    final active = sessions.active;
    if (active == null) return;
    if (!sessions.accepts(active.lease)) return;
    // Navigation is owned by the UI; this port never executes business work.
  }

  Future<HomeResumeSnapshot> load() async {
    final active = sessions.active;
    if (active == null) {
      return _publish(
        const HomeResumeSnapshot(
          HomeResumeState.error,
          message: 'Sesión no activa',
        ),
      );
    }
    final lease = active.lease;
    try {
      final raw = await RuntimeMetadataStore(sessions)
          .read('ui/home/${active.scope.scopeKey}', lease: lease);
      if (!sessions.accepts(lease)) {
        return _publish(
          const HomeResumeSnapshot(
            HomeResumeState.error,
            message: 'La sesión cambió durante la carga',
          ),
        );
      }
      final items = <HomeResumeItem>[];
      if (raw != null) {
        final value = jsonDecode(raw);
        if (value is! List) {
          return _publish(
            const HomeResumeSnapshot(
              HomeResumeState.error,
              message: 'Pendientes locales inválidos',
            ),
          );
        }
        items.addAll(_decodeItems(value));
      }
      // A producer may provide richer business-specific cards. Fill the
      // screen from canonical local orders and queue state when it does not.
      items.addAll(await _localResumeItems(active, lease));
      if (!sessions.accepts(lease)) {
        return _publish(
          const HomeResumeSnapshot(
            HomeResumeState.error,
            message: 'La sesión cambió durante la carga',
          ),
        );
      }
      final unique = <String, HomeResumeItem>{
        for (final item in items) item.id: item,
      };
      return _publish(
        HomeResumeSnapshot(
          unique.isEmpty ? HomeResumeState.empty : HomeResumeState.data,
          items: unique.values.toList(growable: false),
        ),
      );
    } on FormatException {
      return _publish(
        const HomeResumeSnapshot(
          HomeResumeState.error,
          message: 'Pendientes locales inválidos',
        ),
      );
    } catch (_) {
      return _publish(
        const HomeResumeSnapshot(
          HomeResumeState.error,
          message: 'No se pudo leer el trabajo local',
        ),
      );
    }
  }

  HomeResumeSnapshot _publish(HomeResumeSnapshot value) {
    _snapshot = value;
    if (!_changes.isClosed) _changes.add(value);
    return value;
  }

  List<HomeResumeItem> _decodeItems(List value) {
    final decoded = <HomeResumeItem>[];
    for (final raw in value.whereType<Map>()) {
      final permission = raw['permission'] as String?;
      if (permission != null &&
          capabilities?.permissions.contains(permission) != true) {
        continue;
      }
      final id = raw['id'] as String?;
      final title = raw['title'] as String?;
      final subtitle = raw['subtitle'] as String?;
      if (id == null ||
          id.trim().isEmpty ||
          title == null ||
          subtitle == null) {
        continue;
      }
      final count = raw['count'];
      decoded.add(
        HomeResumeItem(
          id: id,
          title: title,
          subtitle: subtitle,
          actionLabel: raw['actionLabel'] as String? ?? 'Abrir',
          route: raw['route'] as String?,
          count: count is num ? count.toInt() : null,
        ),
      );
    }
    return decoded;
  }

  /// Una fila por documento real, no un contador — orden del dueño en
  /// ACC-03: «Documentos a continuar» es una tabla/lista de documentos, cada
  /// uno con su propia fecha, contraparte y total. Las actividades ya no
  /// aparecen aquí: tienen su propia pestaña («Actividad reciente»), que lee
  /// `ActivityPort` directamente en vez de duplicarse en este puerto.
  Future<List<HomeResumeItem>> _localResumeItems(
    SessionActivation active,
    SessionLease lease,
  ) async {
    final db = active.database.database;
    final result = <HomeResumeItem>[];
    final permissions = capabilities?.permissions ?? const <String>{};
    final companyId = capabilities?.companyId;
    if (companyId == null) return result;
    final userId = active.scope.userId;
    final canViewAll = permissions.contains('orders.view_all');

    if (permissions.contains('seller')) {
      var predicate =
          db.saleOrder.companyId.equals(companyId) &
          (db.saleOrder.state.equals('draft') |
              db.saleOrder.pendingConfirm.equals(true));
      if (!canViewAll) predicate = predicate & db.saleOrder.userId.equals(userId);
      final rows =
          await (db.select(db.saleOrder)
                ..where((row) => predicate)
                ..orderBy([(row) => OrderingTerm.desc(row.dateOrder)])
                ..limit(50))
              .get();
      for (final row in rows) {
        result.add(
          HomeResumeItem(
            id: 'home:sales:doc:${row.id}',
            title: row.name,
            subtitle: row.pendingConfirm
                ? 'Confirmada localmente, por sincronizar'
                : 'Borrador sin confirmar',
            actionLabel: 'Ver ventas',
            route: '/sales',
            status: row.pendingConfirm
                ? HomeResumeStatus.enProceso
                : HomeResumeStatus.pendiente,
            documentDate: row.dateOrder,
            counterpart: row.partnerName,
            moduleLabel: 'Ventas',
            totalLabel: homeCurrencyLabel(row.amountTotal),
          ),
        );
      }
    }

    if (permissions.contains('cashier')) {
      final rows =
          await (db.select(db.saleOrder)
                ..where(
                  (row) =>
                      row.companyId.equals(companyId) &
                      row.state.equals('sale') &
                      (row.amountUnpaid.isBiggerThanValue(0) |
                          row.paymentState.isIn(const [
                            'not_paid',
                            'partial',
                            'in_payment',
                          ]) |
                          row.amountToInvoice.isBiggerThanValue(0) |
                          row.hasQueuedInvoice.equals(true)),
                )
                ..orderBy([(row) => OrderingTerm.desc(row.dateOrder)])
                ..limit(50))
              .get();
      for (final row in rows) {
        final amount = row.amountUnpaid > 0 ? row.amountUnpaid : row.amountTotal;
        result.add(
          HomeResumeItem(
            id: 'home:collection:doc:${row.id}',
            title: row.name,
            subtitle: 'Por cobrar',
            actionLabel: 'Abrir caja',
            route: '/collection',
            status: HomeResumeStatus.pendiente,
            documentDate: row.dateOrder,
            counterpart: row.partnerName,
            moduleLabel: 'Caja',
            totalLabel: homeCurrencyLabel(amount),
          ),
        );
      }
    }

    // Sin permiso propio: la cola offline es del DISPOSITIVO, no de un rol
    // de negocio — la misma razón por la que `/sync` está abierto a
    // cualquier persona autenticada en `RouteAccessPolicy` (orden del dueño,
    // 13-sep-2026: «todos los usuarios deben poder ver la información de
    // sincronización, offline»).
    final queueRows =
        await (db.select(db.offlineQueue)
              ..where(
                (row) => row.status.isIn(const [
                  'pending',
                  'processing',
                  'failed',
                ]),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(50))
            .get();
    for (final row in queueRows) {
      final module = _queueModuleLabel(row.model);
      result.add(
        HomeResumeItem(
          id: 'home:sync:doc:${row.id}',
          title: row.recordId != null
              ? '$module local #${row.recordId}'
              : '$module #${row.id}',
          subtitle: 'Pendiente de enviar a Odoo',
          actionLabel: 'Revisar',
          route: '/sync',
          status: switch (row.status) {
            'failed' => HomeResumeStatus.error,
            'processing' => HomeResumeStatus.enProceso,
            _ => HomeResumeStatus.pendiente,
          },
          documentDate: row.createdAt,
          moduleLabel: 'Sincronización',
        ),
      );
    }
    return result;
  }

  /// Nombre legible del módulo dueño de una operación de la cola offline,
  /// para el título de su fila («Venta local #42»). Un modelo que no se
  /// reconoce se muestra tal cual llega — nunca se inventa una etiqueta.
  static String _queueModuleLabel(String model) => switch (model) {
    'sale.order' || 'sale.order.line' => 'Venta',
    'collection.session' || 'collection.payment' => 'Cobro',
    'l10n_ec.envases.operacion' => 'Envases',
    _ => model,
  };
}

/// Traslados de envases por recibir, convertidos a filas de «Documentos a
/// continuar» — reutiliza el mismo controlador que ya usa la pantalla real
/// de Envases (`envasesPorRecibirControllerProvider` en
/// `envases_composition.dart`), sin abrir un segundo caché ni repetir su
/// lectura RPC. Lista vacía (nunca `null`) cuando falta el permiso o el
/// controlador no está disponible: «no hay dato» se lee como «cero filas»,
/// no como error.
final homeEnvasesPorRecibirItemsProvider =
    StreamProvider.autoDispose<List<HomeResumeItem>>((ref) {
      final capabilities = ref.watch(capabilitySnapshotProvider);
      if (capabilities == null ||
          !capabilities.permissions.contains('envases_read')) {
        return Stream.value(const []);
      }
      final controller = ref.watch(envasesPorRecibirControllerProvider);
      if (controller == null) return Stream.value(const []);
      return controller.snapshots.map(
        (snapshot) => [
          for (final row in snapshot?.rows ?? const <EnvasesPorRecibirRow>[])
            HomeResumeItem(
              id: 'home:envases:por-recibir:${row.id}',
              title: row.name,
              subtitle: row.sentido,
              actionLabel: 'Ver traslado',
              route: '/envases/por-recibir/${row.id}',
              status: HomeResumeStatus.porRecibir,
              documentDate: row.fechaSalida,
              counterpart: row.sentido,
              moduleLabel: 'Envases',
            ),
        ],
      );
    });

final class ScopeActivityPort implements ActivityPort {
  ScopeActivityPort(this.sessions, this.capabilities, {this.producer});
  final SessionRuntime sessions;
  final CapabilitySnapshot? capabilities;
  final ScopeU08SyncProducer? producer;
  final _changes = StreamController<List<ActivityItem>>.broadcast();
  List<ActivityItem> _snapshot = const [];

  @override
  List<ActivityItem> get snapshot => _snapshot;
  @override
  Stream<List<ActivityItem>> get changes => _changes.stream;

  Future<void> load() async {
    final active = sessions.active;
    if (active == null ||
        capabilities?.permissions.contains('activities') != true) {
      _snapshot = const [];
      return;
    }
    final lease = active.lease;
    final raw = await RuntimeMetadataStore(sessions)
        .read('ui/activities/${active.scope.scopeKey}', lease: lease);
    if (!sessions.accepts(lease)) return;
    final decoded = raw == null ? const <dynamic>[] : jsonDecode(raw);
    final rows = decoded is Map ? decoded['items'] : decoded;
    if (rows is! List) return;
    _snapshot = rows
        .whereType<Map>()
        .map(_item)
        .whereType<ActivityItem>()
        .toList(growable: false);
    _changes.add(_snapshot);
  }

  @override
  Future<bool> complete(ActivityItem item) async {
    final active = sessions.active;
    if (active == null || !sessions.accepts(active.lease)) return false;
    final currentProducer = producer;
    if (currentProducer == null) return false;
    final completed = await currentProducer.completeActivity(
      item.id,
      lease: active.lease,
    );
    if (completed && sessions.accepts(active.lease)) await load();
    return completed;
  }

  ActivityItem? _item(Map value) {
    final id = value['id']?.toString();
    final title = value['title']?.toString();
    if (id == null || id.isEmpty || title == null || title.isEmpty) return null;
    final name = value['status']?.toString();
    final match = ActivityStatus.values.where((item) => item.name == name);
    final documentId = value['documentId'];
    return ActivityItem(
      id: id,
      title: title,
      status: match.isEmpty ? ActivityStatus.planned : match.first,
      canComplete: value['canComplete'] == true,
      note: value['note'] as String?,
      activityType: value['activityType'] as String?,
      documentModel: value['documentModel'] as String?,
      documentId: documentId is num ? documentId.toInt() : null,
      documentLabel: value['documentLabel'] as String?,
      responsibleId: value['responsibleId'] is num
          ? (value['responsibleId'] as num).toInt()
          : null,
      responsibleName: value['responsibleName'] as String?,
      deadline: DateTime.tryParse(value['deadline']?.toString() ?? ''),
    );
  }
}

/// JSON-2 producer for the U08 caches. It writes only scope-keyed metadata;
/// it never treats a payment as fiscal authorization or fabricates documents.
final class ScopeU08SyncProducer {
  ScopeU08SyncProducer(this.sessions, this.capabilities);
  final SessionRuntime sessions;
  final CapabilitySnapshot? capabilities;

  Future<void> syncActivities({required SessionLease lease}) async {
    final active = sessions.active;
    if (active == null ||
        !sessions.accepts(lease) ||
        capabilities?.permissions.contains('activities') != true ||
        active.client == null) {
      return;
    }
    final rows = await OdooJson2ReadPort(active.client!).searchRead(
      model: 'mail.activity',
      fields: const [
        'id',
        'summary',
        'note',
        'date_deadline',
        'state',
        'active',
        'user_id',
        'activity_type_id',
        'res_model',
        'res_id',
        'res_name',
      ],
      domain: [
        ['user_id', '=', active.scope.userId],
        ['active', '=', true],
      ],
      order: 'date_deadline asc,id asc',
      limit: 200,
    );
    if (!sessions.accepts(lease)) return;
    final now = DateTime.now().toUtc();
    final values = [
      for (final row in rows)
        {
          'id': '${row['id']}',
          'title': row['summary'] as String? ?? 'Actividad',
          'status': _activityStatus(row['date_deadline'], row['state']),
          'canComplete': true,
          'note': row['note'] as String?,
          'activityType': _many2oneName(row['activity_type_id']),
          'documentModel': row['res_model'] as String?,
          'documentId': row['res_id'],
          'documentLabel': row['res_name'] as String?,
          'responsibleId': _many2oneId(row['user_id']),
          'responsibleName': _many2oneName(row['user_id']),
          'deadline': row['date_deadline']?.toString(),
        },
    ];
    await RuntimeMetadataStore(sessions).write(
      'ui/activities/${active.scope.scopeKey}',
      jsonEncode({'fetchedAt': now.toIso8601String(), 'items': values}),
      lease: lease,
    );
  }

  Future<bool> completeActivity(
    String id, {
    required SessionLease lease,
  }) async {
    final active = sessions.active;
    if (active == null || active.client == null || !sessions.accepts(lease)) {
      return false;
    }
    if (capabilities?.permissions.contains('activities') != true) {
      return false;
    }
    try {
      final remoteId = int.tryParse(id);
      if (remoteId == null || remoteId <= 0) return false;
      final result = await active.client!.call(
        model: 'mail.activity',
        method: 'action_done',
        ids: [remoteId],
      );
      if (!sessions.accepts(lease) ||
          result is Map && result['error'] != null) {
        return false;
      }
      await syncActivities(lease: lease);
    } catch (_) {
      return false;
    }
    return true;
  }

  Future<void> syncDocument(
    String documentId, {
    required SessionLease lease,
  }) async {
    final active = sessions.active;
    if (active == null || active.client == null || !sessions.accepts(lease)) {
      return;
    }
    final id = int.tryParse(documentId);
    if (id == null) throw ArgumentError.value(documentId, 'documentId');
    final rows = await OdooJson2ReadPort(active.client!).searchRead(
      model: 'ir.attachment',
      fields: const ['id', 'name', 'mimetype', 'datas'],
      domain: [
        ['id', '=', id],
      ],
      limit: 1,
    );
    if (!sessions.accepts(lease) ||
        rows.length != 1 ||
        rows.single['datas'] is! String) {
      return;
    }
    final row = rows.single;
    final encoded = row['datas'] as String;
    final document = CachedDocument(
      title: row['name'] as String? ?? documentId,
      bytes: base64Decode(encoded),
      mimeType: row['mimetype'] as String? ?? 'application/octet-stream',
      // Generic ir.attachment records have no authoritative fiscal state.
      // Keep it explicitly non-fiscal rather than guessing authorization.
      fiscalState: DocumentFiscalState.notRequired,
      syncState: DocumentSyncState.synced,
    );
    // Validate bytes before committing the cache. This keeps a corrupt or
    // malformed response from becoming an apparently valid offline file.
    CachedDocumentCodec.decode(
      CachedDocumentCodec.encode(document),
      documentId: documentId,
    );
    await RuntimeMetadataStore(sessions).write(
      'ui/documents/${active.scope.scopeKey}/$documentId',
      CachedDocumentCodec.encode(document),
      lease: lease,
    );
  }

  /// JSON-2 representa un many2one como `[id, "Nombre"]` (ver
  /// `odoo_sdk/lib/src/api/odoo_response_parser.dart`); `false` cuando el
  /// campo está vacío.
  static String? _many2oneName(Object? value) {
    if (value is List && value.length > 1 && value[1] is String) {
      final name = value[1] as String;
      return name.isEmpty ? null : name;
    }
    return null;
  }

  static int? _many2oneId(Object? value) {
    if (value is List && value.isNotEmpty && value.first is num) {
      return (value.first as num).toInt();
    }
    return null;
  }

  String _activityStatus(dynamic deadline, dynamic state) {
    if (state == 'done') return 'done';
    final date = DateTime.tryParse('$deadline');
    if (date == null) return 'planned';
    final today = DateTime.now().toUtc();
    final day = DateTime.utc(today.year, today.month, today.day);
    final due = DateTime.utc(date.year, date.month, date.day);
    if (due.isBefore(day)) return 'overdue';
    if (due == day) return 'today';
    return 'planned';
  }
}

final class ScopeDocumentRenderPort implements DocumentRenderPort {
  ScopeDocumentRenderPort(this.sessions);
  final SessionRuntime sessions;

  /// Render from the already-synced QWeb cache and persist the bytes in the
  /// current scope. This never calls Odoo and never infers SRI authorization.
  Future<CachedDocument> generateOffline({
    required String documentId,
    required String templateName,
    required List<Map<String, dynamic>> records,
    Map<String, dynamic>? company,
    Map<String, dynamic>? user,
    RenderOptions? options,
    String docModel = '',
    DocumentFiscalState fiscalState = DocumentFiscalState.notRequired,
  }) async {
    final active = sessions.active;
    if (active == null) throw StateError('Sesión no activa');
    final lease = active.lease;
    final generator = OfflineQwebReportGenerator(
      DatabaseQwebTemplateProvider(active.database.database),
    );
    final bytes = await generator.render(
      templateName: templateName,
      records: records,
      company: company,
      user: user,
      options: options,
      docModel: docModel,
    );
    if (!sessions.accepts(lease)) {
      throw StateError('La sesión cambió durante la generación');
    }
    final document = CachedDocument(
      title: '$documentId.pdf',
      bytes: bytes,
      mimeType: 'application/pdf',
      fiscalState: fiscalState,
      syncState: DocumentSyncState.localOnly,
    );
    await RuntimeMetadataStore(sessions).write(
      'ui/documents/${active.scope.scopeKey}/$documentId',
      CachedDocumentCodec.encode(document),
      lease: lease,
    );
    return document;
  }

  @override
  Future<CachedDocument> loadCached(String documentId) async {
    final active = sessions.active;
    if (active == null) throw StateError('Sesión no activa');
    final lease = active.lease;
    final raw = await RuntimeMetadataStore(
      sessions,
    ).read('ui/documents/${active.scope.scopeKey}/$documentId', lease: lease);
    if (!sessions.accepts(lease)) {
      throw StateError('La sesión cambió durante la carga');
    }
    if (raw == null) {
      throw StateError('No hay documento cacheado');
    }
    return CachedDocumentCodec.decode(raw, documentId: documentId);
  }
}
