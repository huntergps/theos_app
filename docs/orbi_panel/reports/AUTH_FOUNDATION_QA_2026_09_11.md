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
- Login incorpora «Gestionar servidores»: nombre, URL y base de datos guardados
  en el dispositivo, con búsqueda, alta, edición, selección y baja confirmada.
  Escritorio muestra listado y editor juntos; formato compacto apila ambos con
  desplazamiento. Reutiliza tema y componentes Flutter existentes, sin paquetes nuevos.
- Seleccionar un acceso rellena URL/BD y limpia la contraseña anterior; sólo recupera
  el usuario recordado correspondiente al entorno seleccionado. El gestor no guarda
  contraseñas ni claves API. Eliminar un acceso no elimina datos de Odoo ni borradores.
- Se rechazan URLs inválidas/con credenciales y duplicados URL+BD. Una colección
  local dañada se informa y conserva, sin sustituirla por una lista vacía.
- Esta gestión complementa la referencia theos_pos: evita diálogos separados para
  cada edición y añade búsqueda. No importa automáticamente sus servidores ni realiza
  conexiones, pruebas de credenciales o modificaciones en Odoo al guardar un acceso.

## Verificación y límites

- Gestión de servidores: 17 pruebas automatizadas pasaron (persistencia, CRUD por
  interfaz, filtros, selección hacia login, borrado confirmado, descarte de edición,
  corrupción y disposición compacta incluyendo altura de 400 px). Análisis de los
  seis archivos de autenticación/pruebas sin incidencias.
- Build web local correcto. La comprobación real detectó y corrigió un límite de
  desplazamiento de bits de Dart Web al generar IDs; después se comprobó alta,
  selección y persistencia tras recarga con `https://orbi.invalid` y datos ficticios.
- Capturas del gestor: `evidence/2026-09-11/server-manager-desktop.png` y
  `server-manager-phone.png`. Son evidencia de implementación, no nuevas aprobaciones.

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
