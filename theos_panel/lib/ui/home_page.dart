import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_center.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/route_access_policy.dart';
import '../app/session_composition.dart';
import '../app/u08_scope_adapters.dart';

import 'package:go_router/go_router.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(capabilitySnapshotProvider);
    final composition = ref.watch(orbiSessionCompositionProvider);
    final homePort = composition.home ?? ref.watch(scopeHomeResumePortProvider);
    final policy = ref.watch(routeAccessPolicyProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Inicio', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Continúa tu trabajo local y retoma borradores cuando estén disponibles.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (homePort == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Trabajo local'),
                subtitle: Text(
                  'No hay un servicio de sesión disponible para retomar trabajo.',
                ),
              ),
            ),
          Expanded(
            child: homePort == null
                ? const SizedBox.shrink()
                : HomeCenterView(
                    port: homePort,
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
          ),
        ],
      ),
    );
  }
}
