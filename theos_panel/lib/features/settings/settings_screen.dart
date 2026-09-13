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

/// Las categorías tal como las guarda `notificationCategories` (minúscula,
/// es la clave que persiste) frente a cómo se leen en pantalla (mayúscula
/// inicial — orden del dueño, 13-sep-2026: en minúscula parecía texto de
/// depuración, no producto). La clave interna no cambia: sólo cambia lo que
/// ve quien usa Orbi.
const _notificationCategoryKeys = ['ventas', 'caja', 'sistema'];

String _notificationCategoryLabel(String key) => switch (key) {
  'ventas' => 'Ventas',
  'caja' => 'Caja',
  'sistema' => 'Sistema',
  _ => key,
};

/// Los acentos que ya ofrecía Orbi como `ComboBox<int>` (el propio valor por
/// omisión, 0xFF007E82, no cambia — orden del dueño, 13-sep-2026), ahora como
/// muestras de color seleccionables en vez de una lista desplegable: es el
/// mismo patrón que ya usa `theos_pos` para "Color de Acento"
/// (`theos_pos/lib/shared/screens/settings_screen.dart`).
const _accentOptions = <({int seed, String label, String slug})>[
  (seed: 0xFF007E82, label: 'Orbi teal', slug: 'orbi-teal'),
  (seed: 0xFF1565C0, label: 'Azul', slug: 'azul'),
  (seed: 0xFF8D4E00, label: 'Ámbar', slug: 'ambar'),
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.permissionAction,
  });
  final AppPreferencesController controller;
  final NotificationPermissionAction? permissionAction;
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
            _SettingsGroup(
              title: 'Apariencia',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // El formulario estándar (orden del dueño, 12-sep-2026):
                  // sólo Tema y Densidad son de verdad un formulario (una
                  // elección con etiqueta). `OrbiForm` a secas — sin
                  // `.filling` — porque este trozo vive dentro del
                  // `ListView` de esta pantalla, que sigue scrolleando el
                  // resto.
                  OrbiForm(
                    sections: [
                      OrbiFormSection(
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
                                if (value != null) {
                                  controller.setDensity(value);
                                }
                              },
                            ),
                          ),
                          OrbiField(
                            label: 'Acento',
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final option in _accentOptions)
                                  _AccentSwatch(
                                    key: Key('accent-swatch-${option.slug}'),
                                    color: Color(option.seed),
                                    label: option.label,
                                    selected:
                                        controller.snapshot.accentSeed ==
                                        option.seed,
                                    onSelected: () =>
                                        controller.setAccentSeed(option.seed),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tamaño de texto: '
                    '${(controller.snapshot.textScale * 100).round()}%',
                  ),
                  Slider(
                    min: .85,
                    max: 2.0,
                    value: controller.snapshot.textScale,
                    label: '${(controller.snapshot.textScale * 100).round()}%',
                    onChanged: controller.setTextScale,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsGroup(
              title: 'Navegación',
              child: OrbiForm(
                sections: [
                  OrbiFormSection(
                    fields: [
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
                                child: Text(
                                  _navigationIndicatorLabel(indicator),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              controller.setNavigationIndicator(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsGroup(
              title: 'Notificaciones',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Categorías de notificaciones'),
                  for (final category in _notificationCategoryKeys)
                    _SwitchRow(
                      title: _notificationCategoryLabel(category),
                      value:
                          controller.snapshot.notificationCategories[category] ??
                          true,
                      onChanged: (v) =>
                          controller.setNotificationCategory(category, v),
                    ),
                  const SizedBox(height: 8),
                  // La frase de antes hablaba de "acción consciente" y de
                  // que "denegado/no soportado no se convierte en éxito" —
                  // jerga de quien programó el permiso, no algo que le diga
                  // nada a un vendedor (orden del dueño, 13-sep-2026).
                  const Text(
                    'Orbi te pedirá permiso para mostrar notificaciones la '
                    'primera vez que haga falta.',
                  ),
                  const SizedBox(height: 8),
                  if (permissionAction != null)
                    _PermissionButton(action: permissionAction!),
                  MessageDurationsSection(controller: controller),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SettingsGroup(
              title: 'Sincronización',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modo Ruta se trasladó a la pantalla de Sincronización
                  // (orden del dueño, 13-sep-2026): es, en los hechos, una
                  // preferencia de sincronización, y ahí queda junto a las
                  // acciones que afecta.
                  InfoLabel(
                    label: 'Reintentos de sincronización',
                    child: ComboBox<int>(
                      value: controller.snapshot.syncRetries,
                      items: [
                        for (final v in const [0, 1, 3, 5, 10])
                          ComboBoxItem(value: v, child: Text('$v')),
                      ],
                      onChanged: (v) {
                        if (v != null) controller.setSyncRetries(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const PinEnrollmentSection(),
          ],
        ),
      ),
    ),
  );
}

/// Una sección con nombre, plegable pero abierta por omisión: agrupa
/// controles afines (orden del dueño, 13-sep-2026: "secciones agrupadas y
/// consistentes") con el widget que fluent_ui ya trae para eso — mismo
/// patrón que `theos_pos` usa para "Escala de Tipografía" y "Duración de
/// Notificaciones", aquí a nivel de toda la categoría.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Expander(
    initiallyExpanded: true,
    header: Text(title, style: FluentTheme.of(context).typography.bodyStrong),
    content: child,
  );
}

/// Una muestra de acento seleccionable: el círculo de color, con una marca
/// cuando es el elegido. Reemplaza el `ComboBox<int>` de antes con el mismo
/// patrón que ya usa `theos_pos` en su pantalla de ajustes
/// (`_buildColorBlock`, `theos_pos/lib/shared/screens/settings_screen.dart`).
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    color: theme.resources.textFillColorPrimary,
                    width: 2,
                  )
                : null,
          ),
          child: selected
              ? const Icon(FluentIcons.check_mark, size: 14, color: Colors.white)
              : null,
        ),
        onPressed: onSelected,
      ),
    );
  }
}

/// El equivalente propio de un `SwitchListTile`: título (y subtítulo
/// opcional) a la izquierda, el interruptor a la derecha. Fluent no trae ese
/// widget compuesto, pero sí trae `ListTile`, que ya sabe poner un `trailing`
/// junto a un título/subtítulo con el espaciado y la tipografía del tema —
/// no hace falta armar el `Row`+`Column`+`Padding` a mano.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
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
