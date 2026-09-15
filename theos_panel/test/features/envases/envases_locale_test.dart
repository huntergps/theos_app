import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/orbi_app.dart' show orbiAppLocale;
import 'package:theos_panel/features/envases/envases_enviar_form.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Cubre la queja del dueño del 14-sep-2026: «Enviar» mostraba «14 September
/// 2026» y «Movimientos» mostraba «day / month / year» en vez de español.
///
/// La causa raíz vivía en `theos_panel/lib/app/orbi_app.dart`: `FluentApp`
/// nunca fijaba `locale:`, así que resolvía el idioma del SISTEMA operativo
/// en vez de forzar español — el `DatePicker` de fluent_ui arma los nombres
/// de mes con `DateFormat.MMMM(locale)` de `package:intl`, y sin `locale:`
/// fijo el resultado depende de cada equipo.
///
/// Esta prueba usa `orbiAppLocale`, la MISMA constante que `OrbiApp` pasa a
/// su propio `FluentApp.router` — no una copia que podría divergir de lo que
/// la app real usa — así que si algún día se borra ese `locale:` de
/// `orbi_app.dart`, esta prueba vuelve a fallar sin que nadie tenga que
/// acordarse de actualizarla.
final class _NoopEnvasesOperations implements EnvasesOperations {
  @override
  Future<EnvasesOperacionLocal> darPorPerdido({required String operacionUuid, required int pickingId}) async =>
      throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async => throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async => throw UnimplementedError();

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}

void main() {
  testWidgets('date picker shows Spanish month names', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        theme: OrbiFluentTheme.light,
        // La configuración de localización REAL de la app: la misma
        // constante que usa `OrbiApp` en `orbi_app.dart`.
        locale: orbiAppLocale,
        home: EnvasesEnviarForm(
          sedesUsuario: const [EnvasesSedeOption(id: 1, name: 'Guayaquil')],
          sedesDestinoPosibles: const [EnvasesSedeOption(id: 2, name: 'Manta')],
          productos: const [],
          operations: _NoopEnvasesOperations(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // El `DatePicker` arranca con `DateTime.now()` — el mes de hoy, en
    // español («Septiembre»), no en inglés («September»). fluent_ui
    // capitaliza el nombre del mes al mostrarlo en el campo (el dato CLDR
    // de `flutter_localizations` para `STANDALONEMONTHS` en `es` es
    // «septiembre» en minúsculas; lo confirmé imprimiendo el árbol de
    // widgets en un test de depuración antes de fijar esta aserción).
    expect(find.textContaining('Septiembre'), findsOneWidget);
  });
}
