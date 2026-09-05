import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/collection/screens/collection_dashboard_screen.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  const configId = 5;

  CollectionSession session(SessionState state) => CollectionSession(
        id: 1,
        name: 'Caja 5',
        state: state,
        configId: configId,
      );

  test('blocks only opening and opened sessions for the same config', () {
    expect(blocksNewSessionForConfig(session(SessionState.openingControl), configId), isTrue);
    expect(blocksNewSessionForConfig(session(SessionState.opened), configId), isTrue);
    expect(blocksNewSessionForConfig(session(SessionState.paused), configId), isFalse);
    expect(blocksNewSessionForConfig(session(SessionState.closingControl), configId), isFalse);
    expect(blocksNewSessionForConfig(session(SessionState.closed), configId), isFalse);
  });

  test('does not block another config or a missing session', () {
    expect(blocksNewSessionForConfig(session(SessionState.opened), 6), isFalse);
    expect(blocksNewSessionForConfig(null, configId), isFalse);
  });
}
