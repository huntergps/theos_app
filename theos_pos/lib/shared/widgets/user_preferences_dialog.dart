import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../providers/user_provider.dart';
import '../../core/database/providers.dart';
import '../../core/managers/manager_providers.dart' show appDatabaseProvider;

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../../shared/models/res_device.model.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../features/warehouses/providers/warehouse_providers.dart'
    show warehousesProvider;

import '../../core/services/platform/global_notification_service.dart';
import 'dialogs/copyable_info_bar.dart';

part 'user_preferences_tab_groups.dart';
part 'user_preferences_tab_calendar.dart';
part 'user_preferences_tab_general.dart';
part 'user_preferences_tab_private.dart';
part 'user_preferences_tab_security.dart';

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
///
/// `StreamProvider` reactivo (antes `FutureProvider` de una sola vez con SQL
/// crudo directo acá — violación de capa + no reactivo, ver plan de refactor
/// "d-flutter" ítem 2). El fetch de `group_ids` ahora vive en
/// `UserRepository.watchCurrentUserGroupIds()` (usa `.watchSingleOrNull()`
/// de Drift), así que si `group_ids` cambia por un re-sync de sesión/permisos
/// mientras el diálogo está abierto, la UI se actualiza sola. La resolución
/// de nombre por grupo se mantiene acá (dato de catálogo estático, no es el
/// riesgo de reactividad que se quería resolver).
final userGroupsProvider = StreamProvider<List<UserGroupInfo>>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return Stream.value(const []);

  final repo = ref.watch(userRepositoryProvider);
  if (repo == null) return Stream.value(const []);

  final appDb = ref.watch(appDatabaseProvider);

  return repo.watchCurrentUserGroupIds().asyncMap((groupIds) async {
    if (groupIds.isEmpty) return <UserGroupInfo>[];

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
    try {
      await _loadDataInternal().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (mounted) {
        setState(() => _isLoading = false);
        ref
            .read(globalNotificationProvider)
            .showError(
              context,
              title: 'Preferencias',
              message: 'Las preferencias tardaron demasiado en cargar. Revisa la conexión e inténtalo nuevamente.',
            );
      }
    }
  }

  Future<void> _loadDataInternal() async {
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
      // Local streams should resolve offline; bound each one independently so
      // one unavailable cache cannot hold the whole preferences dialog open.
      final languages = await ref
          .read(languagesProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => const []);
      final warehouses = await ref
          .read(warehousesProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => const []);
      final calendars = await ref
          .read(calendarsProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => const []);
      final countries = await ref
          .read(countriesProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => const []);
      final timezones = await ref
          .read(timezonesProvider.future)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => const [
              ['America/Guayaquil', 'America/Guayaquil'],
            ],
          );
      final notificationTypes = await ref
          .read(notificationTypesProvider.future)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => const [
              ['email', 'Correo electrónico'],
              ['inbox', 'Bandeja de entrada'],
            ],
          );

      if (!mounted) return;

      // Fetch partner data (offline-first)
      Client? partner;
      if (user.partnerId != null && repo != null) {
        try {
          partner = await repo
              .getPartner(user.partnerId!)
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          // Intentionally empty - non-critical UI operation
        }
      }

      // Fetch states only if country is selected
      final states = partner?.countryId != null
          ? await ref
                .read(statesProvider(partner!.countryId!).future)
                .timeout(const Duration(seconds: 3), onTimeout: () => const [])
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
      final result = await FilePicker.pickFiles(type: FileType.image);

      if (result.isNotEmpty) {
        final originalBytes = await result.first.readAsBytes();

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
      var success = true;

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
        final repository = ref.read(userRepositoryProvider);
        if (repository == null) {
          success = false;
        } else {
          success = await repository.updateUserAndPartner(
            userId: user!.id,
            partnerId: user.partnerId,
            userValues: userUpdates,
            partnerValues: partnerUpdates,
          );
        }
      } else if (userUpdates.isNotEmpty && user != null) {
        final repository = ref.read(userRepositoryProvider);
        success =
            repository != null &&
            await repository.updateUserAndPartner(
              userId: user.id,
              userValues: userUpdates,
            );
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
        ref.showErrorNotification(
          context,
          title: 'Error al guardar perfil',
          message: '$e',
        );
      }
    }
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
                        color: AppColors.borderLight.withValues(alpha: 0.5),
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
                              color: AppColors.textSecondary,
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
                          Tooltip(
                            message: 'Cambiar foto',
                            child: IconButton(
                              icon: const Icon(
                                FluentIcons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                              onPressed: _pickImage,
                            ),
                          ),
                          if (_avatarBytes != null ||
                              (!_removeAvatar &&
                                  _isValidAvatar(user.avatar128)))
                            Tooltip(
                              message: 'Quitar foto',
                              child: IconButton(
                                icon: const Icon(
                                  FluentIcons.delete,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                onPressed: _clearImage,
                              ),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
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
}
