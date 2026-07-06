// ignore_for_file: invalid_use_of_protected_member
// El extension-on-State del plan de descomposición (Fase E2) no forma parte
// de la jerarquía de la clase para el análisis estático, así que llamar a
// `setState` (protegido en `State`) desde acá dispara ese warning aunque en
// runtime es idéntico a llamarlo desde un método de la clase. Comportamiento
// sin cambios.
part of 'user_preferences_dialog.dart';

/// Tab 'Preferencias' de [UserPreferencesDialog] — extraído de user_preferences_dialog.dart
/// como parte de la descomposición sin cambio de comportamiento (Fase E2).
extension _UserPreferencesGeneralTab on _UserPreferencesDialogState {
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
                        border: Border.all(color: AppColors.borderLight),
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
                                color: AppColors.textSecondary,
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
}
