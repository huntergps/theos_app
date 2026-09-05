# Plan técnico: Theos App — versión productiva de venta y caja

> **Política vigente:** desarrollo nuevo, nunca desplegado en producción.
> Cada instalación crea el esquema Drift vigente y scopes aislados por
> servidor/base/usuario. Flutter global: 3.47.1; Dart: 3.13.1.

## Estado

- Especificación base: `docs/specs/PROJECT_COMPLETION_V1.md`
- Fase: F3, F4, F5 y F7 completadas; en F8 están cerradas la regresión,
  seguridad, builds locales y el E2E nativo read-only. CI Windows y los E2E
  controlados de escritura/Odoo 20 siguen pendientes; F9 permanece pendiente
- Alcance: Odoo 19.x/20.x; iPad, Android, macOS, Windows y web

## Resultado esperado

El trabajo se entregará como dos verticales funcionales, sostenidos por una
infraestructura común:

```text
                 Sesión + capacidades Odoo
                           │
              Catálogo local + sincronización
                           │
            ┌──────────────┴──────────────┐
            ▼                             ▼
      Vendedor vende                Cajero cobra
      y confirma orden              y crea factura
            │                             │
            └──────────────┬──────────────┘
                           ▼
             Cola idempotente + auditoría
                           │
                           ▼
              PDF / impresión / cierre caja
```

No se hará primero una reescritura general. Cada consolidación arquitectónica
deberá desbloquear o proteger uno de esos recorridos.

## Decisiones implementadas que condicionan el cierre

1. La regresión conjunta posterior a F3–F7 está cerrada localmente en F8 con
   3615 pruebas aprobadas, 14 omitidas y los cinco analyzers limpios. Los
   builds locales cubren Android, iOS sin firma, macOS y Web; Windows conserva
   su gate externo.
2. Los recorridos E2E directos de escritura y la matriz Odoo 19/20 continúan
   pendientes y no se dan por cubiertos mediante mocks ni lecturas parciales.
3. `action_apply_and_create_invoice` es el flujo canónico de cobro/factura del
   backend de referencia y se consume mediante contrato JSON-2 tipado.
4. El SDK y los call sites críticos separan `ids`, `kwargs` y `context` para
   métodos de recordset.
5. La cola representa operaciones internas como comandos locales tipados y
   versionados; solo sus handlers las traducen a llamadas Odoo.
6. Menú, accesos rápidos y router comparten una política de rutas y permisos
   default-deny.
7. Estos tres documentos son la fuente viva de alcance y estado; los informes
   históricos no sustituyen la regresión de F8.
8. `DatabaseHelper` y los managers quedan limitados a la instalación y sesión
   actuales, con teardown ordenado en logout, expiración, cambio de servidor y
   cambio de usuario.
9. Login online, login offline y restauración usan el mismo binding de managers
   después de activar Drift: cliente Bearer cuando está disponible, base y cola
   siempre pertenecen al scope actual.
10. La app no mantiene WebSocket. La convergencia remota se obtiene por health
    checks, recuperación y polling HTTP queue-first; Drift propaga los cambios
    ya confirmados a listas, contadores y formularios.

## Dependencias entre fases

```text
F0 Baseline y automatización
 ├──► F1 Contrato Odoo 19/20
 │      ├──► F3 Venta
 │      │      └──► F4 Cobro y facturación
 │      │              └──► F5 Offline e idempotencia
 │      └──► F2 Sesión, permisos y aislamiento
 │                    └────► F4
 └──► F6 Harness adaptativo iPad-first
          └── se aplica continuamente a F2, F3 y F4

F3 + F4 + F5 + F6
 └──► F7 Documentos, impresión y cierre
        └──► F8 Matriz E2E y releases
              └──► F9 Piloto y cierre
```

## F0 — Baseline reproducible y gobierno del monorepo

### Objetivo

Hacer que cualquier cambio posterior tenga una señal confiable de éxito o
regresión en los cinco paquetes.

### Trabajo

- Crear comandos raíz explícitos para dependencias, generación, análisis,
  pruebas y builds, sin introducir un framework de workspace innecesario.
- Ampliar CI para analizar y probar `odoo_sdk`, `theos_pos_core`,
  `odoo_widgets`, `flutter_qweb` y `theos_pos`.
- Añadir jobs de build en macOS, Windows y Linux; iOS se construye sin firma,
  Android como App Bundle y web como release.
- Sustituir el README de plantilla por instalación, arquitectura, versiones
  soportadas y comandos reales.
- Marcar los informes históricos como archivados y señalar la especificación y
  CI como fuentes actuales de verdad.
- Ejecutar un escaneo de secretos sobre archivos versionados y artefactos CI.

### Verificación C0

- Todos los analyzers y suites existentes pasan desde un clon limpio.
- CI ejecuta los cinco paquetes.
- El repositorio no contiene rutas locales obligatorias ni secretos.

## F1 — Contrato JSON-2 y capacidades Odoo 19/20

### Objetivo

Probar primero el borde real de Odoo para no seguir corrigiendo comportamientos
contra mocks que aceptan llamadas inválidas.

### Trabajo

- Introducir/terminar el contrato `OdooTransport` sobre el cliente JSON-2
  existente, manteniendo `OdooClient` como fachada pública.
- Separar explícitamente IDs de recordset, kwargs y context; retirar `args`
  salvo el endpoint custom documentado que realmente lo consume.
- Agregar pruebas de contrato HTTP para `search_read`, `create`, `write`,
  `unlink`, métodos de modelo y métodos de recordset.
- Extender `OdooVersion` para reconocer 19.x y 20.x sin asumir que toda versión
  posterior comparte campos.
- Crear `OdooCapabilities`, cargado al iniciar sesión mediante versión y
  comprobaciones controladas de modelos/campos.
- Definir capacidades del flujo crítico: bancos, UoM, stock, módulos custom,
  caja, wizard de cobro, facturación, reportes y sincronización HTTP.
- Normalizar errores de acceso, validación, desconexión, método/campo ausente y
  sesión expirada.
- Crear un arnés de integración que lea configuración `ODOO19_*`/`ODOO20_*`
  exclusivamente del entorno y sanee logs.
- Usar primero el Odoo local de `dev_odoo20`; `erp2` permanece read-only para
  descubrimiento hasta autorizar escrituras.

### Verificación C1

- Smoke tests read-only pasan contra entornos 19.x y 20.x disponibles.
- Las firmas de los métodos de recordset fallan en test si `ids` vuelve a
  colocarse incorrectamente en kwargs.
- La app muestra versión y capacidades detectadas sin exponer credenciales.

## F2 — Sesión, permisos y aislamiento por servidor

### Objetivo

Garantizar que cada usuario entra al servidor/base correctos y solamente puede
ver y ejecutar lo autorizado.

### Trabajo

- Convertir el router global en configuración observable por Riverpod o añadir
  redirects/guards equivalentes con estado de sesión y permisos.
- Proteger rutas además de filtrar el menú; las rutas desconocidas dejan de ser
  accesibles por defecto.
- Validar grupos de vendedor, cajero, supervisor y administrador desde Odoo.
- Unificar el ciclo de vida de `OdooClient`, managers, health checks,
  orquestador HTTP, repositorios y Drift en login, restauración, logout,
  expiración y cambio de servidor/usuario.
- Reemplazar credenciales sensibles persistidas de forma insegura por el
  mecanismo seguro adecuado a cada plataforma.
- Probar aislamiento entre dos servidores/bases y ausencia de estado residual
  al cambiar de usuario.

### Verificación C2

- Login, restauración, expiración y logout pasan en 19/20.
- Un usuario sin grupo no puede abrir por URL una pantalla restringida.
- Cambiar de servidor no mezcla usuario, catálogo, órdenes ni cola.

## F3 — Vertical de vendedor

**Estado:** completada funcionalmente; regresión global local cerrada en F8.

### Objetivo

Cerrar el recorrido desde catálogo hasta orden confirmada, online y offline.

### Trabajo

- Validar sincronización de clientes, productos, categorías, UoM, impuestos,
  listas de precios, bodegas y stock contra capacidades 19/20.
- Consolidar la lectura/escritura crítica detrás de managers/repositorios; las
  pantallas no llamarán a `OdooService` directamente.
- Probar creación de cliente con validación ecuatoriana y reconciliación del ID
  temporal al recibir el ID Odoo.
- Probar creación/edición de orden, líneas de producto, secciones, notas,
  unidades, impuestos, precios y descuentos.
- Asegurar que el cálculo local coincide con Odoo dentro de la precisión de
  moneda e impuestos configurada.
- Completar confirmación al contado, venta a crédito y solicitud de aprobación.
- Proteger cambios concurrentes de Fast Sale, formulario, sync HTTP y streams
  Drift.
- Aplicar desde esta fase los tamaños y patrones táctiles de iPad.

### Verificación C3

- Vendedor crea y confirma una venta online.
- Vendedor crea una venta offline y se sincroniza una vez al reconectar.
- Totales, cliente, líneas, impuestos y estado coinciden local/remoto.
- Crédito excedido no se confirma sin el flujo de aprobación.

La implementación terminada comparte el mismo scope de identidad entre lista,
contadores y filtros; pagina y busca sin ocultar los registros sincronizados;
persiste encabezado y líneas editables; y usa UUID estable para reconciliar la
creación online/offline sin duplicados. Fast Sale y el formulario conservan su
estado sucio y no pisan cambios locales durante actualizaciones concurrentes.

## F4 — Vertical de cajero: sesión, cobro y facturación

**Estado:** completada funcionalmente; regresión global local cerrada en F8.

### Objetivo

Cerrar el recorrido financiero usando el método real del backend y sin estados
parciales invisibles.

### Trabajo

- Validar apertura, pausa/reanudación, control de cierre y cierre de
  `collection.session` con sus métodos de recordset reales.
- Definir DTOs tipados para líneas de pago: efectivo, tarjeta, transferencia,
  cheque, nota de crédito, anticipo y retención cuando la capacidad exista.
- Corregir todos los call sites del wizard para usar `ids` de recordset.
- Usar como flujo canónico del contado:
  `create wizard → action_apply_and_create_invoice → account.move`.
- Manejar acciones intermedias devueltas por Odoo, como confirmación de
  sobrepago/anticipo o aprobación de crédito, sin tratarlas como éxito final.
- Verificar que la factura queda publicada, conciliada, vinculada a la orden y
  asignada a la sesión correcta.
- Completar la venta a crédito mediante su flujo permitido, sin inventar pagos.
- Sincronizar encabezado y líneas de factura para visualización/reporte.
- Implementar el TODO de marcar anticipos como usados cuando forme parte del
  cobro realizado.

### Verificación C4

- Cajero abre sesión, cobra una orden y obtiene factura publicada.
- Cobros mixtos y vuelto de efectivo respetan las reglas del backend.
- Pago insuficiente no factura; sobrepago no efectivo abre confirmación.
- Cierre de caja coincide con las operaciones de la sesión.

Este checkpoint se ejecuta primero en una base controlada. Cualquier escritura
en `erp2` requiere aprobación explícita, empresa y diario de pruebas.

La implementación terminada usa contratos JSON-2 de recordset para el ciclo de
sesión de caja y el wizard de cobro/factura, rechaza estados remotos obsoletos y
distingue resultados intermedios de un cobro final. Factura, pagos y documentos
quedan disponibles para consulta local sin convertir una respuesta parcial en
éxito financiero.

## F5 — Offline, idempotencia y recuperación

**Estado:** completada funcionalmente; regresión global local cerrada en F8.

### Objetivo

Garantizar que una desconexión o reintento nunca duplique documentos
financieros.

### Trabajo

- Sustituir strings de métodos sintéticos por una jerarquía/enum de comandos
  locales versionados.
- Mantener la traducción comando local → una o varias llamadas Odoo en handlers
  explícitos.
- Formalizar dependencias: cliente → orden → líneas → confirmación → wizard →
  factura/pagos → cierre.
- Asignar claves UUID estables a las operaciones creadas en dispositivo y
  buscar el resultado remoto antes de reintentar una creación ambigua.
- Probar interrupción antes de enviar, durante timeout y después de commit
  remoto sin respuesta.
- Completar dead-letter queue, auditoría, reintento manual y resolución de
  conflictos sin borrar evidencia.
- Si la deduplicación fiable requiere un campo o método nuevo en Odoo, detener
  esa tarea y solicitar autorización de cambio de módulo/schema.

### Verificación C5

- Fault-injection demuestra una sola orden, un solo pago y una sola factura
  después de múltiples reintentos.
- Reiniciar la app durante sync recupera operaciones `processing`.
- Los fallos permanentes llegan a dead-letter con datos saneados y recuperables.

La cola terminada usa comandos tipados y versionados, claves idempotentes
estables y dependencias explícitas entre cabecera, líneas y operaciones
financieras. Incluye recuperación de `processing`, estado
`recovery_pending`, backoff, dead-letter, conflictos persistidos, resolución y
apagado ordenado antes de cerrar Drift.

## F6 — Adaptación multiplataforma iPad-first

### Objetivo

Usar la misma lógica de dominio con políticas de presentación e interacción
adecuadas a cada plataforma.

### Trabajo

- Crear harness de tamaños/capacidades y pruebas de layout antes de modificar
  pantallas grandes.
- iPad: split views cuando aporten contexto, orientación, teclado virtual,
  targets táctiles, cámara/escáner y safe areas.
- Android: teléfono/tablet, back navigation, suspensión/reanudación y permisos.
- macOS/Windows: ventana, teclado, foco, atajos, scroll y diálogo de cierre.
- Web: navegación, workers/WASM de Drift, autenticación Bearer JSON-2, CORS y
  reconexión sin cookies.
- Evitar condicionales de plataforma en dominio; usar políticas/adaptadores.
- Incorporar widget/golden tests representativos para venta y caja.

### Verificación C6

- No hay overflow ni controles inaccesibles en tamaños objetivo.
- El recorrido crítico es usable con touch en iPad/Android y con teclado/ratón
  en escritorio/web.
- Suspender, rotar o redimensionar no pierde la orden o cobro en curso.

## F7 — Documento, impresión y cierre operativo

**Estado:** completada funcionalmente; regresión global local cerrada en F8.

### Objetivo

Entregar una salida verificable al cliente y herramientas claras al cajero.

### Trabajo

- Validar sincronización y render QWeb/PDF de factura y recibo.
- Completar el TODO de impresión/compartir desde Venta Rápida.
- Implementar adaptadores de impresión/compartir por plataforma sin acoplar el
  dominio a plugins.
- Mostrar claramente borrador, publicada, pagada y estado fiscal/SRI.
- Validar formatos, totales, forma de pago y datos de compañía.
- Preparar cierre de sesión con desglose, diferencias y exportación/reporte.

### Verificación C7

- El cajero puede abrir, imprimir o compartir el documento resultante.
- PDF y pantalla coinciden con Odoo en cliente, número, impuestos y total.
- Una autorización SRI pendiente se distingue de una factura inexistente o
  fallida.

La implementación terminada persiste el documento y su estado en Drift,
mantiene separadas la generación, la visualización y la salida de plataforma,
y enlaza el resultado de cobro/factura con el cierre operativo. La comprobación
completa de render, impresión y compartir en cada plataforma pertenece a F8.

## F8 — Matriz E2E, CI de release y seguridad

**Estado:** en progreso. La regresión global, el gate local de seguridad y los
builds disponibles desde macOS están cerrados. Permanecen externos el build
Windows en CI, los recorridos controlados de escritura/Odoo 20, la firma y
notarización para distribución y el piloto.

### Objetivo

Convertir los criterios de éxito de la especificación en gates automáticos.

### Trabajo

- Implementar los ocho recorridos E2E definidos en la especificación.
- Ejecutarlos contra Odoo 19.x y 20.x controlados con fixtures únicos.
- Agregar matriz de builds: iOS sin firma, Android App Bundle, macOS, Windows y
  web.
- Verificar creación reproducible del esquema Drift desde clean-install.
- Auditar logs, almacenamiento de credenciales, HTTPS, CORS y permisos.
- Probar volumen representativo de catálogo, órdenes y cola.
- Crear runbooks de instalación, configuración, actualización, soporte offline,
  recuperación y release.

### Verificación C8

- CI completa verde desde un clon limpio.
- Artefactos release se generan para las cinco plataformas.
- E2E 19/20 verdes y secretos ausentes de repositorio/logs.

### Evidencia local al 2026-08-26

- Analyzers limpios en SDK, core, widgets, QWeb y app.
- 3615 pruebas aprobadas y 14 omitidas: SDK 1787 + 14 omitidas, core 559,
  widgets 188, QWeb 102 y app 979.
- Builds release generados: Android APK/AAB, iOS sin firma, macOS y Web; el
  dry run WebAssembly también terminó correctamente.
- Escaneo de secretos y comprobación de whitespace en verde.
- E2E macOS read-only real en verde (`exit 0`): restauración de sesión en dos
  arranques, permisos, todos los destinos permitidos y loaders diferidos, los
  cuatro accesos rápidos, layout compacto y guard de ruta; cola vacía y
  ninguna escritura en ERP2.
- C8 no se declara cerrado hasta obtener Windows CI y los E2E controlados
  contra la matriz Odoo 19/20. Firma, notarización, distribución y piloto son
  gates externos posteriores, no resultados inferidos del build local.

## F9 — Piloto controlado y cierre

**Estado:** pendiente; comienza únicamente después de C8.

### Objetivo

Validar el sistema con usuarios reales antes de declarar la versión terminada.

### Trabajo

- Piloto iPad con un vendedor y un cajero en empresa/diario de prueba.
- Repetir en Android y luego macOS; Windows/web después de sus builds CI.
- Registrar defectos por severidad y repetir el recorrido después de cada fix.
- Preparar checklist de rollback y recuperación de cola.
- Congelar versión, notas de release y compatibilidad comprobada.
- Con autorización separada, publicar o distribuir builds firmados.

### Verificación C9

- Vendedor y cajero completan sus recorridos sin usar el backend web.
- No existen defectos críticos/altos abiertos en venta, cobro, factura o sync.
- El dueño acepta resultados del piloto y la matriz de compatibilidad.

## Trabajo paralelo y secuencial

### Puede avanzar en paralelo después de C0

- Harness adaptativo y pruebas de layouts.
- Guards de rutas y pruebas de permisos.
- Documentación y ampliación de CI.
- Fixtures de contrato JSON-2 que no dependen de cambios del dominio.

### Debe permanecer secuencial

1. Contrato JSON-2 antes de corregir llamadas financieras.
2. Venta online antes de venta offline.
3. Cobro/factura online antes de replay offline.
4. Idempotencia antes de pruebas con pérdida de red.
5. Base controlada antes de cualquier piloto o escritura en `erp2`.
6. Builds sin firma antes de distribución firmada.

## Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---:|---|
| Diferencias 19.x/20.x | Alto | Capabilities y contract tests, no condicionales dispersos |
| App/backend custom desalineados | Alto | Validar método y campos contra el árbol `dev_odoo20` y entorno real |
| Duplicación por timeout | Crítico | UUID, lookup remoto, comandos idempotentes y fault-injection |
| Pruebas sobre producción | Crítico | `erp2` read-only salvo aprobación y fixtures controlados |
| Factura posteada parcialmente | Crítico | Transacción backend canónica y verificación de estado/resultados |
| Estado global al cambiar servidor | Alto | Ciclo de vida por sesión y pruebas de aislamiento |
| Polling, listas y contadores divergen | Alto | Queue-first, upsert Drift común y pruebas reactivas |
| iOS signing/tiendas | Medio | Build sin firma primero; certificados son gate externo |
| Web CORS/Bearer/WASM | Medio | Job y entorno web específicos, sin cookies |
| Documentación histórica obsoleta | Medio | Archivar y enlazar spec/CI como fuentes vigentes |

## Política de cambios backend

La primera estrategia será consumir correctamente los métodos existentes en
`l10n_ec_collection_box`, `l10n_ec_sale_base` y módulos relacionados. Si una
garantía crítica —especialmente idempotencia— exige modificar un módulo Odoo:

1. se documentará el contrato faltante y su caso reproducible;
2. se propondrá el cambio mínimo con prueba Odoo;
3. se solicitará autorización antes de tocar schema o despliegue;
4. se mantendrá compatibilidad con las revisiones 19/20 soportadas.

## Seguimiento mediante tareas

`PROJECT_COMPLETION_V1_TASKS.md` mantiene la descomposición ejecutable, los
criterios de aceptación y el estado comprobado. Una fase solo cambia a cerrada
cuando su verificación focal termina. La parte local de F8 ya acredita la
regresión global, seguridad y cuatro targets; su cierre total requiere además
Windows CI y los recorridos E2E directos controlados.
