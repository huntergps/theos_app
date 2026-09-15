import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart'
    show CapabilitySnapshot, ServerFeature, ServerFeatureState, ServerFeatures;
import 'package:theos_panel/features/auth/route_access_messages.dart';
import 'package:theos_panel/features/auth/route_access_policy.dart';
import 'package:theos_panel/ui/components/copyable_message.dart';

/// The real ERP2 seller, reduced to what the app actually reads.
///
/// Measured, not invented: uid 9 carries 19 Odoo groups and none of them is
/// `Caja de Cobros / Cajero`, while the cashier (uid 23) carries the same 19
/// plus that one. Two roles, not a broken account.
CapabilitySnapshot _snapshot(Set<String> permissions) => CapabilitySnapshot(
  scopeKey: 'erp2/9',
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026, 9, 12),
  permissions: permissions,
);

final _seller = _snapshot({'seller'});
final _cashier = _snapshot({'seller', 'cashier'});

void main() {
  const policy = RouteAccessPolicy();

  group('a permission you do not have is not an error', () {
    test('the seller is told Caja is not theirs, in plain non-alarming words', () {
      // The exact case: this person can do their whole job, and Caja simply
      // is not part of it.
      expect(
        policy.allows('/collection', authenticated: true, capabilities: _seller),
        isFalse,
        reason: 'If this ever becomes true the message below is moot.',
      );
      final message = routeAccessDeniedMessage(
        '/collection',
        capabilities: _seller,
      )!;
      expect(message.title, contains('Caja'));
      expect(message.body, contains('no es un fallo'));
      expect(message.body.toLowerCase(), contains('supervisor'));
      // Information, never an error: styling this red teaches somebody that
      // the app is unreliable when nothing at all went wrong.
      expect(message.severity, OrbiMessageSeverity.info);
    });

    test('and the cashier is never told anything, because it IS theirs', () {
      expect(
        policy.allows('/collection', authenticated: true, capabilities: _cashier),
        isTrue,
      );
    });

    test('no permission message is worded as a failure', () {
      const alarming = [
        'error',
        'fallo',
        'falló',
        'no se pudo',
        'denegado',
        'prohibido',
        'no tienes acceso',
        'acceso denegado',
      ];
      for (final area in knownGatedAreas) {
        final message = routeAccessDeniedMessage(area, capabilities: _seller);
        if (message == null) continue;
        final text = '${message.title} ${message.body}'.toLowerCase();
        for (final word in alarming) {
          // "no es un fallo" is the one allowed use, and it is the denial of
          // the word, not the word itself.
          final stripped = text.replaceAll('no es un fallo', '');
          expect(
            stripped,
            isNot(contains(word)),
            reason: '$area sounds like something broke: "$word".',
          );
        }
      }
    });

    test('every message says who can actually help', () {
      for (final area in knownGatedAreas) {
        final message = routeAccessDeniedMessage(area, capabilities: _seller);
        if (message == null) continue;
        final text = message.body.toLowerCase();
        expect(
          text.contains('supervisor') || text.contains('administra'),
          isTrue,
          reason:
              '$area closes a door without naming anyone who can open it.',
        );
      }
    });
  });

  group('not knowing yet is not the same as being refused', () {
    test('while permissions are still loading it says so, and says wait', () {
      // RouteAccessPolicy treats a null snapshot as "everything gated stays
      // shut", which is the right call — but reporting it with the same words
      // as a refusal would tell somebody they lack a permission they may well
      // have.
      final message = routeAccessDeniedMessage(
        '/collection',
        capabilities: null,
      )!;
      expect(message.title.toLowerCase(), contains('cargando'));
      expect(message.body.toLowerCase(), contains('vuelve a intentarlo'));
      expect(message.body, isNot(contains('no te corresponde')));
      // Temporary, so it is the one that is styled as attention.
      expect(message.severity, OrbiMessageSeverity.warning);
    });

    test('it is a different message from the refusal one', () {
      final loading = routeAccessDeniedMessage('/warehouse', capabilities: null)!;
      final refused = routeAccessDeniedMessage(
        '/warehouse',
        capabilities: _seller,
      )!;
      expect(loading.title, isNot(refused.title));
    });
  });

  group('the messages stay aligned with the policy', () {
    test('every area the policy gates has something to say about it', () {
      // The drift this catches: somebody adds a gated area to
      // RouteAccessPolicy and the app silently redirects home for it,
      // reintroducing exactly the silence this module exists to end.
      for (final area in knownGatedAreas) {
        expect(
          routeAccessDeniedMessage(area, capabilities: _seller),
          isNotNull,
          reason: '$area has no message.',
        );
      }
    });

    test('a child route inherits its area message', () {
      final parent = routeAccessDeniedMessage(
        '/collection',
        capabilities: _seller,
      )!;
      final child = routeAccessDeniedMessage(
        '/collection/shift',
        capabilities: _seller,
      )!;
      expect(child.title, parent.title);
    });

    test('a gated path with no known area says the honest vague thing', () {
      final message = routeAccessDeniedMessage(
        '/algo-que-no-existe-todavia',
        capabilities: _seller,
      )!;
      expect(message.body, contains('no es un fallo'));
      // It must not invent an area name it cannot know.
      expect(message.title, isNot(contains('Caja')));
    });

    test('the places everyone may go produce no message at all', () {
      for (final path in ['/', '/settings', '/login']) {
        expect(
          routeAccessDeniedMessage(path, capabilities: _seller),
          isNull,
          reason: '$path is open to everyone; saying anything is noise.',
        );
        expect(
          routeAccessDeniedMessage(path, capabilities: null),
          isNull,
          reason: '$path stays reachable even before permissions arrive.',
        );
      }
    });
  });

  group('a module the server does not have is not a permission problem', () {
    test('the message names the module, not a supervisor to ask', () {
      final features = ServerFeatures.empty.withState(
        ServerFeature.sales,
        ServerFeatureState.unavailable,
        DateTime.utc(2026, 9, 14),
      );
      final message = routeAccessDeniedMessage(
        '/sales',
        capabilities: _seller,
        features: features,
      )!;
      expect(message.title, 'Este servidor no tiene el módulo de Ventas.');
      expect(message.body, isNot(contains('supervisor')));
      expect(message.severity, OrbiMessageSeverity.info);
    });

    test('unknown (not yet probed) still reports the ordinary permission '
        'message, never the module one', () {
      final message = routeAccessDeniedMessage(
        '/collection',
        capabilities: _seller,
        features: ServerFeatures.empty,
      )!;
      expect(message.title, contains('Caja'));
      expect(message.title, isNot(contains('módulo')));
    });
  });

  group('and it can be taken away like every other message', () {
    test('the whole thing goes to the clipboard', () {
      final message = routeAccessDeniedMessage(
        '/collection',
        capabilities: _seller,
      )!;
      expect(message.clipboardText, contains(message.title));
      expect(message.clipboardText, contains(message.body));
    });
  });

  group('the refusal survives the trip from the redirect to the screen', () {
    // GoRouter's redirect can only return a destination; it has no way to say
    // anything on the way out. That is exactly why the refusal was silent, so
    // the carrier is what actually ends the silence.
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('a refused navigation leaves a message behind', () {
      final c = container();
      final notifier = c.read(routeAccessDenialProvider.notifier);
      expect(notifier.report('/collection', capabilities: _seller), isTrue);
      expect(c.read(routeAccessDenialProvider), isNotNull);
      expect(c.read(routeAccessDenialProvider)!.title, contains('Caja'));
    });

    test('a path that was always open leaves nothing', () {
      final c = container();
      final notifier = c.read(routeAccessDenialProvider.notifier);
      expect(notifier.report('/settings', capabilities: _seller), isFalse);
      expect(c.read(routeAccessDenialProvider), isNull);
    });

    test('it is read exactly once', () {
      // A refusal explains ONE navigation that did not happen. If it stayed
      // around it would reappear later, attached to a move that had nothing
      // to do with it.
      final c = container();
      final notifier = c.read(routeAccessDenialProvider.notifier);
      notifier.report('/warehouse', capabilities: _seller);
      expect(notifier.take(), isNotNull);
      expect(notifier.take(), isNull);
      expect(c.read(routeAccessDenialProvider), isNull);
    });

    test('a newer refusal replaces an unread older one', () {
      final c = container();
      final notifier = c.read(routeAccessDenialProvider.notifier);
      notifier.report('/warehouse', capabilities: _seller);
      notifier.report('/collection', capabilities: _seller);
      expect(notifier.take()!.title, contains('Caja'));
    });
  });
}
