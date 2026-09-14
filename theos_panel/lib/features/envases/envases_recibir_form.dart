import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';
import 'envases_form_draft_port.dart';
import 'envases_uuid.dart';

/// Id del borrador durable de una recepción: uno por traslado, con el mismo
/// `pickingId` que ya identifica la fila (`EnvasesPorRecibirRow.id`).
String envasesRecepcionDraftId(int pickingId) => 'envases.recepcion.$pickingId';

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
    this.draftPort,
  });

  final EnvasesPorRecibirRow row;
  final Future<List<EnvasesPickingLineaRow>> Function() lineasLoader;
  final EnvasesOperations operations;
  final VoidCallback? onCompleted;

  /// Persistencia opcional del borrador. Sin él (por ejemplo, en los tests
  /// existentes) el formulario funciona igual que antes: sólo en memoria.
  final EnvasesFormDraftPort? draftPort;

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
  bool _recoveredNotice = false;
  EnvasesFormDraftAutoSave? _autoSave;

  String get _draftId => envasesRecepcionDraftId(widget.row.id);

  @override
  void initState() {
    super.initState();
    final port = widget.draftPort;
    if (port != null) {
      _autoSave = EnvasesFormDraftAutoSave(port: port, draftId: _draftId);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final lineas = await widget.lineasLoader();
      if (!mounted) return;
      setState(() => _lineas = [for (final linea in lineas) _LineaControllers(linea)]);
      // La recepción sólo se prellena DESPUÉS de tener las líneas reales:
      // antes de eso no hay con qué cotejar que un `moveId` restaurado siga
      // vigente.
      final port = widget.draftPort;
      if (port != null) await _restoreDraft(port);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _restoreDraft(EnvasesFormDraftPort port) async {
    Map<String, dynamic>? raw;
    try {
      raw = await port.read(_draftId);
    } catch (_) {
      return;
    }
    final lineas = _lineas;
    if (raw == null || lineas == null || !mounted) return;

    final rawLineas = raw['lineas'];
    if (rawLineas is! List) return;
    var recovered = false;
    for (final item in rawLineas) {
      if (item is! Map) continue;
      final moveId = item['moveId'];
      final llegaron = item['llegaron'];
      final danadas = item['danadas'];
      if (moveId is! int || llegaron is! num || danadas is! num) continue;
      // Línea que ya no está en el traslado real (recalculada por Odoo entre
      // sesiones): se descarta en silencio.
      for (final controller in lineas) {
        if (controller.linea.moveId == moveId) {
          controller.llegaron.text = _fmt(llegaron.toDouble());
          controller.danadas.text = _fmt(danadas.toDouble());
          recovered = true;
          break;
        }
      }
    }
    if (!recovered) return;
    setState(() => _recoveredNotice = true);
  }

  Map<String, dynamic> _draftPayload() => {
    'v': 1,
    'lineas': [
      for (final controller in _lineas ?? const <_LineaControllers>[])
        {
          'moveId': controller.linea.moveId,
          'llegaron': controller.llegaronValue,
          'danadas': controller.danadasValue,
        },
    ],
  };

  void _scheduleDraftSave() => _autoSave?.schedule(_draftPayload());

  @override
  void dispose() {
    _autoSave?.dispose();
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
      // Registro aceptado (en línea o encolado sin conexión): el borrador ya
      // cumplió su propósito.
      unawaited(_autoSave?.clear());
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
            if (_recoveredNotice)
              OrbiField(
                label: '',
                span: 2,
                child: InfoBar(
                  title: const Text('Recuperamos lo que estabas registrando.'),
                  severity: InfoBarSeverity.info,
                ),
              ),
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
                        onChanged: (_) {
                          setState(() {});
                          _scheduleDraftSave();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextBox(
                        key: Key('envases-recibir-danadas-${controller.linea.moveId}'),
                        controller: controller.danadas,
                        placeholder: 'Dañadas (incluidas en llegaron)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          setState(() {});
                          _scheduleDraftSave();
                        },
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
