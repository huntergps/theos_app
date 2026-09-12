# Orbi ERP · preparación de `theos_panel`

Fecha: 2026-09-11. Estado: **construcción avanzada y pausada; sin certificar contra ERP2**.

El dueño autorizó preparar la nueva aplicación y el sistema de notificaciones,
aprovechando `theos_pos` sin hacer que una aplicación dependa de la otra. Ese
trabajo ya está mayormente construido: la app existe, compila y tiene pruebas
propias. Lo que este directorio **no** certifica es la integración funcional
contra ERP2, la regresión en las seis plataformas ni ningún despliegue.

El estado operativo del día a día vive en el handoff más reciente,
`COORDINATOR_HANDOFF_<AAAA_MM_DD>.md`, no en este índice.

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
verificador estructural del plan. El código de la app vive en `theos_panel/` y
en `orbi_runtime/`, fuera de aquí.

Al 2026-09-11, de las 38 tareas de `tasks.json`:

| Estado | Cuántas | Cuáles |
| --- | --- | --- |
| `done` | 32 | Todo `F0*`, `N0*`, `U0*`, y la mayoría de `R0*`/`E0*` |
| `in_progress` | 4 | `E05`, `R06`, `R07`, `B01` |
| `todo` | 2 | `V01` integración ERP2 y regresión · `V02` seis plataformas |

Es decir: el andamiaje, la sesión aislada, las notificaciones y las pantallas
están construidos y con pruebas. Lo pendiente es la paridad fiscal offline
(`B01`) y las dos tareas de validación, que son justamente las que convertirían
esto en algo desplegable. **Ninguna tarea la marca `done` un agente: solo el
integrador, y solo con la evidencia que exige `VALIDATION.md`.**

Validación del paquete de trabajo, desde la raíz:

```bash
python3 scripts/check_orbi_plan.py
python3 scripts/check_orbi_plan.py --ready
```

El primer comando comprueba estructura, referencias y dependencias, **no la app**.
El segundo enumera exclusivamente tareas pendientes cuyos prerrequisitos estén
marcados terminados. La revisión humana del integrador sigue siendo necesaria.

## Por dónde sigue el trabajo

`F01` y el resto del andamiaje ya están cerrados. Lo que queda abierto son las
cuatro tareas en curso y las dos de validación; `--ready` enumera cuáles tienen
sus prerrequisitos cumplidos. El integrador controla dependencias, archivos
compartidos, contratos y evidencia.

Los límites históricos de backend continúan: no tocar producción; propuestas de
traslado de reglas entre addons deben presentarse al dueño antes de aplicarse.
No se necesitan preguntas repetidas para decisiones ordinarias dentro de este plan.
