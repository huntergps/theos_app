import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbi_runtime/orbi_runtime.dart'
    show AuthProfile, CapabilitySnapshot;
import 'package:theos_pos_core/theos_pos_core.dart'
    show SessionState, SessionStateExtension;

import '../auth/auth_controller.dart'
    show authControllerProvider, capabilitySnapshotProvider;
import '../sync/sync_center.dart' show SyncCenterSnapshot, syncCenterPortProvider;
import 'home_dashboard_contracts.dart';
import 'home_dashboard_providers.dart';

/// Cuántas columnas le tocan a la rejilla de indicadores según el ancho
/// disponible: 1 a 400px, 2 a 800px, 4 a 1280px — la misma regla en toda la
/// pantalla, expuesta aparte para poder probarla sin montar widgets.
int homeDashboardColumns(double width) {
  if (width >= 1280) return 4;
  if (width >= 800) return 2;
  return 1;
}

String homeCurrencyLabel(double amount) => '\$${amount.toStringAsFixed(2)}';

/// «Hace un momento», «Hace 5 min», «Hoy 14:32», «Ayer 09:10» o `dd/MM HH:mm`
/// — sin `intl`: el paquete no es dependencia de `theos_panel` y añadirlo
/// sólo para esto tocaría el lockfile por algo que no lo pide.
String homeRelativeMoment(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final reference = now ?? DateTime.now();
  final diff = reference.difference(local);
  if (diff.inMinutes < 1) return 'Hace un momento';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return 'Hoy $hh:$mm';
  if (day == today.subtract(const Duration(days: 1))) return 'Ayer $hh:$mm';
  final dd = local.day.toString().padLeft(2, '0');
  final moLabel = local.month.toString().padLeft(2, '0');
  return '$dd/$moLabel $hh:$mm';
}

String homeSessionStateLabel(String code) {
  final match = SessionState.values.where((value) => value.code == code);
  return match.isEmpty ? code : match.first.label;
}

Color homeSessionStateColor(FluentThemeData theme, String code) =>
    switch (code) {
      'opened' => theme.resources.systemFillColorSuccess,
      'closed' => theme.resources.systemFillColorNeutral,
      _ => theme.resources.systemFillColorCaution,
    };

/// Una tarjeta de indicador: icono con tinte de estado, título, cifra real y
/// una línea de contexto. El tinte sale siempre de `FluentTheme`/recursos del
/// tema, nunca de un color escrito a mano.
class HomeIndicatorCard extends StatelessWidget {
  const HomeIndicatorCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.typography.bodyStrong?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
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

/// La rejilla de indicadores completa, ensamblada según las capacidades
/// efectivas: cada sección se agrega sólo cuando su lector responde datos
/// reales; nunca se pinta una tarjeta con un cero fabricado.
class HomeIndicatorGrid extends ConsumerWidget {
  const HomeIndicatorGrid({required this.capabilities, super.key});

  final CapabilitySnapshot capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final cards = <Widget>[];

    if (capabilities.permissions.contains('seller')) {
      ref
          .watch(homeSalesMetricsProvider)
          .whenData((summary) {
            if (summary == null) return;
            cards.addAll(_salesCards(theme, summary));
          });
    }

    if (capabilities.permissions.contains('cashier')) {
      final profile = ref.watch(authControllerProvider).profile;
      ref
          .watch(homeCashSessionsProvider)
          .whenData((sessions) {
            if (sessions == null) return;
            cards.add(
              HomeIndicatorCard(
                title: 'Sesiones de caja abiertas',
                value: '${sessions.length}',
                subtitle: sessions.length == 1
                    ? 'activa ahora'
                    : 'activas ahora',
                icon: FluentIcons.people,
                color: theme.resources.systemFillColorSuccess,
              ),
            );
            final mine = profile == null
                ? const <HomeCashSession>[]
                : sessions
                      .where((session) => session.cashierUserId == profile.userId)
                      .toList();
            if (mine.isNotEmpty) {
              final paymentCount = mine.fold<int>(
                0,
                (total, session) => total + session.paymentCount,
              );
              final paymentsAmount = mine.fold<double>(
                0,
                (total, session) => total + session.totalPaymentsAmount,
              );
              cards.add(
                HomeIndicatorCard(
                  title: 'Cobros del turno',
                  value: homeCurrencyLabel(paymentsAmount),
                  subtitle: paymentCount == 1
                      ? '1 cobro'
                      : '$paymentCount cobros',
                  icon: FluentIcons.money,
                  color: theme.accentColor,
                ),
              );
            }
          });
    }

    // No hay indicador de bodega todavía: ver la nota en
    // `home_dashboard_contracts.dart` sobre por qué el proxy
    // (`state='sale'` + `picking_ids` no vacío) se descartó en vez de
    // corregirse — cuenta pedidos ya entregados porque `delivery_status` no
    // está sincronizado a local. Se omite por completo, no se fabrica.

    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = homeDashboardColumns(constraints.maxWidth);
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) /
            columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  List<Widget> _salesCards(FluentThemeData theme, HomeSalesSummary summary) => [
    HomeIndicatorCard(
      title: 'Total ventas del día',
      value: homeCurrencyLabel(summary.totalAmount),
      subtitle: summary.totalOrders == 1
          ? '1 orden en total'
          : '${summary.totalOrders} órdenes en total',
      icon: FluentIcons.money,
      color: theme.accentColor,
    ),
    HomeIndicatorCard(
      title: 'Borradores',
      value: '${summary.draftCount}',
      subtitle: 'pendientes',
      icon: FluentIcons.edit,
      color: theme.resources.systemFillColorCaution,
    ),
    HomeIndicatorCard(
      title: 'Confirmadas',
      value: '${summary.confirmedCount}',
      subtitle: 'órdenes de venta',
      icon: FluentIcons.check_mark,
      color: theme.accentColor,
    ),
    HomeIndicatorCard(
      title: 'Facturadas',
      value: '${summary.doneCount}',
      subtitle: 'completadas',
      icon: FluentIcons.receipt_processing,
      color: theme.resources.systemFillColorSuccess,
    ),
  ];
}

/// Lista de sesiones de caja activas. Sólo se agrega al árbol cuando quien
/// compone la pantalla ya comprobó la capacidad `cashier` — este widget no
/// vuelve a decidir permisos, sólo pinta lo que el lector devuelve.
class HomeCashSessionsSection extends ConsumerWidget {
  const HomeCashSessionsSection({
    this.onOpenOwnSession,
    this.onOpenSupervisedSession,
    super.key,
  });

  /// Se invoca al tocar la fila del PROPIO turno del cajero autenticado.
  final VoidCallback? onOpenOwnSession;

  /// Se invoca al tocar la fila de un turno AJENO, con el id remoto de ESE
  /// turno (`collection.session` id) — nunca el propio. Quien compone esta
  /// pantalla sólo debe pasar este callback tras comprobar el permiso de
  /// supervisor (`collection_supervisor` ⇐
  /// `l10n_ec_collection_box.group_collection_manager`, "Supervisor de
  /// Caja"): este widget no vuelve a decidir permisos, sólo pinta lo que le
  /// pasaron — mismo principio que ya sigue con la capacidad `cashier`.
  /// Nulo mientras la persona no tenga ese permiso, y entonces una fila
  /// ajena queda informativa, igual que antes de que este permiso existiera.
  final void Function(String sessionId)? onOpenSupervisedSession;

  /// La fila propia usa [onOpenOwnSession] (sin id: `/collection/hub` abre
  /// el turno de quien tiene la sesión). Una fila ajena usa
  /// [onOpenSupervisedSession] con el id de ESE turno, y sólo cuando quien
  /// compone la pantalla ya lo ofreció — ver el docstring del campo.
  VoidCallback? _onPressedFor(HomeCashSession session, AuthProfile? profile) {
    if (profile == null) return null;
    if (session.cashierUserId == profile.userId) return onOpenOwnSession;
    final onOpenSupervised = onOpenSupervisedSession;
    if (onOpenSupervised == null) return null;
    return () => onOpenSupervised(session.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final sessions = ref.watch(homeCashSessionsProvider);
    final profile = ref.watch(authControllerProvider).profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(FluentIcons.people, size: 16, color: theme.accentColor),
            const SizedBox(width: 8),
            Text('Sesiones de caja activas', style: theme.typography.bodyStrong),
          ],
        ),
        const SizedBox(height: 8),
        sessions.when(
          data: (list) {
            if (list == null) return const SizedBox.shrink();
            if (list.isEmpty) {
              return const InfoBar(
                title: Text('Sin sesiones activas'),
                content: Text(
                  'No hay cajeros con turno abierto en este momento.',
                ),
                severity: InfoBarSeverity.info,
              );
            }
            return Column(
              children: [
                for (final session in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Card(
                      child: ListTile(
                        onPressed: _onPressedFor(session, profile),
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: homeSessionStateColor(
                                theme,
                                session.stateCode,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        title: Text(session.name),
                        subtitle: Text(
                          [
                            session.cashierName ?? 'Sin asignar',
                            if (session.configName != null)
                              session.configName!,
                            if (session.startAt != null)
                              homeRelativeMoment(session.startAt!),
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              homeSessionStateLabel(session.stateCode),
                              style: theme.typography.caption?.copyWith(
                                color: homeSessionStateColor(
                                  theme,
                                  session.stateCode,
                                ),
                              ),
                            ),
                            if (_onPressedFor(session, profile) != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                FluentIcons.chevron_right,
                                size: 12,
                                color: theme.resources.textFillColorSecondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: ProgressRing()),
          ),
          error: (error, _) => InfoBar(
            title: const Text('No se pudieron cargar las sesiones'),
            content: Text('$error'),
            severity: InfoBarSeverity.error,
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de última sincronización: hora real del último drenaje correcto,
/// y si hay operaciones pendientes o fallidas en la cola. Navega a
/// Sincronización sólo cuando la capacidad efectiva lo permite.
class HomeLastSyncCard extends ConsumerWidget {
  const HomeLastSyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final capabilities = ref.watch(capabilitySnapshotProvider);
    final port = ref.watch(syncCenterPortProvider);
    final canOpenSync =
        capabilities != null &&
        (capabilities.permissions.contains('sync') ||
            capabilities.permissions.contains('administrator'));

    return StreamBuilder<SyncCenterSnapshot>(
      stream: port.snapshots,
      initialData: port.snapshot,
      builder: (context, snap) {
        final snapshot = snap.data ?? port.snapshot;
        final sync = snapshot.sync;
        final lastLabel = sync.active
            ? 'Sincronizando…'
            : sync.lastCompletedAt == null
            ? 'Nunca se sincronizó'
            : homeRelativeMoment(sync.lastCompletedAt!);
        final pendingLabel = sync.failedCount > 0
            ? '${sync.failedCount} con error'
            : sync.queuedCount > 0
            ? sync.queuedCount == 1
                  ? '1 pendiente'
                  : '${sync.queuedCount} pendientes'
            : 'Sin pendientes';
        final iconColor = sync.failedCount > 0
            ? theme.resources.systemFillColorCritical
            : sync.active
            ? theme.resources.systemFillColorCaution
            : theme.accentColor;

        final card = Card(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                sync.active ? FluentIcons.sync : FluentIcons.cloud_download,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Última sincronización',
                      style: theme.typography.bodyStrong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastLabel,
                      style: theme.typography.caption?.copyWith(
                        color: theme.inactiveColor,
                      ),
                    ),
                    Text(
                      pendingLabel,
                      style: theme.typography.caption?.copyWith(
                        color: theme.inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpenSync)
                Icon(
                  FluentIcons.chevron_right,
                  size: 14,
                  color: theme.resources.textFillColorSecondary,
                ),
            ],
          ),
        );
        if (!canOpenSync) return card;
        return HoverButton(
          onPressed: () => context.go('/sync'),
          builder: (context, states) => card,
        );
      },
    );
  }
}
