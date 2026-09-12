import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

void main() {
  test(
    'write acknowledgement alone is never treated as confirmation — the '
    're-read line quantity/picked decide, exactly like button_validate',
    () async {
      final confirmed = await interpretStockMoveLineWriteResponse(
        true,
        readState: () async => [
          {'id': 5, 'quantity': 3.0, 'picked': true},
        ],
      );
      expect(confirmed.state, StockMoveLineWriteState.confirmed);
      expect(confirmed.confirmedQuantity, 3.0);
      expect(confirmed.confirmedPicked, isTrue);

      final rejected = await interpretStockMoveLineWriteResponse(
        false,
        readState: () async => throw StateError('must not read after rejection'),
      );
      expect(rejected.state, StockMoveLineWriteState.rejected);
    },
  );

  test('a re-read with no matching row or a malformed quantity is rejected', () async {
    final empty = await interpretStockMoveLineWriteResponse(
      true,
      readState: () async => <Map<String, dynamic>>[],
    );
    expect(empty.state, StockMoveLineWriteState.rejected);

    final malformed = await interpretStockMoveLineWriteResponse(
      true,
      readState: () async => [
        {'id': 5, 'quantity': 'not-a-number', 'picked': false},
      ],
    );
    expect(malformed.state, StockMoveLineWriteState.rejected);
  });

  test('an unrecognized write response is rejected, never assumed successful', () async {
    final result = await interpretStockMoveLineWriteResponse(
      const {'type': 'ir.actions.act_window'},
      readState: () async => throw StateError('must not read unknown response'),
    );
    expect(result.state, StockMoveLineWriteState.rejected);
  });

  test('rechecks the warehouse capability before writing anything', () async {
    final port = RuntimeStockMoveLineQuantityPort(
      runtime: SessionRuntime(),
      capabilities: CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
        permissions: const [],
      ),
    );
    final result = await port.setQuantity(lineId: 12, quantity: 4);
    expect(result.state, StockMoveLineWriteState.rejected);
    expect(result.message, contains('Autoridad insuficiente'));
  });

  test('rejects an invalid line id or a non-finite/negative quantity before touching the session', () async {
    final port = RuntimeStockMoveLineQuantityPort(
      runtime: SessionRuntime(),
      capabilities: CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
        permissions: const ['warehouse'],
      ),
    );
    expect(
      (await port.setQuantity(lineId: 0, quantity: 4)).state,
      StockMoveLineWriteState.rejected,
    );
    expect(
      (await port.setQuantity(lineId: 12, quantity: -1)).state,
      StockMoveLineWriteState.rejected,
    );
    expect(
      (await port.setQuantity(lineId: 12, quantity: double.nan)).state,
      StockMoveLineWriteState.rejected,
    );
  });

  test('rejects without a client when no session is active', () async {
    final port = RuntimeStockMoveLineQuantityPort(
      runtime: SessionRuntime(),
      capabilities: CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
        permissions: const ['warehouse'],
      ),
    );
    final result = await port.setQuantity(lineId: 12, quantity: 4);
    expect(result.state, StockMoveLineWriteState.rejected);
    expect(result.message, contains('Sesión Odoo no disponible'));
  });
}
