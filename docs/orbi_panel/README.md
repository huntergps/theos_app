# Orbi ERP · preparación de `theos_panel`

Fecha: 2026-09-06. Estado: **diseño y plan de implementación preparados; nueva app pendiente**.

El dueño autoriza preparar la nueva aplicación y el sistema de notificaciones,
aprovechando `theos_pos` sin hacer que una aplicación dependa de la otra. Este
paquete de trabajo concreta esa autorización para agentes de implementación.
No certifica los flujos históricos ni un despliegue en ERP2.

## Leer según el trabajo

| Documento | Contenido |
| --- | --- |
| [SPEC.md](SPEC.md) | Alcance, reglas de negocio, prioridades y aceptación |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Paquetes, dependencia, sesión y decisiones técnicas |
| [CONTRACTS.md](CONTRACTS.md) | Contratos entre equipos y estados compartidos |
| [DESIGN.md](DESIGN.md) | Diseño Orbi, mapa de pantallas y componentes |
| [NOTIFICATIONS.md](NOTIFICATIONS.md) | Bandeja persistente, entrega, permisos y limitaciones |
| [EXTRACTION.md](EXTRACTION.md) | Código existente aprovechable y método de extracción |
| [VALIDATION.md](VALIDATION.md) | Comandos, evidencias y matriz de plataformas/flujos |
| [AGENTS.md](AGENTS.md) | Encargos, propiedad de archivos y economía de tokens |
| [tasks.json](tasks.json) | Tareas, dependencias y condiciones de finalización |
| [REPORT_TEMPLATE.md](REPORT_TEMPLATE.md) | Entrega obligatoria de cada tarea |

## Decisión principal

- Producto visible: **Orbi ERP**, conservando el logo existente.
- Aplicación nueva: `theos_panel`, independiente de `theos_pos`.
- Compartir código mediante paquetes; datos, preferencias, cola y credenciales
  separados por aplicación/instalación/servidor/base/usuario.
- Material oficial y componentes Orbi; Expressive es una mejora visual selectiva.
- Flutter para iOS, Android, Windows, Linux, macOS y web.
- Offline-first operativo: vender/cobrar y demás operaciones habilitadas por la
  política local documentada; conservar aprobaciones y candados.
- Notificaciones: inbox local persistente y adaptador del sistema; push remoto
  es una capacidad adicional, no una propiedad del plugin de avisos locales.

## Qué existe y qué todavía no

Este directorio contiene especificación, contratos de diseño, backlog y un
verificador estructural del plan. No contiene una app compilada, contratos Dart
ya integrados, migraciones aplicadas ni un sistema de notificaciones ejecutándose.
Todas las tareas de construcción comienzan en `todo` o `blocked`.

Validación del paquete de trabajo, desde la raíz:

```bash
python3 scripts/check_orbi_plan.py
python3 scripts/check_orbi_plan.py --ready
```

El primer comando comprueba estructura, referencias y dependencias, **no la app**.
El segundo enumera exclusivamente tareas pendientes cuyos prerrequisitos estén
marcados terminados. La revisión humana del integrador sigue siendo necesaria.

## Inicio autorizado para el equipo posterior

Primero `F01` (scaffold y contratos Dart), luego las ramas independientes que
enumere `--ready`. El integrador controla dependencias, archivos compartidos,
contratos y evidencia. No lanzar todas las pantallas a la vez sobre APIs inventadas.

Los límites históricos de backend continúan: no tocar producción; propuestas de
traslado de reglas entre addons deben presentarse al dueño antes de aplicarse.
No se necesitan preguntas repetidas para decisiones ordinarias dentro de este plan.
