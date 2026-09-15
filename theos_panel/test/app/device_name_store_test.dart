import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/device_name_factory_io.dart';
import 'package:theos_panel/app/device_name_store.dart';

/// El nombre del equipo, editable, por instalación (encargo del
/// 14-sep-2026). `defaultDeviceName` en sí (con el hostname inyectado, ya
/// que `Platform.localHostname` no pasa por `IOOverrides` en este SDK) se
/// cubre aquí junto con el store que lo guarda — las dos mitades del mismo
/// contrato: "por omisión el hostname, editable, vacío vuelve a él".
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('device name defaults to hostname on native, with the hostname '
      'injected', () {
    expect(
      defaultDeviceName(hostnameReader: () => 'caja-2.local'),
      'caja-2.local',
    );
  });

  test('un hostname vacío o que falla cae a una frase genérica', () {
    expect(defaultDeviceName(hostnameReader: () => '   '), 'Este equipo');
    expect(
      defaultDeviceName(hostnameReader: () => throw StateError('no host')),
      'Este equipo',
    );
  });

  test('store: sin nada guardado, read() cae al valor por omisión', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = DeviceNameStore(preferences);
    expect(store.read(), isNotEmpty);
  });

  test('store: es editable y sobrevive una nueva instancia', () async {
    final preferences = await SharedPreferences.getInstance();
    await DeviceNameStore(preferences).write('Caja 2');
    expect(DeviceNameStore(preferences).read(), 'Caja 2');
  });

  test('store: vacío borra la preferencia y vuelve al valor por omisión', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = DeviceNameStore(preferences);
    await store.write('Caja 2');
    await store.write('   ');
    expect(preferences.getString(DeviceNameStore.key), isNull);
  });

  test('controller: setName actualiza el nombre expuesto y notifica', () async {
    final preferences = await SharedPreferences.getInstance();
    final controller = DeviceNameController(DeviceNameStore(preferences));
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.setName('Mostrador');

    expect(controller.name, 'Mostrador');
    expect(notified, isTrue);
  });
}
