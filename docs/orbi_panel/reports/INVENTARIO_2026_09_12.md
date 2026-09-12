# Inventario real de Orbi — qué falta para estar completa

Cotejado contra el código el 2026-09-12, en `theos_panel/lib/features/` y
`theos_panel/lib/app/router.dart` (rutas + menú), **no contra los documentos**.
Base documental: `APPROVED_SCREEN_INDEX.md` (46 láminas: 7 históricas + 33
round-02 + 6 round-03), `VISUAL_COVERAGE.md`, `NAVIGATION_CAPABILITY_MATRIX.md`,
y la auditoría previa `reports/SCREEN_CORRESPONDENCE_AUDIT_2026_09_11.md`
(reusada como hipótesis de partida, no como verdad — ver §0).

Las 7 láminas históricas (`VENTAS-*`, `PENDIENTES-RESULTADO-COBRO-v1`,
`BODEGA-ENVASES-v1`, `ENV-FACTURA-v1`, `ENV-TOMA-FISICA-v1`) están superadas
por las 39 de round-02/03 o cubren el mismo hueco que ENV-02/03/06/07 — no se
cuentan aparte para no duplicar.

## 0. El número de dieciséis estaba mal, y en qué dirección

**No son 16. Hoy son 13.** El "16" de `PENDIENTES.md` viene de contar las filas
"Ausente" de la auditoría de ayer (`SCREEN_CORRESPONDENCE_AUDIT_2026_09_11.md`).
De esas 16, **dos ya tenían código ayer** y la auditoría las marcó mal:

| Pantalla | Auditoría de ayer decía | Realidad de hoy |
|---|---|---|
| BOD-01 (existencias) | "Ausente — `warehouse_screen.dart` solo lista despachos" | `WarehouseExistencesScreen` ya existía, con contrato y tests propios. Sólo le faltaba ruta y menú (defecto cerrado esta noche) |
| CAJ-09-v2 (contexto turno) | "Ausente — no hay pantalla de abrir acciones del turno" | `CollectionSessionHubScreen` ya existía, con su propio test de ruta. Sólo le faltaba entrada de menú (defecto cerrado esta noche) |

Es el mismo error que motivó el encargo de esta noche: contar "sin código" y
"sin ruta" y "sin menú" como si fueran lo mismo. Con las dos corregidas y ya
alcanzables, y sumando una tercera que **sí tiene código pero sigue sin poder
alcanzarse** (ACC-02, ver abajo), el recuento real de hoy es:

| | Cantidad | Significa |
|---|---:|---|
| **Implementada y alcanzable** | **19** de 39 | Tiene pantalla, ruta y (si aplica) menú; se puede usar de principio a fin para lo que la lámina aprobada muestra |
| **Construida pero inalcanzable** | **1** de 39 | Tiene código y pruebas propias; nadie puede llegar a ella navegando ni la invoca ninguna otra pantalla (ACC-02, PIN de vendedor — ver §1) |
| **A medias** | **6** de 39 | Existe la pantalla; cubre una parte del recorrido aprobado, no todo |
| **Sin código de verdad** | **13** de 39 | Cero rastro en `theos_panel/lib` |

19 + 1 + 6 + 13 = 39. Los 46 de `APPROVED_SCREEN_INDEX.md` menos las 7
históricas ya cubiertas por las de arriba.

## 1. Construida pero inalcanzable (la misma familia de defecto que esta noche)

- **ACC-02 — PIN de vendedor.** `pin_login_screen.dart` existe, compila, tiene
  su propio test (`pin_login_screen_test.dart`) y ya sabe verificar/bloquear un
  PIN. **Nada la invoca**: no está en `router.dart`, `login_screen.dart` no
  ofrece "Modo vendedor", y no hay ruta `/pin`. Es la puerta de entrada que
  `NAVIGATION_CAPABILITY_MATRIX.md` documenta como *la* forma de acceso de un
  vendedor en equipo compartido — hoy no existe manera de llegar ahí sin
  escribir código. Y es más urgente después de esta noche: ya se puede dar de
  alta un PIN (`PinEnrollmentSection`, en Configuración), pero **enrolarlo
  ahora mismo no sirve para nada**, porque la pantalla que lo consume sigue sin
  enganchar.

## 2. Sin código de verdad, por área (13)

| Área | Pantallas | Qué haría cada una |
|---|---|---|
| **Caja** (4) | CAJ-02, CAJ-03, CAJ-04-v2, CAJ-08-v2 | CAJ-02: pestañas de órdenes/facturas/pagos de la sesión abierta, sólo lectura. CAJ-03: cobrar contra varias facturas de un cliente (cartera). CAJ-04-v2: consultar clave y registrar una retención SRI. CAJ-08-v2: cruce de cuentas (fuente/destino, requiere supervisor). |
| **Bodega** (1) | BOD-04 | Conteo físico: capturar esperado/contado/diferencia y enviarlo a revisión de un supervisor, sin ajustar solo. |
| **Envases** (4) | ENV-02, ENV-03, ENV-06, ENV-07 | ENV-02: histórico de movimientos y trazabilidad. ENV-03: entregas/devoluciones/tránsitos pendientes. ENV-06: recepción/devolución con líneas múltiples y deterioro. ENV-07: compra/venta de envase vinculada a factura. |
| **Sistema/MUL** (4) | OPS-01, ALERT-01, ALERT-02, AI-01 | OPS-01: sesión expirada, reautenticar sin perder lo local, diagnóstico sin secretos. ALERT-01: banner de aviso/validación interno separado del inbox. ALERT-02: aviso de permisos/estado del dispositivo. AI-01: asistente condicionado a que Odoo tenga IA instalada. |

## 3. A medias — qué le falta a cada una (6)

| Pantalla | Tiene | Le falta |
|---|---|---|
| **BOD-02** (recepción/preparación/entrega/transferencia) | `warehouse_screen.dart`: validar entrega + backorder, con el candado de cobro previo que sólo existe para `outgoing` en el addon | Recepción y transferencia interna: ni la app ni el addon (`l10n_ec_despachos`) tienen candado o pantalla propia para ellas — es decisión de producto pendiente, no sólo código |
| **BOD-03** (preparación/entrega parcial) | Diálogo "Backorder requerido" (sí/no) | Editar cantidad línea a línea e indicar faltante durante la preparación (hoy sólo valida con lo que YA trae el picking); no hay lector de código de barras en ningún paquete del repo |
| **SYN-03** (conflicto local vs. Odoo) | Pantalla real ya construida esta noche por otro agente (`sync_conflict_resolution_screen.dart`, comparación de campos, estado "Incierta") — cierra el hallazgo "Parcial" de ayer | Los datos que la alimentan llegan vacíos: `PENDIENTES.md` fichó que "el trabajo que calcula los conflictos sólo guarda cuántos hay y descarta el detalle". Pantalla lista, fuente de datos incompleta — defecto ya anotado, sin dueño |
| **CFG-01** (configuración/equipo) | Apariencia, tema, densidad, acento, tamaño de texto, Modo Ruta, reintentos de sync, duraciones de mensaje, permisos de notificación, y desde esta noche la sección de seguridad (alta/cambio/baja de PIN) | La "modalidad" (equipo personal/compartido/híbrido/operativo, §7 de `ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md`) no existe en ningún sitio — no hay selector ni almacenamiento de esa política |
| **CONT-01** (continuidad A→B→A) | Persistencia durable de borrador (`durable_sale_draft_store.dart`, `sale_draft_workspace.dart`): un borrador sobrevive cambiar de pantalla y volver | Ningún indicador visible de que el cambio A→B→A conservó foco/selección, que es lo que la lámina aprobada muestra, no sólo que el dato sobrevive |
| **OUT-01** (salidas de Odoo: previsualizar/imprimir/reintentar) | `document_view.dart`/`offline_qweb_report.dart`: estado fiscal y de sincronización del documento, PDF vía `flutter_qweb` (que sí trae el paquete `printing` como dependencia transitiva) | Ninguna pantalla llama a imprimir ni a compartir, y no hay acción de reintento de envío — el plugin está disponible, nadie lo usa |

## 4. Necesitan trabajo de servidor — verificado, no repetido de memoria

`docs/orbi_panel/decisions/CAJA-BODEGA-01-pantallas-ausentes-backend.md` (ayer,
lectura directa de `/Users/elmers/Documents/dev_odoo20`, cita archivo:línea)
ya examinó las 9 pantallas de Caja+Bodega sin código o parciales. Confirmo su
conclusión, no la repito de memoria:

- **Sólo dos son imposibles hoy sin backend nuevo: CAJ-03 (cartera) y BOD-04
  (conteo físico).** CAJ-03 porque no existe un método que reciba "cliente + N
  facturas + importe" contra cartera general (el único residual por cliente
  vive privado dentro del wizard de UNA orden). BOD-04 porque el núcleo de
  `stock.quant` sólo tiene "aplicar de una vez" o "conflicto"; no existe un
  tercer estado "contado, pendiente de aprobación de un supervisor".
- Las otras 7 (CAJ-02, CAJ-04-v2, CAJ-08-v2, CAJ-09-v2, BOD-01, BOD-02, BOD-03)
  **sí tienen modelo y método suficientes en Odoo** — su bloqueo real es
  transporte Dart ausente, política offline pendiente (CAJ-04-v2 exige SRI en
  línea) o ACL de instancia sin verificar (CAJ-08-v2), nunca "falta backend".
  BOD-01 ya lo demuestra: tenía el modelo completo y esta noche sólo hizo
  falta enchufar la app, sin tocar Odoo.

**Lo que esa ficha NO cubrió, y no voy a inventar un veredicto:** Envases
(ENV-02/03/06/07) y el bloque de Sistema/MUL (OPS-01, ALERT-01/02, AI-01) no
se verificaron con ese mismo rigor (grep contra el código fuente de Odoo). Mi
lectura de las láminas aprobadas es que ENV-02/03/06/07 casi seguro **no**
necesitan backend nuevo — son lecturas/escrituras sobre el mismo módulo de
envases que ya alimenta el dashboard (ENV-01) real — y que OPS-01/ALERT-01/
ALERT-02/AI-01 son composición de app y permisos del sistema operativo, no
modelo de Odoo. Pero es una lectura, no una verificación citada; si el dueño
va a priorizar sobre esto, alguien debería auditarlas con la misma rigurosidad
antes de prometer fecha.

## 5. Lo que falta y no es una pantalla (esto es lo que más importa)

Mirando el conjunto para "alguien lo usa un día entero en un mostrador":

1. **No hay enrolamiento de dispositivo.** Cero rastro de `device_uuid` o
   equivalente en todo el repo (`orbi_runtime`, `theos_pos_core`, `odoo_sdk`,
   `theos_panel`: grep sin resultados). El PIN de hoy identifica una
   *cuenta*, no un *equipo autorizado* — la distinción que
   `ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md` §8 exige ("bloquear operador"
   vs. "cerrar Workspace" vs. "desautorizar dispositivo") no existe. Sin esto,
   "equipo compartido" es sólo una etiqueta de documento, no algo que el
   sistema aplique o revoque.
2. **Sin lector de código de barras, en ningún paquete del monorepo.** Ni
   Mostrador (VEN-03) ni preparación de bodega (BOD-03) pueden escanear —
   ambas láminas aprobadas lo mencionan y ambas lo excluyen explícitamente de
   "lo aprobado" por esa misma razón.
3. **Sin impresión ni "compartir" conectados, aunque el plugin ya está en el
   árbol.** `flutter_qweb` trae `printing: ^5.15.0` como dependencia
   transitiva; ninguna pantalla de Orbi la invoca. Imprimir un comprobante de
   cierre de caja o una cotización hoy no es "falta el plugin", es "nadie
   llamó al plugin".
4. **Sin cajón de dinero ni ninguna otra periferia de mostrador** (impresora
   fiscal, báscula, datáfono) — cero mención en cualquier `pubspec.yaml` del
   monorepo.
5. **La red "sin conexión de verdad" tiene dos huecos ya fichados y sin
   dueño**, ambos en `PENDIENTES.md`: un fallo de conexión se interpreta como
   falta de red sin comprobarlo (el paquete de conectividad está declarado y
   sin usar), y los conflictos de sincronización llegan vacíos a la pantalla
   que ya existe para mostrarlos (ver SYN-03 arriba). Un mostrador que trabaja
   offline todo el día se va a topar con los dos.
6. **ACC-02 inalcanzable (§1) es, en la práctica, un hueco de "un día entero
   en el mostrador":** sin PIN operable, todo cambio de vendedor en un equipo
   compartido pasa por usuario y contraseña completos, que es exactamente lo
   que el PIN existe para evitar.
7. **Configuración de la instancia, no de la app, pero bloquea el día
   completo igual:** `PENDIENTES.md` ya fichó que en ERP2 ningún diario de
   venta está numerado por el cliente y ninguna configuración de caja tiene
   diario/equipo asignado — con eso así, la app **se niega a emitir sin
   conexión** (comprobado en la app vieja, mismo servidor). Si ERP2 es el
   entorno donde se va a probar "un día entero", esto se topa primero que
   cualquier pantalla que falte.

## 6. Regla nueva: qué manda cuando dos láminas se contradicen

Añadida el 2026-09-12 tras un choque real entre `SHELL-01.png` (round-03) y
`ACC-03.png` (round-02): la primera dibuja una barra lateral y una cabecera
distintas de la segunda, y la segunda dibuja un "Inicio operativo" completo
que la primera ni siquiera intenta representar (usa Órdenes y cotizaciones
como contenido de ejemplo). Ninguna de las dos está retirada — las dos siguen
"aprobadas" en `APPROVED_SCREEN_INDEX.md`.

**La regla, confirmada por el team-lead: la lámina más reciente manda, pero
sólo sobre el tema que su propio título declara — no sobre todo lo que
aparece dibujado en ella.**

Aplicado a este choque:
- `SHELL-01` ("Menú y contexto global", round-03) **manda** para la
  estructura del menú lateral y de la barra superior — es su tema declarado.
- `ACC-03` ("Workspace multirrol", round-02) **manda** para el contenido de
  Inicio y para la idea de bloquear/cambiar usuario — SHELL-01 no declara ese
  tema como suyo, así que no lo desplaza aunque sea más nueva.

Esto no es "la más nueva gana en todo": una lámina posterior que sólo enseña
el menú no revoca el contenido de Inicio que una anterior sí definió, y
viceversa. Cuando aparezca el próximo choque, comprobar primero **qué declara
ser el tema de cada lámina** antes de asumir que la fecha decide sola.

## Fuentes citadas

- `docs/orbi_panel/APPROVED_SCREEN_INDEX.md`, `VISUAL_COVERAGE.md`,
  `NAVIGATION_CAPABILITY_MATRIX.md`, `PENDIENTES.md`.
- `docs/orbi_panel/reports/SCREEN_CORRESPONDENCE_AUDIT_2026_09_11.md` (línea
  base, dos correcciones aplicadas arriba).
- `docs/orbi_panel/decisions/CAJA-BODEGA-01-pantallas-ausentes-backend.md`
  (única fuente de la sección 4, verificada contra `dev_odoo20`).
- Código vivo: `theos_panel/lib/features/**`, `theos_panel/lib/app/router.dart`,
  `theos_panel/pubspec.yaml` y el de cada paquete del monorepo (grep de
  `printing`/`share_plus`/`mobile_scanner`/`barcode`/`camera`).
