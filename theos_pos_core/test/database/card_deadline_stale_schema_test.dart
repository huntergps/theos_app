import 'dart:io';

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  test(
    // 🔴 Regresión (12-sep-2026, medida contra ERP2 en el navegador):
    // `SqliteException: no such column: months` al leer «Plazos de
    // tarjeta». La rama de migración `from < 15` (que renombra
    // deadline_days/percentage a months/kind/has_interest) sólo corre
    // cuando `from` es MENOR que 15. Una base que ya hubiera quedado
    // marcada en `user_version = 15` — por ejemplo, el IndexedDB de una
    // pestaña que no se limpia entre reinicios, de una prueba anterior con
    // el esquema a medio terminar — nunca vuelve a pasar por esa rama,
    // porque para Drift esa base ya está "al día" en 15. Simula esa base
    // exacta (stampeada en 15, con las columnas VIEJAS) y comprueba que
    // reabrirla la repara en vez de dejarla rota para siempre.
    'a database already stamped at v15 with the OLD card-deadline columns '
    'gets repaired on reopen, not left broken forever',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'card-deadline-stale-',
      );
      final file = File('${directory.path}/cache.sqlite');
      addTearDown(() => directory.delete(recursive: true));

      // Arranca desde una base fresca en el esquema VIGENTE, para heredar
      // el resto de tablas tal cual, y sólo después se degrada a mano la
      // tabla de plazos de tarjeta a como habría quedado en v15 con las
      // columnas viejas.
      var db = AppDatabase(NativeDatabase(file));
      await db.customSelect('SELECT 1').getSingle();
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
        'DROP TABLE account_credit_card_deadline',
      );
      await db.customStatement('''
        CREATE TABLE account_credit_card_deadline (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          odoo_id INTEGER NOT NULL UNIQUE,
          name TEXT NOT NULL,
          deadline_days INTEGER NOT NULL,
          percentage REAL NOT NULL DEFAULT 0.0,
          active INTEGER NOT NULL DEFAULT 1,
          write_date INTEGER NULL
        )
      ''');
      await db.customStatement('PRAGMA user_version = 15');
      await db.close();

      // Reabrir es exactamente lo que hace la app al reiniciar. Contra el
      // esquema vigente (16), Drift ve `from=15 < 16` y sí vuelve a pasar
      // por el paso que recrea la tabla — la stale-v15 queda reparada.
      db = AppDatabase(NativeDatabase(file));
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), db.schemaVersion);

      final columns = await db
          .customSelect('PRAGMA table_info(account_credit_card_deadline)')
          .get();
      final columnNames = columns.map((row) => row.read<String>('name'));
      expect(columnNames, contains('months'));
      expect(columnNames, contains('kind'));
      expect(columnNames, contains('has_interest'));
      expect(columnNames, isNot(contains('deadline_days')));
      expect(columnNames, isNot(contains('percentage')));

      // Y no sólo la estructura: el catálogo real vuelve a poder llenarse.
      await PaymentConfigRecordMapper.upsertCardDeadline(db, {
        'id': 99,
        'name': '3 meses',
        'meses': 3,
        'type': 'deferred',
        'interes': true,
      });
      final plazo = (await PaymentConfigRecordMapper.readCardDeadlines(
        db,
      )).single;
      expect(plazo['meses'], 3);

      await db.close();
    },
  );
}
