import 'package:flutter/material.dart';

import '../../bindings/record_view_controller.dart';

/// Compact representation of records. It is intentionally a list of cards,
/// not a compressed data grid, for phone and portrait tablet constraints.
class OrbiRecordList<T> extends StatelessWidget {
  const OrbiRecordList({
    super.key,
    required this.controller,
    required this.columns,
    this.onRecordTap,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final OrbiRecordViewController<T> controller;
  final List<OrbiRecordColumn<T>> columns;
  final ValueChanged<OrbiRecord<T>>? onRecordTap;
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
              return _RecordCard<T>(
                key: ValueKey<String>(id),
                record: record,
                columns: columns,
                selected: selectedRow,
                onTap: () {
                  controller.select(record.id);
                  onRecordTap?.call(record);
                },
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
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      selected: selected,
      label: columns.isEmpty ? record.id : columns.first.value(record.value),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: selected ? colors.primaryContainer : colors.surface,
        child: InkWell(
          onTap: onTap,
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
                            style: Theme.of(context).textTheme.labelMedium,
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
    );
  }
}
