# theos_pos_core

Paquete Dart de dominio y persistencia para Theos App. Soporta el alcance
vigente de Odoo 19.x/20.x mediante los contratos JSON-2 de `odoo_sdk`.

Contiene:

- modelos Freezed y mapeos de campos Odoo;
- esquema y acceso local Drift;
- managers concretos basados en `OdooModelManager<T>` de `odoo_sdk`;
- servicios puros de negocio, totales, impuestos, sync e idempotencia.

No contiene UI Flutter ni credenciales. El shell Flutter y los adapters de
plataforma viven en `theos_pos`.

## Desarrollo

Desde este directorio:

```bash
dart pub get
dart run build_runner build
dart analyze
dart test
```

No edite fuentes generadas. El proyecto es una instalación limpia en
desarrollo: los cambios de esquema se validan creando una base nueva y no
mantienen compatibilidad con instalaciones antiguas.

Consulte la
[especificación del producto](../docs/specs/PROJECT_COMPLETION_V1.md) y los
[runbooks](../docs/runbooks/INSTALLATION.md) para el flujo completo.
