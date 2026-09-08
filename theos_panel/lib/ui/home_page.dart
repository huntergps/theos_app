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
    final links =
        <({String title, String path, String permission})>[
              (title: 'Ventas', path: '/sales', permission: 'seller'),
              (title: 'Clientes', path: '/clients', permission: 'seller'),
              (title: 'Productos', path: '/products', permission: 'seller'),
              (title: 'Caja', path: '/collection', permission: 'cashier'),
              (
                title: 'Aprobaciones',
                path: '/approvals',
                permission: 'approver',
              ),
              (
                title: 'Actividades',
                path: '/activities',
                permission: 'activities',
              ),
              (title: 'Sincronización', path: '/sync', permission: 'sync'),
              (
                title: 'Avisos',
                path: '/notifications',
                permission: 'notifications',
              ),
              (title: 'Configuración', path: '/settings', permission: ''),
            ]
            .where(
              (link) => link.permission.isEmpty
                  ? true
                  : policy.allows(
                      link.path,
                      authenticated: true,
                      capabilities: capabilities,
                    ),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Orbi ERP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (homePort == null)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Inicio no configurado'),
                  subtitle: Text(
                    'Conecta un servicio de sesión para retomar trabajo.',
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: links
                  .map(
                    (link) => OutlinedButton(
                      onPressed: () => context.go(link.path),
                      child: Text(link.title),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
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
      ),
    );
  }
}
