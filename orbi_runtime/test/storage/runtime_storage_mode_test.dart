import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';

/// Bloque B de la auditoría de "se pierde todo lo que estaba haciendo"
/// (14-sep-2026): antes de esto, si el navegador caía a
/// `WasmStorageImplementation.inMemory`, nadie se enteraba salvo un `print`
/// de drift_flutter en la consola. Esta prueba fija sólo la lectura PURA de
/// qué implementación cuenta como volátil — la que de verdad corre en un
/// navegador real (`WasmDatabase.open`) no se puede reproducir en un test de
/// VM, así que se prueba por separado en `operational_shell_storage_mode_test.dart`
/// (theos_panel) con el modo ya resuelto.
void main() {
  test('inMemory es la única implementación volátil', () {
    expect(
      storageModeForImplementation(WasmStorageImplementation.inMemory),
      RuntimeStorageMode.volatile,
    );
  });

  test('opfsShared, opfsLocks, sharedIndexedDb y unsafeIndexedDb son persistentes', () {
    for (final implementation in [
      WasmStorageImplementation.opfsShared,
      WasmStorageImplementation.opfsLocks,
      WasmStorageImplementation.sharedIndexedDb,
      WasmStorageImplementation.unsafeIndexedDb,
    ]) {
      expect(
        storageModeForImplementation(implementation),
        RuntimeStorageMode.persistent,
        reason: '$implementation debería contar como persistente.',
      );
    }
  });
}
