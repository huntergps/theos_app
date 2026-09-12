# Traspaso al siguiente coordinador — Orbi

El dueño pidió detener este trabajo y dejarlo preparado para otro coordinador con
agentes económicos. No hay autorización para declarar el proyecto terminado.

## Prompt para iniciar

Actúa como coordinador de Orbi ERP en `/Users/elmers/Documents/develop/2026/theos_app`.
Continúa desde este documento, no desde cero. Aplica `docs/orbi_panel/AGENTS.md`
expresamente a tus encargos de implementación, además de los AGENTS de cada ruta.
Reparte en agentes `sonnet` lo que se produce con criterio medio sobre terreno ya
fijado, y en `haiku` lo que se comprueba sin criterio: contar, cotejar, correr un
comando y traer la salida. Nunca `haiku` para juzgar. Sin subdelegación. Cierra cada
agente en cuanto entregue. Tú resuelves arquitectura, permisos, contratos y revisión
final. No crees múltiples paquetes: componentes compartidos por carpetas.
El tope de agentes vivos a la vez lo fija `AGENTS.md`, que es la autoridad en esto.

Primero identifica estado del worktree y revisa `tasks.json` completo, no sólo
`python3 scripts/check_orbi_plan.py --ready` (comando en una sola línea). **Ese
comando devuelve vacío hoy y seguirá vacío**: sólo lista tareas en `todo` con
prerrequisitos cumplidos, y las cuatro tareas vivas están en `in_progress`, que
nunca muestra. La única en `todo` alcanzable, `V01`, está bloqueada tras `B01`.
Vacío ahí NO significa que no haya trabajo. Contrasta tasks.json con código y
evidencia; no confíes en etiquetas done como prueba de calidad. No continúes todos los ámbitos
a la vez: prioridad actual del usuario es coherencia de splash, login y shell con
las imágenes aprobadas. Luego avanza pantallas operativas con pruebas reales y
revisiones parciales visibles, sin esperar a terminar todo para mostrarlas.

## Estado verificable al detener

- Último commit de implementación: `f0eb14c`, gestión de servidores en login.
- Anteriores: `b45483e` pie translúcido; `eee3f3f` fondo uniforme/icono de tema;
  `88a5947` propuesta de fondo lago; `1f1e7b8` base splash/login/shell.
- No hay agentes de este encargo trabajando: server_book y server_manager_ui
  finalizaron, draft_discovery está interrumpido. No reanudar sus tareas antiguas
  sin nuevo encargo concreto. Sus reportes iniciales no sustituyen revisión del
  coordinador: este corrigió y ejecutó las pruebas que el agente UI no completó.
- Se detuvieron los servidores de previsualización creados aquí: 8769 y 8768.
  Se detectaron otros `flutter run` ajenos/no atribuidos (incluido 8787); no se
  finalizaron para no interferir con trabajo de otros. Inspecciona propietario
  antes de detener o reutilizar procesos. No hay build/test propio activo.

## Lo recién implementado

- Fondo de lago/montañas aprobado: `assets/images/orbi_lake_sunrise.png`.
  `OrbiAuthBackdrop` comparte imagen y capa blanca fija `0x52FFFFFF` para todos
  los tamaños y temas. Nunca oscurecer la foto sólo porque cambia el breakpoint.
- Login horizontal: marca izquierda y formulario derecha. Vertical/teléfono:
  formulario centrado. Tema mediante icono sol/luna, no interruptor.
- Pie: «Desarrollado por GalapagosTech · 2026», superficie alpha .72 y
  `extendBody: true`: foto continúa por detrás, sin corte opaco.
- «Gestionar servidores» sobre el campo servidor: lista con búsqueda + editor;
  creación/edición/uso/borrado confirmado, confirmación de descarte desde acciones
  del diálogo. Compacto apilado con scroll. Guarda sólo nombre, URL, BD e ID en
  SharedPreferences `orbi/login/servers/v1`; no credenciales ni servidores reales
  precargados. No importa automáticamente configuración de theos_pos.
- Elegir servidor rellena URL/BD, limpia contraseña y recupera únicamente el
  usuario recordado de ese entorno. URLs inválidas/duplicadas se rechazan; datos
  locales corruptos se conservan y se informa error, sin reset silencioso.
- Se corrigió bug exclusivo Web: `Random().nextInt(1 << 32)` compilaba a límite
  cero; ahora usa `1 << 30`. No reintroducirlo copiando versiones del agente.

## Pruebas y evidencia

SDK: `/Users/elmers/Documents/develop/dev_flutter/flutter/bin/flutter`.
Desde `theos_panel`:

```bash
flutter test --no-pub test/features/auth/server_manager_dialog_test.dart test/features/auth/saved_servers_test.dart test/features/auth/login_screen_test.dart
```

17 pruebas pasaron: CRUD UI, filtros, retorno al login y limpieza del secreto,
descarte, datos corruptos, persistencia y tamaños compactos (incluida altura400).
Análisis de seis archivos auth/tests sin incidencias antes del último ajuste menor
del límite Random y ampliación de pruebas. Build Web final correcto; aviso previo
de fuente CupertinoIcons ausente sigue presente, no se ocultó ni se corrigió.

Navegador real: alta ficticia `Demostración local`, URL `https://orbi.invalid`, BD
`local_workflow`, selección y persistencia tras recarga verificadas. El acceso
ficticio queda guardado en ese navegador. No se accedió a Odoo real ni a ERP2.
Capturas válidas en `reports/evidence/2026-09-11/server-manager-desktop.png` y
`server-manager-phone.png`. El teléfono quedó bien tras recarga; cambio de viewport
sin recargar puede producir escala/captura incorrecta en el navegador de pruebas.
No presentar esas capturas defectuosas como fallos/resoluciones confirmados de UI.

Otras capturas antiguas sin seguimiento pueden mostrar versiones previas o márgenes
blancos: no son nuevas aprobaciones. Lee `reports/AUTH_FOUNDATION_QA_2026_09_11.md`.

## Reanudar vista local

```bash
cd /Users/elmers/Documents/develop/2026/theos_app/theos_panel
/Users/elmers/Documents/develop/dev_flutter/flutter/bin/flutter build web --no-pub --no-wasm-dry-run --target dev/local_workflows.dart --output build/local_workflows_shell
cd /Users/elmers/Documents/develop/2026/theos_app
python3 -m http.server 8769 --bind 127.0.0.1 --directory theos_panel/build/local_workflows_shell
```

Abrir `http://127.0.0.1:8769/#/login`. Fixtures de desarrollo: servidor
`https://orbi.invalid`, BD `local_workflow`, usuario `demo`, clave ficticia
`orbi-demo`. No son credenciales reales. Runtime/Drift reales con autenticación
local ficticia no demuestran integración financiera ni seguridad de Odoo real.

## Trabajo sin commit: preservar e inspeccionar

Modificados:
- `orbi_runtime/lib/src/envases/envases_dashboard_cache.dart`
- `orbi_runtime/lib/src/read/runtime_order_reader.dart`
- `orbi_runtime/test/envases/envases_dashboard_cache_test.dart`
- `theos_panel/lib/features/sales/sale_editor.dart`
- `theos_panel/lib/features/sales/sale_lines_editor.dart`
- `theos_panel/test/features/sales/sale_lines_editor_test.dart`

Nuevos relevantes: `orbi_runtime/lib/src/envases/envases_location_reader.dart`,
su test homónimo, `orbi_runtime/test/read/runtime_order_reader_test.dart`,
`theos_panel/lib/ui/components/fields/orbi_inline_catalog_picker.dart`.
También hay galerías/previews/tests/scripts sin seguimiento en theos_panel/dev,
test/dev y tool; documentos `RESPUESTA_ODOO_ENVASES.md` y
`design/VISUAL_ACCEPTANCE.md`, y capturas antiguas. Ejecuta git status para inventario
exacto. No borrarlos, restaurarlos ni agregarlos todos a un commit automáticamente.
Cambios de negocio estaban pausados para atender prioridad de login/shell.

## Orden sugerido y división económica

1. Coordinador: revisar esta entrega y coherencia con aprobados; definir archivos
   propietarios. No afirmar que shell o todas las pantallas ya coinciden.
2. Agente A: regresiones login/gestor (back/Escape con edición, errores persistencia,
   teclado móvil y accesibilidad), máximo cinco archivos y pruebas específicas.
3. Agente B: shell según `UI_COHERENCE_RULES.md`, `SHELL_AND_INTERACTION_SPEC.md` y
   `NAVIGATION_CAPABILITY_MATRIX.md`; tareas disjuntas de login, sin lógica financiera.
4. Agente C: auditoría de correspondencia de pantallas aprobadas vs implementadas,
   sólo índice/reporte con gaps verificables; no generar otra ronda masiva de imágenes.
   Asi para mas tareas.
5. Coordinador integra/revisa capturas en desktop, iPad horizontal, iPad vertical
   y teléfono; muestra avances. Después asigna ventas/caja/envases en bloques
   independientes según contratos, sin inventar campos o acciones backend.

## Reglas funcionales que no deben perderse

- Odoo19.5 es autoridad; Orbi es capa offline-first. Ventas usa flujos existentes,
  no sustituir por pos.order ni inventar seller_user_id. Consultar fuentes reales.
- Usuarios multirrol ven capacidades conjuntas; modo PIN limita a vendedor aunque
  tenga otros roles. Cajeros/supervisores/admin/bodega acceden con credenciales.
- Rejillas Syncfusion desktop/tablet horizontal; listas/formularios vertical/móvil.
  Búsqueda de producto INLINE dentro de rejilla, no buscador externo de reemplazo.
- Componentes reactivos al núcleo offline; acceso a tablas/campos mediante contratos,
  imágenes producto/cliente editables sólo con permisos. No paquetes innecesarios.
- Envases distinto de contenido y de inventario comercial; múltiples productos y
  cantidades, propiedad empresa, sin sesión de caja obligatoria. Backend entregado
  en `/Users/elmers/Documents/dev_odoo20/addons/l10n_ec_stock_envases` por otro agente.
- Última corrección de envases: una ubicación de custodia clientes/proveedores por
  bodega, SIN tercero en ubicación; tercero en documento/transferencia. Saldo por
  tercero sale del modelo backend de entregas menos devoluciones hechas, no de quants
  filtrados por cliente. Total agregado sigue de existencias. Confirmar nombres
  técnicos leyendo código y `RESPUESTA_ODOO_ENVASES.md`, no asumirlos.
- Caja debe replicar procesos reales de `l10n_ec_collection_box/wizards/
  sale_order_payment_wizard.py`, XML asociado y `l10n_ec_collection_panel/static/src/panel`.
- IA/impresión/WhatsApp/Telegram sólo según módulos instalados y permisos Odoo;
  personalización propia Orbi tiene prioridad, si no existe hereda la de Odoo.
- Pie técnico: servidor, BD, hora servidor (desactualizada/ausente explícita), red
  y sincronización diferenciadas. No hacer pasar hora del equipo por servidor.
- ERP2 admite pruebas y escrituras sin autorización caso por caso; producción
  (`newerp`) sigue excluida sin excepción. Sin simuladores ni cambios backend
  implícitos. No modificar aprobados ni marcar pantallas aprobadas por el usuario
  sólo por pasar tests.

## Referencias de lectura dirigida

`APPROVAL_REGISTER.md`, `APPROVED_SCREEN_INDEX.md`, `visual_baselines/approved/round-02/`,
`SPEC.md`, `UI_COHERENCE_RULES.md`, `REACTIVE_COMPONENTS_SPEC.md`,
`COMPONENT_INTERFACE_CONTRACTS.md`, `OPERATION_INTERACTION_OFFLINE_MATRIX.md`,
`ODOO_OFFLINE_CONTRACT_MATRIX.md`, `ENVASES_DOMAIN_CONTRACT.md`, `CONTRACTS.md`,
`ENVASES_BACKEND_HANDOFF_REVIEW.md`. Leer sólo lo aplicable a cada subtarea.

No tomar este traspaso como autorización para lanzar trabajo mientras el dueño
mantenga la pausa. El nuevo coordinador debe recibir el encargo de continuar.
