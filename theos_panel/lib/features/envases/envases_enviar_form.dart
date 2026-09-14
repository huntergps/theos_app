import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/fluent/orbi_page.dart';
import 'envases_uuid.dart';

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
  _LineaEnvio({double cantidad = 1}) : cantidadController = TextEditingController(text: _fmt(cantidad));
  EnvasesProductoOption? producto;
  final TextEditingController cantidadController;

  double? get cantidad => double.tryParse(cantidadController.text.trim());

  void dispose() => cantidadController.dispose();
}

String _fmt(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// Enviar envases de una sede a otra (BODEGA-ENVASES botón «Enviar
/// traslado»). El origen sólo ofrece las sedes del usuario; el destino,
/// cualquier sede con `controla_envases` distinta del origen elegido. Sin
/// comprobar disponible aquí — eso lo decide Odoo al aplicar
/// `l10n_ec.stock.envases.wizard.envio`.
class EnvasesEnviarForm extends StatefulWidget {
  const EnvasesEnviarForm({
    super.key,
    required this.sedesUsuario,
    required this.sedesDestinoPosibles,
    required this.productos,
    required this.operations,
    this.onCompleted,
  });

  final List<EnvasesSedeOption> sedesUsuario;
  final List<EnvasesSedeOption> sedesDestinoPosibles;
  final List<EnvasesProductoOption> productos;
  final EnvasesOperations operations;
  final VoidCallback? onCompleted;

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

  @override
  void initState() {
    super.initState();
    if (widget.sedesUsuario.length == 1) _origenId = widget.sedesUsuario.single.id;
  }

  @override
  void dispose() {
    for (final linea in _lineas) {
      linea.dispose();
    }
    super.dispose();
  }

  List<EnvasesSedeOption> get _destinosDisponibles =>
      widget.sedesDestinoPosibles.where((sede) => sede.id != _origenId).toList(growable: false);

  bool get _valido {
    if (_origenId == null || _destinoId == null || _origenId == _destinoId) return false;
    if (_fechaSalida.isAfter(DateTime.now())) return false;
    final lineasValidas = _lineas.where((l) => l.producto != null && (l.cantidad ?? 0) > 0);
    return lineasValidas.isNotEmpty && lineasValidas.length == _lineas.length;
  }

  void _agregarLinea() => setState(() => _lineas.add(_LineaEnvio()));

  void _quitarLinea(_LineaEnvio linea) {
    if (_lineas.length <= 1) return;
    setState(() {
      _lineas.remove(linea);
      linea.dispose();
    });
  }

  Future<void> _enviar() async {
    if (!_valido || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
      _saveNotice = null;
    });
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
        setState(() => _saveNotice = 'Se enviará a Odoo al recuperar conexión.');
      }
      widget.onCompleted?.call();
    } catch (error) {
      if (mounted) setState(() => _saveError = 'No se pudo registrar el envío: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPage(
      title: 'Enviar envases',
      subtitle: 'Traslado entre sedes',
      child: OrbiForm.filling(
        sections: [
          OrbiFormSection(
            fields: [
              OrbiField(
                label: 'Sede de origen',
                required: true,
                child: ComboBox<int>(
                  key: const Key('envases-enviar-origen'),
                  placeholder: const Text('Elige una sede'),
                  value: _origenId,
                  items: [
                    for (final sede in widget.sedesUsuario)
                      ComboBoxItem(value: sede.id, child: Text(sede.name)),
                  ],
                  onChanged: (value) => setState(() {
                    _origenId = value;
                    if (_destinoId == value) _destinoId = null;
                  }),
                ),
              ),
              OrbiField(
                label: 'Sede de destino',
                required: true,
                child: ComboBox<int>(
                  key: const Key('envases-enviar-destino'),
                  placeholder: const Text('Elige una sede'),
                  value: _destinoId,
                  items: [
                    for (final sede in _destinosDisponibles)
                      ComboBoxItem(value: sede.id, child: Text(sede.name)),
                  ],
                  onChanged: (value) => setState(() => _destinoId = value),
                ),
              ),
              OrbiField(
                label: 'Fecha de salida',
                required: true,
                child: DatePicker(
                  key: const Key('envases-enviar-fecha'),
                  selected: _fechaSalida,
                  onChanged: (value) => setState(
                    () => _fechaSalida = DateTime(
                      value.year,
                      value.month,
                      value.day,
                      _fechaSalida.hour,
                      _fechaSalida.minute,
                    ),
                  ),
                ),
              ),
            ],
          ),
          OrbiFormSection(
            title: 'Envases',
            fields: [
              for (final linea in _lineas)
                OrbiField(
                  label: 'Envase',
                  span: 2,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ComboBox<EnvasesProductoOption>(
                          key: Key('envases-enviar-producto-${_lineas.indexOf(linea)}'),
                          placeholder: const Text('Elige un envase'),
                          value: linea.producto,
                          items: [
                            for (final producto in widget.productos)
                              ComboBoxItem(value: producto, child: Text(producto.name)),
                          ],
                          onChanged: (value) => setState(() => linea.producto = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextBox(
                          key: Key('envases-enviar-cantidad-${_lineas.indexOf(linea)}'),
                          controller: linea.cantidadController,
                          placeholder: 'Cantidad',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.delete),
                        onPressed: _lineas.length <= 1 ? null : () => _quitarLinea(linea),
                      ),
                    ],
                  ),
                ),
              OrbiField(
                label: '',
                span: 2,
                child: Button(
                  key: const Key('envases-enviar-agregar-linea'),
                  onPressed: _agregarLinea,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(FluentIcons.add), SizedBox(width: 6), Text('Agregar envase')],
                  ),
                ),
              ),
            ],
          ),
        ],
        actions: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBar(title: const Text('No se pudo enviar'), content: Text(_saveError!), severity: InfoBarSeverity.error),
              ),
            if (_saveNotice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBar(title: Text(_saveNotice!), severity: InfoBarSeverity.warning),
              ),
            FilledButton(
              key: const Key('envases-enviar-confirmar'),
              onPressed: _valido && !_saving ? _enviar : null,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
