import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/config_service.dart';
import '../widgets/form/form_fields.dart';

// Custom cyan/turquoise color using centralized constants
final cyanAccentColor = AccentColor.swatch(AppColors.primaryVariants);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configServiceProvider);
    final notifier = ref.read(configServiceProvider.notifier);

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Configuracion')),
      children: [
        const Text('Personaliza la apariencia y los parametros del sistema.'),
        const SizedBox(height: 20),
        _SettingsSectionProfiles(config: config, notifier: notifier),
        const SizedBox(height: 24),
        _SettingsSectionAppearance(config: config, notifier: notifier),
        const SizedBox(height: 24),
        _SettingsSectionSystem(config: config, notifier: notifier),
        const SizedBox(height: 32),
      ],
    );
  }
}

// =============================================================================
// SECTION 1: Profiles
// =============================================================================

class _SettingsSectionProfiles extends StatelessWidget {
  final dynamic config;
  final ConfigService notifier;

  const _SettingsSectionProfiles({
    required this.config,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSection(title: 'Perfiles de Configuracion'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen =
                constraints.maxWidth < ScreenBreakpoints.mobileMaxWidth;

            Widget buildComboBox() {
              return ComboBox<String>(
                placeholder: const Text('Seleccionar perfil...'),
                isExpanded: true,
                value: config.activeProfileId,
                items: config.profiles.map<ComboBoxItem<String>>((e) {
                  return ComboBoxItem(
                    value: e.id,
                    child: Row(
                      children: [
                        if (e.isDefault) ...[
                          const Icon(FluentIcons.lock, size: 12),
                          const SizedBox(width: 8),
                        ],
                        Text(e.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (profileId) {
                  if (profileId != null) {
                    final profile = config.profiles.firstWhere(
                      (p) => p.id == profileId,
                    );
                    notifier.applyProfile(profile);
                  }
                },
              );
            }

            Widget buildButtons() {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Guardar actual como nuevo perfil',
                    child: IconButton(
                      icon: const Icon(FluentIcons.save),
                      onPressed: () =>
                          _showSaveProfileDialog(context, notifier),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Restablecer perfil a valores por defecto',
                    child: IconButton(
                      icon: const Icon(FluentIcons.reset),
                      onPressed: config.activeProfileId != null
                          ? () => notifier.resetCurrentProfile()
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Eliminar perfil seleccionado',
                    child: IconButton(
                      icon: Icon(FluentIcons.delete, color: Colors.red),
                      onPressed: () => _showDeleteProfileDialog(
                          context, config, notifier),
                    ),
                  ),
                ],
              );
            }

            if (isSmallScreen) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: double.infinity, child: buildComboBox()),
                  const SizedBox(height: 10),
                  buildButtons(),
                ],
              );
            } else {
              return Row(
                children: [
                  SizedBox(width: 300, child: buildComboBox()),
                  const SizedBox(width: 10),
                  buildButtons(),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  void _showSaveProfileDialog(
      BuildContext context, ConfigService notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('Guardar Perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresa un nombre para el nuevo perfil:'),
              const SizedBox(height: 10),
              TextFormBox(
                controller: controller,
                placeholder: 'Nombre del perfil',
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            FilledButton(
              child: const Text('Guardar'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  notifier.createProfile(controller.text);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteProfileDialog(
    BuildContext context,
    dynamic config,
    ConfigService notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('Eliminar Perfil'),
          content: SizedBox(
            height: 200,
            width: 300,
            child: ListView.builder(
              itemCount: config.profiles.length,
              itemBuilder: (context, index) {
                final profile = config.profiles[index];
                if (profile.isDefault) return const SizedBox.shrink();

                return ListTile(
                  title: Text(profile.name),
                  trailing: IconButton(
                    icon: Icon(FluentIcons.delete, color: Colors.red),
                    onPressed: () {
                      notifier.deleteProfile(profile.id);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            Button(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SECTION 2: Appearance
// =============================================================================

class _SettingsSectionAppearance extends StatelessWidget {
  final dynamic config;
  final ConfigService notifier;

  const _SettingsSectionAppearance({
    required this.config,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSection(title: 'Apariencia'),
        const SizedBox(height: 16),

        // Theme Mode
        FormComboBox<ThemeMode>(
          label: 'Modo de Tema',
          value: config.themeMode,
          items: ThemeMode.values.map((e) {
            return ComboBoxItem(
              value: e,
              child: Text(e.toString().split('.').last),
            );
          }).toList(),
          onChanged: (mode) {
            if (mode != null) notifier.setThemeMode(mode);
          },
        ),
        const SizedBox(height: 16),

        // Accent Color
        InfoLabel(
          label: 'Color de Acento',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                [...Colors.accentColors, cyanAccentColor].map((color) {
              return Tooltip(
                message: _getColorName(color),
                child: IconButton(
                  icon: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: config.accentColor == color
                          ? Border.all(
                              color: FluentTheme.of(
                                context,
                              ).typography.bodyStrong!.color!,
                              width: 2,
                            )
                          : null,
                    ),
                    child: config.accentColor == color
                        ? Icon(
                            FluentIcons.check_mark,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  onPressed: () => notifier.setAccentColor(color),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Window Effect (Desktop only)
        if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FormComboBox<WindowEffect>(
              label: 'Efecto de Ventana',
              value: config.windowEffect,
              items: WindowEffect.values.map((e) {
                return ComboBoxItem(
                  value: e,
                  child: Text(e.toString().split('.').last),
                );
              }).toList(),
              onChanged: (effect) {
                if (effect != null) notifier.setWindowEffect(effect);
              },
            ),
          ),

        // Display Mode
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen =
                constraints.maxWidth < ScreenBreakpoints.mobileMaxWidth;

            if (isSmallScreen) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormComboBox<PaneDisplayMode>(
                  label: 'Modo de Visualizacion (Panel)',
                  value: config.displayMode,
                  items: PaneDisplayMode.values.map((e) {
                    return ComboBoxItem(
                      value: e,
                      child: Text(e.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: (mode) {
                    if (mode != null) notifier.setDisplayMode(mode);
                  },
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),

        // Typography Scaling
        Expander(
          header: const Text('Escala de Tipografia'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Button(
                    child: const Text('Restablecer'),
                    onPressed: () => notifier.resetTypography(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSlider(
                context, 'Display', config.displayFactor,
                notifier.setDisplayFactor,
              ),
              _buildSlider(
                context, 'Titulo Grande', config.titleLargeFactor,
                notifier.setTitleLargeFactor,
              ),
              _buildSlider(
                context, 'Titulo', config.titleFactor,
                notifier.setTitleFactor,
              ),
              _buildSlider(
                context, 'Cuerpo Grande', config.bodyLargeFactor,
                notifier.setBodyLargeFactor,
              ),
              _buildSlider(
                context, 'Cuerpo Fuerte', config.bodyStrongFactor,
                notifier.setBodyStrongFactor,
              ),
              _buildSlider(
                context, 'Cuerpo', config.bodyFactor,
                notifier.setBodyFactor,
              ),
              _buildSlider(
                context, 'Subtitulo', config.captionFactor,
                notifier.setCaptionFactor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Spacing Scaling
        InfoLabel(
          label: 'Escala de Espaciado',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: config.spacingFactor,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: config.spacingFactor.toStringAsFixed(1),
                      onChanged: notifier.setSpacingFactor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 50,
                    child: Text(
                      config.spacingFactor.toStringAsFixed(1),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    child: const Text('Reset'),
                    onPressed: () => notifier.resetSpacing(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ajusta el espaciado entre elementos de la interfaz.',
                style:
                    FluentTheme.of(context).typography.caption?.copyWith(
                  color: FluentTheme.of(
                    context,
                  ).resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(
    BuildContext context,
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: value.toStringAsFixed(1),
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 50, child: Text(value.toStringAsFixed(1))),
        ],
      ),
    );
  }

  String _getColorName(AccentColor color) {
    if (color == Colors.yellow) return 'Amarillo';
    if (color == Colors.orange) return 'Naranja';
    if (color == Colors.red) return 'Rojo';
    if (color == Colors.magenta) return 'Magenta';
    if (color == Colors.purple) return 'Morado';
    if (color == Colors.blue) return 'Azul';
    if (color == Colors.teal) return 'Verde azulado';
    if (color == Colors.green) return 'Verde';
    if (color == cyanAccentColor) return 'Cian';
    return 'Personalizado';
  }
}

// =============================================================================
// SECTION 3: System
// =============================================================================

class _SettingsSectionSystem extends StatelessWidget {
  final dynamic config;
  final ConfigService notifier;

  const _SettingsSectionSystem({
    required this.config,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSection(title: 'Sistema'),
        const SizedBox(height: 16),

        // Date Format
        FormComboBox<String>(
          label: 'Formato de visualizacion de fechas',
          value: config.dateFormat,
          items: const [
            ComboBoxItem(
              value: 'dd/MM/yyyy',
              child: Text('dd/MM/yyyy (28/05/2025)'),
            ),
            ComboBoxItem(
              value: 'MM/dd/yyyy',
              child: Text('MM/dd/yyyy (05/28/2025)'),
            ),
            ComboBoxItem(
              value: 'yyyy-MM-dd',
              child: Text('yyyy-MM-dd (2025-05-28)'),
            ),
            ComboBoxItem(
              value: 'd MMM, yyyy',
              child: Text('d MMM, yyyy (28 May, 2025)'),
            ),
          ],
          onChanged: (format) {
            if (format != null) notifier.setDateFormat(format);
          },
        ),
        const SizedBox(height: 16),

        // Sync Configuration Section
        InfoLabel(
          label: 'Reintentos Automaticos de Sincronizacion',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: config.maxSyncRetries.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: config.maxSyncRetries.toString(),
                      onChanged: (value) {
                        notifier.setMaxSyncRetries(value.toInt());
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${config.maxSyncRetries} ${config.maxSyncRetries == 1 ? 'vez' : 'veces'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Intentos antes de requerir intervencion manual.',
                style:
                    FluentTheme.of(context).typography.caption?.copyWith(
                  color: FluentTheme.of(
                    context,
                  ).resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Notification Durations
        Expander(
          header: const Text('Duracion de Notificaciones'),
          content: Column(
            children: [
              const SizedBox(height: 10),
              _buildNotificationDurationSlider(
                context, 'Errores',
                config.errorNotificationDuration,
                notifier.setErrorNotificationDuration,
                FluentIcons.status_error_full, Colors.red, 1, 60,
              ),
              _buildNotificationDurationSlider(
                context, 'Advertencias',
                config.warningNotificationDuration,
                notifier.setWarningNotificationDuration,
                FluentIcons.warning, Colors.orange, 1, 30,
              ),
              _buildNotificationDurationSlider(
                context, 'Exito',
                config.successNotificationDuration,
                notifier.setSuccessNotificationDuration,
                FluentIcons.completed_solid, Colors.green, 1, 30,
              ),
              _buildNotificationDurationSlider(
                context, 'Informacion',
                config.infoNotificationDuration,
                notifier.setInfoNotificationDuration,
                FluentIcons.info, Colors.blue, 1, 30,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationDurationSlider(
    BuildContext context,
    String label,
    int value,
    Function(int) onChanged,
    IconData icon,
    Color color,
    int min,
    int max,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: '$value seg',
              onChanged: (val) => onChanged(val.toInt()),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$value seg',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
