import 'package:flutter/material.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../app/preferences/app_preferences.dart';

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
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: LayoutBuilder(
        builder: (context, c) => ListView(
          padding: EdgeInsets.all(c.maxWidth >= 840 ? 32 : 16),
          children: [
            DropdownButtonFormField<PreferenceThemeMode>(
              initialValue: controller.snapshot.themeMode,
              decoration: const InputDecoration(labelText: 'Tema'),
              items: PreferenceThemeMode.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.setTheme(value);
              },
            ),
            DropdownButtonFormField<PreferenceDensity>(
              initialValue: controller.snapshot.density,
              decoration: const InputDecoration(labelText: 'Densidad'),
              items: PreferenceDensity.values
                  .map(
                    (density) => DropdownMenuItem(
                      value: density,
                      child: Text(density.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.setDensity(value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: controller.snapshot.accentSeed,
              decoration: const InputDecoration(labelText: 'Acento'),
              items: const [
                DropdownMenuItem(value: 0xFF007E82, child: Text('Orbi teal')),
                DropdownMenuItem(value: 0xFF1565C0, child: Text('Azul')),
                DropdownMenuItem(value: 0xFF8D4E00, child: Text('Ámbar')),
              ],
              onChanged: (value) {
                if (value != null) controller.setAccentSeed(value);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Tamaño de texto: ${(controller.snapshot.textScale * 100).round()}%',
            ),
            Slider(
              min: .85,
              max: 2.0,
              value: controller.snapshot.textScale,
              onChanged: controller.setTextScale,
            ),
            SwitchListTile(
              title: const Text('Modo Ruta'),
              subtitle: const Text('Optimiza navegación para trabajo en ruta.'),
              value: controller.snapshot.routeMode,
              onChanged: (enabled) async {
                await controller.setRouteMode(enabled);
                await onRouteModeChanged?.call(enabled);
              },
            ),
            ListTile(
              title: const Text('Reintentos de sincronización'),
              trailing: DropdownButton<int>(
                value: controller.snapshot.syncRetries,
                items: [0, 1, 3, 5, 10]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) controller.setSyncRetries(v);
                },
              ),
            ),
            const Divider(),
            const Text('Categorías de notificaciones'),
            for (final category in const ['ventas', 'caja', 'sistema'])
              SwitchListTile(
                title: Text(category),
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
          ],
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => ListTile(
    title: const Text('Permisos de notificaciones'),
    subtitle: Text(switch (_state) {
      PermissionState.granted => 'Concedido',
      PermissionState.denied => 'Denegado',
      PermissionState.unsupported => 'No compatible en esta plataforma',
      null => 'No solicitado',
    }),
    trailing: FilledButton(
      onPressed: () async {
        final state = await widget.action.requestFromUserGesture();
        if (mounted) setState(() => _state = state);
      },
      child: const Text('Solicitar'),
    ),
  );
}
