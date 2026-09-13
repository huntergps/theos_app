import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart'
    show CollectionSessionSupervisionPort, CollectionSupervisionResult, SyncReason;

import '../../app/collection_scope_composition.dart';
import '../auth/auth_controller.dart';
import '../sync/sync_center.dart' show syncCoordinatorProvider;
import 'collection_session_hub_screen.dart';
import 'collection_session_supervision_actions.dart';

/// Supervisor overview of ANOTHER cashier's turn — `/collection/sessions/:id`.
/// Reuses [CollectionSessionHubScreen] for layout, but every action here
/// runs ONLINE-ONLY through [CollectionSessionSupervisionPort] (never the
/// offline queue): see that port's docstring for why. `availableSupervisionActions`
/// decides what to OFFER; the server's own `UserError` is what actually
/// decides what SUCCEEDS, and is shown to the supervisor verbatim on
/// rejection — this screen never invents its own explanation for a refusal.
class CollectionSupervisedSessionScreen extends ConsumerWidget {
  const CollectionSupervisedSessionScreen({
    required this.sessionId,
    required this.view,
    super.key,
  });

  final int sessionId;
  final CollectionSessionLookup view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final capabilities = ref.watch(capabilitySnapshotProvider);
    final isOwner = profile != null && profile.userId == view.ownerUserId;
    final isSupervisor =
        capabilities?.permissions.contains('collection_supervisor') ?? false;
    final port = ref.watch(scopeCollectionSessionSupervisionActionsProvider);
    final available = availableSupervisionActions(
      rawState: view.rawState,
      isOwner: isOwner,
      isSupervisor: isSupervisor,
    );

    // Un solo hueco de "Cierre" en el hub: cuando varias de las tres
    // acciones de cierre aplican a la vez (`closing_control` ofrece TANTO
    // validar COMO cerrar directo para un supervisor), se prioriza la más
    // precisa para ese estado y la otra queda como acción de turno.
    final CollectionSupervisionAction? closingSlot =
        available.contains(CollectionSupervisionAction.reopenClosed)
        ? CollectionSupervisionAction.reopenClosed
        : available.contains(CollectionSupervisionAction.validate)
        ? CollectionSupervisionAction.validate
        : available.contains(CollectionSupervisionAction.close)
        ? CollectionSupervisionAction.close
        : null;
    final turnActionSet = Set<CollectionSupervisionAction>.from(available)
      ..remove(closingSlot);

    Future<void> run(CollectionSupervisionAction action) async {
      final confirmed = await _confirm(context, action, view);
      if (!confirmed || !context.mounted) return;
      if (port == null) {
        await _inform(
          context,
          'Sin conexión: no se puede completar esta acción sobre el turno '
          'de otro cajero. Inténtalo cuando vuelva la conexión.',
        );
        return;
      }
      final result = await _dispatch(port, action, sessionId);
      if (!context.mounted) return;
      if (result.isSuccess) {
        await ref
            .read(syncCoordinatorProvider)
            .requestSync(SyncReason('collection_session_supervision'));
        ref.invalidate(scopeCollectionSessionByIdFutureProvider(sessionId));
      } else {
        await _inform(
          context,
          result.serverMessage ?? 'La acción no se pudo completar.',
        );
      }
    }

    CollectionHubAction tileFor(CollectionSupervisionAction action) =>
        CollectionHubAction(
          label: CollectionSupervisionActionText.label(action),
          description: CollectionSupervisionActionText.description(action),
          icon: _iconFor(action),
          onOpen: () => run(action),
        );

    return CollectionSessionHubScreen(
      point: view.point,
      shift: view.shift,
      counts: view.counts,
      turnActions: [for (final action in turnActionSet) tileFor(action)],
      // CAJ-02 (registros del turno) no tiene pantalla propia todavía, ni
      // para el turno propio ni para uno ajeno — se deja sin `onOpen` a
      // propósito, nunca un destino inventado.
      recordActions: const [
        CollectionHubAction(
          label: 'Registros del turno',
          description: 'Órdenes, facturas y pagos de la sesión.',
          icon: FluentIcons.bulleted_list,
        ),
      ],
      closing: closingSlot == null
          ? const CollectionHubAction(
              label: 'Cierre',
              description: 'Ningún cierre aplica en el estado actual del turno.',
              icon: FluentIcons.date_time,
            )
          : tileFor(closingSlot),
    );
  }

  Future<CollectionSupervisionResult> _dispatch(
    CollectionSessionSupervisionPort port,
    CollectionSupervisionAction action,
    int sessionId,
  ) => switch (action) {
    CollectionSupervisionAction.pause => port.pause(sessionId),
    CollectionSupervisionAction.resume => port.resume(sessionId),
    CollectionSupervisionAction.validate => port.validate(sessionId),
    CollectionSupervisionAction.close => port.close(sessionId),
    CollectionSupervisionAction.reopenClosed => port.reopenClosed(sessionId),
  };

  IconData _iconFor(CollectionSupervisionAction action) => switch (action) {
    CollectionSupervisionAction.pause => FluentIcons.pause,
    CollectionSupervisionAction.resume => FluentIcons.play,
    CollectionSupervisionAction.validate => FluentIcons.completed_solid,
    CollectionSupervisionAction.close => FluentIcons.lock,
    CollectionSupervisionAction.reopenClosed => FluentIcons.unlock,
  };

  Future<bool> _confirm(
    BuildContext context,
    CollectionSupervisionAction action,
    CollectionSessionLookup view,
  ) async {
    final strong = CollectionSupervisionActionText.requiresStrongConfirmation(
      action,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(CollectionSupervisionActionText.label(action)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(view.point.pointLabel),
            if (view.point.cashierLabel != null)
              Text('Cajero: ${view.point.cashierLabel}'),
            const SizedBox(height: 8),
            Text(CollectionSupervisionActionText.description(action)),
            if (strong) ...[
              const SizedBox(height: 8),
              if (view.shift.differenceMinor != null)
                Text(
                  'Diferencia de efectivo: '
                  '${(view.shift.differenceMinor! / 100).toStringAsFixed(2)}',
                ),
              const Text('Esta acción no se puede deshacer.'),
            ],
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          FilledButton(
            child: const Text('Confirmar'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _inform(BuildContext context, String message) => showDialog<void>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: const Text('No se pudo completar'),
      content: Text(message),
      actions: [
        Button(
          child: const Text('Entendido'),
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ],
    ),
  );
}
