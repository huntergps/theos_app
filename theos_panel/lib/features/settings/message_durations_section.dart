import 'package:flutter/material.dart';

import '../../app/preferences/app_preferences.dart';
import '../../ui/components/copyable_message.dart';

/// Lets a person choose how long each kind of message stays on screen, and
/// remembers it — the owner's "se debe escoger el tiempo a mostrar".
///
/// A slider per severity, the same shape `theos_pos`'s settings screen uses
/// (`settings_screen.dart`, "Duracion de Notificaciones"), rebuilt on
/// Material. Two things are different on purpose:
///
///  * **0 is a real, reachable value, and it means "no se cierra sola".** In
///    `theos_pos` the floor is 1 second and an error always expires. An error
///    that someone is expected to copy and forward must be able to wait for
///    them; see [MessageDurations].
///  * The live value is spelled out in words next to each slider, because
///    "0" on its own reads as "disabled", which is the opposite of what it
///    does here.
///
/// Kept in its own file, and inserted into the settings screen as a single
/// widget, so two people can work on settings without colliding — the same
/// pattern `PinEnrollmentSection` established.
class MessageDurationsSection extends StatelessWidget {
  const MessageDurationsSection({super.key, required this.controller});

  final AppPreferencesController controller;

  static const _labels = {
    OrbiMessageSeverity.error: 'Errores',
    OrbiMessageSeverity.warning: 'Avisos',
    OrbiMessageSeverity.success: 'Confirmaciones',
    OrbiMessageSeverity.info: 'Información',
  };

  static String describeSeconds(int seconds) =>
      seconds <= 0 ? 'Hasta que la cierres' : '$seconds s';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final durations = controller.snapshot.messageDurations;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Text(
              'Duración de los mensajes',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Cuánto tiempo se queda en pantalla cada tipo de mensaje. '
              'Lleva el control hasta el mínimo para que no se cierre sola y '
              'te dé tiempo de leerla o copiarla.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final severity in OrbiMessageSeverity.values)
              _DurationSlider(
                key: Key('message-duration-${severity.name}'),
                label: _labels[severity]!,
                seconds: durations.secondsFor(severity),
                onChanged: (value) =>
                    controller.setMessageDuration(severity, value),
              ),
          ],
        );
      },
    );
  }
}

class _DurationSlider extends StatelessWidget {
  const _DurationSlider({
    super.key,
    required this.label,
    required this.seconds,
    required this.onChanged,
  });

  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = MessageDurationsSection.describeSeconds(seconds);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(description, style: theme.textTheme.labelLarge),
            ],
          ),
          Slider(
            value: seconds.toDouble(),
            min: 0,
            max: MessageDurations.maxSeconds.toDouble(),
            divisions: MessageDurations.maxSeconds,
            // Screen readers get the sentence, not the bare number: "0"
            // announced alone would be read as "off".
            label: description,
            semanticFormatterCallback: (value) =>
                '$label: ${MessageDurationsSection.describeSeconds(value.round())}',
            onChanged: (value) => onChanged(value.round()),
          ),
        ],
      ),
    );
  }
}
