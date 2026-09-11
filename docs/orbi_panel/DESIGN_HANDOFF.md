# Orbi ERP — expediente de cierre y entrega a desarrollo

Fecha: 10/09/2026. Estado: cierre documental en revisión; **no autorización de implementación**.

## Fuente de verdad y precedencia

1. Decisiones explícitas del dueño y [registro de aprobaciones](APPROVAL_REGISTER.md).
2. [Especificación de producto](ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md).
3. [Shell e interacción transversal](SHELL_AND_INTERACTION_SPEC.md), con menú/pie actuales.
4. [Interacción y aceptación por familia](INTERACTION_ACCEPTANCE_SPEC.md).
5. [Contratos de integración](CONTRACTS.md), [matriz Odoo/offline](ODOO_OFFLINE_CONTRACT_MATRIX.md)
   y [capacidades opcionales](ODOO_OPTIONAL_CAPABILITIES.md).

Si se contradicen, registrar el punto y resolverlo antes de implementar; no elegir
la interpretación más fácil. Un nombre/importe/icono incidental generado en una imagen
no crea un modelo, permiso ni regla comercial. Un método encontrado en fuente no
demuestra instalación, configuración ni comportamiento de una instancia.

## Trabajo paralelo integrado

| Frente | Entregable | Resultado y límite |
|---|---|---|
| Visual | [Auditoría](VISUAL_CLOSURE_AUDIT.md) | 46 archivos aprobados inventariados; muestreo visual, no revisión exhaustiva de cada píxel/estado |
| Interacción | [Specs y escenarios](INTERACTION_ACCEPTANCE_SPEC.md) | Familias operativas, foco, errores, continuidad, cuatro tamaños y criterios de pruebas; pruebas no ejecutadas |
| Odoo/offline | [Matriz](ODOO_OFFLINE_CONTRACT_MATRIX.md) | Evidencia de fuente, operaciones condicionadas y garantías por verificar; sin acceso a BD/ERP2 |
| Integración | Este expediente | Precedencia, pendientes y puertas de aceptación; no modifica la app |

Los 46 archivos son 7 históricos, 33 de round-02 y 6 de round-03. No equivalen a
46 recorridos completos probados. Las copias aprobadas son inmutables; una corrección
visual se guarda como nueva versión propuesta y solicita aprobación específica.

## Pendientes concretos, sin reabrir diseños aprobados

### Consolidación documental incorporada

| Encargo | Documento | Límite |
|---|---|---|
| Pantallas aprobadas | [Índice único](APPROVED_SCREEN_INDEX.md) | 46 PNG y recorridos/specs; no auditoría visual exhaustiva |
| Navegación y permisos | [Matriz de navegación](NAVIGATION_CAPABILITY_MATRIX.md) | Menús y capacidades funcionales; ACL reales por verificar |
| Interacciones y offline | [Matriz por operación](OPERATION_INTERACTION_OFFLINE_MATRIX.md) | Acciones, validaciones, retorno y efectos; no pruebas ejecutadas |
| Componentes compartidos | [Widgets reactivos](REACTIVE_COMPONENTS_SPEC.md) | Núcleo offline, campos locales e imágenes editables; no implementación |

Complementan las imágenes aprobadas sin sustituirlas. Las decisiones del dueño
prevalecen sobre ejemplos y nombres técnicos propuestos.

| ID | Falta | Evidencia para cerrarlo |
|---|---|---|
| V01 | Normalizar menú, pie y marca entre rondas | Lámina de componentes globales con logo real, seis áreas y pie en cuatro formatos; correcciones nuevas, no sobrescrituras |
| V02 | Tema compartido claro/oscuro | Colores semánticos y componentes; una comparación y 2–3 pantallas representativas, NO una imagen oscura por pantalla/tamaño |
| V03 | Estados no representados | Matriz por recorrido de carga, vacío, error, permisos, offline, resultado parcial y recuperación; variantes compartidas sólo si realmente equivalentes |
| I01 | Inventario completado; mapa final por validar | [Contrato de teclado/entrada](KEYBOARD_AND_INPUT_CONTRACT.md): evidencia local, colisiones y 18 escenarios; no pruebas ejecutadas |
| B01 | Bindings por formulario y acción | Campo/modelo/método público, parámetros, permiso, efecto y respuesta verificados; especialmente operaciones auxiliares y Bodega |
| B02 | Contrato de Envases | Identificar lo reutilizable y especificar ampliación: contenido separado, propiedad/custodia, presentaciones, múltiples líneas, factura/toma, parciales y trazabilidad |
| O01 | Matriz offline ejecutable | Autorización provisionada por operación, identidad estable, dependencias, reconciliación y conflictos; no cupos inventados por equipo |
| O02 | Concurrencia e identidad fiscal | Prueba de restricción/operación atómica backend, numeración y consulta de resultado incierto; buscar antes de crear no basta |
| P01 | Plataformas y periféricos | Web offline/login, almacén seguro, impresión/lector y notificaciones con app cerrada por plataforma; sin promesas universales |
| L01 | Rejillas Syncfusion | Licencia aplicable confirmada antes de distribuir, componente/versión y soporte comprobados antes de implementar |
| Q01 | Superioridad frente a theos_pos | Mismas tareas/datos/equipo; medir tiempo, pasos, errores y recuperación con usuarios; no declararla sólo por estética |

V01–V03 requieren imágenes nuevas y revisión, no rediseñar todas las pantallas desde cero.
La aclaración posterior del dueño limita V02: no multiplicar imágenes para cambiar
colores. [PERSONALIZATION_SPEC.md](PERSONALIZATION_SPEC.md) fija herencia por propiedad,
tema compartido y validación visual representativa.
B01–B02 requieren especificación sustentada en fuentes; escribirla no instala módulos.
Las verificaciones de instancia, distribución y pruebas reales se harán únicamente en
el entorno autorizado. ERP2 queda fuera de cambios y pruebas con efectos.

## Puertas de aceptación para la fase futura

- **Diseño:** imagen aprobada identificada, cuatro formatos, tema y estados requeridos.
- **Contrato:** operación enlazada y garantías documentadas; los desconocidos no se ocultan con mocks.
- **Prototipo:** si se autoriza después, fixtures prueban sólo interacción y navegación.
- **Integración:** identidad, ACL, efecto local/remoto, impuestos, saldos y numeración comprobados en entorno autorizado.
- **Resiliencia:** doble pulsación, respuesta perdida, reinicio offline, cambio A→B→A,
  conflicto, disco insuficiente y actualización no pierden ni duplican hechos.
- **Usabilidad:** entrada en cada campo comprobada, foco estable y sin bloqueos/parpadeo;
  comparación con la baseline aprobada y tareas reales equivalentes a theos_pos.

Para cada prueba conservar ID del escenario, commit, actor/capacidades, precondiciones,
viewport/tema/entrada, pasos, resultado visible, efecto verificado y evidencia saneada.
Estados: no ejecutado / bloqueado / falló / pasó en prototipo / pasó con integración.
No llamar «E2E completo» a una captura, a un test con respuestas simuladas ni a que compile.

## Orden de continuación

### Contratos técnicos y tareas preparados

- [Auditoría del núcleo offline](OFFLINE_CORE_TECHNICAL_AUDIT.md): firmas reales,
  observabilidad, persistencia de borradores, comandos, archivos y huecos.
- [Interfaces de componentes](COMPONENT_INTERFACE_CONTRACTS.md): entradas/eventos,
  validación y ownership; pseudocódigo propuesto, no APIs implementadas.
- [Mapeo de acciones Odoo](ODOO_ACTION_BINDINGS.md): métodos/campos/guardas localizados;
  ACL efectivas, transporte e instalación pendientes de pruebas seguras.
- [Paquetes de desarrollo](IMPLEMENTATION_WORK_PACKAGES.md): doce tareas iniciales
  con dependencias, propiedad de archivos y aceptación. No activan desarrollo ni
  reemplazan silenciosamente el plan histórico.

La integración prioriza observables conectados al store, borrador íntegro aislado
por empresa y recursos de imagen durables. Las operaciones no auditadas por completo
se conservan explícitas; documentación terminada no equivale a contrato probado.

**Asignación del dueño:** el backend de Envases será desarrollado por otro agente
experto en Odoo 19.5. Este equipo entrega el
[prompt de encargo](PROMPT_ODOO_ENVASES_AGENT.md) y el
[contrato de dominio propuesto](ENVASES_DOMAIN_CONTRACT.md); no implementa ese backend.
El módulo debe operar completo desde Odoo web; Orbi consume los mismos datos/reglas
y permisos. Se espera de vuelta el contrato real probado antes de enlazar Orbi.
Su recepción se rige por [ENVASES_BACKEND_ACCEPTANCE.md](ENVASES_BACKEND_ACCEPTANCE.md).

En paralelo: V01–V03 (variantes), I01 (inventario interacción), B01–B02/O01–O02
(contratos). P01/L01 se preparan documentalmente sin instalar ni desplegar.
Después revisión conjunta del expediente y autorización explícita para desarrollo.
El plan técnico previo de 24 tareas no acredita este cierre: `check_orbi_plan.py`
no tiene tareas pendientes listas y no verifica app, build ni ERP2.
