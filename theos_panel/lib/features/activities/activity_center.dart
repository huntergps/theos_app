import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/components/copyable_message.dart';

enum ActivityStatus { overdue, today, planned, done }

final class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.title,
    required this.status,
    this.canComplete = false,
    this.activityType,
    this.documentLabel,
    this.documentModel,
    this.documentId,
    this.responsibleId,
    this.responsibleName,
    this.deadline,
    this.note,
  });

  final String id;
  final String title;
  final ActivityStatus status;
  final bool canComplete;

  /// Nombre del tipo de actividad (`activity_type_id` en `mail.activity`).
  final String? activityType;

  /// Etiqueta del documento relacionado (`res_name`).
  final String? documentLabel;

  /// Modelo del documento relacionado (`res_model`), p.ej. `sale.order`.
  final String? documentModel;

  /// Id del documento relacionado (`res_id`).
  final int? documentId;

  /// Id del usuario responsable (`user_id`). Permite comparar contra la
  /// sesión activa para el filtro «Mías».
  final int? responsibleId;
  final String? responsibleName;
  final DateTime? deadline;
  final String? note;
}

abstract interface class ActivityPort {
  Stream<List<ActivityItem>> get changes;
  List<ActivityItem> get snapshot;
  Future<bool> complete(ActivityItem item);
}

final activityPortProvider = Provider<ActivityPort>(
  (ref) => const _EmptyActivityPort(),
);

final class _EmptyActivityPort implements ActivityPort {
  const _EmptyActivityPort();
  @override
  List<ActivityItem> get snapshot => const [];
  @override
  Stream<List<ActivityItem>> get changes => const Stream.empty();
  @override
  Future<bool> complete(ActivityItem item) async => false;
}

/// Pantallas de listado que Orbi ya tiene para cada modelo de documento.
/// No hay pantalla de detalle por registro todavía, así que el enlace lleva
/// al listado del tipo de documento, no al registro puntual.
String? _listRouteForModel(String? model) => switch (model) {
  'sale.order' => '/sales',
  'res.partner' => '/clients',
  'product.template' || 'product.product' => '/products',
  _ => null,
};

class ActivityCenterView extends StatefulWidget {
  const ActivityCenterView({required this.port, this.currentUserId, super.key});

  final ActivityPort port;

  /// Id del usuario de la sesión activa. El filtro «Mías / Todas» sólo se
  /// ofrece cuando se conoce esta identidad y hay actividades de más de un
  /// responsable a la vista.
  final int? currentUserId;

  @override
  State<ActivityCenterView> createState() => _ActivityCenterViewState();
}

class _ActivityCenterViewState extends State<ActivityCenterView> {
  bool _onlyMine = false;
  String? _busyItemId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityItem>>(
      stream: widget.port.changes,
      initialData: widget.port.snapshot,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ActivityItem>[];
        if (items.isEmpty) return _EmptyState(hasFilter: false);

        final currentUserId = widget.currentUserId;
        final hasOtherResponsibles =
            currentUserId != null &&
            items.any(
              (item) =>
                  item.responsibleId != null &&
                  item.responsibleId != currentUserId,
            );

        final visible = (_onlyMine && hasOtherResponsibles)
            ? items
                  .where(
                    (item) =>
                        item.responsibleId == null ||
                        item.responsibleId == currentUserId,
                  )
                  .toList(growable: false)
            : items;

        if (visible.isEmpty) return _EmptyState(hasFilter: true);

        final overdue = _sorted(
          visible.where((item) => item.status == ActivityStatus.overdue),
        );
        final today = _sorted(
          visible.where((item) => item.status == ActivityStatus.today),
        );
        final planned = _sorted(
          visible.where((item) => item.status == ActivityStatus.planned),
        );
        final done = _sorted(
          visible.where((item) => item.status == ActivityStatus.done),
        );

        final theme = FluentTheme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasOtherResponsibles) _buildOwnerFilter(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _section(
                    context,
                    'Vencidas',
                    overdue,
                    theme.resources.systemFillColorCritical,
                  ),
                  _section(
                    context,
                    'Hoy',
                    today,
                    theme.resources.systemFillColorCaution,
                  ),
                  _section(
                    context,
                    'Próximas',
                    planned,
                    theme.resources.systemFillColorSuccess,
                  ),
                  if (done.isNotEmpty) _doneSection(context, done),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<ActivityItem> _sorted(Iterable<ActivityItem> items) {
    final list = items.toList(growable: false);
    list.sort((a, b) {
      final ad = a.deadline;
      final bd = b.deadline;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return list;
  }

  Widget _buildOwnerFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          ToggleButton(
            checked: _onlyMine,
            onChanged: (value) => setState(() => _onlyMine = true),
            child: const Text('Mías'),
          ),
          const SizedBox(width: 8),
          ToggleButton(
            checked: !_onlyMine,
            onChanged: (value) => setState(() => _onlyMine = false),
            child: const Text('Todas'),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String label,
    List<ActivityItem> items,
    Color color,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, '$label (${items.length})', color),
        ...items.map((item) => _row(context, item, color)),
      ],
    );
  }

  Widget _doneSection(BuildContext context, List<ActivityItem> items) {
    final color = FluentTheme.of(context).resources.textFillColorDisabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Expander(
        header: Text('Completadas (${items.length})'),
        content: Column(
          children: items.map((item) => _row(context, item, color)).toList(),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label, Color color) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: theme.typography.bodyStrong),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ActivityItem item, Color color) {
    final theme = FluentTheme.of(context);
    final route = _listRouteForModel(item.documentModel);
    final canAct = item.canComplete && item.status != ActivityStatus.done;
    final busy = _busyItemId == item.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 12),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: theme.typography.bodyStrong),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.deadline != null)
                      _MetaText(
                        icon: FluentIcons.calendar_day,
                        text: _formatDeadline(item.deadline!),
                        color: color,
                      ),
                    if ((item.activityType ?? '').isNotEmpty)
                      _MetaText(
                        icon: FluentIcons.task_logo,
                        text: item.activityType!,
                      ),
                    if ((item.responsibleName ?? '').isNotEmpty)
                      _MetaText(
                        icon: FluentIcons.contact,
                        text: item.responsibleName!,
                      ),
                    if ((item.documentLabel ?? '').isNotEmpty)
                      route != null
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: HyperlinkButton(
                                onPressed: () => context.go(route),
                                child: Text(
                                  item.documentLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                          : _MetaText(
                              icon: FluentIcons.document,
                              text: item.documentLabel!,
                            ),
                  ],
                ),
                if ((item.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.note!.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption,
                  ),
                ],
              ],
            ),
          ),
          if (canAct)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: 'Marcar como hecha',
                child: IconButton(
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      : const Icon(FluentIcons.completed_solid),
                  onPressed: busy ? null : () => _confirmComplete(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmComplete(ActivityItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Marcar actividad como hecha'),
        content: Text(
          '¿Confirmas que "${item.title}" ya está lista? '
          'La actividad se dará por completada en Odoo.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Marcar hecha'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyItemId = item.id);
    final ok = await widget.port.complete(item);
    if (!mounted) return;
    setState(() => _busyItemId = null);
    showCopyableMessage(
      context,
      CopyableMessage(
        title: ok ? 'Actividad completada' : 'No se pudo completar la actividad',
        body: ok ? item.title : 'Vuelve a intentarlo en unos segundos.',
        severity: ok ? OrbiMessageSeverity.success : OrbiMessageSeverity.warning,
      ),
      durations: const MessageDurations(),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final resolvedColor = color ?? theme.resources.textFillColorSecondary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: resolvedColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption?.copyWith(color: resolvedColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.completed_solid,
            size: 48,
            color: theme.resources.textFillColorDisabled,
          ),
          const SizedBox(height: 12),
          const Text('No hay actividades'),
          const SizedBox(height: 4),
          Text(
            hasFilter
                ? 'No hay actividades tuyas pendientes.'
                : 'Estás al día.',
            style: theme.typography.caption,
          ),
        ],
      ),
    );
  }
}

String _formatDeadline(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == -1) return 'Ayer';
  if (diff == 1) return 'Mañana';
  if (diff < 0) return 'Hace ${-diff} días';
  if (diff <= 7) return 'En $diff días';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
