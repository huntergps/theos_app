import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/collection/collection_session_supervision_actions.dart';

void main() {
  group('availableSupervisionActions — se ofrece sólo en su estado y a su rol', () {
    test('opened: dueño puede pausar; nadie más sin ser supervisor', () {
      final owner = availableSupervisionActions(
        rawState: 'opened',
        isOwner: true,
        isSupervisor: false,
      );
      expect(owner, {CollectionSupervisionAction.pause});

      final strangerCashier = availableSupervisionActions(
        rawState: 'opened',
        isOwner: false,
        isSupervisor: false,
      );
      expect(strangerCashier, isEmpty);

      final supervisor = availableSupervisionActions(
        rawState: 'opened',
        isOwner: false,
        isSupervisor: true,
      );
      expect(supervisor, {
        CollectionSupervisionAction.pause,
        CollectionSupervisionAction.close,
      });
    });

    test('paused: sólo reanudar, para dueño o supervisor', () {
      expect(
        availableSupervisionActions(
          rawState: 'paused',
          isOwner: true,
          isSupervisor: false,
        ),
        {CollectionSupervisionAction.resume},
      );
      expect(
        availableSupervisionActions(
          rawState: 'paused',
          isOwner: false,
          isSupervisor: true,
        ),
        {CollectionSupervisionAction.resume},
      );
      expect(
        availableSupervisionActions(
          rawState: 'paused',
          isOwner: false,
          isSupervisor: false,
        ),
        isEmpty,
      );
    });

    test(
      'closing_control: pausar es de dueño-o-supervisor; validar y cerrar SÓLO supervisor',
      () {
        final owner = availableSupervisionActions(
          rawState: 'closing_control',
          isOwner: true,
          isSupervisor: false,
        );
        expect(owner, {CollectionSupervisionAction.pause});

        final supervisor = availableSupervisionActions(
          rawState: 'closing_control',
          isOwner: false,
          isSupervisor: true,
        );
        expect(supervisor, {
          CollectionSupervisionAction.pause,
          CollectionSupervisionAction.validate,
          CollectionSupervisionAction.close,
        });
      },
    );

    test('closed: sólo el supervisor puede reabrir, nadie más nada', () {
      expect(
        availableSupervisionActions(
          rawState: 'closed',
          isOwner: true,
          isSupervisor: false,
        ),
        isEmpty,
        reason: 'ni siquiera el dueño del turno puede reabrir uno cerrado',
      );
      expect(
        availableSupervisionActions(
          rawState: 'closed',
          isOwner: false,
          isSupervisor: true,
        ),
        {CollectionSupervisionAction.reopenClosed},
      );
    });

    test('opening_control: nada aplica todavía, ni para el supervisor', () {
      expect(
        availableSupervisionActions(
          rawState: 'opening_control',
          isOwner: false,
          isSupervisor: true,
        ),
        isEmpty,
      );
    });
  });
}
