// ignore_for_file: invalid_use_of_protected_member
// El extension-on-State del plan de descomposición (Fase E2) no forma parte
// de la jerarquía de la clase para el análisis estático, así que llamar a
// `setState` (protegido en `State`) desde acá dispara ese warning aunque en
// runtime es idéntico a llamarlo desde un método de la clase. Comportamiento
// sin cambios.
part of 'user_preferences_dialog.dart';

/// Tab 'Seguridad' de [UserPreferencesDialog] (contraseña, sesiones/dispositivos)
/// — extraído de user_preferences_dialog.dart como parte de la descomposición
/// sin cambio de comportamiento (Fase E2).
extension _UserPreferencesSecurityTab on _UserPreferencesDialogState {
  /// Revoke a specific device
  Future<void> _revokeDevice(int deviceId) async {
    // First, ask for password confirmation
    final passwordController = TextEditingController();
    final String? password;
    try {
      password = await showDialog<String>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Cerrar sesión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro de que quieres cerrar la sesión en este dispositivo?',
              ),
              const SizedBox(height: 16),
              const Text(
                'Por seguridad, ingresa tu contraseña actual:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextBox(
                controller: passwordController,
                placeholder: 'Contraseña',
                obscureText: true,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context, null),
            ),
            FilledButton(
              child: const Text('Cerrar sesión'),
              onPressed: () {
                if (passwordController.text.isEmpty) {
                  return;
                }
                Navigator.pop(context, passwordController.text);
              },
            ),
          ],
        ),
      );
    } finally {
      passwordController.dispose();
    }

    if (password != null && password.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(userRepositoryProvider);
        if (repo == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final success = await repo.revokeDevice(deviceId, password);

        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            // Refresh devices list
            ref.invalidate(userDevicesProvider);
            ref.showSuccessNotification(
              context,
              title: 'Sesión cerrada',
              message: 'La sesión ha sido cerrada exitosamente',
            );
          } else {
            ref.showErrorNotification(
              context,
              title: 'Error al cerrar sesión',
              message: 'Contraseña incorrecta o no se pudo cerrar la sesión',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ref.showErrorNotification(
            context,
            title: 'Error al cerrar sesión',
            message: '$e',
          );
        }
      }
    }
  }

  /// Revoke all devices except current
  Future<void> _revokeAllDevices() async {
    // First, ask for password confirmation
    final passwordController = TextEditingController();
    final String? password;
    try {
      password = await showDialog<String>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Cerrar todas las sesiones'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro de que quieres cerrar la sesión en todos los dispositivos excepto este?',
              ),
              const SizedBox(height: 16),
              const Text(
                'Por seguridad, ingresa tu contraseña actual:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextBox(
                controller: passwordController,
                placeholder: 'Contraseña',
                obscureText: true,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context, null),
            ),
            FilledButton(
              child: const Text('Cerrar sesiones'),
              onPressed: () {
                if (passwordController.text.isEmpty) {
                  return;
                }
                Navigator.pop(context, passwordController.text);
              },
            ),
          ],
        ),
      );
    } finally {
      passwordController.dispose();
    }

    if (password != null && password.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final repo = ref.read(userRepositoryProvider);
        if (repo == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final success = await repo.revokeAllDevices(password);

        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            // Refresh devices list
            ref.invalidate(userDevicesProvider);
            ref.showSuccessNotification(
              context,
              title: 'Sesiones cerradas',
              message: 'Todas las sesiones han sido cerradas exitosamente',
            );
          } else {
            ref.showErrorNotification(
              context,
              title: 'Error al cerrar sesiones',
              message:
                  'Contraseña incorrecta o no se pudieron cerrar las sesiones',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ref.showErrorNotification(
            context,
            title: 'Error al cerrar sesiones',
            message: '$e',
          );
        }
      }
    }
  }

  /// Show change password dialog
  Future<void> _showChangePasswordDialog() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => ContentDialog(
            title: const Text('Cambiar contraseña'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoLabel(
                    label: 'Contraseña actual',
                    child: TextBox(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      suffix: Tooltip(
                        message: obscureOld
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        child: IconButton(
                          icon: Icon(
                            obscureOld
                                ? FluentIcons.red_eye
                                : FluentIcons.hide3,
                          ),
                          onPressed: () =>
                              setState(() => obscureOld = !obscureOld),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'Nueva contraseña',
                    child: TextBox(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      suffix: Tooltip(
                        message: obscureNew
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        child: IconButton(
                          icon: Icon(
                            obscureNew
                                ? FluentIcons.red_eye
                                : FluentIcons.hide3,
                          ),
                          onPressed: () =>
                              setState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'Confirmar nueva contraseña',
                    child: TextBox(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      suffix: Tooltip(
                        message: obscureConfirm
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        child: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? FluentIcons.red_eye
                                : FluentIcons.hide3,
                          ),
                          onPressed: () =>
                              setState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Button(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.pop(context),
              ),
              FilledButton(
                child: const Text('Cambiar contraseña'),
                onPressed: () {
                  final oldPassword = oldPasswordController.text;
                  final newPassword = newPasswordController.text;
                  final confirmPassword = confirmPasswordController.text;

                  if (oldPassword.isEmpty ||
                      newPassword.isEmpty ||
                      confirmPassword.isEmpty) {
                    CopyableInfoBar.showError(
                      context,
                      title: 'Validación de contraseña',
                      message: 'Todos los campos son requeridos',
                    );
                    return;
                  }

                  if (newPassword != confirmPassword) {
                    CopyableInfoBar.showError(
                      context,
                      title: 'Validación de contraseña',
                      message: 'Las contraseñas no coinciden',
                    );
                    return;
                  }

                  if (newPassword.length < 8) {
                    CopyableInfoBar.showError(
                      context,
                      title: 'Validación de contraseña',
                      message: 'La contraseña debe tener al menos 8 caracteres',
                    );
                    return;
                  }

                  Navigator.pop(context);
                  _changePassword(oldPassword, newPassword);
                },
              ),
            ],
          ),
        ),
      );
    } finally {
      oldPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  /// Change password
  Future<void> _changePassword(String oldPassword, String newPassword) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      if (repo == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final success = await repo.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ref.showSuccessNotification(
            context,
            title: 'Contraseña cambiada',
            message: 'Tu contraseña ha sido actualizada exitosamente',
          );
        } else {
          ref.showErrorNotification(
            context,
            title: 'Error al cambiar contraseña',
            message: 'No se pudo cambiar la contraseña. Verifica tu contraseña actual',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ref.showErrorNotification(
          context,
          title: 'Error al cambiar contraseña',
          message: '$e',
        );
      }
    }
  }

  Tab _buildSeguridadTab() {
    return Tab(
      text: const Text('Seguridad'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Change Password
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cambiar contraseña',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Actualiza si es una contraseña en riesgo.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Button(
                    onPressed: _showChangePasswordDialog,
                    child: const Text('Cambiar contraseña'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Devices
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dispositivos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisa si son tuyos.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, child) {
                    final devicesAsync = ref.watch(userDevicesProvider);

                    return devicesAsync.when(
                      data: (devices) {
                        if (devices.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.borderLight),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'No hay dispositivos activos',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < devices.length; i++) ...[
                                if (i > 0) const Divider(),
                                _buildDeviceItem(devices[i]),
                              ],
                            ],
                          ),
                        );
                      },
                      loading: () => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(child: ProgressRing()),
                      ),
                      error: (error, stack) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderLight),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Error al cargar dispositivos: $error',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Button(
                  child: const Text('Cerrar sesión en todos los dispositivos'),
                  onPressed: () => _revokeAllDevices(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(ResDevice device) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(FluentIcons.devices3, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: device.revoked
                            ? AppColors.textSecondary
                            : AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device.getRelativeTime(),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  device.location,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Button(
            onPressed: device.revoked
                ? null
                : () => _revokeDevice(device.odooId),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
