import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';
import 'envases_form_draft_port.dart';
import 'envases_uuid.dart';
import 'widgets/envases_form_actions.dart';
import 'widgets/envases_form_layout.dart';

/// Id del borrador durable de una recepción: uno por traslado, con el mismo
/// `pickingId` que ya identifica la fila (`EnvasesPorRecibirRow.id`).
String envasesRecepcionDraftId(int pickingId) => 'envases.recepcion.$pickingId';

class _LineaControllers {
  _LineaControllers(this.linea) : llegaronValue = linea.pendientes, danadasValue = 0;

  final EnvasesPickingLineaRow linea;
  double? llegaronValue;
  double? danadasValue;

  double get aptos => math.max(0, (llegaronValue ?? 0) - (danadasValue ?? 0));
  double get pendiente => math.max(0, linea.pendientes - (llegaronValue ?? 0));
}

String _fmt(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

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
    this.onCancel,
    this.draftPort,
  });

  final EnvasesPorRecibirRow row;
  final Future<List<EnvasesPickingLineaRow>> Function() lineasLoader;
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
  State<EnvasesRecibirForm> createState() => _EnvasesRecibirFormState();
}

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
          controller.llegaronValue = llegaron.toDouble();
          controller.danadasValue = danadas.toDouble();
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

  String? get _ayuda {
    final lineas = _lineas;
    if (lineas == null || lineas.isEmpty) return null;
    if (_valido) return null;
    return 'Corrige las líneas marcadas en rojo antes de guardar.';
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
          : EnvasesFormWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: SingleChildScrollView(child: _body(context))),
                  const SizedBox(height: 16),
                  EnvasesFormActions(
                    primaryKey: const Key('envases-recibir-guardar'),
                    primaryLabel: 'Guardar recepción',
                    onPrimary: _valido && !_saving ? _guardar : null,
                    saving: _saving,
                    onCancel: widget.onCancel,
                    helpText: _ayuda,
                    error: _saveError,
                    notice: _saveNotice,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _body(BuildContext context) {
    final lineas = _lineas!;
    final typography = FluentTheme.of(context).typography;
    final totalEnviado = lineas.fold<double>(0, (sum, c) => sum + c.linea.pendientes);
    final totalRecibido = lineas.fold<double>(0, (sum, c) => sum + (c.llegaronValue ?? 0));
    final totalDanado = lineas.fold<double>(0, (sum, c) => sum + (c.danadasValue ?? 0));
    final totalPendiente = math.max(0.0, totalEnviado - totalRecibido);
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
        Row(
          children: [
            Expanded(child: Text('Traslado ${widget.row.name}', style: typography.subtitle)),
            const OrbiStatusChip(label: 'En tránsito', icon: FluentIcons.sync_status_solid),
          ],
        ),
        const SizedBox(height: 12),
        EnvasesFieldsRow(
          slots: [
            EnvasesFieldSlot(
              width: 220,
              field: EnvasesInfoField(label: 'Origen', value: widget.row.origenName ?? 'Origen desconocido'),
            ),
            EnvasesFieldSlot(
              width: 220,
              field: EnvasesInfoField(label: 'Destino', value: widget.row.destinoName ?? 'Destino desconocido'),
            ),
            EnvasesFieldSlot(
              width: 220,
              field: EnvasesInfoField(label: 'Fecha de salida', value: _formatDate(widget.row.fechaSalida)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Detalle', style: typography.subtitle),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= kEnvasesDesktopBreakpoint;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isWide) _tablaHeader(context),
                for (final controller in lineas)
                  isWide ? _tablaFila(context, controller) : _tarjeta(context, controller),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Resumen', style: typography.subtitle),
        const SizedBox(height: 12),
        Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            EnvasesInfoField(label: 'Total enviado', value: _fmt(totalEnviado)),
            EnvasesInfoField(label: 'Total recibido', value: _fmt(totalRecibido)),
            EnvasesInfoField(label: 'Total dañados', value: _fmt(totalDanado)),
            EnvasesInfoField(label: 'Pendiente por recibir', value: _fmt(totalPendiente)),
          ],
        ),
        if (totalPendiente > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: InfoBar(
              key: const Key('envases-recibir-diferencias'),
              title: Text('Existen diferencias: quedan ${_fmt(totalPendiente)} envases pendientes por recibir.'),
              severity: InfoBarSeverity.info,
            ),
          ),
      ],
    );
  }

  Widget _tablaHeader(BuildContext context) {
    final style = FluentTheme.of(context).typography.bodyStrong;
    Widget columna(String label, double width) =>
        SizedBox(width: width, child: Text(label, style: style, textAlign: TextAlign.right));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 220, child: Text('')),
          const SizedBox(width: 16),
          columna('Enviados', 80),
          const SizedBox(width: 16),
          columna('Llegaron', 100),
          const SizedBox(width: 16),
          columna('Dañados', 100),
          const SizedBox(width: 16),
          columna('Aptos', 80),
          const SizedBox(width: 16),
          columna('Pendiente', 90),
        ],
      ),
    );
  }

  Widget _tablaFila(BuildContext context, _LineaControllers controller) {
    final theme = FluentTheme.of(context);
    final error = _errorDe(controller);
    final moveId = controller.linea.moveId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: Text(controller.linea.productName, style: theme.typography.body, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: Text(
                  '${_fmt(controller.linea.pendientes)} ${controller.linea.uomName}',
                  textAlign: TextAlign.right,
                  style: theme.typography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: NumberBox<double>(
                  key: Key('envases-recibir-llegaron-$moveId'),
                  value: controller.llegaronValue,
                  mode: SpinButtonPlacementMode.none,
                  textAlign: TextAlign.right,
                  onChanged: (value) {
                    setState(() => controller.llegaronValue = value);
                    _scheduleDraftSave();
                  },
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: NumberBox<double>(
                  key: Key('envases-recibir-danadas-$moveId'),
                  value: controller.danadasValue,
                  mode: SpinButtonPlacementMode.none,
                  textAlign: TextAlign.right,
                  onChanged: (value) {
                    setState(() => controller.danadasValue = value);
                    _scheduleDraftSave();
                  },
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: Text(
                  _fmt(controller.aptos),
                  key: Key('envases-recibir-aptos-$moveId'),
                  textAlign: TextAlign.right,
                  style: theme.typography.bodyStrong,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 90,
                child: Text(
                  _fmt(controller.pendiente),
                  key: Key('envases-recibir-pendiente-$moveId'),
                  textAlign: TextAlign.right,
                  style: theme.typography.bodyStrong?.copyWith(
                    color: controller.pendiente > 0 ? theme.resources.systemFillColorCritical : null,
                  ),
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: theme.typography.caption?.copyWith(color: theme.resources.systemFillColorCritical),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjeta(BuildContext context, _LineaControllers controller) {
    final theme = FluentTheme.of(context);
    final error = _errorDe(controller);
    final moveId = controller.linea.moveId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(controller.linea.productName, style: theme.typography.bodyStrong),
            const SizedBox(height: 4),
            Text(
              'Enviados: ${_fmt(controller.linea.pendientes)} ${controller.linea.uomName}',
              style: theme.typography.caption,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: EnvasesField(
                    label: 'Llegaron',
                    child: NumberBox<double>(
                      key: Key('envases-recibir-llegaron-$moveId'),
                      value: controller.llegaronValue,
                      mode: SpinButtonPlacementMode.inline,
                      onChanged: (value) {
                        setState(() => controller.llegaronValue = value);
                        _scheduleDraftSave();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EnvasesField(
                    label: 'Dañados',
                    child: NumberBox<double>(
                      key: Key('envases-recibir-danadas-$moveId'),
                      value: controller.danadasValue,
                      mode: SpinButtonPlacementMode.inline,
                      onChanged: (value) {
                        setState(() => controller.danadasValue = value);
                        _scheduleDraftSave();
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: EnvasesInfoField(
                    key: Key('envases-recibir-aptos-$moveId'),
                    label: 'Aptos',
                    value: _fmt(controller.aptos),
                  ),
                ),
                Expanded(
                  child: EnvasesInfoField(
                    key: Key('envases-recibir-pendiente-$moveId'),
                    label: 'Pendiente',
                    value: _fmt(controller.pendiente),
                  ),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: theme.typography.caption?.copyWith(color: theme.resources.systemFillColorCritical),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
