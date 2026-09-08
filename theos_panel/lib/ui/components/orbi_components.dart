import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../app/theme/orbi_theme.dart';

class OrbiPageShell extends StatelessWidget {
  const OrbiPageShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: const EdgeInsets.all(OrbiTheme.space16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrbiStatusChip extends StatelessWidget {
  const OrbiStatusChip({
    super.key,
    required this.label,
    this.icon = Icons.info_outline,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Chip(
        avatar: Icon(icon, size: 18, semanticLabel: ''),
        label: Text(label),
      ),
    );
  }
}

class OrbiEmptyState extends StatelessWidget {
  const OrbiEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        container: true,
        label: '$title. $message',
        child: Padding(
          padding: const EdgeInsets.all(OrbiTheme.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 48),
              const SizedBox(height: OrbiTheme.space12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OrbiTheme.space8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: OrbiTheme.space16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OrbiErrorState extends StatelessWidget {
  const OrbiErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Error. $message',
        child: Padding(
          padding: const EdgeInsets.all(OrbiTheme.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: OrbiTheme.space12),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: OrbiTheme.space16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OrbiField extends StatelessWidget {
  const OrbiField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.onChanged,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 1,
      decoration: InputDecoration(labelText: label, hintText: hintText),
    );
  }
}

/// Adapter for a reactive form control owned by the screen/controller.
/// The control is deliberately injected, so rebuilding or resizing the widget
/// never recreates the form state.
class OrbiReactiveTextField extends StatelessWidget {
  const OrbiReactiveTextField({
    super.key,
    required this.control,
    required this.label,
    this.hintText,
  });

  final FormControl<String> control;
  final String label;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return ReactiveTextField<String>(
      formControl: control,
      decoration: InputDecoration(labelText: label, hintText: hintText),
    );
  }
}

class OrbiActionCard extends StatelessWidget {
  const OrbiActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: '$title. $subtitle',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(OrbiTheme.space16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: OrbiTheme.space4),
                      Text(subtitle),
                    ],
                  ),
                ),
                Icon(icon, size: 24, semanticLabel: ''),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
