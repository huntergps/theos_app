import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart' show capabilitySnapshotProvider;
import 'home_dashboard_view.dart';

enum HomeResumeState { loading, data, empty, error }

final class HomeResumeItem {
  const HomeResumeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.route,
    this.count,
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

/// El contenido de Inicio: lo que hay para continuar, con una fila de cifras
/// reales arriba cuando el ítem trae [HomeResumeItem.count], y por dónde
/// empezar cuando no hay nada pendiente.
///
/// No dibuja su propia cabecera: el marco (título, subtítulo, `OrbiPage`) lo
/// pone quien compone la pantalla completa, para no fabricar un segundo
/// esqueleto (`SHELL_AND_INTERACTION_SPEC.md`, «Estándar resuelto del
/// marco»).
class HomeCenterView extends ConsumerWidget {
  const HomeCenterView({
    required this.port,
    this.onResume,
    this.quickStarts = const [],
    this.onOpenOwnCashSession,
    this.onOpenCashSessionById,
    super.key,
  });
  final HomeResumePort port;
  final Future<void> Function(HomeResumeItem item)? onResume;

  /// Áreas a las que la persona sí tiene acceso, para enseñarlas cuando no
  /// hay trabajo pendiente que continuar. Ya llegan filtradas por permisos
  /// de quien compone la pantalla: esta vista no decide accesos, sólo los
  /// muestra tal cual se los pasaron.
  final List<HomeResumeItem> quickStarts;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(capabilitySnapshotProvider);
    // Sólo se arma el panel de indicadores cuando hay al menos una capacidad
    // con una fuente de datos real detrás (venta o cobro; bodega no tiene
    // todavía un dato local confiable — ver `home_dashboard_contracts.dart`).
    // El resto de capacidades (aprobador, sync, actividades…) no aportan un
    // indicador propio todavía, así que no activan el panel por sí solas —
    // eso sería fabricar una sección vacía.
    final showDashboard =
        capabilities != null &&
        capabilities.permissions.intersection(const {
          'seller',
          'cashier',
        }).isNotEmpty;

    return StreamBuilder<HomeResumeSnapshot>(
      stream: port.changes,
      initialData: port.snapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? port.snapshot;
        if (!showDashboard) {
          return switch (state.state) {
            HomeResumeState.loading => const Center(child: ProgressRing()),
            HomeResumeState.error => Center(
              child: Text(state.message ?? 'No se pudo cargar el inicio'),
            ),
            HomeResumeState.empty => _empty(context),
            HomeResumeState.data => _content(context, state.items),
          };
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HomeIndicatorGrid(capabilities: capabilities),
            const SizedBox(height: 16),
            const HomeLastSyncCard(),
            if (capabilities.permissions.contains('cashier')) ...[
              const SizedBox(height: 16),
              HomeCashSessionsSection(
                onOpenOwnSession: onOpenOwnCashSession,
                onOpenSupervisedSession:
                    capabilities.permissions.contains('collection_supervisor')
                    ? onOpenCashSessionById
                    : null,
              ),
            ],
            if (quickStarts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _quickAccessSection(context),
            ],
            if (state.state == HomeResumeState.data && state.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              _resumeSection(context, state.items),
            ] else if (state.state == HomeResumeState.loading) ...[
              const SizedBox(height: 16),
              const Center(child: ProgressRing()),
            ] else if (state.state == HomeResumeState.error) ...[
              const SizedBox(height: 16),
              Text(state.message ?? 'No se pudo cargar el inicio'),
            ],
          ],
        );
      },
    );
  }

  Widget _quickAccessSection(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accesos rápidos', style: typography.bodyStrong),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickStarts
              .map(
                (item) => Button(
                  onPressed: () =>
                      unawaited(onResume?.call(item) ?? port.resume(item)),
                  child: Text(item.title),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.completed_solid, size: 32),
            const SizedBox(height: 12),
            Text('No hay trabajo pendiente', style: typography.bodyStrong),
            if (quickStarts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Empieza por aquí:', style: typography.body),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: quickStarts
                    .map(
                      (item) => Button(
                        onPressed: () => unawaited(
                          onResume?.call(item) ?? port.resume(item),
                        ),
                        child: Text(item.title),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Igual que [_content], pero sin envolver en su propio `ListView`: se usa
  /// dentro del `ListView` general del panel de indicadores, y un
  /// `ListView` sin altura acotada dentro de otro revienta el layout.
  Widget _resumeSection(BuildContext context, List<HomeResumeItem> items) {
    final withCount = items.where((item) => item.count != null).toList();
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (withCount.isNotEmpty) ...[
            _kpiRow(context, withCount),
            const SizedBox(height: 16),
          ],
          _itemsList(context, items, wide: constraints.maxWidth >= 840),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, List<HomeResumeItem> items) {
    final withCount = items.where((item) => item.count != null).toList();
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        children: [
          if (withCount.isNotEmpty) ...[
            _kpiRow(context, withCount),
            const SizedBox(height: 16),
          ],
          _itemsList(context, items, wide: constraints.maxWidth >= 840),
        ],
      ),
    );
  }

  /// Cifras reales, no decorativas: cada tarjeta repite el número que ya
  /// viaja en el ítem de abajo, nunca uno inventado aparte. Ámbar porque
  /// todo lo que llega aquí es, por definición, trabajo pendiente —el color
  /// por significado de `SHELL_AND_INTERACTION_SPEC.md`.
  Widget _kpiRow(BuildContext context, List<HomeResumeItem> items) {
    final theme = FluentTheme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: 200,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _dot(theme.resources.systemFillColorCaution),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.title,
                              style: theme.typography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.count}',
                        style: theme.typography.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _itemsList(
    BuildContext context,
    List<HomeResumeItem> items, {
    required bool wide,
  }) {
    final theme = FluentTheme.of(context);
    Widget child(HomeResumeItem item) => Card(
      child: ListTile(
        leading: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _dot(theme.resources.systemFillColorCaution),
        ),
        title: Text(item.title),
        subtitle: Text(item.subtitle),
        trailing: FilledButton(
          onPressed: () =>
              unawaited(onResume?.call(item) ?? port.resume(item)),
          child: Text(item.actionLabel),
        ),
      ),
    );
    return wide
        ? GridView.extent(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            maxCrossAxisExtent: 420,
            children: items.map(child).toList(),
          )
        : Column(children: items.map(child).toList());
  }

  Widget _dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
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
