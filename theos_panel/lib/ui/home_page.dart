import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_center.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/route_access_policy.dart';
import '../app/session_composition.dart';
import '../app/u08_scope_adapters.dart';
import 'fluent/orbi_page.dart';

import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(capabilitySnapshotProvider);
    final composition = ref.watch(orbiSessionCompositionProvider);
    final homePort = composition.home ?? ref.watch(scopeHomeResumePortProvider);
    final policy = ref.watch(routeAccessPolicyProvider);
    final currentUserId = ref.watch(
      authControllerProvider.select((state) => state.profile?.userId),
    );
    // Mismo puerto que lee `/activities` (`router.dart`): reutilizado, no
    // copiado. La pestaña «Actividad reciente» de `HomeCenterView` decide
    // por su cuenta si la enseña, según el permiso `activities`.
    final activityPort =
        composition.activities ?? ref.watch(scopeActivityPortProvider);
    final envasesPendingItems =
        ref.watch(homeEnvasesPorRecibirItemsProvider).value ??
        const <HomeResumeItem>[];
    return OrbiPage(
      title: _greetingTitle(),
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
              activityPort: activityPort,
              currentUserId: currentUserId,
              envasesPendingItems: envasesPendingItems,
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
              // Turno de otro cajero: sólo le llega el callback a quien tiene
              // `collection_supervisor` (lo decide HomeCenterView).
              onOpenCashSessionById: (sessionId) {
                final route = '/collection/sessions/$sessionId';
                if (policy.allows(
                      route,
                      authenticated: true,
                      capabilities: capabilities,
                    ) &&
                    context.mounted) {
                  context.go(route);
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
}

/// El ÚNICO encabezado de Inicio: «Inicio operativo», siempre — orden del
/// dueño en ACC-03 (punto 1): se quita el saludo por nombre («Hola, nombre»)
/// que traía esta pantalla antes. La fecha larga va debajo, como subtítulo
/// (`homeTodayLabel`).
String _greetingTitle() => 'Inicio operativo';
