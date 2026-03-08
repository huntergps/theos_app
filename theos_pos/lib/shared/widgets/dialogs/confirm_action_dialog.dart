import 'package:fluent_ui/fluent_ui.dart';

/// Dialogo de confirmacion reutilizable para acciones importantes.
///
/// Proporciona una forma consistente de solicitar confirmacion al usuario
/// antes de ejecutar acciones potencialmente destructivas o irreversibles.
///
/// Ejemplo de uso:
/// ```dart
/// final confirmed = await ConfirmActionDialog.show(
///   context,
///   title: 'Eliminar producto',
///   message: 'Esta accion no se puede deshacer. El producto sera eliminado permanentemente.',
///   confirmText: 'Eliminar',
///   confirmColor: Colors.red,
///   icon: FluentIcons.delete,
/// );
///
/// if (confirmed) {
///   await deleteProduct();
/// }
/// ```
class ConfirmActionDialog extends StatelessWidget {
  /// Titulo del dialogo.
  final String title;

  /// Mensaje descriptivo de la accion a confirmar.
  final String message;

  /// Texto del boton de confirmacion.
  final String confirmText;

  /// Texto del boton de cancelacion.
  final String cancelText;

  /// Color del boton de confirmacion.
  /// Por defecto usa el color de acento del tema.
  final Color? confirmColor;

  /// Icono opcional para mostrar junto al titulo.
  final IconData? icon;

  /// Color del icono.
  /// Si no se especifica, usa el color de confirmacion o el de acento.
  final Color? iconColor;

  /// Widget de contenido adicional debajo del mensaje.
  final Widget? additionalContent;

  /// Si es true, el boton de confirmacion tiene estilo destructivo (rojo).
  final bool isDestructive;

  const ConfirmActionDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirmar',
    this.cancelText = 'Cancelar',
    this.confirmColor,
    this.icon,
    this.iconColor,
    this.additionalContent,
    this.isDestructive = false,
  });

  /// Muestra el dialogo de confirmacion y retorna true si el usuario confirma.
  ///
  /// Parametros:
  /// - [context]: El BuildContext para mostrar el dialogo.
  /// - [title]: Titulo del dialogo.
  /// - [message]: Mensaje descriptivo.
  /// - [confirmText]: Texto del boton de confirmacion (default: 'Confirmar').
  /// - [cancelText]: Texto del boton de cancelacion (default: 'Cancelar').
  /// - [confirmColor]: Color del boton de confirmacion.
  /// - [icon]: Icono opcional.
  /// - [iconColor]: Color del icono.
  /// - [additionalContent]: Widget adicional.
  /// - [isDestructive]: Si es true, usa estilo destructivo.
  /// - [barrierDismissible]: Si es true, se puede cerrar tocando fuera.
  ///
  /// Retorna [true] si el usuario confirma, [false] si cancela o cierra.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    Color? confirmColor,
    IconData? icon,
    Color? iconColor,
    Widget? additionalContent,
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ConfirmActionDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        icon: icon,
        iconColor: iconColor,
        additionalContent: additionalContent,
        isDestructive: isDestructive,
      ),
    );

    return result ?? false;
  }

  /// Muestra un dialogo de confirmacion para eliminar un elemento.
  ///
  /// Preconfigurado con estilo destructivo, icono de eliminar y
  /// textos apropiados para acciones de eliminacion.
  static Future<bool> showDelete(
    BuildContext context, {
    required String itemName,
    String? customMessage,
  }) {
    return show(
      context,
      title: 'Eliminar $itemName',
      message:
          customMessage ??
          'Esta accion eliminara "$itemName" de forma permanente. Esta seguro de continuar?',
      confirmText: 'Eliminar',
      icon: FluentIcons.delete,
      isDestructive: true,
    );
  }

  /// Muestra un dialogo de confirmacion para descartar cambios.
  ///
  /// Preconfigurado para advertir sobre perdida de cambios no guardados.
  static Future<bool> showDiscardChanges(BuildContext context) {
    return show(
      context,
      title: 'Descartar cambios',
      message:
          'Tiene cambios sin guardar que se perderan. Esta seguro de continuar?',
      confirmText: 'Descartar',
      cancelText: 'Continuar editando',
      icon: FluentIcons.warning,
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final effectiveConfirmColor = isDestructive
        ? Colors.red
        : (confirmColor ?? theme.accentColor);
    final effectiveIconColor = iconColor ?? effectiveConfirmColor;

    return ContentDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: effectiveIconColor),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(title, style: theme.typography.subtitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: theme.typography.body),
          if (additionalContent != null) ...[
            const SizedBox(height: 16),
            additionalContent!,
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return effectiveConfirmColor.withValues(alpha: 0.8);
              }
              if (states.contains(WidgetState.hovered)) {
                return effectiveConfirmColor.withValues(alpha: 0.9);
              }
              return effectiveConfirmColor;
            }),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// Dialogo de confirmacion con campo de texto para validacion adicional.
///
/// Requiere que el usuario escriba un texto especifico para confirmar,
/// util para acciones muy criticas como eliminar cuentas o datos masivos.
///
/// Ejemplo de uso:
/// ```dart
/// final confirmed = await ConfirmWithTextDialog.show(
///   context,
///   title: 'Eliminar cuenta',
///   message: 'Esta accion eliminara su cuenta y todos sus datos.',
///   confirmationText: 'ELIMINAR',
///   hint: 'Escriba ELIMINAR para confirmar',
/// );
/// ```
class ConfirmWithTextDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmationText;
  final String hint;
  final String confirmText;
  final String cancelText;
  final IconData? icon;

  const ConfirmWithTextDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmationText,
    this.hint = 'Escriba para confirmar',
    this.confirmText = 'Confirmar',
    this.cancelText = 'Cancelar',
    this.icon,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmationText,
    String? hint,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmWithTextDialog(
        title: title,
        message: message,
        confirmationText: confirmationText,
        hint: hint ?? 'Escriba "$confirmationText" para confirmar',
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
      ),
    );

    return result ?? false;
  }

  @override
  State<ConfirmWithTextDialog> createState() => _ConfirmWithTextDialogState();
}

class _ConfirmWithTextDialogState extends State<ConfirmWithTextDialog> {
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validateInput);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateInput() {
    final isValid = _controller.text == widget.confirmationText;
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 24, color: Colors.red),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(widget.title, style: theme.typography.subtitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message, style: theme.typography.body),
          const SizedBox(height: 16),
          InfoBar(
            title: Text('Escriba "${widget.confirmationText}" para confirmar'),
            severity: InfoBarSeverity.warning,
          ),
          const SizedBox(height: 12),
          TextBox(
            controller: _controller,
            placeholder: widget.hint,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(widget.cancelText),
        ),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (!_isValid) {
                return theme.inactiveColor.withValues(alpha: 0.5);
              }
              if (states.contains(WidgetState.pressed)) {
                return Colors.red.withValues(alpha: 0.8);
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.red.withValues(alpha: 0.9);
              }
              return Colors.red;
            }),
          ),
          onPressed: _isValid ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
