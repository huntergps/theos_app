import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuración para BaseFormDialog
class FormDialogConfig {
  /// Título del diálogo
  final String title;

  /// Icono del título (opcional)
  final IconData? icon;

  /// Color del icono (usa accentColor si es null)
  final Color? iconColor;

  /// Descripción/ayuda (opcional, mostrada bajo el título)
  final String? description;

  /// Ancho máximo del diálogo
  final double maxWidth;

  /// Alto máximo del diálogo
  final double? maxHeight;

  /// Texto del botón principal
  final String primaryButtonText;

  /// Texto del botón cancelar
  final String cancelButtonText;

  /// Si mostrar botón de cerrar en header
  final bool showCloseButton;

  /// Si el contenido es scrollable
  final bool scrollable;

  /// Padding del contenido
  final EdgeInsets contentPadding;

  /// Si el botón principal está habilitado (por defecto true)
  final bool isPrimaryEnabled;

  const FormDialogConfig({
    required this.title,
    this.icon,
    this.iconColor,
    this.description,
    this.maxWidth = 500,
    this.maxHeight,
    this.primaryButtonText = 'Guardar',
    this.cancelButtonText = 'Cancelar',
    this.showCloseButton = false,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(0),
    this.isPrimaryEnabled = true,
  });

  /// Copia la configuración con nuevos valores
  FormDialogConfig copyWith({
    String? title,
    IconData? icon,
    Color? iconColor,
    String? description,
    double? maxWidth,
    double? maxHeight,
    String? primaryButtonText,
    String? cancelButtonText,
    bool? showCloseButton,
    bool? scrollable,
    EdgeInsets? contentPadding,
    bool? isPrimaryEnabled,
  }) {
    return FormDialogConfig(
      title: title ?? this.title,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      description: description ?? this.description,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight,
      primaryButtonText: primaryButtonText ?? this.primaryButtonText,
      cancelButtonText: cancelButtonText ?? this.cancelButtonText,
      showCloseButton: showCloseButton ?? this.showCloseButton,
      scrollable: scrollable ?? this.scrollable,
      contentPadding: contentPadding ?? this.contentPadding,
      isPrimaryEnabled: isPrimaryEnabled ?? this.isPrimaryEnabled,
    );
  }
}

/// Estado de validación del formulario
class FormValidationState {
  final bool isValid;
  final List<String> errors;

  const FormValidationState({
    this.isValid = true,
    this.errors = const [],
  });

  const FormValidationState.valid() : isValid = true, errors = const [];
  
  const FormValidationState.invalid(this.errors) : isValid = false;

  factory FormValidationState.fromErrors(List<String?> errors) {
    final filtered = errors.whereType<String>().toList();
    return filtered.isEmpty
        ? const FormValidationState.valid()
        : FormValidationState.invalid(filtered);
  }
}

/// Clase base abstracta para diálogos de formulario.
///
/// Implementa la estructura común:
/// - Header con título y botón cerrar
/// - Contenido del formulario (buildForm)
/// - Footer con botones Guardar/Cancelar
/// - Manejo de estado de carga
/// - Validación
///
/// Uso:
/// ```dart
/// class CreatePartnerDialog extends BaseFormDialog<PartnerData> {
///   const CreatePartnerDialog({super.key});
///
///   @override
///   FormDialogConfig get config => const FormDialogConfig(
///     title: 'Crear Cliente',
///     primaryButtonText: 'Crear',
///   );
///
///   @override
///   Widget buildForm(BuildContext context, WidgetRef ref) {
///     return Column(children: [
///       FormTextField(label: 'Nombre', ...),
///       FormTextField(label: 'RUC', ...),
///     ]);
///   }
///
///   @override
///   FormValidationState validate(WidgetRef ref) {
///     return FormValidationState.fromErrors([
///       if (name.isEmpty) 'El nombre es requerido',
///       if (vat.isEmpty) 'El RUC es requerido',
///     ]);
///   }
///
///   @override
///   Future<PartnerData?> onSubmit(WidgetRef ref) async {
///     return await createPartner();
///   }
/// }
/// ```
abstract class BaseFormDialog<T> extends ConsumerStatefulWidget {
  const BaseFormDialog({super.key});

  /// Configuración del diálogo
  FormDialogConfig get config;

  @override
  ConsumerState<BaseFormDialog<T>> createState() => _BaseFormDialogState<T>();
}

/// Mixin para proveer métodos de construcción del formulario
mixin FormDialogMixin<T> on ConsumerState<BaseFormDialog<T>> {
  /// Construye el contenido del formulario
  Widget buildForm(BuildContext context, WidgetRef ref);

  /// Valida el formulario antes de submit
  FormValidationState validate(WidgetRef ref) => const FormValidationState.valid();

  /// Ejecuta la acción principal (guardar)
  Future<T?> onSubmit(WidgetRef ref);

  /// Callback opcional al cancelar
  void onCancel() {}

  /// Widget opcional para mostrar errores de validación
  Widget? buildValidationErrors(BuildContext context, List<String> errors) {
    return null; // El diálogo base maneja esto
  }

  /// Widget opcional para acciones adicionales en el footer
  Widget? buildAdditionalActions(BuildContext context, WidgetRef ref) {
    return null;
  }
}

class _BaseFormDialogState<T> extends ConsumerState<BaseFormDialog<T>>
    with FormDialogMixin<T> {
  bool _isLoading = false;
  List<String> _validationErrors = [];

  FormDialogConfig get _config => widget.config;

  @override
  Widget buildForm(BuildContext context, WidgetRef ref) {
    throw UnimplementedError('Subclass must implement buildForm');
  }

  @override
  Future<T?> onSubmit(WidgetRef ref) {
    throw UnimplementedError('Subclass must implement onSubmit');
  }

  Future<void> _handleSubmit() async {
    // Validar
    final validation = validate(ref);
    if (!validation.isValid) {
      setState(() => _validationErrors = validation.errors);
      return;
    }

    setState(() {
      _isLoading = true;
      _validationErrors = [];
    });

    try {
      final result = await onSubmit(ref);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _validationErrors = ['Error al procesar. Intente nuevamente.'];
        });
      }
    }
  }

  void _handleCancel() {
    onCancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: _config.maxWidth,
        maxHeight: _config.maxHeight ?? MediaQuery.of(context).size.height * 0.9,
      ),
      title: Row(
        children: [
          if (_config.icon != null) ...[
            Icon(
              _config.icon,
              color: _config.iconColor ?? theme.accentColor,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              _config.title,
              style: theme.typography.subtitle,
            ),
          ),
          if (_config.showCloseButton)
            IconButton(
              icon: const Icon(FluentIcons.chrome_close),
              onPressed: _handleCancel,
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Descripción opcional
          if (_config.description != null) ...[
            _buildDescriptionBanner(theme),
            const SizedBox(height: 16),
          ],
          // Errores de validación
          if (_validationErrors.isNotEmpty) ...[
            _buildValidationBanner(theme),
            const SizedBox(height: 16),
          ],
          // Contenido del formulario
          if (_config.scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: _config.contentPadding,
                child: buildForm(context, ref),
              ),
            )
          else
            Padding(
              padding: _config.contentPadding,
              child: buildForm(context, ref),
            ),
        ],
      ),
      actions: [
        // Acciones adicionales
        if (buildAdditionalActions(context, ref) != null)
          buildAdditionalActions(context, ref)!,
        const Spacer(),
        // Botón cancelar
        Button(
          onPressed: _isLoading ? null : _handleCancel,
          child: Text(_config.cancelButtonText),
        ),
        const SizedBox(width: 8),
        // Botón principal
        FilledButton(
          onPressed: (_isLoading || !_config.isPrimaryEnabled) ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Text(_config.primaryButtonText),
        ),
      ],
    );
  }

  Widget _buildDescriptionBanner(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.inactiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.info,
            size: 16,
            color: theme.inactiveColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _config.description!,
              style: theme.typography.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationBanner(FluentThemeData theme) {
    return InfoBar(
      title: Text(
        _validationErrors.length == 1
            ? 'Error de validación'
            : 'Errores de validación',
      ),
      content: Text(
        _validationErrors.length == 1
            ? _validationErrors.first
            : _validationErrors.map((e) => '• $e').join('\n'),
      ),
      severity: InfoBarSeverity.error,
      isLong: _validationErrors.length > 1,
      onClose: () => setState(() => _validationErrors = []),
    );
  }
}

/// Versión simplificada de BaseFormDialog que usa un builder pattern
///
/// Uso:
/// ```dart
/// SimpleFormDialog<bool>(
///   config: FormDialogConfig(title: 'Confirmar'),
///   builder: (context, ref) => Text('¿Está seguro?'),
///   onSubmit: (ref) async => true,
/// )
/// ```
class SimpleFormDialog<T> extends ConsumerStatefulWidget {
  final FormDialogConfig config;
  final Widget Function(BuildContext context, WidgetRef ref) builder;
  final Future<T?> Function(WidgetRef ref) onSubmit;
  final FormValidationState Function(WidgetRef ref)? validator;

  const SimpleFormDialog({
    super.key,
    required this.config,
    required this.builder,
    required this.onSubmit,
    this.validator,
  });

  @override
  ConsumerState<SimpleFormDialog<T>> createState() => _SimpleFormDialogState<T>();
}

class _SimpleFormDialogState<T> extends ConsumerState<SimpleFormDialog<T>> {
  bool _isLoading = false;
  List<String> _errors = [];

  Future<void> _handleSubmit() async {
    if (widget.validator != null) {
      final validation = widget.validator!(ref);
      if (!validation.isValid) {
        setState(() => _errors = validation.errors);
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errors = [];
    });

    try {
      final result = await widget.onSubmit(ref);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errors = ['Error al procesar. Intente nuevamente.'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: widget.config.maxWidth,
        maxHeight: widget.config.maxHeight ?? MediaQuery.of(context).size.height * 0.9,
      ),
      title: Text(widget.config.title, style: theme.typography.subtitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errors.isNotEmpty) ...[
            InfoBar(
              title: const Text('Error'),
              content: Text(_errors.join('\n')),
              severity: InfoBarSeverity.error,
              onClose: () => setState(() => _errors = []),
            ),
            const SizedBox(height: 16),
          ],
          widget.builder(context, ref),
        ],
      ),
      actions: [
        Button(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(widget.config.cancelButtonText),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Text(widget.config.primaryButtonText),
        ),
      ],
    );
  }
}

// =============================================================================
// STATEFUL FORM DIALOG - Versión sin Riverpod
// =============================================================================

/// Versión de BaseFormDialog que NO requiere Riverpod.
/// 
/// Útil para diálogos simples que no necesitan state management global.
/// 
/// Uso:
/// ```dart
/// class CashCountDialog extends StatefulFormDialog<CollectionSessionCash> {
///   final String title;
///   final CashType cashType;
///   
///   const CashCountDialog({super.key, required this.title, required this.cashType});
///   
///   @override
///   FormDialogConfig get config => FormDialogConfig(
///     title: title,
///     icon: cashType == CashType.opening ? FluentIcons.unlock : FluentIcons.lock,
///     primaryButtonText: 'Confirmar',
///   );
///   
///   @override
///   StatefulFormDialogState<CollectionSessionCash, CashCountDialog> createState() => 
///     _CashCountDialogState();
/// }
/// 
/// class _CashCountDialogState 
///     extends StatefulFormDialogState<CollectionSessionCash, CashCountDialog> {
///   late CashCountState _cashCountState;
///   
///   @override
///   void initState() {
///     super.initState();
///     _cashCountState = CashCountState.initial();
///   }
///   
///   @override
///   Widget buildForm(BuildContext context) {
///     return ReactiveCashCountField(...);
///   }
///   
///   @override
///   Future<CollectionSessionCash?> onSubmit() async {
///     return CollectionSessionCash(...);
///   }
/// }
/// ```
abstract class StatefulFormDialog<T> extends StatefulWidget {
  const StatefulFormDialog({super.key});

  /// Configuración del diálogo
  FormDialogConfig get config;

  @override
  StatefulFormDialogState<T, StatefulFormDialog<T>> createState();
}

/// Estado base para StatefulFormDialog
abstract class StatefulFormDialogState<T, W extends StatefulFormDialog<T>>
    extends State<W> {
  bool _isLoading = false;
  List<String> _validationErrors = [];

  /// Acceso a si está cargando
  bool get isLoading => _isLoading;

  /// Acceso a errores de validación
  List<String> get validationErrors => _validationErrors;

  /// Obtiene la configuración actual (puede ser sobrescrita dinámicamente)
  FormDialogConfig get currentConfig => widget.config;

  /// Construye el contenido del formulario
  Widget buildForm(BuildContext context);

  /// Valida el formulario antes de submit
  FormValidationState validate() => const FormValidationState.valid();

  /// Ejecuta la acción principal (guardar)
  Future<T?> onSubmit();

  /// Callback opcional al cancelar
  void onCancel() {}

  /// Widget opcional para acciones adicionales en el footer
  Widget? buildAdditionalActions(BuildContext context) => null;

  /// Maneja el submit
  Future<void> handleSubmit() async {
    // Validar
    final validation = validate();
    if (!validation.isValid) {
      setState(() => _validationErrors = validation.errors);
      return;
    }

    setState(() {
      _isLoading = true;
      _validationErrors = [];
    });

    try {
      final result = await onSubmit();
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _validationErrors = ['Error al procesar. Intente nuevamente.'];
        });
      }
    }
  }

  /// Maneja la cancelación
  void handleCancel() {
    onCancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final config = currentConfig;

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: config.maxWidth,
        maxHeight: config.maxHeight ?? MediaQuery.of(context).size.height * 0.9,
      ),
      title: Row(
        children: [
          if (config.icon != null) ...[
            Icon(
              config.icon,
              color: config.iconColor ?? theme.accentColor,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(config.title),
          ),
          if (config.showCloseButton)
            IconButton(
              icon: const Icon(FluentIcons.chrome_close),
              onPressed: handleCancel,
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Descripción opcional
          if (config.description != null) ...[
            _buildDescriptionBanner(theme, config.description!),
            const SizedBox(height: 16),
          ],
          // Errores de validación
          if (_validationErrors.isNotEmpty) ...[
            _buildValidationBanner(theme),
            const SizedBox(height: 16),
          ],
          // Contenido del formulario
          if (config.scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: config.contentPadding,
                child: buildForm(context),
              ),
            )
          else
            Padding(
              padding: config.contentPadding,
              child: buildForm(context),
            ),
        ],
      ),
      actions: [
        // Acciones adicionales
        if (buildAdditionalActions(context) != null)
          buildAdditionalActions(context)!,
        const Spacer(),
        // Botón cancelar
        Button(
          onPressed: _isLoading ? null : handleCancel,
          child: Text(config.cancelButtonText),
        ),
        const SizedBox(width: 8),
        // Botón principal
        FilledButton(
          onPressed: (_isLoading || !config.isPrimaryEnabled) ? null : handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Text(config.primaryButtonText),
        ),
      ],
    );
  }

  Widget _buildDescriptionBanner(FluentThemeData theme, String description) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.inactiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.info,
            size: 16,
            color: theme.inactiveColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: theme.typography.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationBanner(FluentThemeData theme) {
    return InfoBar(
      title: Text(
        _validationErrors.length == 1
            ? 'Error de validación'
            : 'Errores de validación',
      ),
      content: Text(
        _validationErrors.length == 1
            ? _validationErrors.first
            : _validationErrors.map((e) => '• $e').join('\n'),
      ),
      severity: InfoBarSeverity.error,
      isLong: _validationErrors.length > 1,
      onClose: () => setState(() => _validationErrors = []),
    );
  }
}
