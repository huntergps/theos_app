import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/auth/saved_servers.dart';
import 'package:theos_panel/features/auth/server_manager_dialog.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Never reaches the network: every test must inject one of these instead of
/// the real [OdooServerDatabaseDiscovery], which would otherwise hit a real
/// socket the moment a valid URL is typed.
///
/// [servedDatabaseScript] defaults to "no single database" (`null`), which
/// falls straight through to [listDatabases] — the behaviour every existing
/// test already expected before `servedDatabase` existed.
class _ScriptedDiscovery implements ServerDatabaseDiscovery {
  _ScriptedDiscovery(
    this._script, {
    Future<String?> Function(String)? servedDatabaseScript,
  }) : _servedDatabaseScript = servedDatabaseScript ?? ((_) async => null);
  final Future<List<String>> Function(String baseUrl) _script;
  final Future<String?> Function(String baseUrl) _servedDatabaseScript;
  final calls = <String>[];
  final servedDatabaseCalls = <String>[];

  @override
  Future<List<String>> listDatabases(String baseUrl) {
    calls.add(baseUrl);
    return _script(baseUrl);
  }

  @override
  Future<String?> servedDatabase(String baseUrl) {
    servedDatabaseCalls.add(baseUrl);
    return _servedDatabaseScript(baseUrl);
  }
}

/// The default for tests that don't care about discovery: behaves like a
/// server nobody can reach from this platform, same shape as a real
/// unsupported-platform outcome, and resolves fast so no test hangs on it.
class _UnavailableDiscovery implements ServerDatabaseDiscovery {
  const _UnavailableDiscovery();

  @override
  Future<List<String>> listDatabases(String baseUrl) async =>
      throw const DatabaseDiscoveryException(
        DatabaseDiscoveryFailureKind.unsupportedPlatform,
      );

  @override
  Future<String?> servedDatabase(String baseUrl) async => null;
}

void main() {
  late SavedServersStore store;
  SavedServer? selected;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SavedServersStore(await SharedPreferences.getInstance());
  });

  Future<void> open(
    WidgetTester tester, {
    double width = 1000,
    double height = 760,
    ServerDatabaseDiscovery discovery = const _UnavailableDiscovery(),
  }) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FluentApp(
        theme: OrbiFluentTheme.light,
        home: ScaffoldPage(
          content: Builder(
            builder: (context) => HyperlinkButton(
              onPressed: () async {
                selected = await showSavedServerManager(
                  context,
                  store: store,
                  discovery: discovery,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('creates, filters and selects a saved server', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('server_name')), 'Demo');
    await tester.enterText(
      find.byKey(const ValueKey('server_url')),
      'https://demo.example.com',
    );
    // Flush the debounced database lookup so its Timer never lingers past
    // this test; the default discovery just says "unavailable" and the
    // manual field (already the one shown) is unaffected.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('server_database')),
      'demo',
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('save_server')));
    });
    await tester.pumpAndSettle();
    expect(store.load().single.name, 'Demo');
    await tester.enterText(
      find.byKey(const ValueKey('server_name')),
      'Demo editado',
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('save_server')));
    });
    await tester.pumpAndSettle();
    expect(store.load().single.name, 'Demo editado');
    await tester.enterText(
      find.byKey(const ValueKey('server_search')),
      'no-existe',
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay coincidencias.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('server_search')), 'demo');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('use_server')));
    await tester.pumpAndSettle();
    expect(selected?.name, 'Demo editado');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(store.load(), hasLength(1));
    await tester.runAsync(() async {
      await tester.tap(find.text('Eliminar'));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(store.load(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  // ==========================================================================
  // El gestor en ancho compacto (orden del dueño, 12-sep-2026, visto en su
  // iPhone): ya no es un `ContentDialog` casi a pantalla completa — es una
  // página de dos pasos («Servidores Odoo» con la lista, y el editor en su
  // propia página), como cualquier otra pantalla de Orbi.
  // ==========================================================================
  group('en ancho compacto el gestor es una página, no un diálogo', () {
    testWidgets('renders legibly in compact and phone viewports', (
      tester,
    ) async {
      await open(tester, width: 560, height: 760);
      // Paso 1: la lista, sin ningún ContentDialog de por medio.
      expect(find.byType(ContentDialog), findsNothing);
      expect(find.text('Servidores Odoo'), findsOneWidget);
      expect(find.text('Nuevo servidor'), findsNothing);
      expect(find.byKey(const ValueKey('server_url')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('new_server')));
      await tester.pumpAndSettle();

      // Paso 2: el editor, en su propia página.
      expect(find.text('Nuevo servidor'), findsOneWidget);
      expect(find.byKey(const ValueKey('server_url')), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(390, 700));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('server_database')), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(390, 400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('save_server')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'tocar «Nuevo servidor» o un acceso guardado abre el editor en su '
      'propia página, con un botón para volver a la lista',
      (tester) async {
        await tester.runAsync(
          () => store.upsert(
            SavedServer(
              id: '1',
              name: 'Existente',
              url: 'https://existente.example.com',
              database: 'existente',
            ),
          ),
        );
        await open(tester, width: 390, height: 760);

        expect(find.text('Servidores Odoo'), findsOneWidget);
        expect(find.text('Existente'), findsOneWidget);
        // En el Paso 1 no hay botón de "Atrás", sólo el de cerrar el gestor.
        expect(
          find.byKey(const ValueKey('server_manager_back_to_list')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('server_manager_close')),
          findsOneWidget,
        );

        await tester.tap(find.text('Existente'));
        await tester.pumpAndSettle();

        expect(find.text('Editar servidor'), findsOneWidget);
        expect(
          tester
              .widget<TextBox>(find.byKey(const ValueKey('server_name')))
              .controller!
              .text,
          'Existente',
        );
        // En el Paso 2 el botón es "Atrás", no el de cerrar el gestor entero.
        expect(
          find.byKey(const ValueKey('server_manager_back_to_list')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('server_manager_close')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey('server_manager_back_to_list')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Servidores Odoo'), findsOneWidget);
        expect(find.text('Existente'), findsOneWidget);
      },
    );

    testWidgets(
      'volver a la lista con cambios sin guardar pide confirmación, igual '
      'que cerrar',
      (tester) async {
        await open(tester, width: 390, height: 760);
        await tester.tap(find.byKey(const ValueKey('new_server')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('server_name')),
          'Borrador',
        );

        await tester.tap(
          find.byKey(const ValueKey('server_manager_back_to_list')),
        );
        await tester.pumpAndSettle();

        expect(find.text('¿Descartar cambios?'), findsOneWidget);
        // "Seguir editando" deja el borrador intacto, en el editor.
        await tester.tap(find.text('Seguir editando'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextBox>(find.byKey(const ValueKey('server_name')))
              .controller!
              .text,
          'Borrador',
        );

        await tester.tap(
          find.byKey(const ValueKey('server_manager_back_to_list')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Descartar'));
        await tester.pumpAndSettle();

        expect(find.text('Servidores Odoo'), findsOneWidget);
      },
    );

    testWidgets(
      'cerrar el gestor desde la lista funciona igual que en el diálogo '
      'ancho',
      (tester) async {
        await open(tester, width: 390, height: 760);
        await tester.tap(find.byKey(const ValueKey('server_manager_close')));
        await tester.pumpAndSettle();
        expect(find.text('Servidores Odoo'), findsNothing);
        expect(selected, isNull);
      },
    );
  });

  // ==========================================================================
  // La sospecha de causa (equipo, 12-sep-2026): un `ContentDialog` que
  // restaba `viewInsets` de su `constraints.maxHeight` cambiaba de altura en
  // cuanto el teclado EMPEZABA a abrir, lo que hacía saltar de rama a
  // `_compactLayout` (de fila con Expanded a SingleChildScrollView con altura
  // fija) — un árbol de widgets distinto bajo el mismo `TextBox`, así que su
  // `EditableText` se desmontaba y el navegador cerraba el teclado solo.
  // Confirmado en rojo contra 7b8a7a2: estas dos pruebas fallaban con el foco
  // perdido apenas `viewInsets` cambiaba. Con la página nueva
  // (`ScaffoldPage.resizeToAvoidBottomInset`, sin recalcular `maxHeight` a
  // mano) el árbol no cambia de forma y el foco se conserva.
  // ==========================================================================
  group('el teclado no le hace perder el foco a los campos', () {
    testWidgets(
      '"URL de Odoo" conserva el foco y el texto cuando el teclado abre',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(
          FluentApp(
            theme: OrbiFluentTheme.light,
            home: ScaffoldPage(
              content: Builder(
                builder: (context) => HyperlinkButton(
                  onPressed: () => showSavedServerManager(
                    context,
                    store: store,
                    discovery: const _UnavailableDiscovery(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('new_server')));
        await tester.pumpAndSettle();

        final urlField = find.byKey(const ValueKey('server_url'));
        await tester.tap(urlField);
        await tester.enterText(urlField, 'https://foco.example.com');
        await tester.pump();

        final editableTextFinder = find.descendant(
          of: urlField,
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(editableTextFinder).focusNode.hasFocus,
          isTrue,
          reason: 'El campo URL debe tener el foco antes de abrir el teclado.',
        );

        // El teclado abre DESPUÉS, como en la app real.
        tester.view.viewInsets = const FakeViewPadding(bottom: 336);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          tester.widget<TextBox>(urlField).controller!.text,
          'https://foco.example.com',
          reason: 'El texto no debe perderse cuando el teclado abre.',
        );
        expect(
          tester.widget<EditableText>(editableTextFinder).focusNode.hasFocus,
          isTrue,
          reason:
              'El campo URL debe SEGUIR con el foco cuando el teclado abre.',
        );
      },
    );

    testWidgets(
      '"Nombre del servidor" y "Base de datos" conservan el foco cuando el '
      'teclado abre',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(
          FluentApp(
            theme: OrbiFluentTheme.light,
            home: ScaffoldPage(
              content: Builder(
                builder: (context) => HyperlinkButton(
                  onPressed: () => showSavedServerManager(
                    context,
                    store: store,
                    discovery: const _UnavailableDiscovery(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('new_server')));
        await tester.pumpAndSettle();

        for (final key in ['server_name', 'server_database']) {
          final field = find.byKey(ValueKey(key));
          await tester.tap(field);
          await tester.enterText(field, 'valor-$key');
          await tester.pump();

          final editableTextFinder = find.descendant(
            of: field,
            matching: find.byType(EditableText),
          );
          expect(
            tester.widget<EditableText>(editableTextFinder).focusNode.hasFocus,
            isTrue,
            reason: '$key debe tener el foco antes de abrir el teclado.',
          );

          tester.view.viewInsets = const FakeViewPadding(bottom: 336);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(
            tester.widget<EditableText>(editableTextFinder).focusNode.hasFocus,
            isTrue,
            reason: '$key debe SEGUIR con el foco cuando el teclado abre.',
          );

          tester.view.resetViewInsets();
          await tester.pump();
        }
      },
    );
  });

  testWidgets('closing an edited connection asks before discarding', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('server_name')),
      'Borrador',
    );
    await tester.tap(find.byKey(const ValueKey('server_manager_close')));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextBox>(find.byKey(const ValueKey('server_name')))
          .controller!
          .text,
      'Borrador',
    );
    expect(store.load(), isEmpty);
  });

  testWidgets('shows corrupt storage error without resetting it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({SavedServersStore.key: '{broken'});
    store = SavedServersStore(
      (await tester.runAsync(() => SharedPreferences.getInstance()))!,
    );
    await open(tester);
    expect(find.textContaining('No se pudieron leer'), findsOneWidget);
  });

  testWidgets('a single discovered database is selected automatically', (
    tester,
  ) async {
    final discovery = _ScriptedDiscovery((_) async => ['unica_bd']);
    await open(tester, discovery: discovery);
    await tester.enterText(
      find.byKey(const ValueKey('server_url')),
      'https://uno.example.com',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(discovery.calls, ['https://uno.example.com']);
    expect(
      tester
          .widget<TextBox>(find.byKey(const ValueKey('server_database')))
          .controller!
          .text,
      'unica_bd',
    );
    expect(
      find.text('Se detectó una sola base de datos y fue seleccionada.'),
      findsOneWidget,
    );
  });

  testWidgets('multiple discovered databases show a dropdown to choose from', (
    tester,
  ) async {
    final discovery = _ScriptedDiscovery((_) async => ['db_uno', 'db_dos']);
    await open(tester, discovery: discovery);
    await tester.enterText(
      find.byKey(const ValueKey('server_name')),
      'Con lista',
    );
    await tester.enterText(
      find.byKey(const ValueKey('server_url')),
      'https://dos.example.com',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('server_database_dropdown')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('server_database')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('server_database_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('db_dos').last);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('save_server')));
    });
    await tester.pumpAndSettle();

    expect(store.load().single.database, 'db_dos');
  });

  testWidgets('the manual entry link recovers free text under a dropdown', (
    tester,
  ) async {
    final discovery = _ScriptedDiscovery((_) async => ['a', 'b']);
    await open(tester, discovery: discovery);
    await tester.enterText(
      find.byKey(const ValueKey('server_url')),
      'https://tres.example.com',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('server_database_dropdown')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('database_manual_entry')));
    await tester.pump();
    // Fluent's Button (HoverButton) schedules a 100ms Timer on tap-up to
    // reset its own pressed visual state; flush it so the test does not end
    // with a pending Timer.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('server_database')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('server_database_dropdown')),
      findsNothing,
    );
  });

  testWidgets(
    'when the server refuses to list databases, typing the name by hand '
    'still saves the server',
    (tester) async {
      final discovery = _ScriptedDiscovery(
        (_) async => throw const DatabaseDiscoveryException(
          DatabaseDiscoveryFailureKind.disabled,
        ),
      );
      await open(tester, discovery: discovery);
      await tester.enterText(
        find.byKey(const ValueKey('server_name')),
        'Manual',
      );
      await tester.enterText(
        find.byKey(const ValueKey('server_url')),
        'https://cuatro.example.com',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // The reason is explained, and the ordinary text field is still there
      // — this is the required fallback, never a dead end.
      expect(
        find.byKey(const ValueKey('database_discovery_notice')),
        findsOneWidget,
      );
      expect(find.textContaining('deshabilitado el listado'), findsOneWidget);
      expect(find.byKey(const ValueKey('server_database')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('server_database')),
        'a_mano',
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('save_server')));
      });
      await tester.pumpAndSettle();

      expect(store.load().single.database, 'a_mano');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid edits cancel the previous pending lookup', (tester) async {
    final discovery = _ScriptedDiscovery((_) async => ['db']);
    await open(tester, discovery: discovery);
    final field = find.byKey(const ValueKey('server_url'));

    await tester.enterText(field, 'https://a.example.com');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(field, 'https://b.example.com');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(discovery.calls, ['https://b.example.com']);
  });

  // ==========================================================================
  // Ruta nueva `/orbi/database` (orden del dueño, 12-sep-2026): un servidor
  // público con `list_db = False` niega el listado a propósito, sin cabecera
  // de origen cruzado — el navegador lo oculta y la app creía que no había
  // red. Caso medido con mepriga.galapagos.tech.
  // ==========================================================================
  group('la base que atiende el dominio (`/orbi/database`)', () {
    testWidgets(
      'un servidor que niega el listado pero atiende una sola base rellena '
      'el campo, sin mostrar el aviso de fallo de conexión',
      (tester) async {
        final discovery = _ScriptedDiscovery(
          (_) async => throw const DatabaseDiscoveryException(
            DatabaseDiscoveryFailureKind.connection,
          ),
          servedDatabaseScript: (_) async => 'envases',
        );
        await open(tester, discovery: discovery);
        await tester.enterText(
          find.byKey(const ValueKey('server_url')),
          'https://mepriga.galapagos.tech',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        expect(
          tester
              .widget<TextBox>(find.byKey(const ValueKey('server_database')))
              .controller!
              .text,
          'envases',
        );
        expect(find.textContaining('No se pudo conectar'), findsNothing);
        expect(
          find.textContaining('atiende la base «envases»'),
          findsOneWidget,
        );
        // La caída a listDatabases nunca ocurre: servedDatabase ya resolvió.
        expect(discovery.calls, isEmpty);
      },
    );

    testWidgets(
      'cuando el dominio no atiende una sola base, se cae a listDatabases '
      'como antes',
      (tester) async {
        final discovery = _ScriptedDiscovery((_) async => ['unica_bd']);
        await open(tester, discovery: discovery);
        await tester.enterText(
          find.byKey(const ValueKey('server_url')),
          'https://seis.example.com',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();

        expect(discovery.servedDatabaseCalls, ['https://seis.example.com']);
        expect(discovery.calls, ['https://seis.example.com']);
        expect(
          tester
              .widget<TextBox>(find.byKey(const ValueKey('server_database')))
              .controller!
              .text,
          'unica_bd',
        );
      },
    );

    testWidgets('el botón "Listar bases" relanza el descubrimiento', (
      tester,
    ) async {
      final discovery = _ScriptedDiscovery((_) async => ['unica_bd']);
      await open(tester, discovery: discovery);
      await tester.enterText(
        find.byKey(const ValueKey('server_url')),
        'https://siete.example.com',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(discovery.calls, ['https://siete.example.com']);

      await tester.tap(
        find.byKey(const ValueKey('server_manager_list_databases')),
      );
      await tester.pump();
      await tester.pump();
      // Fluent's Button (HoverButton) schedules a 100ms Timer on tap-up to
      // reset its own pressed visual state; flush it so the test does not
      // end with a pending Timer.
      await tester.pump(const Duration(milliseconds: 100));

      expect(discovery.calls, [
        'https://siete.example.com',
        'https://siete.example.com',
      ]);
    });

    testWidgets(
      'el botón "Listar bases" está deshabilitado con una URL inválida',
      (tester) async {
        await open(tester);
        expect(
          tester
              .widget<Button>(
                find.byKey(const ValueKey('server_manager_list_databases')),
              )
              .onPressed,
          isNull,
        );
      },
    );
  });

  // Orden del dueño, 12-sep-2026: «todo está ya determinado por fluent_ui» —
  // el gestor deja de ser un `Card` propio dentro de `showDialog` y pasa a
  // ser el `ContentDialog` de Fluent, cuya superficie ya sale opaca del
  // tema (`ContentDialogThemeData.decoration.color = theme.menuColor`).
  group('el gestor es un ContentDialog con superficie opaca', () {
    for (final entry in {
      'claro': OrbiFluentTheme.light,
      'oscuro': OrbiFluentTheme.dark,
    }.entries) {
      testWidgets('en modo ${entry.key}', (tester) async {
        await tester.pumpWidget(
          FluentApp(
            theme: entry.value,
            home: ScaffoldPage(
              content: Builder(
                builder: (context) => HyperlinkButton(
                  onPressed: () => showSavedServerManager(
                    context,
                    store: store,
                    discovery: const _UnavailableDiscovery(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(ContentDialog), findsOneWidget);
        // Ya no hay un Card propio envolviendo el gestor entero.
        expect(find.byType(Card), findsNothing);

        // La superficie del propio ContentDialog: el primer Container
        // descendiente es el que trae `decoration` desde
        // ContentDialogThemeData — la prueba que habría cazado el defecto
        // de transparencia original.
        final container = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(ContentDialog),
                matching: find.byType(Container),
              ),
            )
            .first;
        final color = (container.decoration as BoxDecoration?)?.color;
        expect(
          color,
          isNotNull,
          reason: 'El ContentDialog debe traer color de fondo.',
        );
        expect(
          color!.a,
          1.0,
          reason: 'La superficie del diálogo no debe ser transparente.',
        );
      });
    }
  });

  testWidgets(
    'con el teclado abierto a 390x700, "Servidores Odoo" queda dentro de '
    'pantalla',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        FluentApp(
          theme: OrbiFluentTheme.light,
          home: ScaffoldPage(
            content: Builder(
              builder: (context) => HyperlinkButton(
                onPressed: () => showSavedServerManager(
                  context,
                  store: store,
                  discovery: const _UnavailableDiscovery(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // El teclado abre DESPUÉS del diálogo, como en la app real.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Servidores Odoo')).dy,
        greaterThanOrEqualTo(0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  // ==========================================================================
  // El formulario estándar (orden del dueño, 12-sep-2026): estos casos no
  // comprueban que el widget exista, sino lo que la persona ve — la etiqueta
  // de un campo concreto, que lo obligatorio se marque ANTES de escribir, y
  // que un error de validación caiga pegado a su propio campo y no en un
  // aviso genérico compartido por los tres.
  // ==========================================================================
  group('el editor usa el formulario estándar (OrbiField/OrbiForm)', () {
    testWidgets(
      'las tres etiquetas se ven, y lo obligatorio se marca antes de escribir',
      (tester) async {
        await open(tester);
        for (final label in [
          'Nombre del servidor',
          'URL de Odoo',
          'Base de datos',
        ]) {
          expect(
            find.text(label),
            findsOneWidget,
            reason: 'Falta la etiqueta "$label" del formulario estándar.',
          );
        }
        // El asterisco de obligatorio, uno por cada uno de los tres campos —
        // y anunciado para lectores de pantalla, no sólo pintado.
        expect(find.text('*'), findsNWidgets(3));
        expect(find.bySemanticsLabel('obligatorio'), findsNWidgets(3));
      },
    );

    testWidgets(
      'guardar con el nombre vacío deja el error pegado a "Nombre del '
      'servidor", no en un aviso genérico',
      (tester) async {
        await open(tester);
        await tester.tap(find.byKey(const ValueKey('save_server')));
        await tester.pump();
        // Fluent's Button (HoverButton) schedules a 100ms Timer on tap-up to
        // reset its own pressed visual state; flush it so the test does not
        // end with a pending Timer.
        await tester.pump(const Duration(milliseconds: 100));

        const message = 'Escribe un nombre para identificar el servidor.';
        expect(find.text(message), findsOneWidget);
        expect(
          tester.getCenter(find.text(message)).dy,
          greaterThan(tester.getCenter(find.text('Nombre del servidor')).dy),
          reason: 'El error debe quedar debajo de la etiqueta de su campo.',
        );
        // Y no bajo la etiqueta de otro campo: nada de un aviso a mitad de
        // camino entre los tres que obligue a adivinar cuál falló.
        expect(
          tester.getCenter(find.text(message)).dy,
          lessThan(tester.getCenter(find.text('URL de Odoo')).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'guardar con una URL inválida deja el error pegado a "URL de Odoo"',
      (tester) async {
        await open(tester);
        await tester.enterText(
          find.byKey(const ValueKey('server_name')),
          'Con nombre',
        );
        await tester.enterText(
          find.byKey(const ValueKey('server_url')),
          'no-es-una-url',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('save_server')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        const message = 'La URL debe ser absoluta y usar HTTP o HTTPS';
        expect(find.text(message), findsOneWidget);
        expect(
          tester.getCenter(find.text(message)).dy,
          greaterThan(tester.getCenter(find.text('URL de Odoo')).dy),
        );
        expect(
          find.text('Escribe un nombre para identificar el servidor.'),
          findsNothing,
          reason: 'El campo "Nombre" ya es válido; no debe mostrar error.',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'guardar con la base de datos vacía deja el error pegado a "Base de '
      'datos"',
      (tester) async {
        await open(tester);
        await tester.enterText(
          find.byKey(const ValueKey('server_name')),
          'Con nombre',
        );
        await tester.enterText(
          find.byKey(const ValueKey('server_url')),
          'https://valido.example.com',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('save_server')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        const message = 'Escribe el nombre de la base de datos.';
        expect(find.text(message), findsOneWidget);
        expect(
          tester.getCenter(find.text(message)).dy,
          greaterThan(tester.getCenter(find.text('Base de datos')).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'corregir el campo y volver a guardar hace desaparecer su error',
      (tester) async {
        await open(tester);
        await tester.tap(find.byKey(const ValueKey('save_server')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('Escribe un nombre para identificar el servidor.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('server_name')),
          'Ya con nombre',
        );
        await tester.tap(find.byKey(const ValueKey('save_server')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('Escribe un nombre para identificar el servidor.'),
          findsNothing,
        );
      },
    );
  });
}
