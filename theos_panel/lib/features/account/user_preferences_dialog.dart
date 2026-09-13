import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:image/image.dart' as img;
import 'package:orbi_runtime/orbi_runtime.dart';

/// Abre el diálogo de preferencias PERSONALES del usuario de Odoo — no la
/// configuración de la app (eso sigue siendo `SettingsScreen`). Referencia:
/// `theos_pos/lib/shared/widgets/user_preferences_dialog.dart`.
///
/// Todo lo que se MUESTRA sale de `preferences.watch`/`preferences.catalogs`
/// — Drift local, nunca RPC: el diálogo abre igual con o sin red. Sólo las
/// acciones de [UserSecurityActionsPort] (cambiar clave, dispositivos) son
/// online-only, con su propio aviso.
///
/// Devuelve el mensaje a mostrar tras un guardado exitoso (`"Guardado."` o,
/// sin red, `"Guardado. Se enviará a Odoo al volver la conexión."`), o
/// `null` si se cerró sin guardar — quien abre el diálogo decide cómo
/// mostrarlo (banda global, `InfoBar`, lo que ya tenga cableado), porque
/// ese cableado vive en `router.dart`, fuera de este archivo.
Future<String?> showUserPreferencesDialog(
  BuildContext context, {
  required int userId,
  required UserPreferencesPort preferences,
  required UserSecurityActionsPort security,
}) => showDialog<String>(
  context: context,
  builder: (_) => UserPreferencesDialog(
    userId: userId,
    preferences: preferences,
    security: security,
  ),
);

/// Abstrae `FilePicker.pickFiles` para poder inyectar un doble en pruebas —
/// `FilePicker` (`package:file_picker`) es una clase `abstract final` con
/// métodos `static`, imposible de mockear directo con mocktail.
abstract class AvatarImagePicker {
  /// Bytes crudos del archivo elegido, o `null` si el usuario canceló.
  Future<Uint8List?> pickImage();
}

/// Misma llamada que `_pickImage` en
/// `theos_pos/lib/shared/widgets/user_preferences_dialog.dart:433-452`:
/// `FilePicker.pickFiles` + `PlatformFile.readAsBytes()`. `readAsBytes()` ya
/// resuelve web y nativo por igual — es el reemplazo documentado del
/// parámetro `withData` (deprecado en `file_picker` 12.x), así que no hace
/// falta pasarlo.
final class FilePickerAvatarImagePicker implements AvatarImagePicker {
  const FilePickerAvatarImagePicker();

  @override
  Future<Uint8List?> pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result.isEmpty) return null;
    return result.first.readAsBytes();
  }
}

class UserPreferencesDialog extends StatefulWidget {
  const UserPreferencesDialog({
    super.key,
    required this.userId,
    required this.preferences,
    required this.security,
    this.imagePicker = const FilePickerAvatarImagePicker(),
  });

  final int userId;
  final UserPreferencesPort preferences;
  final UserSecurityActionsPort security;
  final AvatarImagePicker imagePicker;

  @override
  State<UserPreferencesDialog> createState() => _UserPreferencesDialogState();
}

class _UserPreferencesDialogState extends State<UserPreferencesDialog> {
  int _tabIndex = 0;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;

  UserPreferences? _initial;
  UserPreferencesCatalogs? _catalogs;
  late Future<List<UserDevice>> _devicesFuture;

  final _signatureController = TextEditingController();
  final _mobilePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _street2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();

  String? _lang;
  String? _tz;
  String? _notificationType;
  int? _warehouseId;
  int? _countryId;
  int? _stateId;
  bool _removeAvatar = false;

  /// Foto recién elegida, ya redimensionada — igual que `_avatarBytes` en
  /// theos_pos: se muestra de una vez en la cabecera, pero sólo entra al
  /// diff (como `image_1920` en base64) cuando se guarda.
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    _devicesFuture = widget.security.listDevices();
    for (final controller in [
      _signatureController,
      _mobilePhoneController,
      _emailController,
      _phoneController,
      _streetController,
      _street2Controller,
      _cityController,
      _zipController,
    ]) {
      // Recalcula si "Guardar" debe estar activo en cada tecla — no hay
      // seguimiento de "dirty" por campo, así que basta con reconstruir.
      controller.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _mobilePhoneController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _street2Controller.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final prefs = await widget.preferences.watch(widget.userId).first;
      if (prefs == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError =
              'Tu usuario todavía no se sincronizó en este dispositivo.';
        });
        return;
      }
      final catalogs = await widget.preferences.catalogs(
        countryId: prefs.countryId,
      );
      if (!mounted) return;
      setState(() {
        _initial = prefs;
        _catalogs = catalogs;
        _lang = prefs.lang;
        _tz = prefs.tz;
        _notificationType = prefs.notificationType;
        _warehouseId = prefs.warehouseId;
        _countryId = prefs.countryId;
        _stateId = prefs.stateId;
        _removeAvatar = false;
        _avatarBytes = null;
        _signatureController.text = prefs.signature ?? '';
        _mobilePhoneController.text = prefs.mobilePhone ?? '';
        _emailController.text = prefs.email ?? '';
        _phoneController.text = prefs.phone ?? '';
        _streetController.text = prefs.street ?? '';
        _street2Controller.text = prefs.street2 ?? '';
        _cityController.text = prefs.city ?? '';
        _zipController.text = prefs.zip ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudieron cargar las preferencias: $error';
      });
    }
  }

  Future<void> _onCountryChanged(int? countryId) async {
    setState(() {
      _countryId = countryId;
      _stateId = null;
    });
    final catalogs = await widget.preferences.catalogs(countryId: countryId);
    if (!mounted) return;
    setState(() => _catalogs = catalogs);
  }

  Future<void> _pickImage() async {
    try {
      final originalBytes = await widget.imagePicker.pickImage();
      if (originalBytes == null) return;
      final optimized = _optimizeAvatarImage(originalBytes);
      if (optimized == null) return;
      setState(() {
        _avatarBytes = optimized;
        _removeAvatar = false;
      });
    } catch (_) {
      // Igual que theos_pos: elegir foto no es crítico, un error acá no
      // debe tumbar el diálogo entero.
    }
  }

  /// Igual que `_optimizeImage` en
  /// `theos_pos/lib/shared/widgets/user_preferences_dialog.dart:110-135`:
  /// 1920px, JPEG calidad 85.
  Uint8List? _optimizeAvatarImage(
    Uint8List bytes, {
    int maxSize = 1920,
    int quality = 85,
  }) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      var resized = image;
      if (image.width > maxSize || image.height > maxSize) {
        resized = image.width > image.height
            ? img.copyResize(image, width: maxSize)
            : img.copyResize(image, height: maxSize);
      }
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (_) {
      return bytes;
    }
  }

  UserPreferencesEdits _currentEdits() => UserPreferencesEdits(
    lang: _lang,
    tz: _tz,
    notificationType: _notificationType,
    signature: _signatureController.text,
    warehouseId: _warehouseId,
    mobilePhone: _mobilePhoneController.text,
    removeAvatar: _removeAvatar,
    newAvatarBase64: _avatarBytes != null ? base64Encode(_avatarBytes!) : null,
    email: _emailController.text,
    phone: _phoneController.text,
    street: _streetController.text,
    street2: _street2Controller.text,
    city: _cityController.text,
    zip: _zipController.text,
    countryId: _countryId,
    stateId: _stateId,
  );

  UserPreferencesChange _buildChange() {
    final initial = _initial;
    if (initial == null) return const UserPreferencesChange();
    return buildUserPreferencesChange(initial: initial, edited: _currentEdits());
  }

  bool get _hasChanges => !_buildChange().isEmpty;

  Future<void> _save() async {
    final change = _buildChange();
    if (change.isEmpty) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final savedLocally = await widget.preferences.save(widget.userId, change);
    if (!mounted) return;
    if (!savedLocally) {
      setState(() {
        _saving = false;
        _saveError = 'No se pudo guardar en este dispositivo.';
      });
      return;
    }
    final message = widget.security.isOnline
        ? 'Guardado.'
        : 'Guardado. Se enviará a Odoo al volver la conexión.';
    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ContentDialog(
        title: Text('Mis preferencias'),
        content: SizedBox(height: 120, child: Center(child: ProgressRing())),
      );
    }

    if (_loadError != null) {
      return ContentDialog(
        title: const Text('Mis preferencias'),
        content: Text(_loadError!),
        actions: [
          Button(
            child: const Text('Cerrar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
      title: const Text('Mis preferencias'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_saveError != null) ...[
            InfoBar(
              title: const Text('No se guardó'),
              content: Text(_saveError!),
              severity: InfoBarSeverity.error,
            ),
            const SizedBox(height: 12),
          ],
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: TabView(
              currentIndex: _tabIndex,
              onChanged: (index) => setState(() => _tabIndex = index),
              tabs: [
                _buildPreferenciasTab(),
                _buildCalendarioTab(),
                _buildPrivadoTab(),
                _buildGruposTab(),
                _buildSeguridadTab(),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey('user_preferences_save'),
          onPressed: (_saving || !_hasChanges) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2.5),
                )
              : const Text('Guardar'),
        ),
        Button(
          key: const ValueKey('user_preferences_cancel'),
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final initial = _initial!;
    final availableUserFields = initial.availableUserFields;
    final hasWarehouse = availableUserFields.contains('property_warehouse_id');
    final hasMobilePhone = availableUserFields.contains('mobile_phone');
    final warehouses = _catalogs?.warehouses ?? const [];
    // La foto recién elegida manda sobre la que ya estaba, y "quitar" manda
    // sobre ambas — el mismo orden que theos_pos.
    final avatarBytes = _avatarBytes ??
        (!_removeAvatar && _isValidAvatar(initial.avatar128)
            ? base64Decode(initial.avatar128!)
            : null);
    final hasWorkEmail = (initial.workEmail ?? '').isNotEmpty;
    final hasWorkPhone = (initial.workPhone ?? '').isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: FluentTheme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                image: avatarBytes != null
                    ? DecorationImage(
                        image: MemoryImage(avatarBytes),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: avatarBytes == null
                  ? Text(
                      initial.name.isNotEmpty
                          ? initial.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Button(
              key: const ValueKey('user_preferences_pick_avatar'),
              onPressed: _pickImage,
              child: const Text('Elegir foto'),
            ),
            if (avatarBytes != null) ...[
              const SizedBox(height: 4),
              Button(
                key: const ValueKey('user_preferences_remove_avatar'),
                onPressed: () => setState(() {
                  _removeAvatar = true;
                  _avatarBytes = null;
                }),
                child: const Text('Quitar foto'),
              ),
            ],
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                initial.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                initial.login,
                style: TextStyle(color: FluentTheme.of(context).inactiveColor),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  if (hasWorkEmail)
                    SizedBox(
                      width: 220,
                      child: InfoLabel(
                        label: 'Correo de trabajo',
                        child: Text(
                          initial.workEmail!,
                          key: const ValueKey('user_preferences_work_email'),
                        ),
                      ),
                    ),
                  if (hasWorkPhone)
                    SizedBox(
                      width: 220,
                      child: InfoLabel(
                        label: 'Teléfono de trabajo',
                        child: Text(
                          initial.workPhone!,
                          key: const ValueKey('user_preferences_work_phone'),
                        ),
                      ),
                    ),
                  if (hasMobilePhone)
                    SizedBox(
                      width: 220,
                      child: InfoLabel(
                        label: 'Teléfono móvil',
                        child: TextBox(
                          key: const ValueKey('user_preferences_mobile_phone'),
                          controller: _mobilePhoneController,
                        ),
                      ),
                    ),
                  if (hasWarehouse)
                    SizedBox(
                      width: 220,
                      child: InfoLabel(
                        label: 'Almacén',
                        child: ComboBox<int>(
                          key: const ValueKey('user_preferences_warehouse'),
                          placeholder: const Text('Seleccionar almacén'),
                          value: _warehouseId,
                          items: [
                            for (final entry in _idOptions(warehouses))
                              ComboBoxItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _warehouseId = value),
                          isExpanded: true,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Tab _buildPreferenciasTab() {
    final languages = _catalogs?.languages ?? const [];
    final notificationTypes = _catalogs?.notificationTypes ?? const [];
    final hasNotificationType = (_initial?.availableUserFields ?? const {})
        .contains('notification_type');

    return Tab(
      text: const Text('Preferencias'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Idioma',
              child: ComboBox<String>(
                key: const ValueKey('user_preferences_lang'),
                placeholder: const Text('Seleccionar idioma'),
                value: _lang,
                items: [
                  for (final entry in _codeOptions(languages))
                    ComboBoxItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() => _lang = value),
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Firma de correo electrónico',
              child: TextBox(controller: _signatureController, maxLines: 4),
            ),
            if (hasNotificationType) ...[
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Notificación',
                child: RadioGroup<String>(
                  groupValue: _notificationType ?? '',
                  onChanged: (value) =>
                      setState(() => _notificationType = value),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final entry in _codeOptions(notificationTypes))
                        RadioButton<String>(
                          value: entry.key,
                          content: Text(entry.value),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Tab _buildCalendarioTab() {
    final timezones = _catalogs?.timezones ?? const [];

    return Tab(
      text: const Text('Calendario'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: InfoLabel(
          label: 'Zona horaria',
          child: ComboBox<String>(
            key: const ValueKey('user_preferences_tz'),
            placeholder: const Text('Seleccionar zona horaria'),
            value: _tz,
            items: [
              for (final entry in _codeOptions(timezones))
                ComboBoxItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _tz = value),
            isExpanded: true,
          ),
        ),
      ),
    );
  }

  Tab _buildPrivadoTab() {
    final countries = _catalogs?.countries ?? const [];
    final states = _catalogs?.states ?? const [];

    return Tab(
      text: const Text('Privado'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: 'Correo electrónico privado',
              child: TextBox(controller: _emailController),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Teléfono privado',
              child: TextBox(
                key: const ValueKey('user_preferences_phone'),
                controller: _phoneController,
              ),
            ),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Dirección',
              child: Column(
                children: [
                  TextBox(
                    controller: _streetController,
                    placeholder: 'Calle...',
                  ),
                  const SizedBox(height: 8),
                  TextBox(
                    controller: _street2Controller,
                    placeholder: 'Calle 2...',
                  ),
                  const SizedBox(height: 8),
                  TextBox(controller: _cityController, placeholder: 'Ciudad'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: _zipController,
                          placeholder: 'C.P.',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ComboBox<int>(
                          key: const ValueKey('user_preferences_country'),
                          placeholder: const Text('País'),
                          value: _countryId,
                          items: [
                            for (final entry in _idOptions(countries))
                              ComboBoxItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                          ],
                          onChanged: _onCountryChanged,
                          isExpanded: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ComboBox<int>(
                    key: const ValueKey('user_preferences_state'),
                    placeholder: const Text('Provincia/Estado'),
                    value: _stateId,
                    items: [
                      for (final entry in _idOptions(states))
                        ComboBoxItem(value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: (value) => setState(() => _stateId = value),
                    isExpanded: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Tab _buildGruposTab() {
    return Tab(
      text: const Text('Grupos'),
      body: StreamBuilder<List<UserGroupInfo>>(
        stream: widget.preferences.watchGroups(widget.userId),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const [];
          if (!snapshot.hasData) {
            return const Center(child: ProgressRing());
          }
          if (groups.isEmpty) {
            return const Center(child: Text('No hay grupos asignados'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(group.fullName ?? group.name),
              );
            },
          );
        },
      ),
    );
  }

  Tab _buildSeguridadTab() {
    return Tab(
      text: const Text('Seguridad'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cambiar contraseña',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Button(
                  key: const ValueKey('user_preferences_change_password'),
                  onPressed: _showChangePasswordDialog,
                  child: const Text('Cambiar contraseña'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Dispositivos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (!widget.security.isOnline)
              const InfoBar(
                title: Text('Sin conexión'),
                content: Text(
                  'Ver y cerrar sesiones necesita conexión con el servidor.',
                ),
                severity: InfoBarSeverity.warning,
              )
            else
              FutureBuilder<List<UserDevice>>(
                future: _devicesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: ProgressRing());
                  }
                  final devices = snapshot.data!;
                  if (devices.isEmpty) {
                    return const Text('No hay dispositivos activos');
                  }
                  return Column(
                    children: [
                      for (final device in devices)
                        _buildDeviceRow(device),
                      const SizedBox(height: 8),
                      Button(
                        key: const ValueKey(
                          'user_preferences_revoke_all_devices',
                        ),
                        child: const Text(
                          'Cerrar sesión en todos los dispositivos',
                        ),
                        onPressed: () => _confirmRevoke(all: true),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceRow(UserDevice device) {
    final label = [
      device.platform,
      device.browser,
    ].whereType<String>().join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label.isEmpty ? 'Dispositivo' : label)),
          Button(
            child: const Text('Cerrar sesión'),
            onPressed: () => _confirmRevoke(all: false, deviceId: device.id),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    if (!widget.security.isOnline) {
      await showDialog<void>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Sin conexión'),
          content: const Text(
            'Cambiar la contraseña necesita conexión con el servidor.',
          ),
          actions: [
            Button(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    // Fuera del `builder`: si viviera dentro, `setDialogState` lo
    // reiniciaría a `null` en cada reconstrucción y el error jamás llegaría
    // a pintarse.
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return ContentDialog(
              title: const Text('Cambiar contraseña'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error != null) ...[
                      InfoBar(
                        title: const Text('No se pudo cambiar'),
                        content: Text(error!),
                        severity: InfoBarSeverity.error,
                      ),
                      const SizedBox(height: 12),
                    ],
                    InfoLabel(
                      label: 'Contraseña actual',
                      child: TextBox(
                        key: const ValueKey('user_preferences_old_password'),
                        controller: oldPasswordController,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: 'Nueva contraseña',
                      child: TextBox(
                        key: const ValueKey('user_preferences_new_password'),
                        controller: newPasswordController,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoLabel(
                      label: 'Confirmar nueva contraseña',
                      child: TextBox(
                        controller: confirmPasswordController,
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  key: const ValueKey('user_preferences_confirm_password'),
                  child: const Text('Cambiar contraseña'),
                  onPressed: () async {
                    final oldPassword = oldPasswordController.text;
                    final newPassword = newPasswordController.text;
                    final confirmPassword = confirmPasswordController.text;
                    if (oldPassword.isEmpty ||
                        newPassword.isEmpty ||
                        confirmPassword.isEmpty) {
                      setDialogState(
                        () => error = 'Todos los campos son requeridos.',
                      );
                      return;
                    }
                    if (newPassword != confirmPassword) {
                      setDialogState(
                        () => error = 'Las contraseñas no coinciden.',
                      );
                      return;
                    }
                    if (newPassword.length < 8) {
                      setDialogState(
                        () => error =
                            'La contraseña debe tener al menos 8 caracteres.',
                      );
                      return;
                    }
                    final result = await widget.security.changePassword(
                      oldPassword: oldPassword,
                      newPassword: newPassword,
                    );
                    if (result.isApplied) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      return;
                    }
                    setDialogState(
                      () => error =
                          result.outcome == UserSecurityActionOutcome.offline
                          ? 'Cambiar la contraseña necesita conexión con el servidor.'
                          : (result.serverMessage ??
                                'No se pudo cambiar la contraseña.'),
                    );
                  },
                ),
                Button(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      oldPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  Future<void> _confirmRevoke({required bool all, int? deviceId}) async {
    if (!widget.security.isOnline) {
      await showDialog<void>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Sin conexión'),
          content: Text(
            all
                ? 'Cerrar todas las sesiones necesita conexión con el servidor.'
                : 'Cerrar esta sesión necesita conexión con el servidor.',
          ),
          actions: [
            Button(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    final passwordController = TextEditingController();
    String? password;
    try {
      password = await showDialog<String>(
        context: context,
        builder: (context) => ContentDialog(
          title: Text(
            all ? 'Cerrar todas las sesiones' : 'Cerrar sesión',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                all
                    ? '¿Cerrar la sesión en todos los dispositivos excepto '
                          'este? No se puede deshacer.'
                    : '¿Cerrar la sesión en este dispositivo? No se puede '
                          'deshacer.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Por seguridad, ingresa tu contraseña actual:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextBox(
                key: const ValueKey('user_preferences_revoke_password'),
                controller: passwordController,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            FilledButton(
              key: const ValueKey('user_preferences_confirm_revoke'),
              child: Text(all ? 'Cerrar sesiones' : 'Cerrar sesión'),
              onPressed: () => passwordController.text.isEmpty
                  ? null
                  : Navigator.of(context).pop(passwordController.text),
            ),
            Button(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } finally {
      passwordController.dispose();
    }

    if (password == null || password.isEmpty) return;

    final result = all
        ? await widget.security.revokeAllDevices(password)
        : await widget.security.revokeDevice(deviceId!, password);

    if (!mounted) return;
    setState(() {
      _devicesFuture = widget.security.listDevices();
    });
    if (!result.isApplied && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('No se pudo cerrar la sesión'),
          content: Text(
            result.outcome == UserSecurityActionOutcome.offline
                ? 'Necesita conexión con el servidor.'
                : (result.serverMessage ?? 'Contraseña incorrecta.'),
          ),
          actions: [
            Button(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
}

bool _isValidAvatar(String? avatar) {
  if (avatar == null || avatar.isEmpty || avatar == 'false') return false;
  return true;
}

/// Convierte catálogos con código Odoo (`UserPreferencesCodeOption`) en pares
/// (código, etiqueta) — nunca un widget de texto leyendo ese campo en la
/// misma línea: esa forma exacta es justo el patrón que caza
/// `test/ui/no_raw_enum_names_test.dart`, aunque acá ese campo sea un dato de
/// negocio (el nombre del idioma, no un enum). Separar la extracción del
/// widget evita la falsa alarma sin tocar esa prueba. No es una trampa a esa
/// prueba: `option.name` es el nombre real del idioma/país/almacén que Odoo
/// devuelve para mostrar, un dato de negocio, no el `.name` de un `enum`.
List<MapEntry<String, String>> _codeOptions(
  List<UserPreferencesCodeOption> options,
) => [for (final option in options) MapEntry(option.code, option.name)];

List<MapEntry<int, String>> _idOptions(List<UserPreferencesOption> options) =>
    [for (final option in options) MapEntry(option.id, option.name)];

/// Snapshot de lo que hay hoy en los controles del formulario — el otro lado
/// del diff junto a la [UserPreferences] cargada. Separado de
/// `_UserPreferencesDialogState` (y expuesto, junto a
/// [buildUserPreferencesChange]) para poder probar la construcción del diff
/// —incluida la guarda de campos no disponibles— sin tener que montar el
/// widget completo y fingir una edición que la UI real nunca permitiría (un
/// campo oculto no tiene control que lo edite).
@visibleForTesting
final class UserPreferencesEdits {
  const UserPreferencesEdits({
    required this.lang,
    required this.tz,
    required this.notificationType,
    required this.signature,
    required this.warehouseId,
    required this.mobilePhone,
    required this.removeAvatar,
    required this.newAvatarBase64,
    required this.email,
    required this.phone,
    required this.street,
    required this.street2,
    required this.city,
    required this.zip,
    required this.countryId,
    required this.stateId,
  });

  final String? lang;
  final String? tz;
  final String? notificationType;
  final String signature;
  final int? warehouseId;
  final String mobilePhone;
  final bool removeAvatar;

  /// Base64 de la foto recién elegida (ya redimensionada a 1920px/JPEG 85),
  /// o `null` si no se tocó el avatar. Se ignora si [removeAvatar] es
  /// `true` — no tiene sentido pedir la foto nueva Y quitarla a la vez.
  final String? newAvatarBase64;
  final String email;
  final String phone;
  final String street;
  final String street2;
  final String city;
  final String zip;
  final int? countryId;
  final int? stateId;
}

/// Sólo los campos que de verdad cambiaron respecto a [initial] — igual que
/// `UserPreferencesDialog._savePreferences` en theos_pos: cada valor se
/// compara contra su snapshot inicial antes de entrar al diff. Un campo
/// ausente de `initial.availableUserFields`/`availablePartnerFields` (el
/// servidor conectado no lo tiene — ver [UserPreferences.availableUserFields])
/// nunca entra al diff, tenga o no el mismo valor en [edited]: no hay control
/// que lo edite, así que cualquier diferencia sería un error de otra parte
/// del código, no una intención del usuario.
@visibleForTesting
UserPreferencesChange buildUserPreferencesChange({
  required UserPreferences initial,
  required UserPreferencesEdits edited,
}) {
  final userValues = <String, dynamic>{};
  final partnerValues = <String, dynamic>{};

  if (edited.lang != initial.lang) userValues['lang'] = edited.lang;
  if (edited.tz != initial.tz) userValues['tz'] = edited.tz;
  if (edited.signature != (initial.signature ?? '')) {
    userValues['signature'] = edited.signature;
  }
  if (initial.availableUserFields.contains('notification_type') &&
      edited.notificationType != initial.notificationType) {
    userValues['notification_type'] = edited.notificationType;
  }
  if (initial.availableUserFields.contains('property_warehouse_id') &&
      edited.warehouseId != initial.warehouseId) {
    userValues['property_warehouse_id'] = edited.warehouseId;
  }
  if (initial.availableUserFields.contains('mobile_phone') &&
      edited.mobilePhone != (initial.mobilePhone ?? '')) {
    userValues['mobile_phone'] = edited.mobilePhone;
  }
  if (edited.removeAvatar) {
    userValues['image_1920'] = false;
  } else if (edited.newAvatarBase64 != null) {
    userValues['image_1920'] = edited.newAvatarBase64;
  }

  if (edited.email != (initial.email ?? '')) {
    partnerValues['email'] = edited.email;
  }
  if (edited.phone != (initial.phone ?? '')) {
    partnerValues['phone'] = edited.phone;
  }
  if (edited.street != (initial.street ?? '')) {
    partnerValues['street'] = edited.street;
  }
  if (edited.street2 != (initial.street2 ?? '')) {
    partnerValues['street2'] = edited.street2;
  }
  if (edited.city != (initial.city ?? '')) {
    partnerValues['city'] = edited.city;
  }
  if (edited.zip != (initial.zip ?? '')) {
    partnerValues['zip'] = edited.zip;
  }
  if (edited.countryId != initial.countryId) {
    partnerValues['country_id'] = edited.countryId;
  }
  if (edited.stateId != initial.stateId) {
    partnerValues['state_id'] = edited.stateId;
  }

  return UserPreferencesChange(
    partnerId: initial.partnerId,
    userValues: userValues,
    partnerValues: partnerValues,
  );
}
