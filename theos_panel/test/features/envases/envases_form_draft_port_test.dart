import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_form_draft_port.dart';

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
}
