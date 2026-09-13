import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../app/preferences/app_preferences.dart';
import '../../ui/fluent/orbi_page.dart';
import '../auth/pin_enrollment_section.dart';
import 'message_durations_section.dart';

/// Cómo se dice cada modo de tema. El `enum` en sí nunca llega a pantalla
/// (ver `test/ui/no_raw_enum_names_test.dart`).
String _themeModeLabel(PreferenceThemeMode mode) => switch (mode) {
  PreferenceThemeMode.system => 'Automático (según el sistema)',
  PreferenceThemeMode.light => 'Claro',
  PreferenceThemeMode.dark => 'Oscuro',
};

String _densityLabel(PreferenceDensity density) => switch (density) {
  PreferenceDensity.standard => 'Estándar',
  PreferenceDensity.compact => 'Compacta',
};

String _navigationDisplayModeLabel(PreferenceNavigationDisplayMode mode) =>
    switch (mode) {
      PreferenceNavigationDisplayMode.auto => 'Automático',
      PreferenceNavigationDisplayMode.expanded => 'Abierto',
      PreferenceNavigationDisplayMode.compact => 'Compacto',
      PreferenceNavigationDisplayMode.minimal => 'Mínimo',
      PreferenceNavigationDisplayMode.top => 'Arriba',
    };

String _navigationIndicatorLabel(PreferenceNavigationIndicator indicator) =>
    switch (indicator) {
      PreferenceNavigationIndicator.sticky => 'Fijo',
      PreferenceNavigationIndicator.end => 'Al final',
    };

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.permissionAction,
    this.onRouteModeChanged,
  });
  final AppPreferencesController controller;
  final NotificationPermissionAction? permissionAction;
  final Future<void> Function(bool enabled)? onRouteModeChanged;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => OrbiPage(
      title: 'Configuración',
      child: LayoutBuilder(
        builder: (context, c) => ListView(
          padding: EdgeInsets.symmetric(
            horizontal: c.maxWidth >= 840 ? 32 : 0,
            vertical: 16,
          ),
          children: [
            // El formulario estándar (orden del dueño, 12-sep-2026): sólo
            // estos tres son de verdad un formulario (una elección con
            // etiqueta). `OrbiForm` a secas — sin `.filling` — porque este
            // trozo vive dentro del `ListView` de esta pantalla, que sigue
            // scrolleando el resto (deslizador, interruptores, PIN...) tal
            // como antes.
            OrbiForm(
              sections: [
                OrbiFormSection(
                  title: 'Apariencia',
                  fields: [
                    OrbiField(
                      label: 'Tema',
                      child: ComboBox<PreferenceThemeMode>(
                        isExpanded: true,
                        value: controller.snapshot.themeMode,
                        items: [
                          for (final mode in PreferenceThemeMode.values)
                            ComboBoxItem(
                              value: mode,
                              child: Text(_themeModeLabel(mode)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) controller.setTheme(value);
                        },
                      ),
                    ),
                    OrbiField(
                      label: 'Densidad',
                      child: ComboBox<PreferenceDensity>(
                        isExpanded: true,
                        value: controller.snapshot.density,
                        items: [
                          for (final density in PreferenceDensity.values)
                            ComboBoxItem(
                              value: density,
                              child: Text(_densityLabel(density)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) controller.setDensity(value);
                        },
                      ),
                    ),
                    OrbiField(
                      label: 'Menú de navegación',
                      child: ComboBox<PreferenceNavigationDisplayMode>(
                        isExpanded: true,
                        value: controller.snapshot.navigationDisplayMode,
                        items: [
                          for (final mode
                              in PreferenceNavigationDisplayMode.values)
                            ComboBoxItem(
                              value: mode,
                              child: Text(_navigationDisplayModeLabel(mode)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            controller.setNavigationDisplayMode(value);
                          }
                        },
                      ),
                    ),
                    OrbiField(
                      label: 'Indicador del menú',
                      child: ComboBox<PreferenceNavigationIndicator>(
                        isExpanded: true,
                        value: controller.snapshot.navigationIndicator,
                        items: [
                          for (final indicator
                              in PreferenceNavigationIndicator.values)
                            ComboBoxItem(
                              value: indicator,
                              child: Text(_navigationIndicatorLabel(indicator)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            controller.setNavigationIndicator(value);
                          }
                        },
                      ),
                    ),
                    OrbiField(
                      label: 'Acento',
                      child: ComboBox<int>(
                        isExpanded: true,
                        value: controller.snapshot.accentSeed,
                        items: const [
                          ComboBoxItem(
                            value: 0xFF007E82,
                            child: Text('Orbi teal'),
                          ),
                          ComboBoxItem(value: 0xFF1565C0, child: Text('Azul')),
                          ComboBoxItem(value: 0xFF8D4E00, child: Text('Ámbar')),
                        ],
                        onChanged: (value) {
                          if (value != null) controller.setAccentSeed(value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tamaño de texto: ${(controller.snapshot.textScale * 100).round()}%',
            ),
            Slider(
              min: .85,
              max: 2.0,
              value: controller.snapshot.textScale,
              label: '${(controller.snapshot.textScale * 100).round()}%',
              onChanged: controller.setTextScale,
            ),
            const SizedBox(height: 8),
            _SwitchRow(
              title: 'Modo Ruta',
              subtitle: 'Optimiza navegación para trabajo en ruta.',
              value: controller.snapshot.routeMode,
              onChanged: (enabled) async {
                await controller.setRouteMode(enabled);
                await onRouteModeChanged?.call(enabled);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Reintentos de sincronización')),
                ComboBox<int>(
                  value: controller.snapshot.syncRetries,
                  items: [
                    for (final v in const [0, 1, 3, 5, 10])
                      ComboBoxItem(value: v, child: Text('$v')),
                  ],
                  onChanged: (v) {
                    if (v != null) controller.setSyncRetries(v);
                  },
                ),
              ],
            ),
            const Divider(),
            const Text('Categorías de notificaciones'),
            for (final category in const ['ventas', 'caja', 'sistema'])
              _SwitchRow(
                title: category,
                value:
                    controller.snapshot.notificationCategories[category] ??
                    true,
                onChanged: (v) =>
                    controller.setNotificationCategory(category, v),
              ),
            const Divider(),
            const Text(
              'Permisos del sistema se solicitan únicamente desde la acción consciente correspondiente; denegado/no soportado no se convierte en éxito.',
            ),
            const SizedBox(height: 8),
            if (permissionAction != null)
              _PermissionButton(action: permissionAction!),
            MessageDurationsSection(controller: controller),
            const PinEnrollmentSection(),
          ],
        ),
      ),
    ),
  );
}

/// El equivalente propio de un `SwitchListTile`: título (y subtítulo
/// opcional) a la izquierda, el interruptor a la derecha. Fluent no trae ese
/// widget compuesto, pero sí trae `ListTile`, que ya sabe poner un `trailing`
/// junto a un título/subtítulo con el espaciado y la tipografía del tema —
/// no hace falta armar el `Row`+`Column`+`Padding` a mano.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: ToggleSwitch(checked: value, onChanged: onChanged),
    );
  }
}

class _PermissionButton extends StatefulWidget {
  const _PermissionButton({required this.action});
  final NotificationPermissionAction action;

  @override
  State<_PermissionButton> createState() => _PermissionButtonState();
}

class _PermissionButtonState extends State<_PermissionButton> {
  PermissionState? _state;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Permisos de notificaciones'),
              Text(switch (_state) {
                PermissionState.granted => 'Concedido',
                PermissionState.denied => 'Denegado',
                PermissionState.unsupported =>
                  'No compatible en esta plataforma',
                null => 'No solicitado',
              }),
            ],
          ),
        ),
        FilledButton(
          onPressed: () async {
            final state = await widget.action.requestFromUserGesture();
            if (mounted) setState(() => _state = state);
          },
          child: const Text('Solicitar'),
        ),
      ],
    ),
  );
}
