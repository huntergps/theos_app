import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show OdooValidationException;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/collection_scope_composition.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/collection/collection_contracts.dart';
import 'package:theos_panel/features/collection/collection_session_hub_screen.dart';
import 'package:theos_panel/features/collection/collection_supervised_session_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _Call {
  const _Call(this.method);
  final String method;
}

final class _FakeActions implements SaleOdooActions {
  final calls = <_Call>[];
  dynamic Function(String method)? onCall;

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add(_Call(method));
    final handler = onCall;
    if (handler == null) return true;
    final result = handler(method);
    if (result is Exception) throw result;
    return result;
  }
}

CapabilitySnapshot _capabilities(Set<String> permissions) => CapabilitySnapshot(
  scopeKey: 'test-scope',
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026, 9, 13),
  permissions: permissions,
);

AuthProfile _profile({required int userId}) => AuthProfile(
  serverUrl: 'https://erp2.test',
  database: 'erp2_test',
  login: 'supervisor1',
  userId: userId,
  installationId: 'install-1',
  credentialReference: 'ref-1',
);

CollectionSessionLookup _view({
  required int ownerUserId,
  required String rawState,
}) => CollectionSessionLookup(
  shift: const CollectionShiftSnapshot(
    id: '11',
    state: CollectionShiftState.closing,
    expectedVersion: 0,
    differenceMinor: 500,
  ),
  point: const CollectionPointContext(
    pointLabel: '006 SUCURSAL NORTE',
    cashierLabel: 'Erik Aldas',
  ),
  ownerUserId: ownerUserId,
  rawState: rawState,
  counts: const CollectionSessionRecordCounts(),
);

Future<void> _pump(
  WidgetTester tester, {
  required _FakeActions actions,
  required Set<String> permissions,
  int viewerUserId = 9,
  int ownerUserId = 42,
  String rawState = 'closing_control',
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        capabilitySnapshotProvider.overrideWithValue(_capabilities(permissions)),
        authInitialStateProvider.overrideWithValue(
          AuthViewState(profile: _profile(userId: viewerUserId)),
        ),
        scopeCollectionSessionSupervisionActionsProvider.overrideWithValue(
          CollectionSessionSupervisionPort(actions),
        ),
      ],
      child: FluentApp(
        theme: OrbiFluentTheme.light,
        home: CollectionSupervisedSessionScreen(
          sessionId: 11,
          view: _view(ownerUserId: ownerUserId, rawState: rawState),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CollectionSupervisedSessionScreen — cierre por estado', () {
    testWidgets(
      'closing_control: el supervisor ve "Validar cierre" como cierre y '
      '"Cerrar turno" como acción de turno, sin duplicarse',
      (tester) async {
        await _pump(
          tester,
          actions: _FakeActions(),
          permissions: const {'cashier', 'collection_supervisor'},
          rawState: 'closing_control',
        );

        expect(find.text('Validar cierre'), findsOneWidget);
        expect(find.text('Cerrar turno'), findsOneWidget);
      },
    );

    testWidgets(
      'closed: el supervisor sólo ve "Reabrir para corregir"',
      (tester) async {
        await _pump(
          tester,
          actions: _FakeActions(),
          permissions: const {'cashier', 'collection_supervisor'},
          rawState: 'closed',
        );

        expect(find.text('Reabrir para corregir'), findsOneWidget);
        expect(find.text('Validar cierre'), findsNothing);
        expect(find.text('Cerrar turno'), findsNothing);
      },
    );

    testWidgets(
      'un cajero SIN collection_supervisor ajeno al turno no ve ninguna acción',
      (tester) async {
        await _pump(
          tester,
          actions: _FakeActions(),
          permissions: const {'cashier'},
          viewerUserId: 9,
          ownerUserId: 42,
          rawState: 'closing_control',
        );

        expect(find.text('Validar cierre'), findsNothing);
        expect(find.text('Cerrar turno'), findsNothing);
        expect(find.text('Ningún cierre aplica en el estado actual del turno.'), findsOneWidget);
      },
    );
  });

  group('CollectionSupervisedSessionScreen — confirmar y ejecutar en línea', () {
    testWidgets(
      'confirmar "Validar cierre" llama action_session_validate y refresca',
      (tester) async {
        final actions = _FakeActions();
        await _pump(
          tester,
          actions: actions,
          permissions: const {'cashier', 'collection_supervisor'},
          rawState: 'closing_control',
        );

        await tester.tap(find.text('Validar cierre'));
        await tester.pumpAndSettle();
        expect(find.byType(ContentDialog), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(ContentDialog),
            matching: find.text('Confirmar'),
          ),
        );
        await tester.pumpAndSettle();

        expect(actions.calls.map((c) => c.method), contains('action_session_validate'));
        // El diálogo se cerró y no quedó un error en pantalla.
        expect(find.text('No se pudo completar'), findsNothing);
      },
    );

    testWidgets('cancelar el diálogo nunca llama al servidor', (tester) async {
      final actions = _FakeActions();
      await _pump(
        tester,
        actions: actions,
        permissions: const {'cashier', 'collection_supervisor'},
        rawState: 'closing_control',
      );

      await tester.tap(find.text('Validar cierre'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ContentDialog),
          matching: find.text('Cancelar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(actions.calls, isEmpty);
    });

    testWidgets(
      'el rechazo del servidor se muestra tal cual, sin inventar texto',
      (tester) async {
        final actions = _FakeActions()
          ..onCall = (_) => OdooValidationException(
            'No puedes cerrar la sesión: no se ha registrado el depósito '
            'del dinero cobrado (86,00).',
          );
        await _pump(
          tester,
          actions: actions,
          permissions: const {'cashier', 'collection_supervisor'},
          rawState: 'closing_control',
        );

        await tester.tap(find.text('Validar cierre'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(ContentDialog),
            matching: find.text('Confirmar'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No se pudo completar'), findsOneWidget);
        expect(
          find.textContaining('no se ha registrado el depósito'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'sin conexión (puerto nulo), se niega y NUNCA se intenta la llamada',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              capabilitySnapshotProvider.overrideWithValue(
                _capabilities(const {'cashier', 'collection_supervisor'}),
              ),
              authInitialStateProvider.overrideWithValue(
                AuthViewState(profile: _profile(userId: 9)),
              ),
              scopeCollectionSessionSupervisionActionsProvider.overrideWithValue(
                null,
              ),
            ],
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: CollectionSupervisedSessionScreen(
                sessionId: 11,
                view: _view(ownerUserId: 42, rawState: 'closing_control'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Validar cierre'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(ContentDialog),
            matching: find.text('Confirmar'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Sin conexión'), findsOneWidget);
      },
    );
  });
}
