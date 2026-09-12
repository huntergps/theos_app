# Orbi Panel · checklist de aceptación visual

Esta checklist define el umbral de calidad para la maqueta web del shell. La
referencia de acabado de `theos_pos` aporta disciplina de componentes, estados,
fallbacks y responsive; no se copian Fluent UI, servicios ni sus contratos.

## Puerta de calidad

- [ ] La primera lectura responde «qué puedo hacer ahora»: sección, estado de
  conexión, CTA del rol y trabajo pendiente; el catálogo de módulos queda después.
- [ ] La interfaz usa Material 3 y tokens de `OrbiTheme`: escala 4/8/12/16/24/32,
  radios consistentes de 12–20 px, superficies neutrales y contraste AA.
- [ ] Cada control interactivo conserva target mínimo de 48 px en touch; el modo
  pointer reduce espacio sólo si conserva legibilidad y foco visible.
- [ ] No se usan fondos, gradientes, logos o colores hardcodeados fuera de los
  tokens/recursos propios de panel; cada asset tiene fallback y no depende de POS.
- [ ] Loading, offline, pending, restored y error tienen texto/semántica además
  de color; ningún spinner infinito oculta la acción o el diagnóstico.

## Shell y navegación

- [ ] Header persistente: `OrbiBrandMark`, sección/breadcrumb, conectividad,
  pendientes, avisos y usuario; logout vive en menú de usuario.
- [ ] La ruta activa se identifica por texto, icono y contraste, no sólo por color.
- [ ] Navegación filtra exclusivamente por `RouteAccessPolicy`/capabilities; no
  presenta enlaces que el usuario no puede ejecutar.
- [ ] El orden Tab es header → navegación → contenido → acciones; no hay foco
  atrapado, salto inesperado ni remount al cambiar ancho.
- [ ] Cards de acceso son un único destino accesible: título, detalle, estado e
  icono tienen una relación clara y toda la superficie responde al tap.

## Login y formularios

- [ ] Login tiene composición propia: marca breve, contexto («Panel operativo»),
  formulario limitado a ancho de lectura, CTA dominante y ayuda secundaria.
- [ ] Campos tienen labels persistentes, hint útil, iconografía consistente,
  foco teal visible, validación accionable y claves semánticas estables.
- [ ] Contraseña/API key ofrece visibilidad, modo avanzado compacto y no expone
  secretos en preferencias, logs, mensajes o capturas de evidencia.
- [ ] Enviando conserva formulario, foco y scroll; sólo deshabilita la acción
  necesaria y comunica etapa sin bloquear teclado.
- [ ] Cambiar servidor, tema, escala o ancho conserva texto, selección, scroll y
  foco; ningún callback async reemplaza un valor que el usuario ya editó.

## 390 × 844 · smartphone

- [ ] Header en una línea; acciones secundarias pasan a menú.
- [ ] Una columna, padding lateral 16 px y campos apilados; la CTA se alcanza sin
  zoom ni scroll horizontal.
- [ ] Navegación inferior muestra 3–5 destinos prioritarios y «Más» para el resto.
- [ ] Diálogos son fullscreen o casi fullscreen; botones y campos siguen en 48 px.
- [ ] Verificar light/dark y escala de texto 1.0/2.0 sin truncar labels, errores o
  estados vacíos.

## 820 × 1180 · medium/tablet

- [ ] Rail compacto de 72–88 px con tooltip/label accesible; no invade el main.
- [ ] Header conserva título, conectividad y CTA; omite sólo labels no esenciales.
- [ ] Grid de dos columnas sólo si cada tarjeta conserva ≥280 px; nunca aparece
  una tercera columna estrecha.
- [ ] Formularios siguen apilados salvo que cada grupo conserve lectura y foco.

## 1440 × 900 · expanded/desktop

- [ ] Drawer permanente de 240–280 px y header alinean bordes y ritmos.
- [ ] Main centrado, máximo 1.440 px, con grid de 3–4 columnas sin espacio muerto
  excesivo ni scroll horizontal.
- [ ] Formularios/lista-detalle usan columnas sólo cuando la lectura mejora; la
  CTA y el estado operativo permanecen en el primer viewport.

## Motion, materiales y evidencia

- [ ] Motion sólo comunica cambio: crossfade/spring crítico, interruptible y sin
  bloquear entrada; no hay parpadeo repetido por keys o providers.
- [ ] Respeta reduced motion: transición corta por opacidad o estado estático;
  no hay parallax ni fondos animados de pantalla completa.
- [ ] Superficies translúcidas no se apilan hasta perder contraste; cards tienen
  sombra/borde suficiente sobre imagen o contenido ocupado.
- [ ] La validación web adjunta capturas de 390×844, 820×1180 y 1440×900 en
  claro/oscuro, además de teclado Tab, foco, error, offline y loading.
- [ ] Rechazar si existe overflow, CTA oculta, foco invisible, remount al resize,
  acción no autorizada, estado sólo cromático o cualquier texto truncado crítico.
