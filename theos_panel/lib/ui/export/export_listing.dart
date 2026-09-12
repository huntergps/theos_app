import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/preferences/app_preferences.dart';
import '../components/copyable_message.dart';
import 'save_export.dart';

/// Lo que una pantalla de listado necesita para exportar sin saber de Riverpod.
///
/// Las tres pantallas de listado son `StatefulWidget` sin `ref`, y sus rutas sí
/// lo tienen. Pasar esto desde la ruta evita convertirlas todas en
/// consumidoras sólo para poder leer una preferencia.
typedef ListingExporter = void Function(
  BuildContext context,
  List<int> bytes,
  String fileName,
);

/// Guarda el Excel que produjo un listado y dice dónde quedó.
///
/// Existe una sola vez para que las tres pantallas de listado no escriban cada
/// una su versión, que es como acaban diciendo cosas distintas ante el mismo
/// resultado.
///
/// El aviso es del mismo tipo que el resto: se puede **copiar** y dura lo que
/// la persona haya elegido en Configuración. Un fallo al guardar no se traga
/// en silencio: exportar y no obtener nada, sin explicación, es peor que un
/// botón que no existe.
Future<void> exportListingBytes(
  BuildContext context,
  WidgetRef ref,
  List<int> bytes,
  String fileName,
) async {
  final preferences = ref.read(
    appPreferencesProvider(ref.read(preferencesScopeProvider)),
  );
  try {
    final destino = await saveExport(bytes, fileName);
    if (!context.mounted) return;
    showCopyableMessage(
      context,
      CopyableMessage(
        title: 'Exportado a Excel',
        body: destino,
        severity: OrbiMessageSeverity.success,
      ),
      durations: preferences.snapshot.messageDurations,
    );
  } catch (error) {
    if (!context.mounted) return;
    showCopyableMessage(
      context,
      CopyableMessage(
        title: 'No se pudo guardar el Excel',
        body:
            'El listado se generó, pero el archivo no llegó a guardarse. '
            'Vuelve a intentarlo; si sigue igual, copia este mensaje y '
            'pásaselo a quien administre el sistema.\n$error',
        severity: OrbiMessageSeverity.error,
      ),
      durations: preferences.snapshot.messageDurations,
    );
  }
}
