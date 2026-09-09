# Orbi Panel · especificación visual del shell operativo

## Propósito

Definir una maqueta web propia para `theos_panel`: clara para trabajo diario,
adaptable a ventana y entrada, y capaz de comunicar el estado de la sesión sin
ocultar las acciones autorizadas. Esta especificación describe únicamente
estructura y comportamiento visual; no cambia auth, permisos, datos ni Odoo.

## Estructura de la superficie

```text
┌─────────────────────────────────────────────────────────────┐
│ Marca · contexto actual        conexión · avisos · usuario  │ Header
├──────────────┬──────────────────────────────────────────────┤
│ navegación   │ título de sección · acciones                 │
│ autorizada   │ contenido de la ruta                          │ Main
│              │                                                │
└──────────────┴──────────────────────────────────────────────┘
```

- Header persistente: marca Orbi ERP, sección actual, estado de conexión,
  pendientes, avisos, tema y menú de usuario.
- Navegación persistente: destinos filtrados por las capabilities ya resueltas;
  nunca debe mostrar enlaces que la policy no autoriza.
- Main: ancho de lectura limitado a 1.440 px, alineado arriba y con scroll
  propio cuando el contenido excede la ventana.
- Acciones destructivas o de sesión (logout) viven en el menú de usuario, con
  confirmación sólo cuando el flujo existente lo requiera.

## Jerarquía visual

1. Estado y contexto: título, conexión y sección activa.
2. Acción primaria del rol: una CTA FilledButton claramente dominante.
3. Trabajo pendiente: tarjetas reanudables con título, detalle y acción.
4. Accesos secundarios: tarjetas agrupadas por dominio.
5. Información auxiliar: chips, timestamps, ayuda y estados vacíos.

Usar Material 3 y tokens propios: escala de 4 px, superficies diferenciadas,
bordes suaves, contraste AA, radio consistente de 12–20 px y targets mínimos de
48 px en touch. La densidad pointer puede reducir padding, nunca el foco ni la
legibilidad.

## Componentes de la maqueta

- `OrbiShellHeader`: marca, breadcrumb/sección y acciones globales.
- `OrbiConnectivityBadge`: online, sin conexión, reconectando o error.
- `OrbiPendingBadge`: número de operaciones pendientes; enlaza a sincronización.
- `OrbiNotificationButton`: avisos con badge y estado leído/no leído.
- `OrbiUserMenu`: identidad visible, preferencias y cerrar sesión.
- `OrbiAdaptiveNavigation`: drawer permanente, rail o barra inferior según ancho.
- `OrbiSectionHeader`: título, descripción y acciones de contexto.
- `OrbiActionCard`: icono, título, descripción corta y acción; toda la tarjeta
  debe ser accesible como un único destino.
- `OrbiResumeCard`: trabajo pendiente, estado y acción “Continuar”.
- `OrbiStatusChip`: estado semántico con texto, no sólo color.
- `OrbiEmptyState` / `OrbiErrorState`: explicación breve y retry cuando exista.

## Variantes por rol

Las variantes sólo cambian prioridad y orden; el filtro final sigue siendo la
policy/capability del usuario.

| Rol | CTA primaria | Primer bloque | Accesos destacados |
|---|---|---|---|
| Vendedor | Nueva venta | Ventas recientes / pendientes | Clientes, productos |
| Cajero | Abrir caja o cobrar | Cobros pendientes | Caja, ventas |
| Bodega | Ver entregas | Despachos por validar | Bodega, productos |
| Supervisor | Revisar aprobaciones | Métricas y solicitudes | Aprobaciones, ventas, caja |

Si no hay servicio conectado, mostrar estado local y trabajo guardado; no
presentar una falsa capacidad online. Si no hay trabajo pendiente, usar un
estado vacío positivo que mantenga visible la CTA principal.

## Variantes por ventana

### 390 × 844 — compact

- Header de una línea; marca reducida y acciones secundarias en menú.
- Contenido de una columna, padding lateral 16 px.
- Navegación inferior con 3–5 destinos principales; “Más” para secundarios.
- Diálogos fullscreen y campos apilados.
- Verificable: ninguna tarjeta desborda horizontalmente; CTA primaria y
  navegación inferior permanecen alcanzables sin zoom; texto no queda truncado.

### 820 × 1180 — medium

- Rail lateral compacto de 72–88 px con iconos y tooltips/labels accesibles.
- Header completo salvo labels no esenciales.
- Contenido en dos columnas cuando cada tarjeta conserva al menos 280 px.
- Paneles de detalle pueden usar modal centrado.
- Verificable: el rail no invade el contenido; título, CTA y estado online son
  visibles en el primer viewport; el grid no crea una tercera columna estrecha.

### 1440 × 900 — expanded

- Drawer permanente de 240–280 px con grupos y destino activo.
- Header muestra estado, avisos y usuario sin comprimir controles.
- Main centrado, máximo 1.440 px, con grid de 3–4 columnas según contenido.
- Formularios y tablas pueden dividirse en lista + detalle.
- Verificable: no hay espacio muerto excesivo; header y drawer alinean sus
  bordes; cuatro tarjetas no bajan de 240–280 px; contenido crítico aparece
  sin scroll horizontal.

## Estados globales verificables

- `online`: badge positivo discreto, sin bloquear acciones.
- `offline`: banner/chip persistente, explicación de cola local y enlace a sync.
- `syncing`: progreso no modal; la navegación permanece disponible.
- `pending`: contador visible sólo si es mayor que cero y el usuario tiene acceso.
- `error`: mensaje accionable, retry delimitado y sin stack trace.
- `restored/offline session`: indicar que la sesión fue restaurada localmente,
  diferenciándola de una conexión online.

## Criterios de aceptación de la maqueta

- La ruta activa se identifica por texto, icono y contraste; no depende sólo de
  color.
- Los destinos visibles coinciden con la policy de capabilities en cada rol.
- Tab/teclado recorre header → navegación → contenido en orden lógico.
- Focus ring visible y targets táctiles de 48 px.
- Las tres dimensiones anteriores no producen overflow, solapamiento ni CTA
  oculta.
- Cambiar ancho no reinicia el estado de la ruta ni reordena inesperadamente el
  foco.
- Estados offline, pendientes y error siguen siendo legibles en light/dark.
- El shell comunica “qué puedo hacer ahora” antes de “qué módulos existen”.
