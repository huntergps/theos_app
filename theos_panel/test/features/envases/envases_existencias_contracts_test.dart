import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/envases/envases_existencias_contracts.dart';

/// `RuntimeEnvasesExistenciasRepository` es el único lugar donde se decide
/// CUÁNDO se sonda `fields_get` para la foto de producto — la sonda misma
/// vive en `EnvasesExistenciasReader`. Estas pruebas comprueban esa
/// orquestación con una caché real de SQLite (mismo aparejo que
/// `envases_existencias_cache_test.dart`) y `SharedPreferences` en memoria.
void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('orbi-envases-repo-');
    file = File('${dir.path}/runtime.sqlite');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  final scope = AppScope(
    appId: 'orbi',
    installationId: 'i',
    normalizedServerUrl: 'https://odoo.example',
    database: 'db',
    userId: 1,
  );
  CompanyContext company() => CompanyContext.forScope(
    scope: scope,
    companyId: 4,
    allowedCompanyIds: [4],
    capabilityRevision: 1,
  );

  Map<String, dynamic> datos() => {
    'columnas': [
      {'id': 'sede-1', 'nombre': 'Sede 1', 'location_id': 11, 'tipo': 'sede'},
    ],
    'filas': [
      {
        'id': 501,
        'nombre': 'Botella retornable',
        'uom': 'Unidades',
        'celdas': {'sede-1': 10.0},
        'total': 10.0,
      },
    ],
    'totales_columna': {'sede-1': 10.0},
    'total_general': 10.0,
    'pendientes': 0,
  };

  /// Espera lo suficiente para que la fusión de fotos —lanzada con
  /// `unawaited` a propósito en `refresh()`, para no bloquear las cifras—
  /// termine antes de comprobar algo. El transporte falso de esta prueba
  /// resuelve todo de forma síncrona, así que un solo vaciado de microtareas
  /// alcanza.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    '(j) two refreshes against the same server probe fields_get only once',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase(file)),
      );
      final db = await owner.open(scope);
      addTearDown(owner.close);
      final cache = EnvasesExistenciasCache(
        owner: owner,
        lease: db.lease,
        company: company(),
      );
      final preferences = await SharedPreferences.getInstance();
      final imageFieldCache = EnvasesImageFieldCache(
        preferences: preferences,
        serverUrl: scope.normalizedServerUrl,
        database: scope.database,
      );

      var fieldsGetCalls = 0;
      var searchReadCalls = 0;
      EnvasesExistenciasReader reader() => EnvasesExistenciasReader(
        company: company(),
        transport:
            ({
              required String model,
              required String method,
              required Map<String, dynamic> kwargs,
              required Map<String, dynamic> context,
            }) async {
              switch (method) {
                case 'datos':
                  return datos();
                case 'fields_get':
                  fieldsGetCalls++;
                  return {
                    'image_128': {'type': 'binary'},
                  };
                case 'search_read':
                  searchReadCalls++;
                  return [
                    {'id': 501, 'image_128': 'Zm90bw=='},
                  ];
                default:
                  throw StateError('unexpected method $method');
              }
            },
      );

      final repository = RuntimeEnvasesExistenciasRepository(
        cache: cache,
        readerFactory: reader,
        imageFieldCache: imageFieldCache,
      );

      await repository.refresh();
      await settle();
      await repository.refresh();
      await settle();

      expect(
        fieldsGetCalls,
        1,
        reason: 'el estado ya quedó guardado en EnvasesImageFieldCache tras '
            'el primer refresco',
      );
      expect(searchReadCalls, 2, reason: 'cada refresco sí trae fotos');
      expect(
        (await cache.read())!.data.filas.single.imagenBase64,
        'Zm90bw==',
      );
    },
  );

  test(
    'a server without image_128 is remembered too: no repeated fields_get, '
    'and no search_read at all',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase(file)),
      );
      final db = await owner.open(scope);
      addTearDown(owner.close);
      final cache = EnvasesExistenciasCache(
        owner: owner,
        lease: db.lease,
        company: company(),
      );
      final preferences = await SharedPreferences.getInstance();
      final imageFieldCache = EnvasesImageFieldCache(
        preferences: preferences,
        serverUrl: scope.normalizedServerUrl,
        database: scope.database,
      );

      var fieldsGetCalls = 0;
      EnvasesExistenciasReader reader() => EnvasesExistenciasReader(
        company: company(),
        transport:
            ({
              required String model,
              required String method,
              required Map<String, dynamic> kwargs,
              required Map<String, dynamic> context,
            }) async {
              switch (method) {
                case 'datos':
                  return datos();
                case 'fields_get':
                  fieldsGetCalls++;
                  return <String, dynamic>{}; // sin image_128
                case 'search_read':
                  fail('no debía llamar a search_read sin image_128');
                default:
                  throw StateError('unexpected method $method');
              }
            },
      );

      final repository = RuntimeEnvasesExistenciasRepository(
        cache: cache,
        readerFactory: reader,
        imageFieldCache: imageFieldCache,
      );

      await repository.refresh();
      await settle();
      await repository.refresh();
      await settle();

      expect(fieldsGetCalls, 1);
      expect((await cache.read())!.data.filas.single.imagenBase64, isNull);
      expect(
        imageFieldCache.read(),
        EnvasesImageFieldState.unavailable,
      );
    },
  );
}
