# Instrucciones para los agentes de Orbi

Estas instrucciones aplican a este directorio. Para implementación fuera de él,
el integrador debe incluirlas expresamente en el encargo junto con los AGENTS.md
aplicables a cada ruta. El dueño autoriza usar agentes baratos en tareas acotadas.

## Modelo de trabajo

- Integrador/cerebro: arquitectura, contratos, cambios de esquema, dependencias,
  revisión de transacciones/permisos y validación de evidencia.
- Mano de obra, y esta es la autoridad sobre el reparto: el modelo se elige por el
  tipo de trabajo, nunca por prisa. `sonnet` para producir con criterio medio sobre
  terreno ya fijado, como implementar contra un diseño dado, redactar specs o probar
  por pantalla. `haiku` sólo para comprobar sin criterio: contar, extraer, cotejar,
  correr un comando y traer la salida. Nunca `haiku` para juzgar si algo está bien.
  Lo que exige decidir qué está bien no se delega: se queda con el integrador.
- Hasta tres agentes simultáneos además del integrador cuando haya tres tareas
  independientes listas. Cada agente se cierra en cuanto entrega y se le firma el
  encargo; no se dejan vivos «por si acaso».
- No delegación recursiva. Escalar dificultad al integrador con un hallazgo
  concreto; no ampliar el modelo ni repetir auditoría completa por iniciativa.
- Encargos sin historial completo: objetivo, ID, rutas, documentos necesarios,
  dependencia integrada y verificación. Sin secretos ni cuentas reales en prompts.

## Comienzo de tarea

1. Integrador revisa `tasks.json` completo. `python3 scripts/check_orbi_plan.py
   --ready` sólo lista `todo` con prerrequisitos cumplidos, así que devuelve
   vacío mientras el trabajo vivo esté en `in_progress`: vacío no es «no hay
   trabajo».
2. Selecciona tareas sin conflicto de archivos. `writes` marca propiedad amplia;
   antes del trabajo fijar hasta cinco archivos manuales concretos por subtarea.
3. Scaffold de plataforma y generación pueden producir más archivos mecánicos;
   un único propietario los genera y reporta. Dividir extracción grande antes
   de lanzarla, manteniendo contratos y dependencias.
4. Leer SPEC y el documento específico; no cargar todo el repositorio.
5. Cambiar estado a `in_progress` mediante el integrador. Los agentes no editan
   tasks.json, locks, exports globales, CI o contratos compartidos salvo encargo.

## Propiedad

- Integrador: `pubspec.yaml`, lockfiles, `tasks.json`, migración/versionado Drift,
  exports compartidos, router raíz y CI. Puede designar un ejecutor exclusivo.
- UI base: `theos_panel/lib/ui/`, `app/theme/`; no servicios financieros.
- Runtime: `orbi_runtime/lib/src/`; no imports de apps ni librerías visuales.
- Features: solo carpeta asignada y sus tests; consumir contratos integrados.
- Notificaciones: separar persistencia N02, plugin N03, UI N04 para poder
  trabajar después en paralelo sin modificar la misma tabla o interfaz.

Todos comparten filesystem. Usar rutas disjuntas o worktrees explícitos. No
revertir cambios ajenos, no commits sobre archivos de otro agente. El integrador
es quien integra cambios y resuelve conflictos de contratos.

## Skills por tarea

- Diseño/galería: flutter-design + flutter-adaptive-ui; accessibility para revisión.
- Runtime/providers: flutter-riverpod-expert cuando se cambie Riverpod.
- Persistencia: flutter-working-with-databases cuando se cambie Drift.
- Interacciones específicas: apple-design solo si beneficia el componente.
- Addons: skill stack-odoo del proyecto Odoo, leída por quien actúe; respetar
  aprobación de cambios backend. Ninguna tarea de UI tiene implícita esa autoridad.

No usar versiones o código de ejemplo de una skill sin contrastar la API resuelta.
Las decisiones actuales del dueño prevalecen sobre ejemplos históricos.

## Plantilla de encargo

```text
Tarea <ID> de docs/orbi_panel/tasks.json.
Modelo Luna, sin subdelegación. Objetivo: <resultado observable>.
Lee AGENTS aplicables, SPEC y <secciones relevantes>.
Prerrequisitos integrados: <IDs + evidencia>.
Edita solo: <hasta cinco archivos manuales>. Referencias: <rutas concretas>.
No edites locks/esquema/contratos/otras apps fuera de esta asignación.
Aceptación: <copiar criterios de tarea>.
Verifica: <comandos concretos, sin suites irrelevantes>.
Entrega diff + reports/<ID>.md: hechos, comandos, resultado y pendientes.
Si el contrato no alcanza, informa antes de crear una API paralela.
```

## Coste y evidencia

Reutilizar contratos, fixtures y pruebas; no crear mocks que solo devuelven éxito
para acreditar integración. Reportes <=50 líneas salvo evidencia necesaria.
No expandir tareas a «revisar todo». Después de dos intentos fallidos con la misma
causa, comunicar diagnóstico al integrador para resolverlo; no ocultar el fallo.

Ningún agente marca el objetivo global completo. `done` exige revisión del
integrador. No lanzar tareas dependientes porque otro agente «casi termina».
