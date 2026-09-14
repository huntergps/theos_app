import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_form_draft_port.dart';

/// Puerto en memoria cuyo `save` se bloquea hasta que el test complete el
/// `Completer` inyectado — para poder poner un guardado "en vuelo" a
/// voluntad y comprobar que `clear()` de verdad lo espera.
final class _BlockingSavePort implements EnvasesFormDraftPort {
  _BlockingSavePort(this._saveCompleter);

  final Completer<void> _saveCompleter;
  Map<String, dynamic>? stored;
  bool cleared = false;
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>?> read(String draftId) async => stored;

  @override
  Future<void> save(String draftId, Map<String, dynamic> payload) async {
    saveCalls++;
    await _saveCompleter.future;
    stored = payload;
  }

  @override
  Future<void> clear(String draftId) async {
    cleared = true;
    stored = null;
  }
}

/// Puerto en memoria que sólo registra lo que se guardó, sin ninguna demora
/// artificial — para comprobar `dispose()`.
final class _RecordingPort implements EnvasesFormDraftPort {
  final List<Map<String, dynamic>> saves = [];
  final List<String> cleared = [];

  @override
  Future<Map<String, dynamic>?> read(String draftId) async => null;

  @override
  Future<void> save(String draftId, Map<String, dynamic> payload) async {
    saves.add(payload);
  }

  @override
  Future<void> clear(String draftId) async {
    cleared.add(draftId);
  }
}

AppScope _scope() => AppScope(
  appId: 'orbi-panel',
  installationId: 'envases-draft-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: 1,
);

CompanyContext _company(AppScope scope, int id) => CompanyContext.forScope(
  scope: scope,
  companyId: id,
  allowedCompanyIds: [id],
  capabilityRevision: 1,
);

RuntimeDatabaseOwner _owner(File file) =>
    RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbi-envases-draft-');
    file = File('${directory.path}/runtime.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('round-trips a payload, then clear removes it', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final port = DurableEnvasesFormDraftPort(
      store: EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      ),
    );

    expect(await port.read('envases.envio'), isNull);

    await port.save('envases.envio', {
      'v': 1,
      'origenId': 1,
      'destinoId': 2,
      'lineas': [
        {'productoId': 50, 'cantidad': 4},
      ],
    });
    final read = await port.read('envases.envio');
    expect(read?['origenId'], 1);
    expect(read?['destinoId'], 2);

    // Guardar de nuevo (misma revisión ya conocida por el puerto) no debe
    // reventar por conflicto de concurrencia optimista.
    await port.save('envases.envio', {
      'v': 1,
      'origenId': 1,
      'destinoId': 3,
      'lineas': <Map<String, dynamic>>[],
    });
    expect((await port.read('envases.envio'))?['destinoId'], 3);

    await port.clear('envases.envio');
    expect(await port.read('envases.envio'), isNull);
  });

  test('tracks independent draft IDs (envío vs. recepción por picking)', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    final port = DurableEnvasesFormDraftPort(
      store: EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      ),
    );

    await port.save('envases.envio', {'v': 1, 'lineas': <Map<String, dynamic>>[]});
    await port.save('envases.recepcion.11', {
      'v': 1,
      'lineas': [
        {'moveId': 1, 'llegaron': 5, 'danadas': 0},
      ],
    });
    await port.save('envases.recepcion.12', {'v': 1, 'lineas': <Map<String, dynamic>>[]});

    expect((await port.read('envases.recepcion.11'))?['lineas'], [
      {'moveId': 1, 'llegaron': 5, 'danadas': 0},
    ]);

    await port.clear('envases.recepcion.11');
    expect(await port.read('envases.recepcion.11'), isNull);
    // Borrar un borrador no toca los demás.
    expect(await port.read('envases.envio'), isNotNull);
    expect(await port.read('envases.recepcion.12'), isNotNull);
  });

  test('UnavailableEnvasesFormDraftPort never throws and never persists', () async {
    const port = UnavailableEnvasesFormDraftPort();
    expect(await port.read('envases.envio'), isNull);
    await port.save('envases.envio', {'v': 1});
    await port.clear('envases.envio');
    expect(await port.read('envases.envio'), isNull);
  });

  test('clear waits for in-flight save and the draft stays deleted', () async {
    final completer = Completer<void>();
    final port = _BlockingSavePort(completer);
    final autoSave = EnvasesFormDraftAutoSave(
      port: port,
      draftId: 'envases.envio',
      debounce: Duration.zero,
    );

    autoSave.schedule({'v': 1, 'origenId': 1});
    // Deja pasar el debounce (cero) para que el guardado arranque y quede
    // bloqueado en el completer — «en vuelo» de verdad.
    await pumpEventQueue();
    expect(port.saveCalls, 1);
    expect(port.stored, isNull);

    final clearFuture = autoSave.clear();
    // `clear()` no debe terminar (ni borrar) mientras el guardado en vuelo
    // no haya resuelto.
    await pumpEventQueue();
    expect(port.cleared, isFalse);

    completer.complete();
    await clearFuture;

    // El guardado tardío terminó ANTES del borrado: el borrador no revive.
    expect(port.cleared, isTrue);
    expect(port.stored, isNull);
  });

  test('dispose flushes the pending change', () async {
    final port = _RecordingPort();
    final autoSave = EnvasesFormDraftAutoSave(
      port: port,
      draftId: 'envases.envio',
      debounce: const Duration(milliseconds: 300),
    );

    autoSave.schedule({'v': 1, 'destinoId': 2});
    // Se sale de la pantalla ANTES de que venza el debounce: sin el arreglo,
    // el cambio se pierde porque `dispose()` sólo cancelaba el temporizador.
    autoSave.dispose();
    await pumpEventQueue();

    expect(port.saves, [
      {'v': 1, 'destinoId': 2},
    ]);
    expect(port.cleared, isEmpty);
  });

  test('durable save recovers from a revision conflict', () async {
    final scope = _scope();
    final owner = _owner(file);
    addTearDown(owner.close);
    final activation = await owner.open(scope);
    DurableEnvasesFormDraftPort port() => DurableEnvasesFormDraftPort(
      store: EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      ),
    );
    final a = port();
    final b = port();

    // A guarda primero (crea el borrador en revisión 1).
    await a.save('envases.envio', {'from': 'a', 'n': 1});
    // B nunca leyó: su revisión en caché (0) ya está vieja frente a la real
    // (1). Sin reintento, esto lanzaría un conflicto sin recuperarse jamás.
    await b.save('envases.envio', {'from': 'b', 'n': 1});
    // A tampoco releyó desde su propio guardado: su revisión en caché (1)
    // quedó vieja frente a lo que B acaba de escribir (2). Este es «el
    // tercer guardado» que debe quedar en la base.
    await a.save('envases.envio', {'from': 'a', 'n': 2});

    final reader = DurableEnvasesFormDraftPort(
      store: EditableDraftStore(
        owner: owner,
        lease: activation.lease,
        company: _company(scope, 1),
      ),
    );
    expect(await reader.read('envases.envio'), {'from': 'a', 'n': 2});
  });
}
