import 'package:fluent_ui/fluent_ui.dart';

import '../../app/device_name_store.dart';

/// Nombre del equipo, editable — orden del dueño, 14-sep-2026: «sale del
/// nombre del equipo en el sistema operativo y se puede modificar». Se
/// guarda POR INSTALACIÓN (`DeviceNameStore`, `orbi/device/name`), no por
/// usuario, así que este control no depende de qué identidad haya iniciado
/// sesión — cualquiera que abra Ajustes en este mismo equipo ve y cambia el
/// mismo valor.
///
/// En su propio archivo, insertado como un solo widget en la pantalla de
/// Ajustes — mismo patrón que ya establecieron `PinEnrollmentSection` y
/// `MessageDurationsSection`.
class DeviceNameSection extends StatefulWidget {
  const DeviceNameSection({super.key, required this.controller});

  final DeviceNameController controller;

  @override
  State<DeviceNameSection> createState() => _DeviceNameSectionState();
}

class _DeviceNameSectionState extends State<DeviceNameSection> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.name);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Vacío vuelve al valor por omisión (`DeviceNameStore.write`); el campo
    // de texto se refresca con lo que de verdad quedó guardado, para que no
    // se vea vacío tras guardar "" cuando el valor real es el hostname.
    await widget.controller.setName(_text.text);
    if (mounted) _text.text = widget.controller.name;
  }

  @override
  Widget build(BuildContext context) => InfoLabel(
    label: 'Nombre del equipo',
    child: Row(
      children: [
        Expanded(
          child: TextBox(
            key: const Key('device-name-field'),
            controller: _text,
            placeholder: 'Nombre por omisión de este equipo',
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(width: 8),
        Button(
          key: const Key('device-name-save'),
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
