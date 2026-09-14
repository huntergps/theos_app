import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../app/preferences/app_preferences.dart' show AppPreferencesController;
import '../../ui/fluent/orbi_page.dart';
import '../../ui/state_labels.dart' show syncJobLabel;

/// SYN-01/02 — "Sincronización de Datos": la pantalla que un vendedor abre
/// antes de salir a campo para descargar catálogos y vaciar la cola offline.
///
/// Todo lo que esta pantalla sabe llega por [SyncDataPort]. El widget nunca
/// construye un `OdooClient`, nunca abre `AppDatabase` y nunca lanza una
/// pasada de sincronización por su cuenta: cada acción del usuario termina en
/// una llamada al puerto, y la implementación real ([RuntimeSyncDataPort])
/// es la única que conoce el `SyncCoordinatorImpl` y la
/// `RuntimeCatalogComposition`.

/// Si el catálogo ya tiene un cursor guardado, la próxima pasada sólo pide lo
/// que cambió desde entonces. Sin cursor, la próxima pasada es una carga
/// completa (primera vez, o después de "Vaciar tablas"/"Recargar desde
/// cero"). El contenido exacto del cursor es un detalle interno del runtime
/// (`json2_read_adapters.dart` lo documenta como opaco): esta pantalla sólo
/// mira si existe, nunca lo decodifica.
enum CatalogFreshness { readyIncremental, pendingFullLoad }

/// Datos reales de un catálogo para su tarjeta en la rejilla. Nada aquí se
/// inventa: [localCount] es `records.length` de lo que ya hay en Drift,
/// [freshness] viene de si hay cursor guardado, y [lastSyncedThisSession] es
/// exactamente eso — nunca "la última vez que se sincronizó alguna vez",
/// porque el runtime no guarda esa marca de tiempo por catálogo hoy.
final class SyncCatalogCardData {
  const SyncCatalogCardData({
    required this.key,
    required this.label,
    required this.icon,
    required this.localCount,
    required this.freshness,
    this.error,
    this.lastSyncedThisSession,
    this.unsupported = false,
  });

  final String key;
  final String label;
  final IconData icon;
  final int localCount;
  final CatalogFreshness freshness;
  final Object? error;
  final DateTime? lastSyncedThisSession;

  /// El servidor activo no tiene el modelo o un campo obligatorio de este
  /// catálogo (`RuntimeCatalogAvailability`, E02) — no es un error: no se
  /// intentó sincronizar, y no cuenta para el contador de fallos del pie.
  /// La tarjeta se pinta aparte y atenuada, sin botones de acción.
  final bool unsupported;
}

/// Una fila de la lista "Preparar datos para trabajar". [detail] siempre
/// describe lo que se comprobó de verdad, nunca un texto genérico.
final class SyncReadinessItem {
  const SyncReadinessItem({
    required this.label,
    required this.ok,
    required this.detail,
  });

  final String label;
  final bool ok;
  final String detail;
}

/// Puerto que alimenta la pantalla. La implementación real
/// ([RuntimeSyncDataPort]) es la única que habla con
/// `SyncCoordinatorImpl`/`RuntimeCatalogComposition`; esta interfaz existe
/// para que la pantalla se pueda probar con un doble de prueba (mocktail),
/// igual que el resto de pantallas de Orbi.
abstract interface class SyncDataPort {
  bool get isOnline;

  /// Si la sesión activa puede cobrar — decide si "Métodos de pago" entra en
  /// la lista de preparación (orden del dueño: sólo aplica a quien cobra).
  bool get userCanCollect;

  SyncSnapshot get syncSnapshot;
  Stream<SyncSnapshot> get syncSnapshots;

  Future<List<SyncCatalogCardData>> loadCatalogCards();

  /// Operaciones en la cola offline que todavía no se enviaron (pendientes,
  /// en recuperación o en revisión manual). Se usa para la lista de
  /// preparación y para deshabilitar "Vaciar tablas".
  Future<int> loadPendingOperationsCount();

  /// Sincroniza los catorce catálogos. SIEMPRE pasa por el coordinador.
  Future<void> syncAll();

  /// Sincroniza un catálogo puntual. SIEMPRE pasa por el coordinador
  /// (`SyncReason.onlyJobIds`), nunca por un lector directo.
  Future<void> syncCatalog(String key);

  /// Reinicia el cursor de un catálogo y pide una pasada: la próxima
  /// sincronización vuelve a descargarlo desde cero. Como el coordinador
  /// corre cada trabajo una vez por drenaje, una tabla grande puede tardar
  /// varios ciclos en completarse — la pantalla lo dice, no promete que
  /// termine al instante.
  Future<void> forceFullReloadCatalog(String key);

  Future<void> forceFullReloadAll();

  /// Vacía un catálogo local. Nunca borra una fila con una operación
  /// pendiente en la cola offline (lo protege el propio
  /// `LocalCatalogStore.commit`).
  Future<void> clearCatalog(String key);

  Future<void> clearAllTables();

  /// Si el vendedor pausó la sincronización automática para trabajar en
  /// ruta. Vivía como un interruptor suelto en Configuración; se trasladó
  /// aquí porque es, en los hechos, una preferencia de sincronización (orden
  /// del dueño, 13-sep-2026).
  bool get routeModeEnabled;

  Future<void> setRouteMode(bool enabled);
}

/// Orden y catálogo de iconos de los catorce catálogos reales de Orbi (ver
/// `RuntimeCatalogComposition`). Los primeros cinco son los que la lista de
/// preparación revisa uno a uno; el resto sólo aparece en la rejilla.
const List<String> orbiCatalogKeys = <String>[
  'partner',
  'product',
  'tax',
  'pricelist',
  'paymentMethodLine',
  'paymentTerm',
  'uom',
  'warehouse',
  'journal',
  'collectionConfig',
  'collectionSession',
  'cardBrand',
  'cardDeadline',
  'cardLote',
];

const Map<String, IconData> _catalogIcons = <String, IconData>{
  'partner': FluentIcons.people,
  'product': FluentIcons.product,
  'tax': FluentIcons.money,
  'pricelist': FluentIcons.tag,
  'paymentMethodLine': FluentIcons.payment_card,
  'paymentTerm': FluentIcons.calendar,
  'uom': FluentIcons.calculator,
  'warehouse': FluentIcons.home,
  'journal': FluentIcons.bank,
  'collectionConfig': FluentIcons.settings,
  'collectionSession': FluentIcons.receipt_processing,
  'cardBrand': FluentIcons.payment_card,
  'cardDeadline': FluentIcons.calendar,
  'cardLote': FluentIcons.database,
};

IconData catalogIconFor(String key) => _catalogIcons[key] ?? FluentIcons.database;

/// Ejecuta una acción con el coordinador en pausa, salvo que YA estuviera en
/// pausa por una decisión ajena a esta pantalla (hoy, sólo Modo Ruta) — en
/// ese caso no la toca: ni la reactiva de más, ni la reanuda al terminar.
/// Reanudarla sería deshacer, sin que nadie lo pidiera, la elección del
/// vendedor de no sincronizar mientras conduce.
///
/// Aislado de [RuntimeSyncDataPort]/`RuntimeCatalogComposition` a propósito:
/// esta decisión sólo depende de [SyncCoordinatorImpl], así que se puede
/// probar contra uno real y liviano (`SyncCoordinatorImpl(jobs: const [])`),
/// sin tener que construir una composición de catálogos completa (`final
/// class`, no admite un doble de prueba).
final class SyncMaintenanceGuard {
  const SyncMaintenanceGuard(this.coordinator);

  final SyncCoordinatorImpl coordinator;

  /// `pause()` fija `_paused` de forma SÍNCRONA (su cuerpo no tiene ningún
  /// `await`), así que entre la comprobación de `isPaused`/`active` y la
  /// pausa no hay hueco donde un drenaje externo (p. ej. el reintento
  /// automático al reconectar, `SyncAutoResyncTrigger`) pueda colarse.
  ///
  /// Devuelve si esta llamada tomó la pausa ella misma (y por tanto ya la
  /// reanudó al terminar, así que lo que haya hecho [action] es definitivo).
  /// `false` si el coordinador ya estaba pausado por otra razón: [action]
  /// corrió igual, pero cualquier `requestSync` que haya encolado dentro
  /// queda pendiente hasta que ESA otra pausa termine — el llamador no debe
  /// dar el resultado por sincronizado todavía.
  Future<bool> run(Future<void> Function() action) async {
    if (coordinator.isPaused) {
      await action();
      return false;
    }
    if (coordinator.snapshot.active) {
      throw StateError('Hay una sincronización en curso; espera a que termine.');
    }
    await coordinator.pause(PauseReason('sync_screen_maintenance'));
    try {
      await action();
    } finally {
      await coordinator.resume();
    }
    return true;
  }
}

/// Implementación real sobre `SyncCoordinatorImpl` + `RuntimeCatalogComposition`.
///
/// "Forzar sync completo" y "Vaciar tablas" no necesitan ningún método nuevo
/// del runtime: ambos se apoyan en `LocalCatalogStore.commit`, que ya sabe
/// borrar filas sin operación pendiente y ya sabe aceptar un cursor `null`
/// (recarga completa). Pasar `remoteActiveIds: {}` es "nada está activo en
/// el servidor" — el store borra todo lo local que no esté protegido por la
/// cola offline. Ninguna de las dos acciones lanza una pasada por su cuenta:
/// [forceFullReloadCatalog]/[forceFullReloadAll] terminan pidiendo la
/// sincronización real a través de [coordinator].
///
/// 🔴 Ambas escriben directo en `LocalCatalogStore`, fuera de un `SyncJob`:
/// si un drenaje del coordinador estuviera en vuelo al mismo tiempo, su
/// propio `commit()` (con un cursor/registros ya leídos ANTES de esta
/// llamada) podría aterrizar después del mío y deshacer en silencio el
/// reinicio de cursor o el vaciado. [_withCoordinatorPaused] cierra esa
/// ventana con `pause()`/`resume()`, que ya son públicos en
/// `SyncCoordinatorImpl` — no hace falta ningún método nuevo del runtime.
final class RuntimeSyncDataPort implements SyncDataPort {
  RuntimeSyncDataPort({
    required this.coordinator,
    required this.catalogs,
    required this.isOnline,
    required this.userCanCollect,
    required this.preferences,
    this.operationsJob,
  }) : _maintenance = SyncMaintenanceGuard(coordinator);

  final SyncCoordinatorImpl coordinator;
  final RuntimeCatalogComposition catalogs;
  final OperationsSyncJob? operationsJob;
  final SyncMaintenanceGuard _maintenance;

  /// Dueño real de la preferencia de Modo Ruta (persistida, por sesión de
  /// usuario) — la misma que hoy expone Configuración. Vive en `app/` porque
  /// `SettingsScreen` ya la usa así; moverla aquí sólo añade un segundo
  /// consumidor, no un segundo dueño.
  final AppPreferencesController preferences;

  @override
  final bool isOnline;

  @override
  final bool userCanCollect;

  @override
  bool get routeModeEnabled => preferences.snapshot.routeMode;

  // Sólo persiste. El efecto real (pausar/reanudar el coordinador) lo aplica
  // `scopeRouteModePauseProvider` (router.dart), que escucha esta MISMA
  // `AppPreferencesController` desde un punto que existe aunque esta
  // pantalla nunca se abra — así activar Modo Ruta, cerrar la app y volver
  // a abrirla deja la sincronización pausada de verdad, no sólo la
  // preferencia guardada.
  @override
  Future<void> setRouteMode(bool enabled) => preferences.setRouteMode(enabled);

  /// Cuándo se completó, en esta sesión, la última pasada sin error para
  /// cada catálogo. Se pierde al cerrar la app a propósito: el runtime no
  /// guarda hoy una marca de tiempo por catálogo (sólo el cursor), así que
  /// esto es lo único honesto que se puede mostrar sin inventar un dato.
  final Map<String, DateTime> _lastSyncedThisSession = {};

  @override
  SyncSnapshot get syncSnapshot => coordinator.snapshot;

  @override
  Stream<SyncSnapshot> get syncSnapshots => coordinator.snapshots;

  @override
  Future<List<SyncCatalogCardData>> loadCatalogCards() async {
    final scope = catalogs.activation.scope;
    final cards = <SyncCatalogCardData>[];
    for (final key in orbiCatalogKeys) {
      final store = catalogs.stores[key];
      if (store == null) continue;
      final state = await store.read(scope);
      // No sondea de más: `RuntimeCatalogAvailability.resolve` ya memoiza el
      // sondeo real (una sola `ir.model` para todos) — este `await` sólo
      // paga esa red la primera vez que la pantalla (o un job) lo pide.
      final resolved = await catalogs.availability.resolve(key);
      cards.add(
        SyncCatalogCardData(
          key: key,
          label: syncJobLabel('catalog:$key'),
          icon: catalogIconFor(key),
          localCount: state.count,
          freshness: state.cursor != null
              ? CatalogFreshness.readyIncremental
              : CatalogFreshness.pendingFullLoad,
          error: state.error,
          lastSyncedThisSession: _lastSyncedThisSession[key],
          unsupported: !resolved.canRun,
        ),
      );
    }
    return cards;
  }

  @override
  Future<int> loadPendingOperationsCount() async {
    final job = operationsJob;
    if (job == null) return 0;
    final snapshot = await job.queueSnapshot();
    return snapshot.pending + snapshot.deadLetter + snapshot.conflicts.length;
  }

  @override
  Future<void> syncAll() async {
    // Si el coordinador ya está pausado (Modo Ruta), `requestSync` sólo
    // ACUMULA la restricción y vuelve de inmediato — no hay drenaje del que
    // hablar todavía, así que no se marca nada como sincronizado.
    final queuedOnly = coordinator.isPaused;
    await coordinator.requestSync(SyncReason('sync_screen_all'));
    if (!queuedOnly) _markSyncedIfNoFailure(null);
  }

  @override
  Future<void> syncCatalog(String key) async {
    final queuedOnly = coordinator.isPaused;
    await coordinator.requestSync(
      SyncReason('sync_screen_catalog', onlyJobIds: {'catalog:$key'}),
    );
    if (!queuedOnly) _markSyncedIfNoFailure(key);
  }

  @override
  Future<void> forceFullReloadCatalog(String key) async {
    final actuallyDrained = await _maintenance.run(() async {
      final store = catalogs.stores[key];
      if (store == null) return;
      await store.commit(
        catalogs.activation.scope,
        const CatalogBatch<Map<String, dynamic>>(records: [], cursor: null),
      );
      // Si `_maintenance` no tomó la pausa ella misma (ya estaba pausado por
      // Modo Ruta), esto sólo ACUMULA la restricción; el drenaje de verdad
      // llega cuando el vendedor desactive Modo Ruta, no aquí.
      await coordinator.requestSync(
        SyncReason('sync_screen_catalog', onlyJobIds: {'catalog:$key'}),
      );
    });
    if (actuallyDrained) _markSyncedIfNoFailure(key);
  }

  @override
  Future<void> forceFullReloadAll() async {
    final actuallyDrained = await _maintenance.run(() async {
      // E02, punto 5: "Forzar Sync Completo" vuelve a preguntarle al
      // servidor qué catálogos existen — un módulo instalado después de la
      // última vez vuelve a habilitar su catálogo sin reinstalar la app.
      catalogs.availability.invalidate();
      for (final key in orbiCatalogKeys) {
        final store = catalogs.stores[key];
        if (store == null) continue;
        await store.commit(
          catalogs.activation.scope,
          const CatalogBatch<Map<String, dynamic>>(records: [], cursor: null),
        );
      }
      await coordinator.requestSync(SyncReason('sync_screen_all'));
    });
    if (actuallyDrained) _markSyncedIfNoFailure(null);
  }

  @override
  Future<void> clearCatalog(String key) async {
    await _maintenance.run(() => _clearCatalogRows(key));
  }

  @override
  Future<void> clearAllTables() async {
    await _maintenance.run(() async {
      for (final key in orbiCatalogKeys) {
        await _clearCatalogRows(key);
      }
    });
  }

  Future<void> _clearCatalogRows(String key) async {
    final store = catalogs.stores[key];
    if (store == null) return;
    await store.commit(
      catalogs.activation.scope,
      const CatalogBatch<Map<String, dynamic>>(
        records: [],
        cursor: null,
        remoteActiveIds: <int>{},
      ),
    );
  }

  void _markSyncedIfNoFailure(String? onlyKey) {
    final failedJobIds = coordinator.snapshot.failures
        .map((failure) => failure.jobId)
        .toSet();
    final now = DateTime.now();
    final keys = onlyKey == null ? orbiCatalogKeys : [onlyKey];
    for (final key in keys) {
      if (!failedJobIds.contains('catalog:$key')) {
        _lastSyncedThisSession[key] = now;
      }
    }
  }
}

class SyncDataScreen extends StatefulWidget {
  const SyncDataScreen({required this.port, this.onOpenConflicts, super.key});

  final SyncDataPort port;

  /// Abre SYN-03 (resolución de conflictos). `null` esconde el botón — por
  /// ejemplo, si quien enruta no tiene todavía una `OfflineQueueStore` con la
  /// que construir esa pantalla.
  final VoidCallback? onOpenConflicts;

  @override
  State<SyncDataScreen> createState() => _SyncDataScreenState();
}

class _SyncDataScreenState extends State<SyncDataScreen> {
  List<SyncCatalogCardData> _cards = const [];
  int _pending = 0;
  bool _loaded = false;
  bool _busy = false;
  bool _routeModeBusy = false;
  String? _actionError;
  String? _actionNotice;
  DateTime? _lastKnownCompletedAt;
  StreamSubscription<SyncSnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _lastKnownCompletedAt = widget.port.syncSnapshot.lastCompletedAt;
    unawaited(_refresh());
    _subscription = widget.port.syncSnapshots.listen((snapshot) {
      if (!mounted) return;
      if (snapshot.lastCompletedAt != _lastKnownCompletedAt) {
        _lastKnownCompletedAt = snapshot.lastCompletedAt;
        unawaited(_refresh());
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    final cards = await widget.port.loadCatalogCards();
    final pending = await widget.port.loadPendingOperationsCount();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _pending = pending;
      _loaded = true;
    });
  }

  /// Guarda explícita contra un segundo toque mientras la primera acción
  /// sigue en vuelo. No basta con deshabilitar el botón tras `setState`: en
  /// una prueba (o en una pantalla lenta en redibujar) dos toques pueden
  /// llegar antes de que el árbol se reconstruya. Esto es lo que de verdad
  /// impide una segunda pasada en paralelo.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          Button(
            key: const Key('sync-confirm-dialog-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('sync-confirm-dialog-accept'),
            style: destructive
                ? ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      FluentTheme.of(dialogContext).resources.systemFillColorCritical,
                    ),
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmForceFullAll() async {
    final confirmed = await _confirm(
      title: 'Forzar sincronización completa',
      message:
          'Se reiniciarán los catorce catálogos y se volverán a descargar '
          'desde cero. Puede tardar varios ciclos de sincronización.',
      confirmLabel: 'Forzar',
    );
    if (confirmed && _stillSafeToRunMaintenance()) {
      final queuedByRouteMode = widget.port.routeModeEnabled;
      await _run(widget.port.forceFullReloadAll);
      _noticeIfQueuedByRouteMode(queuedByRouteMode);
    }
  }

  Future<void> _confirmForceFullCatalog(String key, String label) async {
    final confirmed = await _confirm(
      title: 'Recargar $label desde cero',
      message:
          'Se reiniciará este catálogo y se volverá a descargar completo. '
          'Puede tardar varios ciclos de sincronización.',
      confirmLabel: 'Recargar',
    );
    if (confirmed && _stillSafeToRunMaintenance()) {
      final queuedByRouteMode = widget.port.routeModeEnabled;
      await _run(() => widget.port.forceFullReloadCatalog(key));
      _noticeIfQueuedByRouteMode(queuedByRouteMode);
    }
  }

  /// El estado de Modo Ruta se lee ANTES de correr la acción — no después —
  /// porque `forceFullReload*` puede tardar y, en teoría, alguien podría
  /// desactivar Modo Ruta durante esa ventana; lo que importa para este
  /// aviso es si quedó encolado cuando se pidió, no el estado final.
  void _noticeIfQueuedByRouteMode(bool queuedByRouteMode) {
    if (!mounted || !queuedByRouteMode) return;
    setState(
      () => _actionNotice =
          'Se aplicará cuando desactives el Modo Ruta: la recarga quedó '
          'encolada, no se descargó todavía.',
    );
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await _confirm(
      title: '¿Vaciar todas las tablas?',
      message:
          'Se eliminarán los catálogos guardados en este dispositivo. '
          'Tendrás que sincronizar de nuevo antes de trabajar sin conexión.',
      confirmLabel: 'Vaciar',
      destructive: true,
    );
    if (confirmed && _stillSafeToRunMaintenance()) {
      await _run(widget.port.clearAllTables);
    }
  }

  /// Vuelve a comprobar justo antes de ejecutar: el diálogo de confirmación
  /// pudo quedar abierto varios segundos, tiempo de sobra para que un
  /// drenaje externo (reconexión, otra pestaña de este mismo scope) arranque
  /// entre el toque que abrió el diálogo y la confirmación. `RuntimeSyncDataPort`
  /// también se niega a ejecutar en ese caso (ver `SyncMaintenanceGuard`),
  /// pero comprobarlo aquí evita mostrar un error genérico cuando ya sabemos
  /// que no se debe intentar. Una pausa por Modo Ruta NO cuenta como "en
  /// curso": `active` sigue en `false` mientras está pausado, así que esto
  /// nunca bloquea la acción por Modo Ruta — sólo por un drenaje de verdad.
  bool _stillSafeToRunMaintenance() {
    if (!mounted) return false;
    if (widget.port.syncSnapshot.active) {
      setState(
        () => _actionError = 'Hay una sincronización en curso; espera a que termine.',
      );
      return false;
    }
    return true;
  }

  Future<void> _setRouteMode(bool enabled) async {
    setState(() {
      _routeModeBusy = true;
      _actionError = null;
      _actionNotice = null;
    });
    try {
      await widget.port.setRouteMode(enabled);
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _routeModeBusy = false);
    }
  }

  List<SyncReadinessItem> _readiness(SyncSnapshot snapshot) {
    SyncCatalogCardData? find(String key) {
      for (final card in _cards) {
        if (card.key == key) return card;
      }
      return null;
    }

    SyncReadinessItem catalogItem(String key, String noun) {
      final count = find(key)?.localCount ?? 0;
      return SyncReadinessItem(
        label: syncJobLabel('catalog:$key'),
        ok: count > 0,
        detail: count > 0
            ? '$count $noun disponibles sin conexión'
            : 'Sin $noun — sincroniza antes de salir',
      );
    }

    final items = <SyncReadinessItem>[
      catalogItem('product', 'productos'),
      catalogItem('partner', 'clientes'),
      catalogItem('tax', 'impuestos'),
      catalogItem('pricelist', 'listas de precio'),
      if (widget.port.userCanCollect) catalogItem('paymentMethodLine', 'métodos de pago'),
      SyncReadinessItem(
        label: 'Cola offline',
        ok: _pending == 0,
        detail: _pending == 0
            ? 'No hay operaciones pendientes de enviar'
            : '$_pending operación(es) pendiente(s) de enviar',
      ),
    ];
    final lastCompleted = snapshot.lastCompletedAt;
    final recent = lastCompleted != null &&
        DateTime.now().toUtc().difference(lastCompleted) < const Duration(hours: 24);
    items.add(
      SyncReadinessItem(
        label: 'Sincronización reciente',
        ok: recent,
        detail: recent
            ? 'La última sincronización fue hace menos de 24 horas'
            : lastCompleted == null
                ? 'Todavía no se ha sincronizado en este dispositivo'
                : 'La última sincronización fue hace más de 24 horas',
      ),
    );
    // Sólo aparece si está activo: es una elección del vendedor, no un
    // problema que resolver, así que no tiene sentido listarlo como "en
    // espera" cuando está apagado (el caso normal).
    if (widget.port.routeModeEnabled) {
      items.add(
        const SyncReadinessItem(
          label: 'Modo Ruta',
          ok: true,
          detail: 'Activo: pausaste la sincronización automática por tu cuenta.',
        ),
      );
    }
    return items;
  }

  List<CommandBarItem> _commands(SyncSnapshot snapshot, bool disabled) {
    // El motivo visible de por qué un botón está deshabilitado — nunca sólo
    // un botón apagado sin explicación (orden del dueño sobre esta
    // corrección). `null` dice "sin razón para deshabilitarlo": Fluent no
    // muestra tooltip en ese caso.
    String? syncAllReason() {
      if (snapshot.active) return 'Ya hay una sincronización en curso.';
      if (!widget.port.isOnline) return 'Sin conexión al servidor.';
      if (widget.port.routeModeEnabled) {
        return 'Modo Ruta está activo: se encolará y se aplicará al desactivarlo.';
      }
      return null;
    }

    String? clearAllReason() {
      if (snapshot.active) return 'Espera a que termine la sincronización en curso.';
      if (_pending > 0) {
        return 'Hay $_pending operación(es) pendiente(s) en la cola offline.';
      }
      return null;
    }

    return [
      if (snapshot.active)
        _BusyCommandBarItem(FluentTheme.of(context).accentColor),
      CommandBarButton(
        key: const Key('sync-all-button'),
        icon: const Icon(FluentIcons.sync),
        label: const Text('Sincronizar Todo'),
        tooltip: syncAllReason(),
        onPressed: disabled || !widget.port.isOnline ? null : () => _run(widget.port.syncAll),
      ),
      CommandBarButton(
        key: const Key('force-full-sync-button'),
        icon: const Icon(FluentIcons.refresh),
        label: const Text('Forzar Sync Completo'),
        tooltip: syncAllReason() ?? 'Reinicia los catorce catálogos y los descarga desde cero.',
        onPressed:
            disabled || !widget.port.isOnline ? null : _confirmForceFullAll,
      ),
      CommandBarButton(
        key: const Key('clear-all-tables-button'),
        icon: const Icon(FluentIcons.delete),
        label: const Text('Vaciar Tablas'),
        tooltip: clearAllReason(),
        onPressed: disabled || _pending > 0 ? null : _confirmClearAll,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.port.syncSnapshot;
    final disabled = _busy || snapshot.active;
    return OrbiPage(
      title: 'Sincronización de Datos',
      subtitle: 'Descarga catálogos para usarlos también sin conexión',
      commands: _commands(snapshot, disabled),
      child: !_loaded
          ? const Center(child: ProgressRing())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_actionError != null) ...[
                    InfoBar(
                      key: const Key('sync-action-error'),
                      title: const Text('No se pudo completar la acción'),
                      content: Text(_actionError!),
                      severity: InfoBarSeverity.error,
                      onClose: () => setState(() => _actionError = null),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_actionNotice != null) ...[
                    InfoBar(
                      key: const Key('sync-action-notice'),
                      title: Text(_actionNotice!),
                      severity: InfoBarSeverity.info,
                      onClose: () => setState(() => _actionNotice = null),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (snapshot.failures.isNotEmpty || snapshot.conflictCount > 0) ...[
                    InfoBar(
                      title: Text(
                        snapshot.conflictCount > 0
                            ? 'Hay conflictos por resolver'
                            : 'Algunos catálogos no se pudieron sincronizar',
                      ),
                      content: Text(
                        snapshot.failures.isNotEmpty
                            ? snapshot.failures
                                .map((failure) => syncJobLabel(failure.jobId))
                                .join(', ')
                            : '${snapshot.conflictCount} conflicto(s) pendiente(s)',
                      ),
                      severity: InfoBarSeverity.warning,
                      action: snapshot.conflictCount > 0 && widget.onOpenConflicts != null
                          ? Button(
                              key: const Key('sync-open-conflicts-button'),
                              onPressed: widget.onOpenConflicts,
                              child: const Text('Ver conflictos'),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _primaryAction(context, snapshot, disabled),
                  const SizedBox(height: 16),
                  _routeModeCard(context),
                  const SizedBox(height: 16),
                  _readinessCard(context, snapshot),
                  const SizedBox(height: 16),
                  Text('Catálogos', style: FluentTheme.of(context).typography.subtitle),
                  const SizedBox(height: 8),
                  _catalogGrid(context, disabled: disabled),
                  if (_cards.any((card) => card.unsupported)) ...[
                    const SizedBox(height: 16),
                    Text(
                      'No disponibles en este servidor',
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    const SizedBox(height: 8),
                    _unsupportedCatalogGrid(context),
                  ],
                ],
              ),
            ),
    );
  }

  /// Antes vivía como un interruptor suelto en Configuración; se traslada
  /// aquí porque es, en los hechos, una preferencia de sincronización —
  /// mismo formato que "Modo Offline" de `theos_pos`
  /// (`offline_mode_section.dart`): icono en círculo, título, estado
  /// Activo/Inactivo con su color, la explicación de qué hace de verdad, y
  /// un `ToggleSwitch`.
  Widget _routeModeCard(BuildContext context) {
    final theme = FluentTheme.of(context);
    final enabled = widget.port.routeModeEnabled;
    final statusColor = enabled
        ? theme.accentColor.normal
        : theme.resources.textFillColorSecondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: enabled
                    ? theme.accentColor.lighter.withValues(alpha: .18)
                    : theme.resources.cardBackgroundFillColorDefault,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(FluentIcons.car, color: statusColor, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Modo Ruta', style: theme.typography.bodyStrong),
                  Text(
                    enabled ? 'Activo' : 'Inactivo',
                    style: theme.typography.caption?.copyWith(color: statusColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pausa la sincronización automática mientras trabajas en '
                    'ruta. Puedes seguir sincronizando manualmente cuando '
                    'quieras; se reanuda sola al desactivarlo.',
                    style: theme.typography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ToggleSwitch(
              key: const Key('route-mode-toggle'),
              checked: enabled,
              onChanged: _routeModeBusy ? null : (value) => _setRouteMode(value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryAction(BuildContext context, SyncSnapshot snapshot, bool disabled) {
    final theme = FluentTheme.of(context);
    final button = FilledButton(
      key: const Key('sync-all-primary-button'),
      onPressed: disabled || !widget.port.isOnline ? null : () => _run(widget.port.syncAll),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text('Sincronizar todo'),
      ),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Preparar datos para trabajar', style: theme.typography.subtitle),
        const SizedBox(height: 4),
        Text(
          widget.port.isOnline
              ? 'Descarga productos, clientes y medios de pago para '
                    'usarlos también sin conexión.'
              : 'Sin conexión al servidor. Se conservan los datos y '
                    'operaciones pendientes de este dispositivo.',
          style: theme.typography.body,
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Por debajo de cierto ancho, el botón ya no comparte fila con el
        // icono y el texto: a 400px de ancho de pantalla el texto por sí
        // solo ocupa casi todo el espacio y forzar los tres en una fila
        // desborda el `Row` (medido con las pruebas de 400/800/1280px).
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(FluentIcons.sync, size: 24, color: theme.accentColor),
                      const SizedBox(width: 12),
                      Expanded(child: texts),
                    ],
                  ),
                  const SizedBox(height: 12),
                  button,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(FluentIcons.sync, size: 28, color: theme.accentColor),
                const SizedBox(width: 16),
                Expanded(child: texts),
                const SizedBox(width: 16),
                button,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _readinessCard(BuildContext context, SyncSnapshot snapshot) {
    final theme = FluentTheme.of(context);
    final items = _readiness(snapshot);
    final pendingCount = items.where((item) => !item.ok).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pendingCount == 0
                  ? 'Listo para trabajar sin conexión'
                  : '$pendingCount elemento(s) pendiente(s)',
              style: theme.typography.bodyStrong,
            ),
            const SizedBox(height: 4),
            Text(
              pendingCount == 0
                  ? 'Todo lo necesario está disponible en este dispositivo.'
                  : 'Resuelve los elementos en rojo antes de salir.',
              style: theme.typography.caption,
            ),
            const SizedBox(height: 8),
            for (final item in items) _readinessRow(context, item),
          ],
        ),
      ),
    );
  }

  Widget _readinessRow(BuildContext context, SyncReadinessItem item) {
    final theme = FluentTheme.of(context);
    final color = item.ok
        ? theme.resources.systemFillColorSuccess
        : theme.resources.systemFillColorCritical;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox(width: 8, height: 8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.label, style: theme.typography.bodyStrong),
                Text(
                  item.detail,
                  style: theme.typography.caption?.copyWith(color: item.ok ? null : color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            item.ok ? FluentIcons.completed_solid : FluentIcons.status_error_full,
            color: color,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _catalogGrid(BuildContext context, {required bool disabled}) {
    final supported = _cards.where((card) => !card.unsupported).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1280
            ? 4
            : constraints.maxWidth >= 800
                ? 2
                : 1;
        const spacing = 12.0;
        final cardWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final data in supported)
              SizedBox(
                width: cardWidth,
                child: _catalogCard(context, data, disabled: disabled),
              ),
          ],
        );
      },
    );
  }

  /// E02, punto G: separados, atenuados, sin botón de sincronizar ni texto
  /// de error — un catálogo `unsupported` no es un fallo, es un catálogo que
  /// este servidor no tiene.
  Widget _unsupportedCatalogGrid(BuildContext context) {
    final unsupported = _cards.where((card) => card.unsupported).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1280
            ? 4
            : constraints.maxWidth >= 800
                ? 2
                : 1;
        const spacing = 12.0;
        final cardWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final data in unsupported)
              SizedBox(
                width: cardWidth,
                child: _unsupportedCatalogCard(context, data),
              ),
          ],
        );
      },
    );
  }

  Widget _unsupportedCatalogCard(BuildContext context, SyncCatalogCardData data) {
    final theme = FluentTheme.of(context);
    final mutedColor = theme.resources.textFillColorDisabled;
    return Opacity(
      opacity: 0.6,
      child: Card(
        key: Key('catalog-card-${data.key}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(data.icon, size: 18, color: mutedColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.label,
                      style: theme.typography.bodyStrong?.copyWith(color: mutedColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'No disponible en este servidor',
                style: theme.typography.caption?.copyWith(color: mutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catalogCard(BuildContext context, SyncCatalogCardData data, {required bool disabled}) {
    final theme = FluentTheme.of(context);
    return Card(
      key: Key('catalog-card-${data.key}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(data.icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.label,
                    style: theme.typography.bodyStrong,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Local: ${data.localCount} registro(s)', style: theme.typography.caption),
            Text(
              data.freshness == CatalogFreshness.readyIncremental
                  ? 'Listo para sincronización incremental'
                  : 'Pendiente de la primera carga completa',
              style: theme.typography.caption,
            ),
            Text(
              data.lastSyncedThisSession != null
                  ? 'Última sync en esta sesión: ${_formatTime(data.lastSyncedThisSession!)}'
                  : 'Aún no sincronizado en esta sesión',
              style: theme.typography.caption,
            ),
            if (data.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${data.error}',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.systemFillColorCritical,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Button(
                    key: Key('sync-catalog-${data.key}-button'),
                    onPressed: disabled ? null : () => _run(() => widget.port.syncCatalog(data.key)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.sync, size: 14),
                        SizedBox(width: 6),
                        Text('Sincronizar'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Recargar desde cero',
                  child: IconButton(
                    key: Key('reload-catalog-${data.key}-button'),
                    icon: const Icon(FluentIcons.history, size: 14),
                    onPressed:
                        disabled ? null : () => _confirmForceFullCatalog(data.key, data.label),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Adapta un widget cualquiera (no una acción) a la barra de [OrbiPage],
/// que sólo entiende [CommandBarItem]. Mismo patrón que
/// `envases_dashboard_screen.dart` para su insignia de conexión.
class _BusyCommandBarItem extends CommandBarItem {
  const _BusyCommandBarItem(this.accentColor) : super(key: null);

  final AccentColor accentColor;

  @override
  Widget build(BuildContext context, CommandBarItemDisplayMode displayMode) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: ProgressRing(strokeWidth: 2, activeColor: accentColor.normal),
        ),
        const SizedBox(width: 8),
        const Text('Sincronizando…'),
      ],
    ),
  );
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
