import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_widgets/odoo_widgets.dart'
    show OdooFieldConfig, OdooTextField, OdooSelectionField, OdooMultilineField, SelectionOption;
import 'package:uuid/uuid.dart';

import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../core/services/logger_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show clientManager, ClientManagerBusiness, resCountryManager, resCountryStateManager;
import 'package:odoo_sdk/latam.dart' show EcuadorVatValidator;

/// Dialog for creating a client offline
///
/// Creates a local client that will be synced when connection is restored.
/// Returns the created client data for immediate use in forms.
///
/// Usage:
/// ```dart
/// final client = await showDialog<Map<String, dynamic>>(
///   context: context,
///   builder: (_) => const CreateClientOfflineDialog(),
/// );
/// if (client != null) {
///   // Handle created client
/// }
/// ```
class CreateClientOfflineDialog extends ConsumerStatefulWidget {
  const CreateClientOfflineDialog({super.key});

  @override
  ConsumerState<CreateClientOfflineDialog> createState() =>
      _CreateClientOfflineDialogState();
}

class _CreateClientOfflineDialogState
    extends ConsumerState<CreateClientOfflineDialog> {
  bool _isCreating = false;
  bool _isLoadingMasterData = true;
  String? _error;

  // Value-based state (no controllers)
  String _name = '';
  String _vat = '';
  String _email = '';
  String _phone = '';
  String _street = '';
  String _city = '';

  String _selectedIdType = EcuadorVatValidator.typeCedula;
  String? _selectedTaxpayerType;
  int? _selectedStateId;
  int? _selectedCountryId;

  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _filteredStates = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    try {
      // Load countries via manager, then sort Ecuador first
      final countries = await resCountryManager.searchLocal(orderBy: 'name asc');
      _countries = countries
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'code': c.code,
              })
          .toList();
      // Sort Ecuador first
      _countries.sort((a, b) {
        final aEc = a['code'] == 'EC' ? 0 : 1;
        final bEc = b['code'] == 'EC' ? 0 : 1;
        if (aEc != bEc) return aEc.compareTo(bEc);
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      // Load all states via manager
      final states = await resCountryStateManager.searchLocal(orderBy: 'name asc');
      _states = states
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'code': s.code,
                'country_id': s.countryId,
              })
          .toList();

      final ecuadorCountry =
          _countries.where((c) => c['code'] == 'EC').firstOrNull;
      if (ecuadorCountry != null) {
        _selectedCountryId = ecuadorCountry['id'] as int;
        _filterStatesByCountry(_selectedCountryId!);
      }

      if (mounted) setState(() => _isLoadingMasterData = false);
    } catch (e) {
      logger.e('[CreateClientOfflineDialog]', 'Error loading master data', e);
      if (mounted) {
        setState(() {
          _isLoadingMasterData = false;
          _error = 'Error cargando datos maestros: $e';
        });
      }
    }
  }

  void _filterStatesByCountry(int countryId) {
    _filteredStates =
        _states.where((s) => s['country_id'] == countryId).toList();
    _selectedStateId = null;
  }

  String _getVatLabel() => switch (_selectedIdType) {
        EcuadorVatValidator.typeCedula => 'Cedula',
        EcuadorVatValidator.typeRucNatural => 'RUC',
        EcuadorVatValidator.typePassport => 'Numero de Pasaporte',
        EcuadorVatValidator.typeForeignId => 'Numero de ID Extranjero',
        _ => 'Identificacion',
      };

  String _getVatPlaceholder() => switch (_selectedIdType) {
        EcuadorVatValidator.typeCedula => 'Ej: 1234567890',
        EcuadorVatValidator.typeRucNatural => 'Ej: 1234567890001',
        EcuadorVatValidator.typePassport => 'Ej: AB123456',
        EcuadorVatValidator.typeForeignId => 'Ej: E12345678',
        _ => 'Numero de identificacion',
      };

  Future<void> _createClient() async {
    if (_name.trim().isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }

    final name = _name.trim();
    final vat = _vat.trim().isNotEmpty
        ? EcuadorVatValidator.clean(_vat.trim())
        : null;
    final email = _email.trim().isNotEmpty ? _email.trim() : null;
    final phone = _phone.trim().isNotEmpty ? _phone.trim() : null;
    final street = _street.trim().isNotEmpty ? _street.trim() : null;
    final city = _city.trim().isNotEmpty ? _city.trim() : null;

    String? stateName, stateCode, countryName, countryCode;
    if (_selectedStateId != null) {
      final state =
          _filteredStates.where((s) => s['id'] == _selectedStateId).firstOrNull;
      stateName = state?['name'] as String?;
      stateCode = state?['code'] as String?;
    }
    if (_selectedCountryId != null) {
      final country =
          _countries.where((c) => c['id'] == _selectedCountryId).firstOrNull;
      countryName = country?['name'] as String?;
      countryCode = country?['code'] as String?;
    }

    if (vat != null) {
      final vatError = EcuadorVatValidator.getValidationError(
        vat,
        identificationType: _selectedIdType,
      );
      if (vatError != null) {
        setState(() => _error = vatError);
        return;
      }
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final collectionRepo = ref.read(collectionRepositoryProvider);

      if (collectionRepo == null) {
        setState(() {
          _isCreating = false;
          _error = 'Repositorio no disponible';
        });
        return;
      }

      if (vat != null) {
        final vatUniquenessError = await clientManager.checkVatUniqueness(vat);
        if (vatUniquenessError != null) {
          setState(() {
            _isCreating = false;
            _error = vatUniquenessError;
          });
          return;
        }
      }

      final partnerUuid = const Uuid().v4();
      final localId = await collectionRepo.createPartnerOffline(
        name: name,
        partnerUuid: partnerUuid,
        vat: vat,
        email: email,
        phone: phone,
        street: street,
        city: city,
      );

      logger.d(
        '[CreateClientOfflineDialog]',
        'Client created offline: localId=$localId, uuid=$partnerUuid',
      );

      if (mounted) {
        Navigator.of(context).pop({
          'id': localId,
          'name': name,
          'vat': vat,
          'identification_type': _selectedIdType,
          'taxpayer_type': _selectedTaxpayerType,
          'email': email,
          'phone': phone,
          'street': street,
          'city': city,
          'state_id': _selectedStateId,
          'state_name': stateName,
          'state_code': stateCode,
          'country_id': _selectedCountryId,
          'country_code': countryCode,
          'country_name': countryName,
          'partner_uuid': partnerUuid,
          'is_offline': true,
        });
      }
    } catch (e) {
      logger.e('[CreateClientOfflineDialog]', 'Error creating client', e);
      if (mounted) {
        setState(() {
          _isCreating = false;
          _error = 'Error al crear cliente: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Row(
        children: [
          Icon(FluentIcons.add_friend, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          const Text('Crear Cliente'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Offline',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
      content: _isLoadingMasterData
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProgressRing(),
                    SizedBox(height: 16),
                    Text('Cargando datos maestros...'),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(child: _buildForm(theme)),
      actions: [
        Button(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createClient,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }

  Widget _buildForm(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.info, size: 14, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El cliente se creara localmente y se sincronizara cuando haya conexion.',
                  style: theme.typography.caption?.copyWith(
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Name
        OdooTextField(
          config: const OdooFieldConfig(
            label: 'Nombre',
            isEditing: true,
            isRequired: true,
            hint: 'Nombre del cliente o razon social',
          ),
          value: _name,
          onChanged: (v) => setState(() => _name = v ?? ''),
          autofocus: true,
        ),
        const SizedBox(height: 12),

        // ID Type + VAT
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: OdooSelectionField<String>(
                config: const OdooFieldConfig(
                  label: 'Tipo de Identificacion',
                  isEditing: true,
                ),
                value: _selectedIdType,
                options: EcuadorVatValidator.getIdentificationTypes()
                    .map(
                      (type) => SelectionOption<String>(
                        value: type['code']!,
                        label: type['name']!,
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedIdType = value;
                      _error = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: OdooTextField(
                config: OdooFieldConfig(
                  label: _getVatLabel(),
                  isEditing: true,
                  hint: _getVatPlaceholder(),
                ),
                value: _vat,
                onChanged: (v) => setState(() => _vat = v ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Taxpayer Type
        OdooSelectionField<String>(
          config: const OdooFieldConfig(
            label: 'SRI Tipo de Contribuyente',
            isEditing: true,
          ),
          value: _selectedTaxpayerType,
          placeholder: 'Seleccione tipo de contribuyente',
          options: EcuadorVatValidator.getSriTaxpayerTypes()
              .map(
                (type) => SelectionOption<String>(
                  value: type['code'] as String,
                  label: '${type['code']} - ${type['name']}',
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedTaxpayerType = value),
        ),
        const SizedBox(height: 12),

        // Email + Phone
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OdooTextField(
                config: const OdooFieldConfig(
                  label: 'Email',
                  isEditing: true,
                  hint: 'correo@ejemplo.com',
                ),
                value: _email,
                onChanged: (v) => setState(() => _email = v ?? ''),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OdooTextField(
                config: const OdooFieldConfig(
                  label: 'Telefono',
                  isEditing: true,
                  hint: 'Ej: 0991234567',
                ),
                value: _phone,
                onChanged: (v) => setState(() => _phone = v ?? ''),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Street
        OdooMultilineField(
          config: const OdooFieldConfig(
            label: 'Direccion',
            isEditing: true,
            hint: 'Direccion completa',
          ),
          value: _street,
          onChanged: (v) => setState(() => _street = v ?? ''),
          minLines: 2,
          maxLines: 2,
        ),
        const SizedBox(height: 12),

        // City + State
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OdooTextField(
                config: const OdooFieldConfig(
                  label: 'Ciudad',
                  isEditing: true,
                  hint: 'Ciudad',
                ),
                value: _city,
                onChanged: (v) => setState(() => _city = v ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OdooSelectionField<int>(
                config: const OdooFieldConfig(
                  label: 'Provincia / Estado',
                  isEditing: true,
                ),
                value: _selectedStateId,
                placeholder: _filteredStates.isEmpty
                    ? 'Sin provincias disponibles'
                    : 'Seleccione provincia',
                options: _filteredStates
                    .map(
                      (state) => SelectionOption<int>(
                        value: state['id'] as int,
                        label: state['name'] as String,
                      ),
                    )
                    .toList(),
                onChanged: _filteredStates.isEmpty
                    ? null
                    : (value) => setState(() => _selectedStateId = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Country
        OdooSelectionField<int>(
          config: const OdooFieldConfig(
            label: 'Pais',
            isEditing: true,
          ),
          value: _selectedCountryId,
          placeholder: _countries.isEmpty ? 'Cargando paises...' : 'Seleccione pais',
          options: _countries
              .map(
                (country) => SelectionOption<int>(
                  value: country['id'] as int,
                  label: country['name'] as String,
                ),
              )
              .toList(),
          onChanged: _countries.isEmpty
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCountryId = value;
                      _filterStatesByCountry(value);
                    });
                  }
                },
        ),

        // Error message
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.error, size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Helper function to show create client offline dialog
///
/// Returns the created client data or null if cancelled.
Future<Map<String, dynamic>?> showCreateClientOfflineDialog(
  BuildContext context,
) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const CreateClientOfflineDialog(),
  );
}
