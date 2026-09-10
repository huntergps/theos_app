# Encargo para el agente experto en Odoo 19.5 — módulo de Envases

Puedes entregar este documento completo al agente. Es un encargo de desarrollo
del backend y UI nativa de Odoo; no una solicitud de implementar Flutter.

---

Actúa como arquitecto y desarrollador experto de Odoo **19.5**. Debes construir un
módulo de control de envases de la empresa, completamente operable desde la web
nativa de Odoo. Orbi ERP (`theos_panel`) será otra interfaz sobre los mismos modelos,
reglas, permisos y documentos. **No construyas un sistema exclusivo para Orbi ni
dos inventarios independientes. Odoo debe funcionar sin Orbi abierta o instalada.**

## 1. Entorno, alcance y seguridad

- Código Odoo y custom: `/Users/elmers/Documents/dev_odoo20`; localiza los addons
  reales e instrucciones del repositorio. El nombre de la carpeta no demuestra
  versión: confirma rama/runtime 19.5 y compatibilidad antes de implementar.
- Documentación Orbi: `/Users/elmers/Documents/develop/2026/theos_app/docs/orbi_panel/`.
- Lee `AGENTS.md` y la skill Odoo del repositorio. Respeta sus mecanismos de búsqueda.
- Sólo trabajar en fuentes y entorno de desarrollo/pruebas autorizado. **No tocar
  ERP2**, desplegar, instalar/actualizar módulos en producción ni alterar datos reales.
  Si no existe entorno seguro identificado, continúa código/tests sin ejecutar contra
  una instancia desconocida y reporta lo necesario para validarlo.
- No modificar Flutter/theos_pos/theos_panel. No eliminar cambios ajenos.
- Guarda avances en commits pequeños, sin secretos. Reporta pruebas realmente ejecutadas.

## 2. Investigación previa obligatoria

Inspecciona productos, unidades/presentaciones, inventario, movimientos, ubicaciones,
ventas/compras/facturas y addons existentes. Reutiliza lo existente cuando corresponda.
No inventes que un modelo/campo ya existe ni crees campos duplicados por comodidad.
Propón nombre técnico y dependencias del módulo a partir de esa inspección.

Decide justificadamente qué reutiliza `stock` y qué extensión hace falta para custodia,
propiedad y deuda física de envases. Si hay libro auxiliar, debe derivar de operaciones
identificadas/reconciliables, no competir con otro saldo editable. No exige instalar HR,
Caja o POS sólo para gestionar envases. Venta comercial del proyecto es `sale.order`,
no `pos.order`; reutiliza los flujos actuales sin sustituirlos.

## 3. Requisitos confirmados del negocio

1. Los envases son propiedad de la empresa: se compraron inicialmente y se pueden
   comprar más. Pueden venderse si el cliente quiere conservarlos o facturarse por
   no devolución mediante el procedimiento comercial autorizado.
2. **Contenido, envase y presentación son distintos.** Vender gaseosa/cerveza u otro
   contenido no significa vender el recipiente. La botella es unidad; la jaba es
   una presentación con equivalencia configurable. No suponer que toda jaba es otro
   activo físico cobrado/controlado ni fijar una equivalencia universal.
3. No limitar a botellas: admitir distintos tipos de envase y diferentes productos,
   marcas/capacidades/presentaciones. El control y el dashboard son **por producto**.
   Explica cómo evitar duplicar unidades físicas si productos comparten un recipiente
   compatible; no asumas intercambiabilidad sin configuración explícita.
4. Gestión por cantidades y múltiples líneas, **no identificación uno a uno** obligatoria.
5. Controlar Guayaquil y Galápagos, ambas direcciones de tránsito, otras sedes futuras,
   envases en empresa, clientes y proveedores. Custodia no cambia propiedad.
6. Envío y recepción son hechos separados; admitir recepción/devolución parcial,
   diferencias, daños, pérdida y correcciones con trazabilidad y autoridad.
7. El responsable de envases opera sin sesión de Caja. Bodega/Envases son áreas
   distintas; productos normales de venta mantienen su inventario habitual.
8. Se puede iniciar el control desde una **factura** o una **toma física**. Factura es
   referencia comercial, no necesariamente el evento físico que suma existencias.
   Investiga la integración correcta con los documentos actuales.

## 4. Operación completa en Odoo web

Implementa navegación, búsquedas, filtros, vistas de lista/formulario y acciones nativas
adecuadas a 19.5. No basta con modelos/API sin pantallas. Deben poder realizarse:

- Dashboard consolidado por producto/envase/presentación con cantidades en sedes,
  clientes, proveedores y tránsito separado por sentido; pasar al detalle desde el total.
- Catálogo/configuración de relaciones contenido–envase–presentación y equivalencias.
- Listado histórico de movimientos y trazabilidad hasta documento origen y actor.
- Entregas/devoluciones de clientes y proveedores, con varias líneas y parciales.
- Despachos, recepciones y seguimiento de tránsitos entre sedes.
- Registro/asociación desde factura y toma física con revisión de diferencias.
- Compra adicional y venta/facturación de envases con documentos comerciales reales.
- Incidencias, bajas, correcciones/reversiones autorizadas e historial auditable.
- Consulta de saldos físicos por cliente/proveedor y documento; no confundir deuda
  de unidades con deuda monetaria ni emitir facturas automáticamente sin autorización.

Usa las imágenes aprobadas como referencia funcional/visual, sin copiar un widget
Flutter dentro de Odoo. Las vistas nativas deben ser útiles por sí mismas. Cantidades
y filtros del dashboard deben coincidir con las líneas que abre cada indicador.

## 5. Invariantes y casos delicados

- Un envase propio ocupa una sola categoría de custodia/ubicación vigente. Tránsito
  no cuenta simultáneamente como disponible en origen y destino.
- Condición (usable/dañado) es otra dimensión, no una cantidad adicional al total.
- Bajas definitivas y ventas con transferencia de propiedad salen del total propio
  vigente, pero conservan historial. Devolución logística no es una nueva compra.
- Toma física registra observado, compara al corte y ajusta sólo diferencia autorizada.
  No sumar todo el conteo como entrada ni excluir del conteo unidades ya registradas.
- Una compra ya recibida o incluida en apertura no vuelve a sumar al asociar factura.
  Explicitar cómo se concilian facturas históricas y movimientos concurrentes al conteo.
- Facturar no devolución debe definir su efecto patrimonial/contable según el flujo
  configurado; **no equiparar automáticamente factura, pago y salida física**.
- Definir corrección si aparece un envase después de facturarlo: procedimiento
  autorizado y documentos existentes; no devolución de dinero automática.
- No borrar movimientos validados ni resolver conflictos sumando, perdiendo evidencia
  o cambiando el autor. Evitar importes y reglas fiscales inventados en Orbi.

## 6. Permisos y multiempresa

Define grupos/ACL/reglas nativos para consulta, operación y ajustes sensibles usando
convenciones existentes. Propón asignaciones concretas sin presumir poderes por un
nombre de rol. Verifica empresa, ubicaciones, documentos relacionados y actor tanto
en UI web como API. No usar `sudo()` indiscriminado para que una operación pase.
Un cajero no es requisito. Un administrador no debe eludir silenciosamente controles.

## 7. Contrato consumible por Orbi offline-first

Orbi conserva lecturas y trabajo local autorizado, pero Odoo es autoridad. Entrega
contrato documentado para consultar catálogo/dashboard/movimientos/documentos y ejecutar
las mismas acciones públicas que la UI nativa, con permisos equivalentes.

- Identificadores estables, unidades/precisión, filtros, paginación y cursor/revisión
  de cambios; contemplar anulaciones y cambios que desaparecen del filtro.
- Matriz por operación: consulta local, preparación local, registro offline autorizado,
  acción que exige servidor y conciliación al reconectar. No declarar todo offline
  ni prohibirlo todo por comodidad. Decisiones nuevas deben estar señaladas.
- Identidad estable del comando, actor, empresa, dispositivo y documento; el servidor
  comprueba identidad autenticada. No confiar en `user_id` suministrado libremente.
- Dedupe **atómica**: mismo comando reintentado, incluso concurrentemente, produce
  un solo efecto y permite consultar/recuperar el resultado. Mismo ID con otro payload
  se rechaza. Buscar antes de crear no basta.
- Dependencias (crear→enviar→recibir), versión esperada, transacción y respuesta
  estructurada. Distinguir resultado incierto de rechazo y de conflicto.
- No imponer políticas como “último gana” o merge de cantidades en conflictos físicos.
  Conservar evidencia y ofrecer sólo resoluciones autorizadas.
- No exponer métodos privados como API. Elige transporte compatible con la instalación
  real, sin inventar que un endpoint de Orbi ya existe.

## 8. Pruebas mínimas verificables

Con fixtures ficticios y entorno aislado, prueba al menos:

1. Apertura A: GYE100/GPS20. Enviar10 a GPS → GYE90/GPS20/tránsito10/total120.
   Recibir6 → GYE90/GPS26/tránsito4/total120. Recibir4 completa el tránsito.
2. Tránsito contrario, cliente y proveedor conservan propiedad y no duplican total.
3. Operación de varios productos/presentaciones: cada conversión conserva su unidad
   base, sin sumar tipos incompatibles como si fueran el mismo producto.
4. Compra12 ya incluida en una toma/factura asociada: alta una sola vez.
5. Conteo observado118 frente a registrado120: diferencia−2 propuesta, no entrada118;
   aplicar sólo con autorización y prueba de cambios concurrentes desde el corte.
6. Devolver5 de10; registrar daño en2 de las5 sin sumar daño otra vez al total.
7. Compra adicional, venta/no devolución y devolución posterior según procedimiento
   configurado: efectos físicos y comerciales separados, enlaces auditables.
8. Dos llamadas concurrentes con mismo comando; timeout posterior al commit;
   reintento tras reinicio; mismo ID y payload distinto; ninguna duplicación.
9. Responsable sin Caja puede operar; usuario no autorizado/multiempresa cruzada no.
10. Flujos completos desde **Odoo web sin Orbi** y paridad de efecto mediante API.

Incluye tests automatizados de modelos/acciones y pruebas del recorrido web compatibles
con el proyecto. No declares éxito porque el módulo importa o el test usa mocks felices.

## 9. Entrega al integrador de Orbi

Entrega código, vistas, ACL/reglas, datos mínimos, migraciones si aplican, tests,
commits y guía de instalación segura. Además, documento de contrato con:

- Nombre/versiones/dependencias e instalación realmente comprobada.
- Modelos/campos reales, métodos públicos, parámetros y respuestas de ejemplo saneadas.
- Mapeo de cada pantalla/acción Orbi a su equivalente Odoo.
- Permisos, estados, validaciones, errores recuperables y conflictos.
- Cursor/delta, comando/idempotencia, límites offline y compatibilidad de versiones.
- Pruebas ejecutadas con resultado y pendientes explícitos.

No devuelvas “listo para integrar” si faltan efectos atómicos, UI nativa o permisos.
Si una decisión material no está fijada, muestra alternativas con recomendación y
continúa las partes independientes sin inventar la regla de negocio.

## Referencias locales

Lee `ENVASES_DOMAIN_CONTRACT.md`, `ODOO_OFFLINE_CONTRACT_MATRIX.md`,
`ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md`, `APPROVAL_REGISTER.md` y `CONTRACTS.md`.
Imágenes: `visual_baselines/approved/round-02/ENV-01.png`, `ENV-02.png`, `ENV-03.png`,
`ENV-06.png`, `ENV-07.png`; localiza en el índice las históricas ENV-FACTURA y
ENV-TOMA-FISICA. Las imágenes no son esquemas de datos ni sustituyen las reglas de arriba.
