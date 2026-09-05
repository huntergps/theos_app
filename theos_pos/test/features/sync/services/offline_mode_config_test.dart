import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_pos/features/sync/services/offline_mode_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late OfflineModeService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = OfflineModeService(db: database);
  });

  tearDown(() => database.close());

  test('missing preference defaults to online-capable mode', () async {
    SharedPreferences.setMockInitialValues({});

    final config = await service.loadConfig();

    expect(config.isEnabled, isFalse);
  });

  test(
    'corrupt preference fails closed instead of returning disabled',
    () async {
      SharedPreferences.setMockInitialValues({
        'offline_mode_config': '{not valid json',
      });

      await expectLater(service.loadConfig(), throwsA(isA<FormatException>()));
    },
  );
}
