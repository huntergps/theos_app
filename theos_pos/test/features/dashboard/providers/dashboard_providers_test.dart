import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/dashboard/providers/dashboard_providers.dart';

void main() {
  test('equal daily metrics collapse duplicate stream emissions', () async {
    const first = DailySaleMetrics(
      totalOrders: 4,
      totalAmount: 125.50,
      draftCount: 1,
      confirmedCount: 3,
    );
    const duplicate = DailySaleMetrics(
      totalOrders: 4,
      totalAmount: 125.50,
      draftCount: 1,
      confirmedCount: 3,
    );
    const changed = DailySaleMetrics(
      totalOrders: 5,
      totalAmount: 150,
      draftCount: 2,
      confirmedCount: 3,
    );

    final emissions = await Stream.fromIterable([first, duplicate, changed])
        .distinct()
        .toList();

    expect(emissions, [first, changed]);
    expect(first, duplicate);
    expect(first.hashCode, duplicate.hashCode);
  });
}
