// ignore_for_file: invalid_use_of_protected_member
// El extension-on-State del plan de descomposición (Fase E2) no forma parte
// de la jerarquía de la clase para el análisis estático, así que llamar a
// `setState` (protegido en `State`) desde acá dispara ese warning aunque en
// runtime es idéntico a llamarlo desde un método de la clase. Comportamiento
// sin cambios.
part of 'user_preferences_dialog.dart';

/// Tab 'Calendario' de [UserPreferencesDialog] — extraído de user_preferences_dialog.dart
/// como parte de la descomposición sin cambio de comportamiento (Fase E2).
extension _UserPreferencesCalendarTab on _UserPreferencesDialogState {
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
}
