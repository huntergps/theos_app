import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../app/theme/orbi_theme.dart';
import '../../ui/components/orbi_components.dart';
import '../../ui/export/export_listing.dart';
import '../../ui/fluent/orbi_page.dart';
import 'envases_existencias_contracts.dart';

/// «Estado de envases» (lámina aprobada ENV-01, ronda 2).
///
/// Lee exclusivamente por [EnvasesExistenciasRepository.watch]: la copia
/// local reactiva que expone `EnvasesExistenciasCache`. Una vez que un ciclo
/// de sincronización deja una copia nueva en SQLite, esta pantalla se
/// actualiza sola — nunca vuelve a preguntarle a Odoo sólo porque está en
/// pantalla.
///
/// Ni una sede ni un sentido de tránsito están escritos aquí: cada columna
/// de la rejilla sale, en el orden que entregue el servidor, de
/// `l10n_ec.envases.existencias.datos()` (`EnvasesExistenciasReader`). Eso
/// incluye las columnas `custodia_cliente`/`custodia_proveedor` — "Clientes"
/// y "Proveedores" de la lámina no son un caso especial: son una ubicación
/// más, con su propio `tipo`.
///
/// En ancho grande (escritorio) sigue pintando el `OrbiListing` estándar:
/// rejilla + `Total` como última columna. Por debajo del corte de tarjeta
/// (`OrbiListing.cardBreakpoint`, el mismo `OrbiTheme.mediumBreakpoint`), la
/// ficha por producto es a medida de esta pantalla (`OrbiListing.cardBuilder`)
/// porque la lámina pide algo que la ficha genérica no ofrece: foto,
/// insignia de acento, una flecha que pliega/despliega las ubicaciones, y
/// las propias ubicaciones en tres columnas (tableta) o una fila cada una
/// (teléfono) — sin la fila «Total» suelta, porque la insignia ya es el
/// total.
class EnvasesExistenciasScreen extends StatefulWidget {
  const EnvasesExistenciasScreen({super.key, required this.repository, this.onExport});

  final EnvasesExistenciasRepository repository;
  final ListingExporter? onExport;

  @override
  State<EnvasesExistenciasScreen> createState() =>
      _EnvasesExistenciasScreenState();
}

class _EnvasesExistenciasScreenState extends State<EnvasesExistenciasScreen> {
  bool _refreshing = false;
  Object? _refreshError;
  String _productQuery = '';

  /// `null` en los tres es "Todas" — el valor por omisión de la lámina.
  String? _filtroProducto;
  String? _filtroPresentacion;
  String? _filtroUbicacion;

  // Capturado una sola vez: `watch()` debe seguir siendo la misma
  // suscripción entre reconstrucciones (escribir en el filtro reconstruye
  // este widget en cada tecla). Volver a llamar a `widget.repository.watch()`
  // desde `build()` resuscribiría en cada reconstrucción en vez de reusar un
  // único flujo vivo.
  late final Stream<EnvasesExistenciasSnapshot?> _snapshots =
      widget.repository.watch();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      await widget.repository.refresh();
    } catch (error) {
      if (mounted) setState(() => _refreshError = error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => OrbiPage(
    title: 'Estado de envases',
    commands: [
      CommandBarButton(
        key: const Key('envases-existencias-refresh-button'),
        icon: _refreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            : const Icon(FluentIcons.refresh),
        label: const Text('Actualizar'),
        tooltip: 'Actualizar existencias de envases',
        onPressed: _refreshing ? null : _refresh,
      ),
    ],
    child: StreamBuilder<EnvasesExistenciasSnapshot?>(
      // Esta suscripción es lo que hace que la pantalla reaccione sola a una
      // sincronización terminada: `EnvasesExistenciasCache.watch()` vuelve a
      // emitir cuando la tabla local cambia, sin que este widget lo pida.
      stream: _snapshots,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return OrbiErrorState(
            message: 'No se pudo leer la copia local de existencias.',
            onRetry: _refresh,
          );
        }
        final value = snapshot.data;
        if (value == null) {
          if (_refreshError != null) {
            return OrbiErrorState(
              message: 'No se pudo actualizar las existencias de envases.',
              onRetry: _refresh,
            );
          }
          return const Center(
            child: ProgressRing(key: Key('envases-existencias-loading')),
          );
        }
        return _body(context, value);
      },
    ),
  );

  Widget _body(BuildContext context, EnvasesExistenciasSnapshot snapshot) {
    final data = snapshot.data;
    final rows = _filteredRows(data.filas);
    final columnas = _filteredColumnas(data.columnas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, snapshot),
        if (_refreshError != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(onRetry: _refresh),
        ],
        const SizedBox(height: 12),
        _filtersRow(context, data),
        const SizedBox(height: 12),
        Expanded(
          child: data.filas.isEmpty
              ? const OrbiEmptyState(
                  title: 'Sin existencias',
                  message: 'No hay productos con existencia de envases.',
                )
              : Card(
                  backgroundColor: FluentTheme.of(
                    context,
                  ).scaffoldBackgroundColor,
                  borderColor: FluentTheme.of(
                    context,
                  ).resources.surfaceStrokeColorDefault,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.all(8),
                  child: OrbiListing<EnvasesExistenciasRow>(
                    rows: rows,
                    columns: _columns(columnas),
                    storageKey: 'envases-existencias',
                    filterText: _productQuery,
                    onFilterChanged: (value) => setState(
                      () => _productQuery = value.trim().toLowerCase(),
                    ),
                    filterPlaceholder: 'Filtrar por producto o unidad',
                    onExport: widget.onExport == null
                        ? null
                        : (bytes, name) => widget.onExport!(context, bytes, name),
                    exportFileName: 'envases-existencias',
                    emptyMessage: 'No hay productos que coincidan con el filtro.',
                    cardBuilder: _buildCard,
                  ),
                ),
        ),
      ],
    );
  }

  List<EnvasesExistenciasRow> _filteredRows(List<EnvasesExistenciasRow> rows) {
    var result = rows;
    if (_filtroProducto case final producto?) {
      result = result
          .where((row) => row.nombre == producto)
          .toList(growable: false);
    }
    if (_filtroPresentacion case final presentacion?) {
      result = result
          .where((row) => row.uom == presentacion)
          .toList(growable: false);
    }
    if (_productQuery.isNotEmpty) {
      result = result
          .where(
            (row) =>
                row.nombre.toLowerCase().contains(_productQuery) ||
                row.uom.toLowerCase().contains(_productQuery),
          )
          .toList(growable: false);
    }
    return result;
  }

  /// Filtrar por «Ubicación» no esconde filas: dejar sólo esa columna
  /// (tabla) o esa fila de detalle (tarjeta), en el mismo lugar donde ya
  /// viven las demás ubicaciones — nunca un camino aparte.
  List<EnvasesExistenciasColumn> _filteredColumnas(
    List<EnvasesExistenciasColumn> columnas,
  ) {
    if (_filtroUbicacion case final ubicacion?) {
      return columnas
          .where((columna) => columna.nombre == ubicacion)
          .toList(growable: false);
    }
    return columnas;
  }

  /// Columnas de la rejilla: producto, unidad, una por cada `columna` que
  /// entregó `datos()` (en su mismo orden) y, al final, el total — nunca un
  /// nombre de sede o de sentido cableado aquí.
  List<OrbiColumn<EnvasesExistenciasRow>> _columns(
    List<EnvasesExistenciasColumn> columnas,
  ) => [
    OrbiColumn(
      key: 'product',
      label: 'Producto',
      value: (row) => row.nombre,
      alwaysVisible: true,
    ),
    OrbiColumn(
      key: 'uom',
      label: 'Unidad',
      value: (row) => row.uom,
      subtitle: true,
    ),
    for (final columna in columnas)
      OrbiColumn<EnvasesExistenciasRow>(
        key: 'col-${columna.id}',
        label: columna.nombre,
        numeric: true,
        metric: true,
        value: (row) => _formatQuantity(row.celdas[columna.id] ?? 0),
      ),
    OrbiColumn(
      key: 'total',
      label: 'Total',
      numeric: true,
      emphasis: true,
      value: (row) => _formatQuantity(row.total),
    ),
  ];

  /// La ficha a medida de esta pantalla (`OrbiListing.cardBuilder`): foto,
  /// nombre + unidad, insignia de acento y una flecha que pliega/despliega
  /// las ubicaciones — nunca la fila «Total» suelta, porque la insignia ya
  /// es el total.
  Widget _buildCard(
    BuildContext context,
    EnvasesExistenciasRow row,
    List<OrbiColumn<EnvasesExistenciasRow>> columns,
    double width,
  ) {
    String? subtitulo;
    final ubicaciones = <_UbicacionValor>[];
    for (final column in columns) {
      if (column.subtitle) {
        subtitulo = column.value(row);
      } else if (column.metric) {
        ubicaciones.add(
          _UbicacionValor(nombre: column.label, valor: column.value(row)),
        );
      }
    }
    return _EnvasesProductCard(
      key: ValueKey('envases-existencias-card-${row.id}'),
      nombre: row.nombre,
      subtitulo: subtitulo,
      totalTexto: '${_formatQuantity(row.total)} propios',
      imagenBase64: row.imagenBase64,
      ubicaciones: ubicaciones,
      width: width,
    );
  }

  /// Producto/Presentación/Ubicación, siempre en una sola fila (también en
  /// teléfono, tal como la lámina) — orden del dueño: los desplegables van
  /// SOBRE el buscador de texto, que se conserva debajo.
  Widget _filtersRow(BuildContext context, EnvasesExistenciasData data) {
    final productos = data.filas.map((fila) => fila.nombre).toSet().toList()
      ..sort();
    final presentaciones = data.filas.map((fila) => fila.uom).toSet().toList()
      ..sort();
    final ubicaciones = <String>{
      for (final columna in data.columnas) columna.nombre,
    }.toList(growable: false);
    return Row(
      children: [
        Expanded(
          child: _FiltroCombo(
            key: const Key('envases-existencias-filtro-producto'),
            label: 'Producto',
            value: _filtroProducto,
            opciones: productos,
            onChanged: (value) => setState(() => _filtroProducto = value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FiltroCombo(
            key: const Key('envases-existencias-filtro-presentacion'),
            label: 'Presentación',
            value: _filtroPresentacion,
            opciones: presentaciones,
            onChanged: (value) => setState(() => _filtroPresentacion = value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FiltroCombo(
            key: const Key('envases-existencias-filtro-ubicacion'),
            label: 'Ubicación',
            value: _filtroUbicacion,
            opciones: ubicaciones,
            onChanged: (value) => setState(() => _filtroUbicacion = value),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, EnvasesExistenciasSnapshot snapshot) {
    final typography = FluentTheme.of(context).typography;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El título de la pantalla ya lo pinta `OrbiPage` (una sola vez);
          // aquí sólo va lo que lo acompaña, nunca el título repetido —
          // defecto medido el 15-sep-2026 contra la lámina aprobada.
          Text(
            'Última actualización en este equipo: ${_formatDate(snapshot.cachedAt)}',
            style: typography.body,
          ),
          const SizedBox(height: 12),
          _PendingWork(pendientes: snapshot.data.pendientes),
        ],
      ),
    );
  }
}

/// Un desplegable Fluent con su etiqueta, con "Todas" (`null`) por omisión —
/// mismo widget para los tres filtros de la lámina, sólo cambian la etiqueta
/// y las opciones.
class _FiltroCombo extends StatelessWidget {
  const _FiltroCombo({
    super.key,
    required this.label,
    required this.value,
    required this.opciones,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => InfoLabel(
    label: label,
    child: ComboBox<String?>(
      isExpanded: true,
      value: value,
      placeholder: const Text('Todas'),
      items: [
        const ComboBoxItem<String?>(value: null, child: Text('Todas')),
        for (final opcion in opciones)
          ComboBoxItem<String?>(
            value: opcion,
            child: Text(opcion, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}

/// Una ubicación ya resuelta a texto (nombre de columna + cifra formateada)
/// — el detalle de la tarjeta no vuelve a tocar `EnvasesExistenciasColumn`.
class _UbicacionValor {
  const _UbicacionValor({required this.nombre, required this.valor});
  final String nombre;
  final String valor;
}

/// La tarjeta de producto de la lámina aprobada: foto, nombre + unidad,
/// insignia de acento a la derecha, y una flecha (`Expander`) que pliega o
/// despliega las ubicaciones — desplegada por omisión.
class _EnvasesProductCard extends StatelessWidget {
  const _EnvasesProductCard({
    super.key,
    required this.nombre,
    required this.subtitulo,
    required this.totalTexto,
    required this.imagenBase64,
    required this.ubicaciones,
    required this.width,
  });

  final String nombre;
  final String? subtitulo;
  final String totalTexto;
  final String? imagenBase64;
  final List<_UbicacionValor> ubicaciones;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Expander(
      initiallyExpanded: true,
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProductThumbnail(imagenBase64: imagenBase64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: theme.typography.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitulo != null)
                  Text(subtitulo!, style: theme.typography.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AccentChip(text: totalTexto),
        ],
      ),
      content: ubicaciones.isEmpty
          ? Text(
              'Sin ubicaciones con existencia.',
              style: theme.typography.caption,
            )
          : (width < OrbiTheme.compactBreakpoint
                ? _UbicacionesFilas(ubicaciones: ubicaciones)
                : _UbicacionesGrid(ubicaciones: ubicaciones)),
    );
  }
}

/// Miniatura de producto de tamaño fijo. `product.product.image_128` sólo
/// llega si `EnvasesExistenciasReader.readImages` la confirmó con
/// `fields_get` y `EnvasesExistenciasCache.mergeImages` ya la fusionó en la
/// copia local — por eso funciona sin conexión igual que el resto de la
/// pantalla. Un `null`, o una foto que no decodifica, cae al ícono de
/// Fluent de producto, nunca rompe la tarjeta.
class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.imagenBase64});

  final String? imagenBase64;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    if (imagenBase64 case final imagen?) {
      try {
        final bytes = base64Decode(imagen);
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            bytes,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallback(context),
          ),
        );
      } catch (_) {
        return _fallback(context);
      }
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final resources = FluentTheme.of(context).resources;
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(FluentIcons.product, size: 20),
    );
  }
}

/// La insignia «N propios»: relleno sólido del acento con el texto «sobre
/// acento» del propio tema — el mismo par que usa `InfoBadge` de fluent_ui,
/// no un tinte inventado aquí.
///
/// 🔴 Historial del 15-sep-2026, dos vueltas:
/// 1. `accentColor.normal` a secas se leía mal en tema oscuro (acento oscuro
///    sobre fondo oscuro, medido en `telefono-oscuro.png`): `.normal` es el
///    MISMO tono en los dos temas, no el que Fluent elige por brillo.
/// 2. Cambiar sólo el TEXTO a `defaultBrushFor(brightness)` manteniendo un
///    fondo apenas teñido (alpha 0.16) tampoco alcanzaba 4.5:1: para esta
///    marca (`#017E84`, ya oscura de por sí) ninguna variante de acento
///    "clara" (`lighter`/`lightest`, 30-38% hacia blanco) es lo bastante
///    clara sobre un fondo prácticamente negro — medido: contraste 1.28.
///
/// La solución no es afinar un tinte a mano: es copiar el PAR que usa Fluent
/// para esta misma forma (una insignia de color) —
/// `InfoBadge.build` en `fluent_ui-4.16.1/lib/src/controls/utils/info_badge.dart:81-93` —
/// fondo sólido `accentColor.defaultBrushFor(brightness)` (línea 347-352 de
/// `styles/color.dart`) más texto `resources.textOnAccentFillColorPrimary`,
/// que Fluent ya calibró para tener buen contraste contra ESE fondo exacto
/// en cada tema (blanco en claro, negro en oscuro — `color_resources.dart`
/// líneas 197 y 284).
class _AccentChip extends StatelessWidget {
  const _AccentChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final background = theme.accentColor.defaultBrushFor(theme.brightness);
    final foreground = theme.resources.textOnAccentFillColorPrimary;
    return Container(
      key: const Key('envases-existencias-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Ancho medio (tableta): rejilla de tres columnas sobre el fondo de la
/// propia tarjeta, separadas por líneas finas del tema — nunca bloques
/// grises rellenos.
class _UbicacionesGrid extends StatelessWidget {
  const _UbicacionesGrid({required this.ubicaciones});

  final List<_UbicacionValor> ubicaciones;

  static const _columnas = 3;

  @override
  Widget build(BuildContext context) {
    final divider = FluentTheme.of(context).resources.dividerStrokeColorDefault;
    final filas = <TableRow>[];
    for (var i = 0; i < ubicaciones.length; i += _columnas) {
      filas.add(
        TableRow(
          children: [
            for (var c = 0; c < _columnas; c++)
              i + c < ubicaciones.length
                  ? _celda(context, ubicaciones[i + c])
                  : const SizedBox.shrink(),
          ],
        ),
      );
    }
    return Table(
      border: TableBorder.symmetric(inside: BorderSide(color: divider)),
      children: filas,
    );
  }

  Widget _celda(BuildContext context, _UbicacionValor ubicacion) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ubicacion.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(ubicacion.valor, style: theme.typography.bodyStrong),
        ],
      ),
    );
  }
}

/// Ancho compacto (teléfono): una fila por ubicación, nombre a la izquierda
/// y cifra a la derecha, con un divisor fino entre filas — nunca bloques
/// grises apilados.
class _UbicacionesFilas extends StatelessWidget {
  const _UbicacionesFilas({required this.ubicaciones});

  final List<_UbicacionValor> ubicaciones;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < ubicaciones.length; i++) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ubicaciones[i].nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(ubicaciones[i].valor, style: theme.typography.bodyStrong),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// «Trabajo de hoy», acotado en este encargo a la cifra `pendientes` de
/// `datos()`: sólo el número, sin abrir la lista de traslados por recibir —
/// esa lista es otro encargo.
class _PendingWork extends StatelessWidget {
  const _PendingWork({required this.pendientes});

  final int pendientes;

  @override
  Widget build(BuildContext context) {
    final resources = FluentTheme.of(context).resources;
    final theme = FluentTheme.of(context);
    return Container(
      key: const Key('envases-existencias-pendientes'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.delivery_truck, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Trabajo de hoy · Traslados por recibir:',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text('$pendientes', style: theme.typography.bodyStrong),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final resources = FluentTheme.of(context).resources;
    return Card(
      backgroundColor: resources.systemFillColorCriticalBackground,
      borderColor: resources.systemFillColorCritical,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(FluentIcons.error_badge, color: resources.systemFillColorCritical),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No se pudo actualizar las existencias.'),
                Text('Se conserva la última copia disponible.'),
              ],
            ),
          ),
          if (onRetry != null)
            Button(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
