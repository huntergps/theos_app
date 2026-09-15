import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../../ui/state_labels.dart' show envasesCustodyRoleLabel;

/// Color de tema para cada estado local de una operación de envases.
///
/// Siempre un token de `FluentThemeData.resources` (`systemFillColor*`),
/// nunca un color cableado — por orden del dueño (11-sep-2026), *«todos los
/// listados deben tener el mismo aspecto»*. `revisarAMano` usa el acento en
/// vez de `systemFillColorAttention` porque esta versión de `fluent_ui` no
/// trae ese token en primer plano, sólo su variante de fondo.
Color envasesEstadoColor(FluentThemeData theme, EnvasesOperacionEstado estado) {
  final resources = theme.resources;
  return switch (estado) {
    EnvasesOperacionEstado.pendienteDeEnviar => resources.systemFillColorCaution,
    EnvasesOperacionEstado.enviada => resources.systemFillColorSuccess,
    EnvasesOperacionEstado.rechazada => resources.systemFillColorCritical,
    EnvasesOperacionEstado.revisarAMano => theme.accentColor.normal,
  };
}

/// Mismo texto que ya usaban `envases_por_recibir_screen.dart` y
/// `envases_traslado_detalle.dart`, ahora centralizado para que la tabla, la
/// tarjeta y la ficha de detalle digan siempre lo mismo.
String envasesEstadoLabel(EnvasesOperacionEstado estado, {String? mensajeOdoo}) =>
    switch (estado) {
      EnvasesOperacionEstado.pendienteDeEnviar => 'Pendiente de enviar',
      EnvasesOperacionEstado.enviada => 'Enviada',
      EnvasesOperacionEstado.rechazada => mensajeOdoo ?? 'Rechazada por Odoo',
      EnvasesOperacionEstado.revisarAMano => 'Revisar a mano',
    };

/// Color de tema para el rol de custodia de un tercero (Clientes de BODEGA).
/// Mismo criterio que [envasesEstadoColor]: un tercero que tiene envases
/// prestados (cliente) no se lee igual que uno que nos prestó a nosotros
/// (proveedor).
Color envasesCustodyRoleColor(FluentThemeData theme, String role) =>
    switch (role) {
      'custodia_cliente' => theme.accentColor.normal,
      'custodia_proveedor' => theme.resources.systemFillColorCaution,
      _ => theme.resources.systemFillColorSolidNeutral,
    };

/// Insignia de estado con el color del tema, para usarse tanto suelta (ficha
/// de detalle, tarjeta angosta) como fuente de `OrbiColumn.badgeColor` en la
/// tabla ancha de `OrbiListing` — mismo aspecto en los dos, porque es la
/// misma información. El color se pasa ya resuelto (por
/// [envasesEstadoColor]/[envasesCustodyRoleColor]) porque un `OrbiColumn`
/// pide un color por fila, no un `BuildContext`.
class ListaEstadoChip extends StatelessWidget {
  const ListaEstadoChip({super.key, required this.label, required this.color});

  /// Insignia de una operación local (enviar/recibir/perdido). Resuelve el
  /// color contra el tema vigente en `build()`.
  static Widget operacion(EnvasesOperacionLocal operacion, {Key? key}) =>
      _EstadoOperacionChip(key: key, operacion: operacion);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => _pill(label, color);
}

class _EstadoOperacionChip extends StatelessWidget {
  const _EstadoOperacionChip({super.key, required this.operacion});

  final EnvasesOperacionLocal operacion;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ListaEstadoChip(
      label: envasesEstadoLabel(operacion.estado, mensajeOdoo: operacion.mensajeOdoo),
      color: envasesEstadoColor(theme, operacion.estado),
    );
  }
}

/// Insignia de color para el rol de custodia de un tercero.
class ListaCustodyRoleChip extends StatelessWidget {
  const ListaCustodyRoleChip({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ListaEstadoChip(
      label: envasesCustodyRoleLabel(role),
      color: envasesCustodyRoleColor(theme, role),
    );
  }
}

Widget _pill(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.16),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    text,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
  ),
);
