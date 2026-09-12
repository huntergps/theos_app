import 'package:fluent_ui/fluent_ui.dart';

import '../../bindings/field_binding.dart';

/// Fluent text control backed by a typed [FieldBinding<String>].
class OrbiBoundTextField extends StatefulWidget {
  const OrbiBoundTextField({
    super.key,
    required this.binding,
    required this.label,
    this.hintText,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
  });

  final FieldBinding<String> binding;
  final String label;
  final String? hintText;
  final bool enabled;
  final TextInputAction textInputAction;

  @override
  State<OrbiBoundTextField> createState() => _OrbiBoundTextFieldState();
}

class _OrbiBoundTextFieldState extends State<OrbiBoundTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.binding.value);
    _focusNode = FocusNode();
    widget.binding.addListener(_bindingChanged);
  }

  @override
  void didUpdateWidget(covariant OrbiBoundTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.binding != widget.binding) {
      oldWidget.binding.removeListener(_bindingChanged);
      widget.binding.addListener(_bindingChanged);
      _setTextIfDifferent(widget.binding.value);
    }
  }

  void _setTextIfDifferent(String value) {
    if (_controller.text == value) return;
    final selection = _controller.selection;
    _controller.value = TextEditingValue(
      text: value,
      selection:
          selection.isValid &&
              selection.baseOffset <= value.length &&
              selection.extentOffset <= value.length
          ? selection
          : TextSelection.collapsed(offset: value.length),
    );
  }

  void _bindingChanged() {
    if (!mounted) return;
    // Never overwrite the editor while it is dirty/conflicted.  Clean external
    // updates are safe to reflect, including during a parent rebuild.
    if (!widget.binding.isDirty &&
        widget.binding.status != FieldBindingStatus.conflict) {
      _setTextIfDifferent(widget.binding.value);
    }
    setState(() {});
  }

  String? get _errorText {
    final error = widget.binding.error;
    if (error == null) return null;
    return error.toString();
  }

  String _statusLabel() => switch (widget.binding.status) {
    FieldBindingStatus.pristine => '',
    FieldBindingStatus.dirty => 'Sin guardar',
    FieldBindingStatus.saving => 'Guardando…',
    FieldBindingStatus.saved => 'Guardado',
    FieldBindingStatus.error => 'Error al guardar',
    FieldBindingStatus.conflict => 'Conflicto: cambio externo',
  };

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel();
    final theme = FluentTheme.of(context);
    final errorText = _errorText;
    return Semantics(
      liveRegion: status.isNotEmpty,
      label: status.isEmpty ? widget.label : '${widget.label}. $status',
      child: InfoLabel(
        label: widget.label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextBox(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              textInputAction: widget.textInputAction,
              placeholder: widget.hintText,
              onChanged: widget.binding.edit,
              onSubmitted: (_) => widget.binding.save(),
              suffix: widget.binding.isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(FluentIcons.save),
                      onPressed: widget.binding.isDirty
                          ? widget.binding.save
                          : null,
                    ),
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  errorText,
                  style: TextStyle(
                    color: theme.resources.systemFillColorCritical,
                    fontSize: 12,
                  ),
                ),
              )
            else if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(status, style: theme.typography.caption),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.binding.removeListener(_bindingChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
