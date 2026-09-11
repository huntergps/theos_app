# Estructura operativa integrada

Referencia: `approved/round-03/SHELL-01.png`; reglas `UI_COHERENCE_RULES.md`.
Fecha: 2026-09-11. Estado: avance funcional/visual, no aprobación de paridad.

- `OperationalShell` envuelve rutas autenticadas reales mediante `ShellRoute`.
  Login permanece fuera. Menú filtrado por el mismo control de rutas existente.
- Sidebar desktop, Drawer tablet/teléfono, marca común, salida de sesión,
  pie persistente horizontal y detalle compacto en vertical/teléfono.
- Servidor/BD/login/ID de empresa proceden del perfil activo. No se inventan
  nombre de empresa, hora remota, estado de red ni contadores sincronizados.
- Inicio ya no duplica navegación/logout; conserva reanudación y permisos.
- Navegador local: login digitado en cada campo, navegación lateral hacia
  Envases y consulta de caché agregada comprobados. Sin errores en consola.
  Evidencia: `evidence/2026-09-11/envases-shell-desktop.png`.
- Pruebas iniciales: 11 tests de router/Home/shell pasaron; luego shell se
  amplió a 5 tests incluyendo los cuatro tamaños, Drawer, contexto y contraste.
- Compilación web local correcta; aviso de fuente CupertinoIcons preexistente.
  El contraste del logo y semántica lateral se corrigieron tras la captura;
  requieren recompilar y nueva verificación de navegador.

Pendiente: completar contenido/jerarquía de pantallas contra aprobaciones,
contexto empresa/ubicación y estados reales desde contratos disponibles,
verificar semántica sidebar con rutas anidadas en navegador y obtener capturas
finales en cuatro tamaños. El contenido aún no acredita calidad visual final.
No se modificó ERP2 ni backend. Esta entrega no es E2E financiero.
