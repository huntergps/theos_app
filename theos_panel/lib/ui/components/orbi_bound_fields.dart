import 'package:flutter/material.dart';

import '../bindings/field_binding.dart';

/// Material text control backed by a typed [FieldBinding<String>].
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
    return Semantics(
      liveRegion: status.isNotEmpty,
      label: status.isEmpty ? widget.label : '${widget.label}. $status',
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        textInputAction: widget.textInputAction,
        onChanged: widget.binding.edit,
        onSubmitted: (_) => widget.binding.save(),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          errorText: _errorText,
          helperText: status.isEmpty ? null : status,
          suffixIcon: widget.binding.isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Guardar',
                  onPressed: widget.binding.isDirty
                      ? widget.binding.save
                      : null,
                  icon: const Icon(Icons.save_outlined),
                ),
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
