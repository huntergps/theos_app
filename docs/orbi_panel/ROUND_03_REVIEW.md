# Ronda 03 — Experiencia transversal

Estado: **seis láminas aprobadas**. Fecha: 10/09/2026.
SHELL-01, ALERT-01 y ALERT-02: aprobadas en las versiones abiertas en Vista Previa;
originales en `visual_baselines/approved/round-03/`.
CONT-01, OUT-01 y AI-01: aprobadas tras abrirlas en Vista Previa y recibir
«aprobado, que mas falta?». Revisiones posteriores no heredan aprobación.
Esta ronda complementa, no sustituye, las 33 láminas aprobadas de round-02.
No autoriza desarrollar ni modificar Odoo.

## Láminas

| ID | Propuesta | Imagen |
|---|---|---|
| SHELL-01 | Menú multirrol, cabecera, servidor, BD y hora del servidor | [Abrir](visual_baselines/proposed/round-03/SHELL-01.png) |
| ALERT-01 | Avisos en Orbi, validación, banner y centro de actividades | [Abrir](visual_baselines/proposed/round-03/ALERT-01.png) |
| ALERT-02 | Avisos del dispositivo, permisos y privacidad | [Abrir](visual_baselines/proposed/round-03/ALERT-02.png) |
| CONT-01 | Borradores, foco, búsqueda inline y cambio de usuario | [Abrir](visual_baselines/proposed/round-03/CONT-01.png) |
| OUT-01 | Vista previa, impresión y canales habilitados en Odoo | [Abrir](visual_baselines/proposed/round-03/OUT-01.png) |
| AI-01 | Asistente opcional de Odoo y límites de contexto | [Abrir](visual_baselines/proposed/round-03/AI-01.png) |

Cada lámina propone escritorio, iPad horizontal, iPad vertical y teléfono.
No son pruebas de funcionamiento ni una implementación. Los datos son ficticios.
El texto contractual prevalece sobre cifras, estados comerciales o detalles
incidentales de las imágenes generadas. No se aprobarán funcionalidades nuevas
por aparecer incidentalmente en una ilustración.

## Qué revisar

- Menú autorizado conjunto, sin cambio de perfil para acceder a otro rol.
- Pie persistente en pantallas anchas y detalle compacto en vertical/teléfono.
- Diferenciar conexión, operaciones pendientes y antigüedad de hora del servidor.
- Avisos sin robar foco ni exponer datos privados en la pantalla bloqueada.
- Cambio de usuario sin perder borradores ni transferir su autoría.
- Reintentar una salida de documento nunca repite el cobro.
- IA y canales externos sólo cuando existen y están habilitados en Odoo.

## Especificación y límites

[SHELL_AND_INTERACTION_SPEC.md](SHELL_AND_INTERACTION_SPEC.md) define navegación,
estados, interacción y continuidad. [ODOO_OPTIONAL_CAPABILITIES.md](ODOO_OPTIONAL_CAPABILITIES.md)
registra la evidencia del código y los límites de las integraciones existentes.

Faltan validar los bindings concretos, permisos efectivos, capacidades de cada
plataforma y entrega de notificaciones con la aplicación cerrada. No se afirma
que las láminas resuelvan esas validaciones. Las variantes oscuras completas
de los cuatro tamaños no están incluidas en esta ronda.

Generación: skill imagegen, herramienta integrada. Prompts y procedencia se
conservan en `visual_baselines/proposed/round-03/generation.json`.
Los originales aprobados no se sobrescriben. Una futura aprobación debe
registrarse por ID y copiar los mismos bytes al directorio `approved/round-03/`.
