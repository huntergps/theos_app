/// Utilidades de traduccion para actividades de Odoo
library;

/// Traduce el tipo de actividad de Odoo al espanol
String translateActivityType(String activityType) {
  const translations = {
    'email': 'Correo electronico',
    'mail': 'Correo',
    'call': 'Llamada',
    'phone': 'Telefono',
    'meeting': 'Reunion',
    'todo': 'Tarea',
    'to-do': 'Tarea',
    'to do': 'Tarea',
    'task': 'Tarea',
    'note': 'Nota',
    'upload': 'Subir archivo',
    'download': 'Descargar archivo',
    'reminder': 'Recordatorio',
    'deadline': 'Fecha limite',
    'follow up': 'Seguimiento',
    'followup': 'Seguimiento',
    'session open over 7': 'Sesion abierta mas de 7 dias',
    'session open over 7 days': 'Sesion abierta mas de 7 dias',
  };

  final normalized = activityType
      .toLowerCase()
      .trim()
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  if (translations.containsKey(normalized)) {
    return translations[normalized]!;
  }

  final withDash = normalized.replaceAll(' ', '-');
  if (translations.containsKey(withDash)) {
    return translations[withDash]!;
  }

  for (final entry in translations.entries) {
    final keyNormalized = entry.key
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.contains(keyNormalized) ||
        keyNormalized.contains(normalized)) {
      return entry.value;
    }
  }

  if (normalized.contains('todo') || normalized.contains('to do')) {
    return 'Tarea';
  }

  return activityType.capitalize();
}

/// Traduce el nombre del modelo de Odoo al espanol
String translateModelName(String modelName) {
  const translations = {
    'account': 'Cuenta',
    'move': 'Movimiento',
    'invoice': 'Factura',
    'payment': 'Pago',
    'sale': 'Venta',
    'order': 'Pedido',
    'purchase': 'Compra',
    'stock': 'Inventario',
    'picking': 'Recogida',
    'product': 'Producto',
    'partner': 'Contacto',
    'customer': 'Cliente',
    'vendor': 'Proveedor',
    'lead': 'Prospecto',
    'opportunity': 'Oportunidad',
    'project': 'Proyecto',
    'task': 'Tarea',
    'meeting': 'Reunion',
    'call': 'Llamada',
    'email': 'Correo',
    'message': 'Mensaje',
    'note': 'Nota',
    'contract': 'Contrato',
    'subscription': 'Suscripcion',
    'ticket': 'Ticket',
    'helpdesk': 'Mesa de ayuda',
    'hr': 'RRHH',
    'employee': 'Empleado',
    'attendance': 'Asistencia',
    'leave': 'Permiso',
    'expense': 'Gasto',
    'timesheet': 'Hoja de horas',
    'production': 'Produccion',
    'manufacturing': 'Fabricacion',
    'quality': 'Calidad',
    'maintenance': 'Mantenimiento',
    'mrp': 'Produccion',
    'bom': 'Lista de materiales',
    'pos': 'Punto de Venta',
    'session': 'Sesion',
  };

  if (modelName.contains('.')) {
    final parts = modelName.split('.');
    final translatedParts = parts.map((part) {
      return translations[part.toLowerCase()] ?? part.capitalize();
    }).toList();
    return translatedParts.join(' / ');
  }

  return translations[modelName.toLowerCase()] ?? modelName.capitalize();
}

/// Extension para capitalizar strings
extension StringCapitalizeExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
