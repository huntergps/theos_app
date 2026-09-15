import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_widgets/odoo_widgets.dart' show OrbiColumn, OrbiListing;
import 'package:orbi_runtime/orbi_runtime.dart' show CapabilitySnapshot;

import '../activities/activity_center.dart' show ActivityCenterView, ActivityPort;
import '../auth/auth_controller.dart' show capabilitySnapshotProvider;
import 'home_dashboard_providers.dart'
    show HomeMyCashSummary, homeMyCashSummaryProvider, homeSalesMetricsProvider;
import 'home_dashboard_view.dart';
import 'home_resume_status.dart';

enum HomeResumeState { loading, data, empty, error }

final class HomeResumeItem {
  const HomeResumeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.route,
    this.count,
    this.status,
    this.documentDate,
    this.counterpart,
    this.moduleLabel,
    this.totalLabel,
  });
  final String id;
  final String title;
  final String subtitle;
  final String actionLabel;
  final String? route;

  /// La cifra real detrás de [subtitle], cuando quien produce el ítem la
  /// tiene disponible como número y no sólo como texto ya compuesto. Nula
  /// cuando no hay cifra que enseñar: una tarjeta resumen nunca se rellena
  /// con un cero para simular un dato que no existe.
  final int? count;

  /// Estado de la fila en «Documentos a continuar» (chip de color). Nulo
  /// cuando quien produce el ítem no clasifica documentos (por ejemplo, un
  /// candidato de acceso rápido de una versión anterior de esta pantalla) —
  /// la tabla lo pinta como un guion, nunca inventa un estado.
  final HomeResumeStatus? status;

  /// Fecha propia del documento (`date_order`, `envases_fecha_salida`,
  /// `created_at` de la cola…), no de cuándo se generó este ítem. Nula
  /// cuando el origen no trae una fecha de documento.
  final DateTime? documentDate;

  /// «Cliente/Proveedor» en ventas y cobros; «Origen → Destino» en un
  /// traslado de envases. Nulo cuando el documento no tiene contraparte
  /// (una operación de la cola offline, por ejemplo).
  final String? counterpart;

  /// Nombre del módulo de origen tal como se pinta en la columna «Módulo»
  /// de la lámina ACC-03 («Ventas», «Caja», «Envases», «Sincronización»).
  final String? moduleLabel;

  /// Total ya formateado (`$1,250.00`). Nulo cuando el documento no tiene
  /// una cifra monetaria propia (un traslado de envases, una operación de
  /// la cola) — la columna se deja vacía en vez de fingir un total.
  final String? totalLabel;
}

final class HomeResumeSnapshot {
  const HomeResumeSnapshot(this.state, {this.items = const [], this.message});
  final HomeResumeState state;
  final List<HomeResumeItem> items;
  final String? message;
}

abstract interface class HomeResumePort {
  HomeResumeSnapshot get snapshot;
  Stream<HomeResumeSnapshot> get changes;
  Future<void> resume(HomeResumeItem item);
}

final homeResumePortProvider = Provider<HomeResumePort>(
  (ref) => const _EmptyHomeResumePort(),
);

final class _EmptyHomeResumePort implements HomeResumePort {
  const _EmptyHomeResumePort();
  @override
  HomeResumeSnapshot get snapshot =>
      const HomeResumeSnapshot(HomeResumeState.empty);
  @override
  Stream<HomeResumeSnapshot> get changes => const Stream.empty();
  @override
  Future<void> resume(HomeResumeItem item) async {}
}

/// `dd/MM/yyyy`, sin depender de `intl` (mismo motivo que `homeTodayLabel` más
/// abajo: el paquete no es dependencia de `theos_panel`).
String _formatDocumentDate(DateTime date) {
  final local = date.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year}';
}

/// El contenido de Inicio: la fila de cifras reales, «Documentos a
/// continuar» / «Actividad reciente» / «Indicadores» en pestañas, y las
/// tarjetas por módulo al pie (sólo en ventana ancha) — diseño aprobado en
/// `docs/orbi_panel/visual_baselines/approved/round-02/ACC-03.png`.
///
/// No dibuja su propia cabecera: el marco (título, subtítulo, `OrbiPage`) lo
/// pone quien compone la pantalla completa, para no fabricar un segundo
/// esqueleto (`SHELL_AND_INTERACTION_SPEC.md`, «Estándar resuelto del
/// marco»).
///
/// 🔴 Ya no hay «Accesos rápidos» ni «Empieza por aquí»: la navegación real
/// (panel lateral y barra inferior) ya lleva a cada módulo — orden del
/// dueño, punto 5 de ACC-03. Un candidato de acceso rápido que todavía se le
/// pase a [HomeCenterView] se ignora.
class HomeCenterView extends ConsumerStatefulWidget {
  const HomeCenterView({
    required this.port,
    this.onResume,
    this.activityPort,
    this.currentUserId,
    this.envasesPendingItems = const [],
    this.onOpenOwnCashSession,
    this.onOpenCashSessionById,
    super.key,
  });
  final HomeResumePort port;
  final Future<void> Function(HomeResumeItem item)? onResume;

  /// Mismo puerto que lee `/activities` (`ScopeActivityPort` vía
  /// `scopeActivityPortProvider`) — reutilizado, no copiado. Nulo cuando
  /// quien compone la pantalla no tiene un servicio de actividades, o el
  /// usuario no tiene el permiso `activities` (`HomePage` decide esto antes
  /// de pasarlo).
  final ActivityPort? activityPort;

  /// Id del usuario de la sesión activa, para el filtro «Mías/Todas» de
  /// `ActivityCenterView` — mismo dato que ya usa `/activities`.
  final int? currentUserId;

  /// Traslados de envases por recibir, ya resueltos por quien compone la
  /// pantalla (`EnvasesPorRecibirCache` vía el mismo controlador que usa la
  /// pantalla real de envases) — `HomeCenterView` no abre su propio caché,
  /// sólo pinta lo que le llega.
  final List<HomeResumeItem> envasesPendingItems;

  /// Se invoca al tocar la fila del PROPIO turno en «Sesiones de caja
  /// activas». Sin id: `/collection/hub` (la única ruta que abre el hub del
  /// turno propio) nunca recibe uno.
  final VoidCallback? onOpenOwnCashSession;

  /// Se invoca al tocar la fila de un turno AJENO, con el id remoto de ESE
  /// turno. Sólo se ofrece a `HomeCashSessionsSection` cuando la persona
  /// tiene el permiso `collection_supervisor` (⇐
  /// `l10n_ec_collection_box.group_collection_manager`, "Supervisor de
  /// Caja"); sin ese permiso una fila ajena se queda informativa, igual que
  /// antes de que este permiso existiera.
  final void Function(String sessionId)? onOpenCashSessionById;

  @override
  ConsumerState<HomeCenterView> createState() => _HomeCenterViewState();
}

class _HomeCenterViewState extends ConsumerState<HomeCenterView> {
  int _tabIndex = 0;

  void _resume(HomeResumeItem item) =>
      unawaited(widget.onResume?.call(item) ?? widget.port.resume(item));

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitySnapshotProvider);
    final permissions = capabilities?.permissions ?? const <String>{};

    return StreamBuilder<HomeResumeSnapshot>(
      stream: widget.port.changes,
      initialData: widget.port.snapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.port.snapshot;
        final portItems = state.state == HomeResumeState.data
            ? state.items
            : const <HomeResumeItem>[];
        final documentItems = [...portItems, ...widget.envasesPendingItems];

        final showActivities =
            widget.activityPort != null && permissions.contains('activities');

        final tabs = <_HomeTab>[
          _HomeTab(
            label: 'Documentos a continuar (${documentItems.length})',
            body: _documentsBody(context, state, documentItems),
          ),
          if (showActivities)
            _HomeTab(
              label: 'Actividad reciente',
              body: ActivityCenterView(
                port: widget.activityPort!,
                currentUserId: widget.currentUserId,
              ),
            ),
          _HomeTab(
            label: 'Indicadores',
            body: _indicatorsBody(context, capabilities),
          ),
        ];
        final tabIndex = _tabIndex >= tabs.length ? 0 : _tabIndex;

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1008;
            // En teléfono (< 600) la lámina no repite la fila de cifras: la
            // cuenta ya vive en el propio rótulo de la pestaña
            // («Documentos a continuar (N)»). Con cuatro tarjetas apiladas
            // ahí no cabían: cada una a 200 px de ancho fijo no dejaba sitio
            // a una segunda por fila, y las cuatro juntas se comían la
            // pantalla entera antes de llegar a las pestañas.
            final showMetrics = constraints.maxWidth >= 600;
            // Antes `Expanded(child: TabView(...))` llenaba TODO el alto
            // sobrante del `ScaffoldPage`, así que las tarjetas por módulo
            // quedaban pegadas al borde inferior de la ventana con un hueco
            // enorme encima (orden del dueño, 15-sep-2026, viendo
            // `inicio-completo-1920.png`). Una altura acotada —con su propio
            // scroll y paginación, que `OrbiListing` ya trae— deja las
            // tarjetas justo debajo de la tabla, como en la lámina.
            final tabsHeight = constraints.maxHeight.isFinite
                ? (constraints.maxHeight * 0.55).clamp(320.0, 560.0)
                : 440.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showMetrics) ...[
                  _metricsRow(context, capabilities, documentItems),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: tabsHeight,
                  child: TabView(
                    currentIndex: tabIndex,
                    onChanged: (index) => setState(() => _tabIndex = index),
                    // Ninguna pestaña se cierra ni se añade: son fijas, así
                    // que el control nativo más cercano a las pestañas
                    // subrayadas de la lámina (`fluent_ui`
                    // `controls/navigation/tab_view/tab_view.dart`) se usa
                    // sin su cruz de cerrar ni su botón «+». Por debajo de
                    // 600 px no caben las tres etiquetas completas; el
                    // propio `TabView` ya trae flechas de desplazamiento
                    // horizontal (`showScrollButtons`, activas por
                    // omisión) para llegar a la que no cabe.
                    closeButtonVisibility: CloseButtonVisibilityMode.never,
                    tabWidthBehavior: TabWidthBehavior.sizeToContent,
                    tabs: [
                      for (final tab in tabs)
                        Tab(text: Text(tab.label), body: tab.body),
                    ],
                  ),
                ),
                if (wide) ...[
                  const SizedBox(height: 16),
                  _moduleCardsRow(context, ref, capabilities),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _documentsBody(
    BuildContext context,
    HomeResumeSnapshot state,
    List<HomeResumeItem> items,
  ) {
    if (state.state == HomeResumeState.error && items.isEmpty) {
      return Center(
        child: Text(state.message ?? 'No se pudo cargar el inicio'),
      );
    }
    if (state.state == HomeResumeState.loading && items.isEmpty) {
      return const Center(child: ProgressRing());
    }
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OrbiListing<HomeResumeItem>(
        key: const Key('home-documents-listing'),
        storageKey: 'home.documents',
        rows: items,
        showFilterBox: false,
        emptyMessage: 'No hay documentos por continuar',
        onRowTap: _resume,
        cardBuilder: _documentCard,
        columns: [
          OrbiColumn<HomeResumeItem>(
            key: 'estado',
            label: 'Estado',
            // Documento, no Estado, identifica la fila: en tarjeta angosta
            // genérica, `OrbiListing` usa la primera columna `alwaysVisible`
            // como título, y «En proceso»/«Pendiente» como título repetido
            // en varias filas leía mal.
            value: (item) => homeResumeStatusLabel(item.status),
            badgeColor: (item) => homeResumeStatusColor(theme, item.status),
          ),
          OrbiColumn<HomeResumeItem>(
            key: 'documento',
            label: 'Documento',
            alwaysVisible: true,
            value: (item) => item.title,
          ),
          OrbiColumn<HomeResumeItem>(
            key: 'fecha',
            label: 'Fecha',
            value: (item) => item.documentDate == null
                ? '—'
                : _formatDocumentDate(item.documentDate!),
          ),
          OrbiColumn<HomeResumeItem>(
            key: 'contraparte',
            label: 'Cliente/Proveedor',
            value: (item) => item.counterpart ?? '—',
          ),
          OrbiColumn<HomeResumeItem>(
            key: 'modulo',
            label: 'Módulo',
            value: (item) => item.moduleLabel ?? '—',
          ),
          OrbiColumn<HomeResumeItem>(
            key: 'total',
            label: 'Total (USD)',
            numeric: true,
            emphasis: true,
            value: (item) => item.totalLabel ?? '',
          ),
        ],
      ),
    );
  }

  /// Ficha compacta de teléfono para «Documentos a continuar» (ACC-03,
  /// columna «Teléfono»): chip de estado + documento en negrita y el total
  /// EN LA MISMA fila; debajo, la contraparte (u «Origen → Destino») y la
  /// fecha en texto secundario con un chip pequeño de módulo; y una flecha a
  /// la derecha que abre el documento (el toque de la tarjeta entera ya lo
  /// hace `onRowTap`, la flecha es sólo la pista visual de la lámina). El
  /// chip de estado usa fondo SÓLIDO + texto de contraste
  /// (`homeResumeStatusSolid*`), no el tinte al 16 % del listado genérico:
  /// ese tinte es justo lo que perdía contraste en tema oscuro.
  Widget _documentCard(
    BuildContext context,
    HomeResumeItem item,
    List<OrbiColumn<HomeResumeItem>> columns,
    double width,
  ) {
    final theme = FluentTheme.of(context);
    final hasTotal = (item.totalLabel ?? '').isNotEmpty;
    final hasCounterpart = (item.counterpart ?? '').isNotEmpty;
    final hasModule = (item.moduleLabel ?? '').isNotEmpty;
    return Card(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusPill(theme, item.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.typography.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasTotal) ...[
                      const SizedBox(width: 8),
                      Text(item.totalLabel!, style: theme.typography.bodyStrong),
                    ],
                  ],
                ),
                if (hasCounterpart || item.documentDate != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (hasCounterpart) item.counterpart!,
                      if (item.documentDate != null)
                        _formatDocumentDate(item.documentDate!),
                    ].join(' · '),
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (hasModule) ...[
                  const SizedBox(height: 6),
                  _modulePill(theme, item.moduleLabel!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              FluentIcons.chevron_right,
              size: 14,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(FluentThemeData theme, HomeResumeStatus? status) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: homeResumeStatusSolidBackground(theme, status),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          homeResumeStatusLabel(status),
          style: TextStyle(
            color: homeResumeStatusSolidForeground(theme, status),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );

  Widget _modulePill(FluentThemeData theme, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: theme.resources.subtleFillColorSecondary,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: theme.typography.caption?.copyWith(fontSize: 11),
    ),
  );

  Widget _indicatorsBody(BuildContext context, CapabilitySnapshot? capabilities) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        if (capabilities != null) ...[
          HomeIndicatorGrid(capabilities: capabilities),
          const SizedBox(height: 16),
        ],
        const HomeLastSyncCard(),
        if (capabilities != null &&
            capabilities.permissions.contains('cashier')) ...[
          const SizedBox(height: 16),
          HomeCashSessionsSection(
            onOpenOwnSession: widget.onOpenOwnCashSession,
            onOpenSupervisedSession:
                capabilities.permissions.contains('collection_supervisor')
                ? widget.onOpenCashSessionById
                : null,
          ),
        ],
      ],
    );
  }

  /// Máximo 4 tarjetas, en el orden fijo de ACC-03: Ventas hoy, Documentos a
  /// continuar (siempre), Cobros del turno, Por recibir — y sólo si queda un
  /// quinto hueco, Pendientes de enviar. Nunca se rellena con un cero
  /// fabricado: cada tarjeta sólo aparece cuando su lector ya resolvió un
  /// dato real.
  Widget _metricsRow(
    BuildContext context,
    CapabilitySnapshot? capabilities,
    List<HomeResumeItem> documentItems,
  ) {
    final permissions = capabilities?.permissions ?? const <String>{};
    final cards = <_MetricCard>[];

    if (permissions.contains('seller')) {
      final sales = ref.watch(homeSalesMetricsProvider).value;
      if (sales != null) {
        cards.add(
          _MetricCard(
            label: 'Ventas hoy',
            value: homeCurrencyLabel(sales.totalAmount),
            detail: sales.totalOrders == 1
                ? '1 orden'
                : '${sales.totalOrders} órdenes',
          ),
        );
      }
    }

    cards.add(
      _MetricCard(
        label: 'Documentos a continuar',
        value: '${documentItems.length}',
        detail: documentItems.isEmpty ? 'Al día' : 'A continuar',
      ),
    );

    if (permissions.contains('cashier')) {
      final HomeMyCashSummary? cash = ref
          .watch(homeMyCashSummaryProvider)
          .value;
      if (cash != null) {
        cards.add(
          _MetricCard(
            label: 'Cobros del turno',
            value: homeCurrencyLabel(cash.totalAmount),
            detail: cash.paymentCount == 1
                ? '1 cobro'
                : '${cash.paymentCount} cobros',
          ),
        );
      }
    }

    if (permissions.contains('envases_read')) {
      cards.add(
        _MetricCard(
          label: 'Por recibir',
          value: '${widget.envasesPendingItems.length}',
          detail: widget.envasesPendingItems.isEmpty
              ? 'Sin traslados'
              : 'traslados',
        ),
      );
    }

    if (cards.length < 4) {
      final pendingCount = documentItems
          .where((item) => item.moduleLabel == 'Sincronización')
          .length;
      if (pendingCount > 0) {
        cards.add(
          _MetricCard(
            label: 'Pendientes de enviar',
            value: '$pendingCount',
            detail: pendingCount == 1 ? '1 operación' : '$pendingCount operaciones',
          ),
        );
      }
    }

    final visible = cards.take(4).toList(growable: false);
    // Se reparten TODO el ancho disponible en una sola fila, como en la
    // lámina — antes cada una medía 200 px fijos y dejaba un hueco vacío a
    // la derecha en vez de repartirse (orden del dueño, 15-sep-2026, viendo
    // `inicio-completo-1920.png`). Mismo cálculo que ya usa
    // `HomeIndicatorGrid` (ancho disponible ÷ tarjetas, con `Wrap`, no
    // `Row`+`Expanded`): un `Row` con `CrossAxisAlignment.stretch` alrededor
    // de un `Card` colgaba `pumpAndSettle` para siempre en las pruebas —
    // `Wrap` con un ancho ya calculado no tiene ese problema.
    const spacing = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = visible.isEmpty
            ? 0.0
            : (constraints.maxWidth - spacing * (visible.length - 1)) /
                  visible.length;
        return Wrap(
          key: const Key('home-metrics-row'),
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in visible)
              SizedBox(
                key: Key('home-metric-card-${card.label}'),
                width: width,
                child: _metricCardView(context, card),
              ),
          ],
        );
      },
    );
  }

  Widget _metricCardView(BuildContext context, _MetricCard card) {
    final theme = FluentTheme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.label,
              style: theme.typography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Una sola línea, reducida de escala en vez de partida en dos
            // (defecto viejo con «$12,480.50»: sin miles cabía por poco, con
            // miles ya no, y el número se envolvía a un segundo renglón).
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  card.value,
                  style: theme.typography.titleLarge,
                  maxLines: 1,
                ),
              ),
            ),
            if (card.detail != null)
              Text(
                card.detail!,
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  /// Una tarjeta por módulo disponible, sólo con datos que Orbi ya tiene —
  /// sin minigráfico: no hay historia local todavía (orden del dueño, punto
  /// 4 de ACC-03). Bodega y Aprobaciones se omiten: ningún lector local
  /// existe para ellas hoy (`home_dashboard_contracts.dart`).
  Widget _moduleCardsRow(
    BuildContext context,
    WidgetRef ref,
    CapabilitySnapshot? capabilities,
  ) {
    final permissions = capabilities?.permissions ?? const <String>{};
    final cards = <Widget>[];

    if (permissions.contains('seller')) {
      final sales = ref.watch(homeSalesMetricsProvider).value;
      if (sales != null) {
        cards.add(
          _moduleCard(
            context,
            icon: FluentIcons.shopping_cart,
            title: 'Ventas',
            value: '${sales.totalOrders}',
            detail: '${sales.totalOrders == 1 ? 'documento' : 'documentos'} · ${homeCurrencyLabel(sales.totalAmount)}',
          ),
        );
      }
    }

    if (permissions.contains('cashier')) {
      final cash = ref.watch(homeMyCashSummaryProvider).value;
      if (cash != null) {
        cards.add(
          _moduleCard(
            context,
            icon: FluentIcons.money,
            title: 'Caja',
            value: '${cash.paymentCount}',
            detail: '${cash.paymentCount == 1 ? 'cobro' : 'cobros'} · ${homeCurrencyLabel(cash.totalAmount)}',
          ),
        );
      }
    }

    if (permissions.contains('envases_read')) {
      cards.add(
        _moduleCard(
          context,
          icon: FluentIcons.product,
          title: 'Envases',
          value: '${widget.envasesPendingItems.length}',
          detail: 'traslados por recibir',
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [for (final card in cards) SizedBox(width: 220, child: card)],
    );
  }

  Widget _moduleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String detail,
  }) {
    final theme = FluentTheme.of(context);
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.accentColor.normal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: theme.accentColor.normal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.typography.bodyStrong),
                Text(
                  value,
                  style: theme.typography.subtitle,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _HomeTab {
  const _HomeTab({required this.label, required this.body});
  final String label;
  final Widget body;
}

final class _MetricCard {
  const _MetricCard({required this.label, required this.value, this.detail});
  final String label;
  final String value;
  final String? detail;
}

/// «Lunes, 14 de abril de 2025», sin depender de `intl`: el paquete no es
/// dependencia directa de `theos_panel` y añadirla sólo para esto tocaría el
/// lockfile por un cambio que no lo pide (`CLAUDE.md`, reglas de proceso).
String homeTodayLabel([DateTime? now]) {
  const weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final today = now ?? DateTime.now();
  final weekday = weekdays[today.weekday - 1];
  final month = months[today.month - 1];
  final capitalized = '${weekday[0].toUpperCase()}${weekday.substring(1)}';
  return '$capitalized, ${today.day} de $month de ${today.year}';
}
