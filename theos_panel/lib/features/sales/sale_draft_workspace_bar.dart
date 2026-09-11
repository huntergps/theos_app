import 'package:flutter/material.dart';

import 'sale_draft_workspace.dart';

/// Compact, horizontally scalable document switcher. The editor remains
/// outside this widget and is supplied by the route owner.
final class SaleDraftWorkspaceBar extends StatelessWidget {
  const SaleDraftWorkspaceBar({
    super.key,
    required this.workspace,
    this.onNew,
    this.onSelected,
    this.labelBuilder,
  });

  final SaleDraftWorkspace workspace;
  final Future<void> Function()? onNew;
  final Future<void> Function(String draftId)? onSelected;
  final String Function(String draftId, int index)? labelBuilder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: workspace,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      return Material(
        color: colors.surface,
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < workspace.draftIds.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ChoiceChip(
                                selected:
                                    workspace.draftIds[i] ==
                                    workspace.selectedDraftId,
                                label: Text(
                                  labelBuilder?.call(
                                        workspace.draftIds[i],
                                        i,
                                      ) ??
                                      _shortDraftLabel(workspace.draftIds[i]),
                                ),
                                onSelected: workspace.busy
                                    ? null
                                    : (_) async {
                                        try {
                                          await (onSelected?.call(
                                                workspace.draftIds[i],
                                              ) ??
                                              workspace.select(
                                                workspace.draftIds[i],
                                              ));
                                        } catch (_) {
                                          // Workspace exposes the actionable
                                          // error; the route decides how to
                                          // present it.
                                        }
                                      },
                              ),
                              IconButton(
                                key: ValueKey(
                                  'close-draft-${workspace.draftIds[i]}',
                                ),
                                tooltip:
                                    'Cerrar ${_shortDraftLabel(workspace.draftIds[i])}',
                                icon: const Icon(Icons.close, size: 18),
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: workspace.busy
                                    ? null
                                    : () async {
                                        try {
                                          await workspace.close(
                                            workspace.draftIds[i],
                                          );
                                        } catch (_) {
                                          // Keep errors in the workspace state.
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: workspace.busy
                    ? null
                    : () async {
                        try {
                          if (onNew != null) {
                            await onNew!();
                          } else {
                            await workspace.create();
                          }
                        } catch (_) {
                          // Workspace exposes the actionable error; keep the
                          // bar free of unhandled UI futures.
                        }
                      },
                icon: const Icon(Icons.add),
                label: const Text('Nueva'),
              ),
              _ReopenButton(workspace: workspace),
              if (constraints.maxWidth >= 600 && workspace.error != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: 'No se pudo recuperar el borrador. Revisa el almacenamiento local.',
                    child: Icon(Icons.error_outline, color: colors.error),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

final class _ReopenButton extends StatefulWidget {
  const _ReopenButton({required this.workspace});
  final SaleDraftWorkspace workspace;

  @override
  State<_ReopenButton> createState() => _ReopenButtonState();
}

final class _ReopenButtonState extends State<_ReopenButton> {
  late Future<List<String>> _available;

  @override
  void initState() {
    super.initState();
    _available = widget.workspace.availableDraftIds();
  }

  @override
  void didUpdateWidget(covariant _ReopenButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace) {
      _available = widget.workspace.availableDraftIds();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _available,
    builder: (context, snapshot) => PopupMenuButton<String>(
      key: const Key('reopen-draft-button'),
      tooltip: 'Reabrir borrador',
      icon: const Icon(Icons.folder_open_outlined),
      enabled:
          !widget.workspace.busy &&
          snapshot.connectionState == ConnectionState.done,
      onSelected: (draftId) async {
        try {
          await widget.workspace.reopen(draftId);
        } catch (_) {
          // Keep errors in the workspace state.
        }
      },
      itemBuilder: (context) => [
        for (final id in snapshot.data ?? const <String>[])
          PopupMenuItem<String>(value: id, child: Text(_shortDraftLabel(id))),
        if (snapshot.connectionState == ConnectionState.done &&
            (snapshot.data?.isEmpty ?? true))
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('No hay borradores cerrados'),
          ),
      ],
    ),
  );
}

String _shortDraftLabel(String draftId) {
  if (draftId.length <= 14) return draftId;
  return 'Venta …${draftId.substring(draftId.length - 8)}';
}
