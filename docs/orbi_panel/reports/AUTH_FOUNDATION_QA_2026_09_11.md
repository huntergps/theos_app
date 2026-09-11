# Revisión splash, login y shell

Ámbito: base visual local; no ERP2, sin simuladores ni cambios backend.

## Cambios

- Fondo lago aprobado aplicado mediante un único componente compartido.
- Eliminadas las diferencias de iluminación por breakpoint y tema.
- Corregida superposición marca/formulario en escritorio.
- iPad 1024×1366 utiliza composición vertical, no dos columnas.
- Tema desde icono, persistido con preferencias existentes; no sobrescribe
  personalización explícita de otro usuario.
- Pie de autoría en login, pie técnico del shell ocupa el ancho disponible.
- Runner local muestra splash y transición existentes antes del login.

## Verificación y límites

- Tests de login, splash, shell y preferencias cubren foco, persistencia,
  cambio de tema y viewports 390×844, 820×1180, 1024×1366, 1180×820, 1440×900.
- Navegador: fondo visible, cambio oscuro→claro y persistencia tras recarga
  comprobados. Autenticación local utiliza fixtures, no acredita Odoo real.
- Se detectó y corrigió omisión inicial del asset en pubspec; no era fallo
  del servidor ni del motor de imágenes.
- Algunas capturas con override horizontal presentaron un margen blanco por
  discrepancia de escala del navegador: no se consideran evidencia aprobatoria.
- No declarar equivalencia visual completa de todas las pantallas: esta entrega
  está limitada al acceso/base. Las pantallas de negocio conservan pendientes.
