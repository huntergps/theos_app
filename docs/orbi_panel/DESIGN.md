# Diseño de Orbi ERP

## Identidad y lenguaje

Conservar logo y nombre Orbi ERP. Recursos de referencia:
`theos_pos/assets/images/logo.svg`, `logo_nombre.svg`, `nombre.svg` y sus PNG.
Copiar recursos a assets propios de la nueva app con atribución/origen documentado;
no depender de rutas de assets de otra app ni descargar fuentes al arrancar.

Usar tema central Material oficial y tokens semánticos. Acento de Odoo como valor
por defecto con override del usuario por servidor/empresa. Superficies neutrales,
texto y estados de contraste apropiado; no teñir todos los fondos con el acento.
Las cifras/estados se entienden sin color. El producto es para público general.

Espaciados iniciales: 4/8/12/16/24/32. Tipografía por roles Material, texto de
trabajo normalmente 14–16 dp según densidad, títulos y totales jerarquizados.
No imponer tamaño fijo contra la escala del usuario. Objetivos táctiles de 48 dp
como base; modo compacto de escritorio explícito con foco/teclado conservados.
Las cifras monetarias mantienen precisión, alineación y formato de moneda.

## Adaptación

Medir constraints del área de trabajo, no modelo de dispositivo ni orientación.
Puntos iniciales orientativos: compacto <600 dp, medio 600–839, amplio >=840.
La cantidad real de paneles depende también de sus mínimos y la escala de texto.

| Región | Compacto | Medio | Amplio |
| --- | --- | --- | --- |
| Navegación | Barra inferior con destinos prioritarios y Más | Rail etiquetado | Lateral expandible |
| Órdenes | Lista → detalle | Lista y detalle si caben | Tabla/lista + detalle |
| Venta | Catálogo/pedido por pestaña, total y acción visibles | Dos áreas cuando sean legibles | Catálogo + pedido/resumen |
| Cobro | Documento → medios → resumen en continuidad | Panel de medios y resumen | Pendientes + detalle de cobro |
| Notificaciones | Página completa | Panel lateral o página | Bandeja lateral con acceso al detalle |
| Formularios | Una columna | Grupos de campos | Ancho máximo y columnas justificadas |

Safe areas y teclado forman parte de constraints; respetar estado de iPad sin
franjas arbitrarias. Conservar selección, scroll, foco y edición al redimensionar.
Acciones por teclado son aceleradores; también existen controles táctiles visibles.
No elegir layout «web» por plataforma: un navegador puede ser estrecho.

## Pantallas y acciones

| Pantalla | Contenido y acción principal | Estados que debe representar |
| --- | --- | --- |
| Acceso | Servidor, usuario recordado por servidor, contraseña o alternativa admitida; marca/fondo cacheado | Inicial, enviando, fallo, restore, offline aprovisionado |
| Inicio por rol | Retomar trabajo, ventas/pendientes y actividad útil | Sin turno, sin datos, con trabajo pendiente |
| Órdenes | Búsqueda, Mis ventas removible, estados comerciales y fiscales | Pendiente aprobar/facturar/cobrar, local y sincronizado |
| Mostrador | Selección rápida, cliente, líneas y pago permitido | Aprobación, stock, precio y sesión según capacidades |
| Consultiva | Cliente, condiciones, líneas, seguimiento y documentos | Edición, bloqueado, pendiente, confirmado |
| Caja | Punto, sesión propia, pendientes, medios y comprobante | Apertura, activa, diferencias, cierre pendiente/completo |
| Clientes/productos | Búsqueda local, detalle y edición autorizada | Carga inicial diferenciada de lista vacía/error |
| Aprobaciones | Solicitud, motivo, entidad, aprobar/rechazar autorizado | Pendiente, resuelta, caducada/conflictiva según contrato |
| Actividades | Pendientes personales, fecha y entidad | Vencida, próxima, completada |
| Documentos | Factura/recibo/reporte y estado fiscal | Local emitido, pendiente SRI, autorizado, rechazado |
| Sincronización | Estado único, pendientes, detalle de errores, reintento | Sin red/Odoo, auth requerida, parcial, conflicto, éxito |
| Notificaciones | No leídas, filtros, abrir objetivo, preferencias | Vacía, persistida, leída, archivada, objetivo inaccesible |
| Configuración | Tema, acento, densidad, accesibilidad, notificaciones, Modo Ruta | Preferencia local frente a política de empresa |

Casos como anticipos, retenciones, notas de crédito y salidas usan superficies
especializadas dentro de Caja; no ocultarlos definitivamente bajo «Más» si son
frecuentes para el rol. No mostrar acciones sin explicación cuando estén bloqueadas.

## Componentes iniciales

- `OrbiScaffold`, navegación y encabezado adaptable.
- `OrbiSearchField` y `EntityPicker`: consultar local, debounce y paginación.
- `OrbiMoneyField`, `OrbiQuantityField`, campos de fecha/selección/texto.
- `OrderStatus`, `SyncStatus`, `FiscalStatus`: etiquetas diferenciadas.
- `OrderSummary`, `PaymentMethodEditor`, `PrimaryActionBar`.
- `AsyncContent`: vacío/error/datos/carga parcial explícitos, sin spinner eterno.
- `NotificationRow`, `NotificationBadge`, panel de detalles y preferencias.

Evitar envolver todos los widgets Material por costumbre. Abstraer componentes
que expresen comportamiento repetido del producto. Mantener localización en
español inicial mediante ARB, textos extensibles a otros idiomas, fechas/monedas
del contexto y nombres largos. Nunca encoger automáticamente un error para que quepa.

## Catálogo de revisión

Una galería Widgetbook o harness equivalente debe mostrar componentes y estados
con datos ficticios: nombres largos, importes grandes, 0 resultados, error,
espera de aprobación y offline. Tres tamaños base y claro/oscuro; escala de texto
1.0 y 2.0 en los componentes esenciales. Galería accesible sin ERP2 ni credenciales.

La skill `flutter-design` orienta tokens y reutilización del tema; sus ejemplos
históricos de imports no sustituyen la API real de `material_ui` elegida.
`flutter-adaptive-ui` orienta constraints y entradas; `accessibility` verifica
calidad general y `apple-design` solo interacciones donde aporte consistencia.
No exigir todos los skills a todos los agentes: ver AGENTS.md.
