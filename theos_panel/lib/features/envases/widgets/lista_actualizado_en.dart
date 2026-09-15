import 'package:fluent_ui/fluent_ui.dart';

/// «Última actualización: fecha hora», tal como aparece en las cuatro
/// láminas de listado aprobadas (ENV-01/02/03, BODEGA). Centralizado para que
/// las cuatro pantallas de Envases digan la fecha con el mismo formato — antes
/// sólo Existencias la mostraba.
class ListaActualizadoEn extends StatelessWidget {
  const ListaActualizadoEn({super.key, required this.cachedAt});

  final DateTime cachedAt;

  @override
  Widget build(BuildContext context) => Text(
    'Última actualización: ${_formatDate(cachedAt)}',
    style: FluentTheme.of(context).typography.caption,
  );
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
