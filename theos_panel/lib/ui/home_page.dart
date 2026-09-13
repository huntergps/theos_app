import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show CapabilitySnapshot;

import '../features/home/home_center.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/route_access_policy.dart';
import '../app/session_composition.dart';
import '../app/u08_scope_adapters.dart';
import 'fluent/orbi_page.dart';

import 'package:go_router/go_router.dart';

/// Candidatas a «empieza por aquí» cuando Inicio no tiene nada pendiente.
/// Un grupo por fila del menú de unión (`SHELL_AND_INTERACTION_SPEC.md`):
/// se filtran por `RouteAccessPolicy` antes de mostrarse, así que nadie ve
/// un área que no le corresponde sólo porque Inicio está vacío.
const _quickStartCandidates = [
  (route: '/sales', label: 'Ventas'),
  (route: '/collection', label: 'Caja'),
  (route: '/warehouse', label: 'Bodega'),
  (route: '/envases', label: 'Envases'),
  (route: '/approvals', label: 'Aprobaciones'),
  (route: '/sync', label: 'Sistema'),
];

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(capabilitySnapshotProvider);
    final composition = ref.watch(orbiSessionCompositionProvider);
    final homePort = composition.home ?? ref.watch(scopeHomeResumePortProvider);
    final policy = ref.watch(routeAccessPolicyProvider);
    return OrbiPage(
      title: 'Inicio operativo',
      subtitle: homeTodayLabel(),
      child: homePort == null
          ? const Card(
              child: ListTile(
                leading: Icon(FluentIcons.info),
                title: Text('Trabajo local'),
                subtitle: Text(
                  'No hay un servicio de sesión disponible para retomar trabajo.',
                ),
              ),
            )
          : HomeCenterView(
              port: homePort,
              quickStarts: _quickStarts(policy, capabilities),
              // Sólo el turno propio: `/collection/hub` abre el del usuario de la
              // sesión y no recibe un id, así que un turno ajeno no es tocable.
              onOpenOwnCashSession: () {
                if (policy.allows(
                      '/collection/hub',
                      authenticated: true,
                      capabilities: capabilities,
                    ) &&
                    context.mounted) {
                  context.go('/collection/hub');
                }
              },
              onResume: (item) async {
                final route = item.route;
                if (route == null ||
                    !policy.allows(
                      route,
                      authenticated: true,
                      capabilities: capabilities,
                    )) {
                  return;
                }
                if (context.mounted) context.go(route);
              },
            ),
    );
  }

  List<HomeResumeItem> _quickStarts(
    RouteAccessPolicy policy,
    CapabilitySnapshot? capabilities,
  ) => [
    for (final candidate in _quickStartCandidates)
      if (policy.allows(
        candidate.route,
        authenticated: true,
        capabilities: capabilities,
      ))
        HomeResumeItem(
          id: 'home:quickstart:${candidate.route}',
          title: candidate.label,
          subtitle: 'Ir a ${candidate.label}',
          actionLabel: 'Abrir',
          route: candidate.route,
        ),
  ];
}
