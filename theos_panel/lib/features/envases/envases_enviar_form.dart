import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/fluent/orbi_page.dart';
import 'envases_form_draft_port.dart';
import 'envases_uuid.dart';
import 'widgets/envases_form_actions.dart';
import 'widgets/envases_form_layout.dart';
import 'widgets/envases_producto_field.dart';

/// Id del único borrador durable del formulario de envío. Hay un solo
/// formulario de envío activo a la vez (a diferencia de la recepción, que
/// tiene uno por traslado), así que no necesita interpolar nada.
const String envasesEnvioDraftId = 'envases.envio';

/// Una sede ofrecida en el formulario — nunca cableada, siempre la que trae
/// el servidor (`res.users.envases_warehouse_ids` para origen,
/// `stock.warehouse` con `controla_envases` para destino).
final class EnvasesSedeOption {
  const EnvasesSedeOption({required this.id, required this.name});
  final int id;
  final String name;
}

/// Un producto ofrecible en una línea de envío. La lista la trae quien
/// compone la pantalla (por ejemplo, los productos ya vistos en el
/// dashboard de existencias) — este formulario no busca en un catálogo.
final class EnvasesProductoOption {
  const EnvasesProductoOption({required this.id, required this.name, required this.uomName});
  final int id;
  final String name;
  final String uomName;
}

class _LineaEnvio {
  _LineaEnvio({this.cantidad = 1});
  EnvasesProductoOption? producto;
  double? cantidad;
}

String _fmt(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// Enviar envases de una sede a otra (BODEGA-ENVASES botón «Enviar
/// traslado»). El origen sólo ofrece las sedes del usuario; el destino,
/// cualquier sede con `controla_envases` distinta del origen elegido. Sin
/// comprobar disponible aquí — eso lo decide Odoo al aplicar
/// `l10n_ec.stock.envases.wizard.envio`.
///
/// Diseño aprobado (`docs/orbi_panel/visual_baselines/approved/round-02/`):
/// datos generales en una fila de campos de ancho fijo, líneas en tabla
/// (tarjeta en teléfono) con «Envase», «Cantidad» y quitar, y la acción
/// principal alineada a la derecha del contenido — no una barra a todo el
/// ancho.
class EnvasesEnviarForm extends StatefulWidget {
  const EnvasesEnviarForm({
    super.key,
    required this.sedesUsuario,
    required this.sedesDestinoPosibles,
    required this.productos,
    required this.operations,
    this.onCompleted,
    this.onCancel,
    this.draftPort,
  });

  final List<EnvasesSedeOption> sedesUsuario;
  final List<EnvasesSedeOption> sedesDestinoPosibles;
  final List<EnvasesProductoOption> productos;
  final EnvasesOperations operations;
  final VoidCallback? onCompleted;

  /// Cerrar sin guardar. Nulo cuando la pantalla no tiene a dónde volver
  /// (por ejemplo, en los tests existentes) — entonces no se ofrece
  /// «Cancelar».
  final VoidCallback? onCancel;

  /// Persistencia opcional del borrador. Sin él (por ejemplo, en los tests
  /// existentes) el formulario funciona igual que antes: sólo en memoria.
  final EnvasesFormDraftPort? draftPort;

  @override
  State<EnvasesEnviarForm> createState() => _EnvasesEnviarFormState();
}

class _EnvasesEnviarFormState extends State<EnvasesEnviarForm> {
  int? _origenId;
  int? _destinoId;
  DateTime _fechaSalida = DateTime.now();
  final List<_LineaEnvio> _lineas = [_LineaEnvio()];
  bool _saving = false;
  String? _saveError;
  String? _saveNotice;
  bool _recoveredNotice = false;
  EnvasesFormDraftAutoSave? _autoSave;

  @override
  void initState() {
    super.initState();
    if (widget.sedesUsuario.length == 1) _origenId = widget.sedesUsuario.single.id;
    final port = widget.draftPort;
    if (port != null) {
      _autoSave = EnvasesFormDraftAutoSave(port: port, draftId: envasesEnvioDraftId);
      unawaited(_restoreDraft(port));
    }
  }

  @override
  void dispose() {
    _autoSave?.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft(EnvasesFormDraftPort port) async {
    Map<String, dynamic>? raw;
    try {
      raw = await port.read(envasesEnvioDraftId);
    } catch (_) {
      return;
    }
    if (raw == null || !mounted) return;

    var recovered = false;
    int? origenId;
    final rawOrigen = raw['origenId'];
    if (rawOrigen is int && widget.sedesUsuario.any((sede) => sede.id == rawOrigen)) {
      origenId = rawOrigen;
      recovered = true;
    }
    int? destinoId;
    final rawDestino = raw['destinoId'];
    if (rawDestino is int &&
        rawDestino != origenId &&
        widget.sedesDestinoPosibles.any((sede) => sede.id == rawDestino)) {
      destinoId = rawDestino;
      recovered = true;
    }
    final restoredLineas = <_LineaEnvio>[];
    final rawLineas = raw['lineas'];
    if (rawLineas is List) {
      for (final item in rawLineas) {
        if (item is! Map) continue;
        final productoId = item['productoId'];
        final cantidad = item['cantidad'];
        if (productoId is! int || cantidad is! num) continue;
        EnvasesProductoOption? producto;
        for (final option in widget.productos) {
          if (option.id == productoId) {
            producto = option;
            break;
          }
        }
        // Producto que ya no está entre las opciones actuales: se descarta
        // en silencio, la línea entera desaparece.
        if (producto == null) continue;
        restoredLineas.add(_LineaEnvio(cantidad: cantidad.toDouble())..producto = producto);
      }
    }
    if (restoredLineas.isNotEmpty) recovered = true;
    if (!recovered) return;

    setState(() {
      if (origenId != null) _origenId = origenId;
      if (destinoId != null) _destinoId = destinoId;
      if (restoredLineas.isNotEmpty) {
        _lineas
          ..clear()
          ..addAll(restoredLineas);
      }
      _recoveredNotice = true;
    });
  }

  Map<String, dynamic> _draftPayload() => {
    'v': 1,
    'origenId': _origenId,
    'destinoId': _destinoId,
    'lineas': [
      for (final linea in _lineas) {'productoId': linea.producto?.id, 'cantidad': linea.cantidad},
    ],
  };

  void _scheduleDraftSave() => _autoSave?.schedule(_draftPayload());

  List<EnvasesSedeOption> get _destinosDisponibles =>
      widget.sedesDestinoPosibles.where((sede) => sede.id != _origenId).toList(growable: false);

  bool get _fechaValida => !_fechaSalida.isAfter(DateTime.now());

  Iterable<_LineaEnvio> get _lineasValidas =>
      _lineas.where((l) => l.producto != null && (l.cantidad ?? 0) > 0);

  bool get _valido {
    if (_origenId == null || _destinoId == null || _origenId == _destinoId) return false;
    if (!_fechaValida) return false;
    final lineasValidas = _lineasValidas;
    return lineasValidas.isNotEmpty && lineasValidas.length == _lineas.length;
  }

  /// Qué falta para poder confirmar, en palabras — visible junto al botón
  /// mientras esté deshabilitado en vez de dejarlo mudo. `null` cuando ya se
  /// puede confirmar.
  String? get _ayuda {
    if (_origenId != null && _destinoId != null && _origenId == _destinoId) {
      return 'El origen y el destino tienen que ser sedes distintas.';
    }
    if (!_fechaValida) return 'La fecha de salida no puede ser futura.';
    final faltantes = <String>[
      if (_origenId == null) 'la sede de origen',
      if (_destinoId == null) 'la de destino',
      if (_lineasValidas.isEmpty) 'al menos un envase',
    ];
    if (faltantes.isEmpty) return null;
    if (faltantes.length == 1) return 'Elige ${faltantes.single}.';
    return 'Elige ${faltantes.sublist(0, faltantes.length - 1).join(', ')} y ${faltantes.last}.';
  }

  void _agregarLinea() {
    setState(() => _lineas.add(_LineaEnvio()));
    _scheduleDraftSave();
  }

  void _quitarLinea(_LineaEnvio linea) {
    if (_lineas.length <= 1) return;
    setState(() => _lineas.remove(linea));
    _scheduleDraftSave();
  }

  Future<void> _enviar() async {
    if (!_valido || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
      _saveNotice = null;
    });
    var registrado = false;
    try {
      final resultado = await widget.operations.enviar(
        EnvasesEnviarCommand(
          operacionUuid: generateEnvasesOperacionUuid(),
          origenId: _origenId!,
          destinoId: _destinoId!,
          fechaSalida: _fechaSalida,
          lineas: [
            for (final linea in _lineas)
              EnvasesEnvioLinea(productId: linea.producto!.id, cantidad: linea.cantidad!),
          ],
        ),
      );
      if (!mounted) return;
      if (resultado.estado == EnvasesOperacionEstado.pendienteDeEnviar) {
        setState(
          () => _saveNotice =
              'Guardado en este equipo. Se envía a Odoo en cuanto haya conexión.',
        );
      }
      // Registro aceptado (en línea o encolado sin conexión): el borrador ya
      // cumplió su propósito.
      unawaited(_autoSave?.clear());
      registrado = true;
    } catch (error) {
      if (mounted) setState(() => _saveError = 'No se pudo registrar el envío: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    // Fuera del try: si `onCompleted` navega y lanza (p. ej. no hay nada que
    // hacer pop), eso no debe reescribirse como si el registro hubiera
    // fallado — el registro ya quedó confirmado o encolado arriba.
    if (registrado) {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPage(
      title: 'Enviar envases',
      subtitle: 'Traslado entre sedes',
      child: EnvasesFormScaffold(
        body: _body(context),
        actions: EnvasesFormActions(
          primaryKey: const Key('envases-enviar-confirmar'),
          primaryLabel: 'Enviar',
          onPrimary: _valido && !_saving ? _enviar : null,
          saving: _saving,
          onCancel: widget.onCancel,
          helpText: _ayuda,
          errorTitle: 'No se pudo enviar',
          error: _saveError,
          notice: _saveNotice,
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recoveredNotice)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InfoBar(
              title: const Text('Recuperamos lo que estabas registrando.'),
              severity: InfoBarSeverity.info,
            ),
          ),
        Text('Datos del envío', style: typography.subtitle),
        const SizedBox(height: 12),
        EnvasesFieldsRow(
          slots: [
            EnvasesFieldSlot(
              width: 260,
              field: EnvasesField(
                label: 'Sede de origen',
                required: true,
                child: ComboBox<int>(
                  key: const Key('envases-enviar-origen'),
                  placeholder: const Text('Elige una sede'),
                  isExpanded: true,
                  value: _origenId,
                  items: [
                    for (final sede in widget.sedesUsuario)
                      ComboBoxItem(value: sede.id, child: Text(sede.name)),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _origenId = value;
                      if (_destinoId == value) _destinoId = null;
                    });
                    _scheduleDraftSave();
                  },
                ),
              ),
            ),
            EnvasesFieldSlot(
              width: 260,
              field: EnvasesField(
                label: 'Sede de destino',
                required: true,
                child: ComboBox<int>(
                  key: const Key('envases-enviar-destino'),
                  placeholder: const Text('Elige una sede'),
                  isExpanded: true,
                  value: _destinoId,
                  items: [
                    for (final sede in _destinosDisponibles)
                      ComboBoxItem(value: sede.id, child: Text(sede.name)),
                  ],
                  onChanged: (value) {
                    setState(() => _destinoId = value);
                    _scheduleDraftSave();
                  },
                ),
              ),
            ),
            EnvasesFieldSlot(
              width: 220,
              field: EnvasesField(
                label: 'Fecha de salida',
                required: true,
                child: EnvasesDateField(
                  datePickerKey: const Key('envases-enviar-fecha'),
                  selected: _fechaSalida,
                  onChanged: (value) {
                    setState(
                      () => _fechaSalida = DateTime(
                        value.year,
                        value.month,
                        value.day,
                        _fechaSalida.hour,
                        _fechaSalida.minute,
                      ),
                    );
                    _scheduleDraftSave();
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Envases', style: typography.subtitle),
        const SizedBox(height: 12),
        // Sin origen elegido y todavía sin ningún envase seleccionado (el
        // estado inicial: una sola línea vacía), la tabla se reemplaza por
        // este aviso — pero un borrador restaurado que YA trae envases
        // elegidos se sigue mostrando aunque el origen no se haya
        // restaurado con él (por ejemplo, porque la sede guardada ya no es
        // válida): no tiene sentido esconder líneas que el usuario ya
        // llenó.
        if (_origenId == null && _lineas.every((l) => l.producto == null))
          const Text('Elige la sede de origen para agregar envases.')
        else
          _lineasArea(context),
      ],
    );
  }

  Widget _lineasArea(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kEnvasesDesktopBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWide) _lineasTablaHeader(context),
            for (var i = 0; i < _lineas.length; i++)
              isWide ? _lineaFila(context, i) : _lineaTarjeta(context, i),
            const SizedBox(height: 8),
            // `Align` evita que el `crossAxisAlignment.stretch` de este
            // `Column` estire el botón al ancho entero de la tabla — 🔴 esa
            // era la «barra de 1.200 px» de la queja del dueño (14-sep-2026):
            // un `Button` de Fluent SÍ se estira para llenar el ancho que le
            // da su padre cuando se lo permiten así, y aquí se lo permitía.
            Align(
              alignment: Alignment.centerLeft,
              child: Button(
                key: const Key('envases-enviar-agregar-linea'),
                onPressed: _agregarLinea,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(FluentIcons.add), SizedBox(width: 6), Text('Agregar envase')],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total envases: ${_fmt(_lineas.fold<double>(0, (sum, l) => sum + (l.cantidad ?? 0)))}',
                  key: const Key('envases-enviar-total'),
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _lineasTablaHeader(BuildContext context) {
    final style = FluentTheme.of(context).typography.bodyStrong;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 420, child: Text('Envase', style: style)),
          const SizedBox(width: 24),
          SizedBox(width: 120, child: Text('Cantidad', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 24),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _lineaFila(BuildContext context, int index) {
    final linea = _lineas[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 420,
            child: EnvasesProductoField(
              key: Key('envases-enviar-producto-$index'),
              productos: widget.productos,
              value: linea.producto,
              onChanged: (value) {
                setState(() => linea.producto = value);
                _scheduleDraftSave();
              },
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 120,
            child: NumberBox<double>(
              key: Key('envases-enviar-cantidad-$index'),
              value: linea.cantidad,
              mode: SpinButtonPlacementMode.none,
              placeholder: 'Cantidad',
              onChanged: (value) {
                setState(() => linea.cantidad = value);
                _scheduleDraftSave();
              },
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 40,
            child: IconButton(
              key: Key('envases-enviar-quitar-$index'),
              icon: const Icon(FluentIcons.delete),
              onPressed: _lineas.length <= 1 ? null : () => _quitarLinea(linea),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineaTarjeta(BuildContext context, int index) {
    final linea = _lineas[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: EnvasesProductoField(
                    key: Key('envases-enviar-producto-$index'),
                    productos: widget.productos,
                    value: linea.producto,
                    onChanged: (value) {
                      setState(() => linea.producto = value);
                      _scheduleDraftSave();
                    },
                  ),
                ),
                IconButton(
                  key: Key('envases-enviar-quitar-$index'),
                  icon: const Icon(FluentIcons.delete),
                  onPressed: _lineas.length <= 1 ? null : () => _quitarLinea(linea),
                ),
              ],
            ),
            const SizedBox(height: 8),
            EnvasesField(
              label: 'Cantidad',
              child: NumberBox<double>(
                key: Key('envases-enviar-cantidad-$index'),
                value: linea.cantidad,
                mode: SpinButtonPlacementMode.inline,
                placeholder: 'Cantidad',
                onChanged: (value) {
                  setState(() => linea.cantidad = value);
                  _scheduleDraftSave();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
