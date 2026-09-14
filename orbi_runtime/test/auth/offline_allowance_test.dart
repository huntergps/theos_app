import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Límite de sesión sin conexión (decisión del dueño, 14-sep-2026): máximo
/// 3 días sin hablar con Odoo, parametrizable por servidor. Estas pruebas
/// cubren [OfflineAllowanceStore] en aislamiento — `native_auth_service_test.dart`
/// cubre cómo `NativeAuthService.restore(offline: true)` lo usa de verdad.
void main() {
  const serverUrl = 'https://erp.test';
  const database = 'db';
  const userId = 7;

  Future<(OfflineAllowanceStore, SharedPreferences)> store() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return (OfflineAllowanceStore(prefs), prefs);
  }

  test(
    'a credential never seen before is allowed — the migration case, and it '
    'registers "now" as the starting point',
    () async {
      final (s, prefs) = await store();
      final now = DateTime.utc(2026, 9, 14, 12);

      final allowance = await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        deviceNowUtc: now,
      );

      expect(allowance.isAllowed, isTrue);

      // Y quedó registrado — un día después, dentro del plazo, sigue
      // `allowed` sin volver a tratarlo como "nunca visto".
      final nextDay = await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        deviceNowUtc: now.add(const Duration(days: 1)),
      );
      expect(nextDay.isAllowed, isTrue);
      expect(prefs.getKeys(), isNotEmpty);
    },
  );

  test('allowed within the default 3-day limit', () async {
    final (s, _) = await store();
    final now = DateTime.utc(2026, 9, 14, 12);
    await s.recordOnline(
      serverUrl: serverUrl,
      database: database,
      userId: userId,
      nowUtc: now,
    );

    final allowance = await s.evaluate(
      serverUrl: serverUrl,
      database: database,
      userId: userId,
      deviceNowUtc: now.add(const Duration(days: 2)),
    );

    expect(allowance.status, OfflineAllowanceStatus.allowed);
  });

  test('expired past the default 3-day limit, with the day count', () async {
    final (s, _) = await store();
    final now = DateTime.utc(2026, 9, 14, 12);
    await s.recordOnline(
      serverUrl: serverUrl,
      database: database,
      userId: userId,
      nowUtc: now,
    );

    final allowance = await s.evaluate(
      serverUrl: serverUrl,
      database: database,
      userId: userId,
      deviceNowUtc: now.add(const Duration(days: 4)),
    );

    expect(allowance.status, OfflineAllowanceStatus.expired);
    expect(allowance.daysOffline, 4);
    expect(allowance.maxDays, kDefaultOfflineAllowanceDays);
  });

  test(
    'a clock more than 5 minutes behind the last seen device time is a '
    'rollback, never read as "expired"',
    () async {
      final (s, _) = await store();
      final now = DateTime.utc(2026, 9, 14, 12);
      await s.recordOnline(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        nowUtc: now,
      );
      // Una evaluación "allowed" adelanta lastSeenDeviceUtc.
      await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        deviceNowUtc: now.add(const Duration(hours: 1)),
      );

      final rollback = await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        // Más de 5 minutos por detrás de la última hora vista.
        deviceNowUtc: now.add(const Duration(hours: 1)).subtract(
          const Duration(minutes: 10),
        ),
      );

      expect(rollback.status, OfflineAllowanceStatus.clockRollback);
    },
  );

  test(
    'a clock within 5 minutes behind is tolerated — never a false rollback',
    () async {
      final (s, _) = await store();
      final now = DateTime.utc(2026, 9, 14, 12);
      await s.recordOnline(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        nowUtc: now,
      );

      final allowance = await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        deviceNowUtc: now.subtract(const Duration(minutes: 2)),
      );

      expect(allowance.status, OfflineAllowanceStatus.allowed);
    },
  );

  test(
    'server-synced max days overrides the default, and counts as a good '
    'connection too',
    () async {
      final (s, _) = await store();
      final now = DateTime.utc(2026, 9, 14, 12);
      await s.recordServerSync(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        offlineMaxDays: 7,
        nowUtc: now,
      );

      // A los 5 días sigue `allowed` porque el máximo real es 7, no el 3
      // por omisión.
      final allowance = await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        deviceNowUtc: now.add(const Duration(days: 5)),
      );

      expect(allowance.status, OfflineAllowanceStatus.allowed);
      expect(allowance.maxDays, 7);

      // Y a los 8 sí vence, con el máximo de 7 (no el de 3).
      final expired = await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        deviceNowUtc: now.add(const Duration(days: 8)),
      );
      expect(expired.status, OfflineAllowanceStatus.expired);
      expect(expired.maxDays, 7);
    },
  );

  test(
    'credentials are isolated by server + database + user — one being '
    'expired never affects another',
    () async {
      final (s, _) = await store();
      final now = DateTime.utc(2026, 9, 14, 12);
      await s.recordOnline(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        nowUtc: now.subtract(const Duration(days: 10)),
      );
      await s.recordOnline(
        serverUrl: serverUrl,
        database: database,
        userId: 8,
        nowUtc: now,
      );

      final expired = await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
        deviceNowUtc: now,
      );
      final allowed = await s.evaluate(
        serverUrl: serverUrl,
        database: database,
        userId: 8,
        deviceNowUtc: now,
      );

      expect(expired.status, OfflineAllowanceStatus.expired);
      expect(allowed.status, OfflineAllowanceStatus.allowed);
    },
  );
}
