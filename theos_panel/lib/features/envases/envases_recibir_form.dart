import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';
import 'envases_uuid.dart';

/// Recibir un traslado pendiente (ENV-06, BODEGA-ENVASES teléfono).
///
/// La app sólo valida lo evidente por línea — nada negativo, dañadas ≤
/// llegaron ≤ pendientes — todo lo demás (disponibilidad, sede del usuario,
/// que el picking siga pendiente) lo decide Odoo al aplicar
/// `l10n_ec.stock.envases.wizard.recepcion`. `lineasLoader` es quien de
/// verdad lee el picking (inyectado para que esta pantalla no importe un
/// `OdooClient`), y `operations` es el único camino de escritura.
class EnvasesRecibirForm extends StatefulWidget {
  const EnvasesRecibirForm({
    super.key,
    required this.row,
    required this.lineasLoader,
    required this.operations,
    this.onCompleted,
  });

  final EnvasesPorRecibirRow row;
  final Future<List<EnvasesPickingLineaRow>> Function() lineasLoader;
  final EnvasesOperations operations;
  final VoidCallback? onCompleted;

  @override
  State<EnvasesRecibirForm> createState() => _EnvasesRecibirFormState();
}

class _LineaControllers {
  _LineaControllers(EnvasesPickingLineaRow linea)
    : linea = linea,
      llegaron = TextEditingController(text: _fmt(linea.pendientes)),
      danadas = TextEditingController(text: _fmt(0));

  final EnvasesPickingLineaRow linea;
  final TextEditingController llegaron;
  final TextEditingController danadas;

  double? get llegaronValue => double.tryParse(llegaron.text.trim());
  double? get danadasValue => double.tryParse(danadas.text.trim());

  void dispose() {
    llegaron.dispose();
    danadas.dispose();
  }
}

String _fmt(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

class _EnvasesRecibirFormState extends State<EnvasesRecibirForm> {
  List<_LineaControllers>? _lineas;
  Object? _loadError;
  bool _saving = false;
  String? _saveError;
  String? _saveNotice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lineas = await widget.lineasLoader();
      if (!mounted) return;
      setState(() => _lineas = [for (final linea in lineas) _LineaControllers(linea)]);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  @override
  void dispose() {
    for (final controller in _lineas ?? const <_LineaControllers>[]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// `null` cuando la línea está bien; el texto del error cuando no.
  String? _errorDe(_LineaControllers controller) {
    final llegaron = controller.llegaronValue;
    final danadas = controller.danadasValue;
    if (llegaron == null || danadas == null) return 'Escribe un número válido.';
    if (llegaron < 0 || danadas < 0) return 'No puede ser negativo.';
    if (danadas > llegaron) return 'Las dañadas no pueden ser más de lo que llegó.';
    if (llegaron > controller.linea.pendientes) return 'No puede llegar más de lo que salió.';
    return null;
  }

  bool get _valido {
    final lineas = _lineas;
    if (lineas == null || lineas.isEmpty) return false;
    return lineas.every((c) => _errorDe(c) == null);
  }

  Future<void> _guardar() async {
    if (!_valido || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
      _saveNotice = null;
    });
    try {
      final resultado = await widget.operations.recibir(
        EnvasesRecibirCommand(
          operacionUuid: generateEnvasesOperacionUuid(),
          pickingId: widget.row.id,
          lineas: [
            for (final controller in _lineas!)
              EnvasesRecepcionLinea(
                productId: controller.linea.productId,
                llegaron: controller.llegaronValue!,
                danadas: controller.danadasValue!,
              ),
          ],
        ),
      );
      if (!mounted) return;
      if (resultado.estado == EnvasesOperacionEstado.pendienteDeEnviar) {
        setState(() => _saveNotice = 'Se enviará a Odoo al recuperar conexión.');
      }
      widget.onCompleted?.call();
    } catch (error) {
      if (mounted) setState(() => _saveError = 'No se pudo registrar la recepción: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPage(
      title: 'Recibir envases',
      subtitle: widget.row.name,
      child: _loadError != null
          ? OrbiErrorState(message: 'No se pudieron leer las líneas del traslado.', onRetry: _load)
          : _lineas == null
          ? const Center(child: ProgressRing(key: Key('envases-recibir-loading')))
          : _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final lineas = _lineas!;
    return OrbiForm.filling(
      sections: [
        OrbiFormSection(
          fields: [
            for (final controller in lineas)
              OrbiField(
                label: controller.linea.productName,
                span: 2,
                hint: 'Pendientes: ${_fmt(controller.linea.pendientes)} ${controller.linea.uomName}. '
                    'Aptas: ${_fmt((controller.llegaronValue ?? 0) - (controller.danadasValue ?? 0))}',
                error: _errorDe(controller),
                child: Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        key: Key('envases-recibir-llegaron-${controller.linea.moveId}'),
                        controller: controller.llegaron,
                        placeholder: 'Llegaron',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextBox(
                        key: Key('envases-recibir-danadas-${controller.linea.moveId}'),
                        controller: controller.danadas,
                        placeholder: 'Dañadas (incluidas en llegaron)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
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
              child: InfoBar(title: const Text('No se pudo guardar'), content: Text(_saveError!), severity: InfoBarSeverity.error),
            ),
          if (_saveNotice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InfoBar(title: Text(_saveNotice!), severity: InfoBarSeverity.warning),
            ),
          FilledButton(
            key: const Key('envases-recibir-guardar'),
            onPressed: _valido && !_saving ? _guardar : null,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
                : const Text('Guardar recepción'),
          ),
        ],
      ),
    );
  }
}
