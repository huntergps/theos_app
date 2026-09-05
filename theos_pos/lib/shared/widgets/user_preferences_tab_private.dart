// ignore_for_file: invalid_use_of_protected_member
// El extension-on-State del plan de descomposición (Fase E2) no forma parte
// de la jerarquía de la clase para el análisis estático, así que llamar a
// `setState` (protegido en `State`) desde acá dispara ese warning aunque en
// runtime es idéntico a llamarlo desde un método de la clase. Comportamiento
// sin cambios.
part of 'user_preferences_dialog.dart';

/// Tab 'Privado' de [UserPreferencesDialog] — extraído de user_preferences_dialog.dart
/// como parte de la descomposición sin cambio de comportamiento (Fase E2).
extension _UserPreferencesPrivateTab on _UserPreferencesDialogState {
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
                                      final states =
                                          await ref
                                              .read(userRepositoryProvider)
                                              ?.getStatesByCountry(value) ??
                                          const <Map<String, dynamic>>[];
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
}
