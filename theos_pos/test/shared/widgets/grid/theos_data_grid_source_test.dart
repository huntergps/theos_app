import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_pos/shared/widgets/grid/theos_data_grid_source.dart';

void main() {
  TheosDataGridSource<int> source(List<int> values) {
    return TheosDataGridSource<int>(
      data: values,
      rowBuilder: (value) => [
        DataGridCell<int>(columnName: 'value', value: value),
      ],
    );
  }

  test('pagination exposes only the current bounded page', () async {
    final dataSource = source(List.generate(205, (index) => index));
    dataSource.configurePagination(enabled: true, rowsPerPage: 80);

    expect(dataSource.totalRowCount, 205);
    expect(dataSource.rows, hasLength(80));
    expect(dataSource.getItem(0), 0);
    expect(dataSource.getItem(79), 79);

    await dataSource.handlePageChange(0, 2);

    expect(dataSource.currentPageIndex, 2);
    expect(dataSource.rows, hasLength(45));
    expect(dataSource.getItem(0), 160);
    expect(dataSource.getItem(44), 204);
    expect(dataSource.getItem(45), isNull);
  });

  test('shrinking data clamps an out-of-range page', () async {
    final dataSource = source(List.generate(160, (index) => index));
    dataSource.configurePagination(enabled: true, rowsPerPage: 40);
    await dataSource.handlePageChange(0, 3);

    dataSource.updateData(List.generate(15, (index) => index));

    expect(dataSource.currentPageIndex, 0);
    expect(dataSource.rows, hasLength(15));
    expect(dataSource.getItem(14), 14);
  });

  test('disabling pagination exposes every row', () {
    final dataSource = source(List.generate(120, (index) => index));
    dataSource.configurePagination(enabled: true, rowsPerPage: 25);
    dataSource.configurePagination(enabled: false, rowsPerPage: 25);

    expect(dataSource.rows, hasLength(120));
    expect(dataSource.getItem(119), 119);
  });

  test(
    'external pagination delegates without slicing the database page',
    () async {
      final requestedPages = <int>[];
      final dataSource = source(List.generate(80, (index) => 80 + index));
      dataSource.configurePagination(enabled: false, rowsPerPage: 80);
      dataSource.onExternalPageChange = (pageIndex) async {
        requestedPages.add(pageIndex);
        return true;
      };

      final accepted = await dataSource.handlePageChange(0, 2);

      expect(accepted, isTrue);
      expect(requestedPages, [2]);
      expect(dataSource.currentPageIndex, 2);
      expect(dataSource.rows, hasLength(80));
      expect(dataSource.getItem(0), 80);
    },
  );

  test(
    'sorting resets to the first page and preserves row-to-model mapping',
    () async {
      final dataSource = source(List.generate(12, (index) => index));
      dataSource.configurePagination(enabled: true, rowsPerPage: 5);
      await dataSource.handlePageChange(0, 2);
      dataSource.sortedColumns.add(
        const SortColumnDetails(
          name: 'value',
          sortDirection: DataGridSortDirection.descending,
        ),
      );

      await dataSource.performSorting(dataSource.rows);

      expect(dataSource.currentPageIndex, 0);
      expect(dataSource.rows, hasLength(5));
      expect(dataSource.getItem(0), 11);
      expect(dataSource.getItem(4), 7);
    },
  );
}
