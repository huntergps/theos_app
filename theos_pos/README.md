# Orbi ERP (`theos_pos`)

Aplicación Flutter offline-first de venta, cobro y facturación para Odoo 19.x
y 20.x mediante JSON-2. El paquete contiene la UI, la composición Riverpod y
los shells de plataforma; el dominio y la persistencia viven en
`theos_pos_core`, y la integración Odoo en `odoo_sdk`.

La fuente de verdad del producto es
[`docs/specs/PROJECT_COMPLETION_V1.md`](../docs/specs/PROJECT_COMPLETION_V1.md).
Para preparar una estación use el
[runbook de instalación](../docs/runbooks/INSTALLATION.md); para generar
artefactos use el [runbook de release](../docs/runbooks/RELEASE.md); para
incidentes de sincronización use el
[runbook offline](../docs/runbooks/OFFLINE_SUPPORT.md).

Desde la raíz del repositorio:

```bash
make deps
make verify
make run-macos
```

Web requiere introducir la clave API en cada nueva sesión del navegador. Los
builds release no incorporan claves, certificados ni configuración secreta.
