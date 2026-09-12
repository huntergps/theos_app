import 'package:fluent_ui/fluent_ui.dart';

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
      final theme = FluentTheme.of(context);
      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
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
                              ToggleButton(
                                checked:
                                    workspace.draftIds[i] ==
                                    workspace.selectedDraftId,
                                onChanged: workspace.busy
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
                                child: Text(
                                  labelBuilder?.call(
                                        workspace.draftIds[i],
                                        i,
                                      ) ??
                                      _shortDraftLabel(workspace.draftIds[i]),
                                ),
                              ),
                              IconButton(
                                key: ValueKey(
                                  'close-draft-${workspace.draftIds[i]}',
                                ),
                                icon: const Icon(
                                  FluentIcons.chrome_close,
                                  size: 18,
                                ),
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
              FilledButton(
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add),
                    SizedBox(width: 6),
                    Text('Nueva'),
                  ],
                ),
              ),
              _ReopenButton(workspace: workspace),
              if (constraints.maxWidth >= 600 && workspace.error != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message:
                        'No se pudo recuperar el borrador. Revisa el almacenamiento local.',
                    child: Icon(
                      FluentIcons.error_badge,
                      color: theme.resources.systemFillColorCritical,
                    ),
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
    widget.workspace.addListener(_refresh);
  }

  // A create/close elsewhere in the workspace must be reflected here without
  // waiting for this widget's own State to be torn down and rebuilt — the
  // same async-freshness defect that hid a restored note behind a collapsed
  // section: a value fetched once at build time and never re-synced.
  void _refresh() {
    if (!mounted) return;
    setState(() {
      _available = widget.workspace.availableDraftIds();
    });
  }

  @override
  void didUpdateWidget(covariant _ReopenButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace) {
      oldWidget.workspace.removeListener(_refresh);
      widget.workspace.addListener(_refresh);
      _available = widget.workspace.availableDraftIds();
    }
  }

  @override
  void dispose() {
    widget.workspace.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _available,
    builder: (context, snapshot) {
      final ready = snapshot.connectionState == ConnectionState.done;
      final enabled = !widget.workspace.busy && ready;
      final ids = snapshot.data ?? const <String>[];
      return Tooltip(
        message: 'Reabrir borrador',
        child: DropDownButton(
          key: const Key('reopen-draft-button'),
          disabled: !enabled,
          leading: const Icon(FluentIcons.open_folder_horizontal),
          items: ids.isEmpty
              ? [
                  MenuFlyoutItem(
                    text: const Text('No hay borradores cerrados'),
                    onPressed: null,
                  ),
                ]
              : [
                  for (final id in ids)
                    MenuFlyoutItem(
                      key: ValueKey('reopen-draft-item-$id'),
                      text: Text(_shortDraftLabel(id)),
                      onPressed: () async {
                        try {
                          await widget.workspace.reopen(id);
                        } catch (_) {
                          // Keep errors in the workspace state.
                        }
                      },
                    ),
                ],
        ),
      );
    },
  );
}

String _shortDraftLabel(String draftId) {
  if (draftId.length <= 14) return draftId;
  return 'Venta …${draftId.substring(draftId.length - 8)}';
}
