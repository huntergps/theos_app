# Análisis histórico archivado

El análisis anterior del SDK mezclaba nombres y capas que fueron consolidados.
Se retiró para evitar que contradiga el contrato vigente.

Actualmente `odoo_sdk` es el paquete unificado para Odoo 19.x/20.x: expone el
transporte JSON-2, `OdooClient`, capacidades, managers y primitivas offline. La
fuente normativa es
[`PROJECT_COMPLETION_V1.md`](../docs/specs/PROJECT_COMPLETION_V1.md), y el
código/pruebas del paquete son la evidencia ejecutable.

El contenido anterior puede consultarse en el historial Git para análisis
forense, pero no debe usarse para añadir endpoints, dependencias o protocolos.
