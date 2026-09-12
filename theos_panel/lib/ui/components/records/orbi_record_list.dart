import 'package:fluent_ui/fluent_ui.dart';

import '../../bindings/record_view_controller.dart';

/// Compact representation of records. It is intentionally a list of cards,
/// not a compressed data grid, for phone and portrait tablet constraints.
class OrbiRecordList<T> extends StatelessWidget {
  const OrbiRecordList({
    super.key,
    required this.controller,
    required this.columns,
    this.onRecordTap,
    this.cardBuilder,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final OrbiRecordViewController<T> controller;
  final List<OrbiRecordColumn<T>> columns;
  final ValueChanged<OrbiRecord<T>>? onRecordTap;
  final Widget Function(BuildContext, OrbiRecord<T>)? cardBuilder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<OrbiRecord<T>>>(
      valueListenable: controller.recordsListenable,
      builder: (context, records, _) {
        if (records.isEmpty) {
          return const Center(child: Text('No hay registros'));
        }
        return ValueListenableBuilder<Set<String>>(
          valueListenable: controller.selectedIdsListenable,
          builder: (context, selected, _) => ListView.separated(
            padding: padding,
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final record = records[index];
              final id = controller.idFor(record);
              final selectedRow = selected.contains(id);
              void onTap() {
                controller.select(record.id);
                onRecordTap?.call(record);
              }

              if (cardBuilder != null) {
                return Semantics(
                  container: true,
                  // Material's InkWell wraps its own tap semantics in a
                  // second `container` boundary, so it never merged into
                  // this label. Fluent's GestureDetector does not — without
                  // `explicitChildNodes`, its tap action and every Text
                  // child below fold into this node, turning "B" into
                  // "B\nNombre\nB" and breaking exact-label lookups.
                  explicitChildNodes: true,
                  selected: selectedRow,
                  label: columns.isEmpty
                      ? record.id
                      : columns.first.value(record.value),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: ValueKey<String>(id),
                      onTap: onTap,
                      child: cardBuilder!(context, record),
                    ),
                  ),
                );
              }
              return _RecordCard<T>(
                key: ValueKey<String>(id),
                record: record,
                columns: columns,
                selected: selectedRow,
                onTap: onTap,
              );
            },
          ),
        );
      },
    );
  }
}

class _RecordCard<T> extends StatelessWidget {
  const _RecordCard({
    super.key,
    required this.record,
    required this.columns,
    required this.selected,
    required this.onTap,
  });

  final OrbiRecord<T> record;
  final List<OrbiRecordColumn<T>> columns;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Semantics(
      container: true,
      // See the matching note in OrbiRecordList._RecordCard's sibling
      // branch above: without this, GestureDetector's tap semantics and
      // every Text child merge into this node instead of staying separate.
      explicitChildNodes: true,
      selected: selected,
      label: columns.isEmpty ? record.id : columns.first.value(record.value),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? theme.accentColor.lightest : theme.cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.all(color: theme.resources.cardStrokeColorDefault),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == columns.length - 1 ? 0 : 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 112,
                            child: Text(
                              columns[i].label,
                              style: theme.typography.caption,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              columns[i].value(record.value),
                              textAlign: columns[i].textAlign,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
