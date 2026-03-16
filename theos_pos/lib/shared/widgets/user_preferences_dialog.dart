import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/app_constants.dart';
import '../providers/user_provider.dart';
import '../../core/services/odoo_service.dart';
import '../../core/database/providers.dart';
import '../../core/managers/manager_providers.dart' show appDatabaseProvider;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../shared/models/res_device.model.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../features/warehouses/warehouses.dart';

import '../../core/services/platform/global_notification_service.dart';
import 'dialogs/copyable_info_bar.dart';

/// Provider for user devices (sessions)
final userDevicesProvider = FutureProvider<List<ResDevice>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  if (repo == null) return [];
  return await repo.getUserDevices();
});

/// Model for user group info
class UserGroupInfo {
  final int id;
  final String name;
  final String? fullName;
  final String? xmlId;

  const UserGroupInfo({
    required this.id,
    required this.name,
    this.fullName,
    this.xmlId,
  });
}

/// Provider for user groups
final userGroupsProvider = FutureProvider<List<UserGroupInfo>>((ref) async {
  final user = ref.watch(userProvider);
  if (user == null) return [];

  final appDb = ref.watch(appDatabaseProvider);

  // Get group_ids directly from database (more reliable than UserModel)
  final currentUserRow = await appDb
      .customSelect(
        'SELECT group_ids FROM res_users WHERE is_current_user = 1 LIMIT 1',
      )
      .getSingleOrNull();

  if (currentUserRow == null) return [];

  final groupIdsStr = currentUserRow.read<String?>('group_ids');
  if (groupIdsStr == null || groupIdsStr.isEmpty) return [];

  // Parse comma-separated group IDs
  final groupIds = groupIdsStr
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toList();

  if (groupIds.isEmpty) return [];

  // Query groups from database
  final groups = <UserGroupInfo>[];
  for (final groupId in groupIds) {
    try {
      final result = await appDb
          .customSelect(
            'SELECT odoo_id, name, full_name, xml_id FROM res_groups WHERE odoo_id = ?',
            variables: [drift.Variable.withInt(groupId)],
          )
          .getSingleOrNull();

      if (result != null) {
        groups.add(
          UserGroupInfo(
            id: result.read<int>('odoo_id'),
            name: result.read<String>('name'),
            fullName: result.read<String?>('full_name'),
            xmlId: result.read<String?>('xml_id'),
          ),
        );
      }
    } catch (e) {
      // Intentionally empty - non-critical UI operation
    }
  }

  // Sort by name
  groups.sort((a, b) => a.name.compareTo(b.name));
  return groups;
});

/// Resize and compress image for Odoo upload (max 1920px, JPEG quality 85)
Uint8List? _optimizeImage(
  Uint8List bytes, {
  int maxSize = 1920,
  int quality = 85,
}) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // Resize if larger than maxSize
    img.Image resized = image;
    if (image.width > maxSize || image.height > maxSize) {
      if (image.width > image.height) {
        resized = img.copyResize(image, width: maxSize);
      } else {
        resized = img.copyResize(image, height: maxSize);
      }
    }

    // Encode as JPEG with quality
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  } catch (e) {
    return bytes; // Return original if optimization fails
  }
}

/// Check if avatar is valid (not null, not empty, not 'false', not SVG)
bool _isValidAvatar(String? avatar) {
  if (avatar == null || avatar.isEmpty || avatar == 'false') return false;
  // SVG starts with "PD94bWwg" (<?xml) when base64 encoded - Flutter can't decode SVG
  if (avatar.startsWith('PD94bWwg')) return false;
  return true;
}

class UserPreferencesDialog extends ConsumerStatefulWidget {
  const UserPreferencesDialog({super.key});

  @override
  ConsumerState<UserPreferencesDialog> createState() =>
      _UserPreferencesDialogState();
}

class _UserPreferencesDialogState extends ConsumerState<UserPreferencesDialog> {
  int _currentIndex = 0;
  bool _isLoading = false;

  // Data Sources
  List<Map<String, dynamic>> _languages = [];
  List<dynamic> _timezones = []; // List of [code, name]
  List<dynamic> _notificationTypes = []; // List of [code, name]
  List<Map<String, dynamic>> _workSchedules = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];

  // Form State
  TextEditingController? _signatureController;
  TextEditingController? _outOfOfficeController;
  TextEditingController? _emailController; // Private Email
  TextEditingController? _phoneController; // Private Phone
  TextEditingController? _workEmailController;
  TextEditingController? _workPhoneController;
  TextEditingController? _mobilePhoneController;

  // Address Controllers
  TextEditingController? _streetController;
  TextEditingController? _street2Controller;
  TextEditingController? _cityController;
  TextEditingController? _zipController;

  // Emergency Contact
  TextEditingController? _emergencyNameController;
  TextEditingController? _emergencyPhoneController;

  String? _selectedLang;
  String? _selectedTz;
  String? _notificationType;
  int? _selectedWarehouseId;
  int? _selectedCountryId;
  int? _selectedStateId;

  // Initial values for change detection
  Map<String, dynamic> _initialUserValues = {};
  Map<String, dynamic> _initialPartnerValues = {};

  // Avatar State
  Uint8List? _avatarBytes;
  bool _removeAvatar = false;

  bool _controllersInitialized = false;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final repo = ref.read(userRepositoryProvider);

    try {
      // User already loaded at login - use existing data
      final user = ref.read(userProvider);
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Fetch data from Brick (offline-first)
      final languages = await ref.read(languagesProvider.future);
      final warehouses = await ref.read(warehousesProvider.future);
      final calendars = await ref.read(calendarsProvider.future);
      final countries = await ref.read(countriesProvider.future);
      final timezones = await ref.read(timezonesProvider.future);
      final notificationTypes = await ref.read(
        notificationTypesProvider.future,
      );

      if (!mounted) return;

      // Fetch partner data (offline-first)
      Client? partner;
      if (user.partnerId != null && repo != null) {
        try {
          partner = await repo.getPartner(user.partnerId!);
        } catch (e) {
      // Intentionally empty - non-critical UI operation
    }
      }

      // Fetch states only if country is selected
      final states = partner?.countryId != null
          ? await ref.read(statesProvider(partner!.countryId!).future)
          : <dynamic>[];

      if (!mounted) return;

      setState(() {
        // Initialize options from Brick
        _languages = languages
            .map((l) => {'id': l.id, 'name': l.name, 'code': l.code})
            .toList();
        _warehouses = warehouses
            .map((w) => {'id': w.id, 'name': w.name, 'code': w.code})
            .toList();
        _workSchedules = calendars
            .map((c) => {'id': c.id, 'name': c.name})
            .toList();
        _countries = countries
            .map((c) => {'id': c.id, 'name': c.name, 'code': c.code})
            .toList();
        _timezones = timezones;
        _notificationTypes = notificationTypes;
        _states = states
            .map((s) => {'id': s.id, 'name': s.name, 'code': s.code})
            .toList();

        // Initialize controllers with user data
        _signatureController = TextEditingController(
          text: user.signature ?? '',
        );
        _outOfOfficeController = TextEditingController();

        // Private info from partner
        _emailController = TextEditingController(text: partner?.email ?? '');
        _phoneController = TextEditingController(text: partner?.phone ?? '');

        // Work info (these are HR related fields, may be empty without HR module)
        _workEmailController = TextEditingController(
          text: user.workEmail ?? '',
        );
        _workPhoneController = TextEditingController(
          text: user.workPhone ?? '',
        );
        _mobilePhoneController = TextEditingController(
          text: user.mobilePhone ?? '',
        );

        // Store initial values for change detection
        _initialUserValues = {
          'lang': user.lang,
          'tz': user.tz,
          'signature': user.signature ?? '',
          'property_warehouse_id': user.warehouseId,
          'mobile_phone': user.mobilePhone,
        };
        _initialPartnerValues = {
          'email': partner?.email ?? '',
          'phone': partner?.phone ?? '',
          'street': partner?.street ?? '',
          'street2': partner?.street2 ?? '',
          'city': partner?.city ?? '',
          'zip': partner?.zip ?? '',
          'country_id': partner?.countryId,
          'state_id': partner?.stateId,
        };

        // Address
        _streetController = TextEditingController(text: partner?.street ?? '');
        _street2Controller = TextEditingController(
          text: partner?.street2 ?? '',
        );
        _cityController = TextEditingController(text: partner?.city ?? '');
        _zipController = TextEditingController(text: partner?.zip ?? '');

        _selectedCountryId = partner?.countryId;
        _selectedStateId = partner?.stateId;

        // Emergency (Placeholder for now as fields might vary)
        _emergencyNameController = TextEditingController();
        _emergencyPhoneController = TextEditingController();

        // Validate selections
        _selectedLang = user.lang;
        if (_selectedLang != null &&
            !_languages.any((l) => l['code'] == _selectedLang)) {
          // If language is not in the list (maybe inactive?), keep it or nullify?
          // Fluent UI might crash if value not in items.
          // Let's add it temporarily or nullify. Safer to nullify if we can't display it.
          // Or better: don't set it if not found.
          // Actually, Odoo 'lang' code should be in 'res.lang'.
          if (_languages.isNotEmpty) {
            // If we have languages but ours is not there, maybe we should fetch it?
            // For now, let's just allow it if it matches, otherwise null.
            // _selectedLang = null;
            // Wait, if it's null, the user loses their setting on save.
            // Better to add it to the list if missing?
            // For now, let's assume getLanguages returns all active langs.
            // If user has an inactive lang, it might be an issue.
            // Let's check if it exists.
            bool exists = _languages.any((l) => l['code'] == _selectedLang);
            if (!exists) _selectedLang = null;
          }
        }

        _selectedTz = user.tz;
        // Timezones are handled in the build method (it adds the selected one if missing)

        _selectedWarehouseId = user.warehouseId;
        if (_selectedWarehouseId != null) {
          bool exists = _warehouses.any((w) => w['id'] == _selectedWarehouseId);
          if (!exists) {
            _selectedWarehouseId = null;
          }
        }

        _notificationType =
            'email'; // Default, ideally fetch from user if available

        _controllersInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _signatureController?.dispose();
    _outOfOfficeController?.dispose();
    _emailController?.dispose();
    _phoneController?.dispose();
    _workEmailController?.dispose();
    _workPhoneController?.dispose();
    _mobilePhoneController?.dispose();
    _streetController?.dispose();
    _street2Controller?.dispose();
    _cityController?.dispose();
    _zipController?.dispose();
    _emergencyNameController?.dispose();
    _emergencyPhoneController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final originalBytes = result.files.single.bytes!;

        // Optimize image for upload
        final optimized = _optimizeImage(originalBytes);
        if (optimized != null) {
          setState(() {
            _avatarBytes = optimized;
            _removeAvatar = false;
          });
        }
      }
    } catch (e) {
      // Intentionally empty - non-critical UI operation
    }
  }

  void _clearImage() {
    setState(() {
      _avatarBytes = null;
      _removeAvatar = true;
    });
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);

    // Build user updates - only include changed fields
    final userUpdates = <String, dynamic>{};

    if (_selectedLang != _initialUserValues['lang']) {
      userUpdates['lang'] = _selectedLang;
    }
    if (_selectedTz != _initialUserValues['tz']) {
      userUpdates['tz'] = _selectedTz;
    }
    final currentSignature = _signatureController?.text ?? '';
    if (currentSignature != _initialUserValues['signature']) {
      userUpdates['signature'] = currentSignature;
    }
    if (_selectedWarehouseId != _initialUserValues['property_warehouse_id']) {
      userUpdates['property_warehouse_id'] = _selectedWarehouseId;
    }
    final currentMobilePhone = _mobilePhoneController?.text ?? '';
    if (currentMobilePhone != _initialUserValues['mobile_phone']) {
      userUpdates['mobile_phone'] = currentMobilePhone;
    }

    // Handle Avatar Update (always include if changed)
    if (_removeAvatar) {
      userUpdates['image_1920'] = false;
    } else if (_avatarBytes != null) {
      userUpdates['image_1920'] = base64Encode(_avatarBytes!);
    }

    try {
      final user = ref.read(userProvider);
      bool success = true;

      // Only call API if there are changes
      if (userUpdates.isNotEmpty) {
        success = await ref.read(userProvider.notifier).updateUser(userUpdates);
      }

      // Build partner updates - only include changed fields (no 'mobile' field)
      if (user?.partnerId != null) {
        final partnerUpdates = <String, dynamic>{};

        final currentEmail = _emailController?.text ?? '';
        if (currentEmail != _initialPartnerValues['email']) {
          partnerUpdates['email'] = currentEmail;
        }
        final currentPhone = _phoneController?.text ?? '';
        if (currentPhone != _initialPartnerValues['phone']) {
          partnerUpdates['phone'] = currentPhone;
        }
        final currentStreet = _streetController?.text ?? '';
        if (currentStreet != _initialPartnerValues['street']) {
          partnerUpdates['street'] = currentStreet;
        }
        final currentStreet2 = _street2Controller?.text ?? '';
        if (currentStreet2 != _initialPartnerValues['street2']) {
          partnerUpdates['street2'] = currentStreet2;
        }
        final currentCity = _cityController?.text ?? '';
        if (currentCity != _initialPartnerValues['city']) {
          partnerUpdates['city'] = currentCity;
        }
        final currentZip = _zipController?.text ?? '';
        if (currentZip != _initialPartnerValues['zip']) {
          partnerUpdates['zip'] = currentZip;
        }
        if (_selectedCountryId != _initialPartnerValues['country_id']) {
          partnerUpdates['country_id'] = _selectedCountryId;
        }
        if (_selectedStateId != _initialPartnerValues['state_id']) {
          partnerUpdates['state_id'] = _selectedStateId;
        }

        // Only call API if there are changes
        if (partnerUpdates.isNotEmpty) {
          final odoo = ref.read(odooServiceProvider);

          final partnerSuccess = await odoo.call(
            model: 'res.partner',
            method: 'write',
            kwargs: {
              'ids': [user!.partnerId],
              'vals': partnerUpdates,
            },
          );
          if (partnerSuccess != true) {}
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context);
        } else {
          ref.showErrorNotification(
            context,
            title: 'Error al guardar perfil',
            message: 'No se pudieron guardar los cambios en el usuario',
          );
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ref.showErrorNotification(context, title: 'Error al guardar perfil', message: '$e');
      }
    }
  }

  /// Revoke a specific device
  Future<void> _revokeDevice(int deviceId) async {
    // First, ask for password confirmation
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
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
              title: 'Error al cerrar sesion',
              message: 'Contraseña incorrecta o no se pudo cerrar la sesión',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ref.showErrorNotification(context, title: 'Error al cerrar sesion', message: '$e');
        }
      }
    }
  }

  /// Revoke all devices except current
  Future<void> _revokeAllDevices() async {
    // First, ask for password confirmation
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
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
          ref.showErrorNotification(context, title: 'Error al cerrar sesiones', message: '$e');
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
                    suffix: IconButton(
                      icon: Icon(
                        obscureOld ? FluentIcons.red_eye : FluentIcons.hide3,
                      ),
                      onPressed: () => setState(() => obscureOld = !obscureOld),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Nueva contraseña',
                  child: TextBox(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    suffix: IconButton(
                      icon: Icon(
                        obscureNew ? FluentIcons.red_eye : FluentIcons.hide3,
                      ),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InfoLabel(
                  label: 'Confirmar nueva contraseña',
                  child: TextBox(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    suffix: IconButton(
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
                    title: 'Validacion de contraseña',
                    message: 'Todos los campos son requeridos',
                  );
                  return;
                }

                if (newPassword != confirmPassword) {
                  CopyableInfoBar.showError(
                    context,
                    title: 'Validacion de contraseña',
                    message: 'Las contraseñas no coinciden',
                  );
                  return;
                }

                if (newPassword.length < 8) {
                  CopyableInfoBar.showError(
                    context,
                    title: 'Validacion de contraseña',
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
            message:
                'No se pudo cambiar la contraseña. Verifica tu contraseña actual',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ref.showErrorNotification(context, title: 'Error al cambiar contraseña', message: '$e');
      }
    }
  }

  Widget _buildEditableRow(
    IconData icon,
    String label,
    TextEditingController? controller,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: TextBox(
            controller: controller,
            placeholder: label,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseSelector() {
    return Row(
      children: [
        const Icon(FluentIcons.product, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: _warehouses.isEmpty
              ? const Text('Cargando...')
              : ComboBox<int>(
                  placeholder: const Text('Almacén'),
                  value: _selectedWarehouseId,
                  items: _warehouses.map((wh) {
                    return ComboBoxItem<int>(
                      value: wh['id'],
                      child: Text(wh['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedWarehouseId = value);
                  },
                  isExpanded: true,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    if (user == null || !_controllersInitialized) {
      return ContentDialog(
        title: const Text('Cargando...'),
        content: const Center(child: ProgressRing()),
        actions: [
          Button(
            child: const Text('Cerrar'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }

    // Controllers are initialized in _loadData

    return ContentDialog(
      constraints: const BoxConstraints(
        maxWidth: DialogSizes.xlargeWidth,
        maxHeight: DialogSizes.xlargeHeight,
      ),
      // title: const Text('Cambiar mis preferencias'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Avatar and Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rectangular Avatar (Odoo style)
              // Rectangular Avatar (Odoo style)
              Stack(
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: Colors.grey[30],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[100].withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      image: _avatarBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_avatarBytes!),
                              fit: BoxFit.cover,
                            )
                          : (!_removeAvatar && _isValidAvatar(user.avatar128))
                          ? DecorationImage(
                              image: MemoryImage(base64Decode(user.avatar128!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child:
                        (_avatarBytes == null &&
                            (_removeAvatar || !_isValidAvatar(user.avatar128)))
                        ? Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 48,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  // Edit Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                      ),
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              FluentIcons.edit,
                              size: 14,
                              color: Colors.white,
                            ),
                            onPressed: _pickImage,
                          ),
                          if (_avatarBytes != null ||
                              (!_removeAvatar && _isValidAvatar(user.avatar128)))
                            IconButton(
                              icon: const Icon(
                                FluentIcons.delete,
                                size: 14,
                                color: Colors.white,
                              ),
                              onPressed: _clearImage,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.login,
                      style: TextStyle(fontSize: 14, color: Colors.grey[100]),
                    ),
                    const SizedBox(height: 12),
                    // Editable fields in two columns
                    _buildResponsiveLayout([
                      Column(
                        children: [
                          _buildEditableRow(
                            FluentIcons.mail,
                            'Email trabajo',
                            _workEmailController,
                          ),
                          const SizedBox(height: 8),
                          _buildEditableRow(
                            FluentIcons.phone,
                            'Teléfono trabajo',
                            _workPhoneController,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          _buildEditableRow(
                            FluentIcons.cell_phone,
                            'Móvil',
                            _mobilePhoneController,
                          ),
                          const SizedBox(height: 8),
                          _buildWarehouseSelector(),
                        ],
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Tabs
          Expanded(
            child: TabView(
              currentIndex: _currentIndex,
              onChanged: (index) => setState(() => _currentIndex = index),
              tabs: [
                _buildPreferenciasTab(user),
                _buildCalendarioTab(user),
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
          onPressed: _isLoading ? null : _savePreferences,
          child: _isLoading
              ? const ProgressRing(activeColor: Colors.white, strokeWidth: 2.5)
              : const Text('Actualizar preferencias'),
        ),
        Button(
          child: const Text('Descartar'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildResponsiveLayout(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < ScreenBreakpoints.mobileMaxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: child,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map((child) => Expanded(child: child))
              .toList()
              .expand((widget) => [widget, const SizedBox(width: 24)])
              .take(children.length * 2 - 1)
              .toList(),
        );
      },
    );
  }

  Tab _buildPreferenciasTab(dynamic user) {
    return Tab(
      text: const Text('Preferencias'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResponsiveLayout([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoLabel(
                    label: 'Idioma',
                    child: ComboBox<String>(
                      placeholder: const Text('Seleccionar idioma'),
                      value: _selectedLang,
                      items: _languages.map((lang) {
                        return ComboBoxItem<String>(
                          value: lang['code'],
                          child: Text(lang['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedLang = value);
                      },
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'Firma de correo electrónico',
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[80]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      constraints: const BoxConstraints(
                        minHeight: 80,
                        maxHeight: 120,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: (_signatureController?.text.isNotEmpty ?? false)
                          ? SingleChildScrollView(
                              child: Html(data: _signatureController!.text),
                            )
                          : Text(
                              'Sin firma',
                              style: TextStyle(
                                color: Colors.grey[100],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 16,
                  ), // Align with second item of left col
                  InfoLabel(
                    label: 'Notificación',
                    child: _notificationTypes.isEmpty
                        ? const Text('Cargando opciones...')
                        : RadioGroup<String>(
                            groupValue: _notificationType ?? '',
                            onChanged: (v) =>
                                setState(() => _notificationType = v),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: _notificationTypes.map((type) {
                                final code = type[0] as String;
                                final name = type[1] as String;
                                return RadioButton<String>(
                                  value: code,
                                  content: Text(name),
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Tab _buildCalendarioTab(dynamic user) {
    return Tab(
      text: const Text('Calendario'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResponsiveLayout([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoLabel(
                    label: 'Zona horaria',
                    child: ComboBox<String>(
                      placeholder: const Text('Seleccionar zona horaria'),
                      value: _selectedTz,
                      items: _timezones.map((tz) {
                        final code = tz[0] as String;
                        final name = tz[1] as String;
                        return ComboBoxItem<String>(
                          value: code,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedTz = value);
                      },
                      isExpanded: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InfoLabel(
                    label: 'Posición del Chatter',
                    child: ComboBox<String>(
                      placeholder: const Text('Posición'),
                      value: 'Abajo',
                      items: const [
                        ComboBoxItem(value: 'Abajo', child: Text('Abajo')),
                        ComboBoxItem(value: 'Lado', child: Text('Lado')),
                      ],
                      onChanged: (value) {},
                      isExpanded: true,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubicación principal de trabajo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Sin especificar'),
                  const SizedBox(height: 24),
                  const Text(
                    'Horario de trabajo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _workSchedules.isEmpty
                      ? const Text('Cargando horarios...')
                      : ComboBox<int>(
                          placeholder: const Text('Seleccionar horario'),
                          // value: _selectedWorkScheduleId, // Bind when model has it
                          items: _workSchedules.map((schedule) {
                            return ComboBoxItem<int>(
                              value: schedule['id'],
                              child: Text(schedule['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            // setState(() => _selectedWorkScheduleId = value);
                          },
                          isExpanded: true,
                        ),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Tab _buildPrivadoTab() {
    return Tab(
      text: const Text('Privado'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _buildResponsiveLayout([
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INFORMACIÓN PRIVADA',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Dirección particular',
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
                    Row(
                      children: [
                        Expanded(
                          child: TextBox(
                            controller: _cityController,
                            placeholder: 'Ciudad',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _states.isEmpty && _selectedCountryId != null
                              ? const Text('Cargando...')
                              : ComboBox<int>(
                                  placeholder: const Text('Estado'),
                                  value: _selectedStateId,
                                  items: _states.map((s) {
                                    return ComboBoxItem<int>(
                                      value: s['id'],
                                      child: Text(s['name']),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedStateId = value);
                                  },
                                  isExpanded: true,
                                ),
                        ),
                      ],
                    ),
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
                          child: _countries.isEmpty
                              ? const Text('Cargando...')
                              : ComboBox<int>(
                                  placeholder: const Text('País'),
                                  value: _selectedCountryId,
                                  items: _countries.map((c) {
                                    return ComboBoxItem<int>(
                                      value: c['id'],
                                      child: Text(c['name']),
                                    );
                                  }).toList(),
                                  onChanged: (value) async {
                                    setState(() {
                                      _selectedCountryId = value;
                                      _selectedStateId = null;
                                      _states = [];
                                    });
                                    if (value != null) {
                                      final states = await ref
                                          .read(odooServiceProvider)
                                          .getStates(value);
                                      if (mounted) {
                                        setState(() => _states = states);
                                      }
                                    }
                                  },
                                  isExpanded: true,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Correo electrónico privado',
                child: TextBox(
                  controller: _emailController,
                  placeholder: 'Correo privado',
                ),
              ),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Teléfono privado',
                child: TextBox(
                  controller: _phoneController,
                  placeholder: 'Teléfono',
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONTACTO DE EMERGENCIA',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Nombre del contacto',
                child: TextBox(
                  controller: _emergencyNameController,
                  placeholder: 'Por ejemplo, Juan Pérez',
                ),
              ),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Teléfono del contacto',
                child: TextBox(
                  controller: _emergencyPhoneController,
                  placeholder: 'Teléfono',
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Tab _buildGruposTab() {
    return Tab(
      text: const Text('Grupos'),
      body: Consumer(
        builder: (context, ref, child) {
          final groupsAsync = ref.watch(userGroupsProvider);

          return groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.group,
                        size: 48,
                        color: Colors.grey[100],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay grupos asignados',
                        style: TextStyle(color: Colors.grey[100]),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(FluentIcons.group, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Grupos asignados (${groups.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: FluentTheme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[80]),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      FluentIcons.permissions,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.fullName ?? group.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (group.xmlId != null &&
                                          group.xmlId!.isNotEmpty)
                                        Text(
                                          group.xmlId!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[100],
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: ProgressRing()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar grupos: $error',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
                        style: TextStyle(color: Colors.grey[100]),
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
                  style: TextStyle(color: Colors.grey[100]),
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
                              border: Border.all(color: Colors.grey[80]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'No hay dispositivos activos',
                              style: TextStyle(color: Colors.grey[100]),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[80]),
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
                          border: Border.all(color: Colors.grey[80]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(child: ProgressRing()),
                      ),
                      error: (error, stack) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[80]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Error al cargar dispositivos: $error',
                          style: TextStyle(color: Colors.red),
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
                        color: device.revoked ? Colors.grey : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device.getRelativeTime(),
                      style: TextStyle(color: Colors.grey[100], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  device.location,
                  style: TextStyle(color: Colors.grey[100], fontSize: 12),
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
