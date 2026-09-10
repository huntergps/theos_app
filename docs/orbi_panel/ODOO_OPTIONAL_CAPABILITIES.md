# Capacidades opcionales de Odoo en Orbi

Fecha: 2026-09-10. Decisión del dueño incorporada a la propuesta; sólo documentación.
Inspección de código local de dev_odoo20, commit observado `0f2e3790c`.
No se consultó una BD para acreditar módulos instalados, ni se enviaron mensajes,
imprimieron documentos o modificaron Odoo/ERP2.

## Regla de producto

**Orbi reutiliza los módulos de IA y salidas de Odoo. Si la capacidad no existe
instalada en la base conectada, tampoco se ofrece en Orbi.**
Instalación es necesaria, no suficiente: comprobar configuración, empresa,
permisos, documento, destinatario y disponibilidad del transporte.

Esta decisión sustituye la propuesta anterior de un proveedor IA propio de Orbi.
No instalar un SDK LLM, cuenta WhatsApp, bot Telegram, cola de mensajes o motor
de plantillas paralelo en Flutter. Los secretos/configuración permanecen en Odoo.
Un adaptador de transporte de impresión en el dispositivo no es otro sistema de
salidas: ejecuta el trabajo que Odoo autorizó y generó.

## Piezas encontradas en el código

Rutas relativas a `/Users/elmers/Documents/dev_odoo20/`.

| Capacidad | Fuente existente | Reutilización y límite |
|---|---|---|
| IA nativa | `enterprise/ai/models/ai_session.py`, `services/ai_provider.py` | Sesiones/agentes y ejecución de herramientas en Odoo; no LLM independiente en Orbi |
| Proveedores IA custom | `addons/ai_extra_providers/__manifest__.py`, `addons/ai_local_provider/__manifest__.py` | Ambos dependen de `ai`; detectar proveedor realmente activo, no elegir por presencia de carpetas |
| Asesor comercial | `addons/ai_asesor_ventas/__manifest__.py`, `models/ai_asesor_tools.py` | Depende de ai/account/sale; cliente fijado a la sesión, cotización borrador y revisión humana. No asumir que un agente de chat externo ya es un asistente interno multirrol |
| Puentes IA | `addons/ai_whatsapp_bridge`, `addons/telegram_ai_bridge` | Integran esos canales con sesiones IA; no implican que ambos canales estén habilitados |
| Búsqueda semántica | `addons/ai_record_rag` | Opcional; presencia del módulo no acredita indexación. Cron del fuente revisado está desactivado |
| Salidas de documentos | `addons/l10n_ec_salidas_caja/models/salida_caja.py:340` | Resolución central por caja/compañía/informe; devuelve destinos y fallos |
| Impresión | `addons/gpstech_printer/models/ir_actions_report.py:79`, `addons/l10n_ec_impresion_ticket` | Trabajos PDF/raw/ZPL según informe/transporte; tickets en venta/factura/pago/anticipo. No suponer acceso directo a cualquier impresora desde cada plataforma |
| Informes | `addons/gpstech_reports/models/ir_actions_report.py` | Reutilizar plantillas y render de Odoo, no reproducir layouts fiscales de memoria |
| WhatsApp | `addons/whatsapp_gateway`, `addons/l10n_ec_salidas_whatsapp/models/salida_caja.py:81` | Gateway sobre WhatsApp nativo; salida de Caja genera PDF y delega al dispatcher |
| Motor de avisos | `addons/l10n_ec_notification_base/models/notification_dispatcher.py:95` | Reutilizar `notify()` y sus resultados/candados; no enviar por fuera de ellos |
| Telegram | `addons/telegram_gateway`, `addons/l10n_ec_notification_base/models/notification_dispatcher.py:501` | Canal de texto existente. El dispatcher rechaza adjuntos y no envía texto si se pretendía adjuntar un documento |

## Impresión y envío: preservar el proceso real

- La lista específica activa de Caja sustituye a la general; no se mezclan ambas.
  Si no hay lista específica, se consulta la general de compañía. Si no hay líneas
  resueltas, el código usa impresoras del informe cuando éste se proporciona.
- El orden viene de `sequence, id`; Orbi no inventa otra prioridad.
- `_resolver_para(..., records=...)` recibe el documento real. **No es una consulta
  inocua**: puede despachar WhatsApp durante su ejecución. No invocarlo para pintar
  menús ni descubrir capacidades. Su uso externo requerirá contrato público seguro;
  no llamar métodos privados directamente desde Flutter.
- Impresión: Odoo entrega los trabajos; el cliente ejecuta el transporte compatible.
  Los otros despachos se realizan en servidor. Distinguir trabajo generado,
  entregado al transporte, fallo y confirmación disponible; no afirmar salida física
  sin evidencia de la impresora.
- WhatsApp exige informe `qweb-pdf`; no mandar una tirilla raw como documento.
  `copias` no multiplica mensajes. Conservar destinatario/documento y resultado real.
- **Telegram no está acreditado como tipo de salida de Caja**: no se encontró
  `_despachar_telegram`. Notificar por texto no equivale a enviar el comprobante.
  Para PDFs Telegram se necesitaría ampliar primero el módulo Odoo, en otra tarea
  autorizada; no resolverlo con un bot nuevo en Orbi.
- Imprimir/reimprimir o reenviar no vuelve a confirmar la venta ni registra otro cobro.
  Antes de reintentar un envío con resultado incierto, consultar su estado; no
  atribuir idempotencia de extremo a extremo a canales donde no fue comprobada.

## Contrato de capacidades a definir antes de implementar

Contrato propuesto, **no API existente verificada**: Odoo entrega capacidades
efectivas para servidor/BD/empresa/usuario, sin secretos. Debe separar disponibilidad
del módulo, configuración, autorización y compatibilidad de la operación.

1. Al autenticar/cambiar empresa o usuario, consultar capacidades efectivas.
2. Orbi muestra Asistente/Imprimir/WhatsApp/Telegram únicamente donde corresponda.
3. Instalado pero sin configurar: explicar motivo al usuario autorizado; no ofrecer
   configurar credenciales en una pantalla operativa al cajero/vendedor.
4. Ausente/no autorizado: ocultar la acción; el servidor también debe rechazarla.
5. Al ejecutar, revalidar documento, empresa, destinatario y permisos en Odoo.
6. Invalidar contexto al cambiar usuario/BD; no reutilizar historial privado ni
   capacidades del anterior. PIN continúa limitado a ventas, incluso para supervisor.
7. Revalidar tras cambios de módulos/configuración; la caché no concede privilegios.

La UI puede tener un adaptador al contrato de Odoo, pero no otro catálogo de agentes,
herramientas, proveedores o políticas comerciales. La IA opera con las herramientas
autorizadas del agente Odoo, auditadas y con confirmación sensible conforme al contrato.
No habilitar herramientas financieras sólo porque `ai` esté instalado.

## Comportamiento offline

- No llamar IA remota ni asegurar envíos WhatsApp/Telegram estando desconectado de Odoo.
- Mostrar disponibilidad/desconexión; no recurrir a proveedores externos alternativos.
- Impresión local únicamente si existen documento/trabajo y configuración autorizada
  disponibles offline y un transporte compatible. Si faltan, conservar el resultado
  de venta/cobro y mostrar impresión pendiente, no regenerar la transacción.
- Una cola futura de intenciones de envío requerirá contrato de deduplicación,
  permisos y destinatario revalidados; no se da por implementada con este documento.
- Una respuesta IA nunca continúa bajo otro usuario tras un cambio de sesión.

## Efecto en menú, avisos y diseños

- Cabecera: Asistente condicional. Sin módulos IA, no icono vacío ni contratación externa.
- Documento/resultado: salidas efectivas con destinatario, formato y resultado por canal.
- Avisos internos de Orbi (error de entrada, guardado local, conexión) siguen siendo UI
  local; no requieren WhatsApp/Telegram ni se confunden con envíos externos.
- Ajustes: información de capacidades de Odoo; gestionar módulos/cuentas donde ya
  corresponda en Odoo, con sus permisos.
- Las imágenes aprobadas mantienen su aprobación. Los controles de estas capacidades
  y sus estados condicionales necesitan ampliación visual explícita antes de implementar;
  no fingir que están dibujados en todas las láminas de round-02.

## Criterios de aceptación futuros

- Sin módulo instalado no aparece la función ni existe fallback externo.
- Instalado sin configuración/permisos no permite ejecutar; la causa es comprensible.
- Una misma operación conserva documentos, autoría y políticas existentes de Odoo.
- PDF WhatsApp usa el documento real; Telegram no declara entregado un PDF no enviado.
- Fallo de salida no repite el cobro; impresión física no se declara por generar bytes.
- Cambio de usuario/empresa desconecta contexto anterior y vuelve a validar capacidades.
- Validación por plataforma/transporte pendiente: estos hallazgos de fuente no prueban
  que la integración ya funcione en desktop, web, iPad o teléfono.
