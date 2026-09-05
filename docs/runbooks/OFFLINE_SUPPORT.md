# Soporte offline y recuperación

La cola offline protege operaciones aptas mediante comandos tipados,
dependencias e idempotencia. Una desconexión no autoriza a borrar datos ni a
repetir manualmente cobros o facturas. Este runbook sigue la fase F5 de
[`PROJECT_COMPLETION_V1_PLAN.md`](../specs/PROJECT_COMPLETION_V1_PLAN.md).

## Información segura para el diagnóstico

Registre antes de intervenir:

- versión de la app, plataforma y hora con zona horaria;
- URL, base y UID/usuario, sin clave API;
- indicador de conexión y última sincronización;
- cantidad y estado de operaciones pendientes, conflictos y cola fallida;
- acción que estaba en curso y si la app se cerró durante la sincronización;
- logs saneados, sin headers, tokens, documentos fiscales ni datos personales.

No copie la base local completa a un ticket sin un procedimiento autorizado de
protección de datos.

## Recuperación normal

1. Detenga nuevos cobros o confirmaciones en ese dispositivo.
2. Restablezca una red estable y confirme que el health check vuelve a online.
3. Use **Sincronizar** una sola vez y espere su resultado.
4. Revise **Cola Offline**. Las operaciones interrumpidas en `processing`
   deben recuperarse como trabajo pendiente al reiniciar la app.
5. Verifique en la app y en Odoo si la orden, pago o factura ya existe antes de
   intentar otra acción. La misma intención debe conservar su clave
   idempotente.

Cerrar la ventana normalmente conserva la sesión y el scope local. **Salir** o
una expiración realizan teardown de sesión; no los use como método genérico de
reparación.

## Conflictos y cola fallida

Las pantallas de diagnóstico aparecen para usuarios autorizados al habilitar
modo desarrollador:

- **Conflictos de Sync** (`/conflicts`): compare el valor local y el del
  servidor. Elija local o servidor solo con evidencia del resultado correcto.
- **Cola Fallida** (`/dead-letter-queue`): corrija primero la causa permanente
  (permiso, dato inválido, método/capacidad ausente) y luego use el reintento
  manual.

No use **Vaciar**, **Eliminar** o **Limpiar cola** durante un incidente sin
exportar/registrar primero la evidencia y obtener autorización. Eliminar una
fila no revierte una escritura que Odoo ya haya aceptado.

## Casos frecuentes

| Síntoma | Acción |
| --- | --- |
| La app muestra offline, pero hay Internet | Compruebe HTTPS/DNS y el endpoint JSON-2; no pruebe `/web/session/authenticate`. |
| Web muestra un error de red tras 401 | Ingrese de nuevo una clave válida; los errores HTTP pueden quedar ocultos por CORS. |
| Reinicio dejó una operación procesando | Reinicie una vez, deje que startup recovery la reprograme y sincronice. |
| Hay conflicto | Resuélvalo en la pantalla de conflictos; no edite simultáneamente el mismo registro en otro dispositivo. |
| La operación cayó en dead-letter | Corrija la causa, verifique si Odoo ya la aplicó y recién entonces reintente. |
| Cambió de servidor o usuario | Confirme el scope activo antes de sincronizar; los datos no deben mezclarse entre scopes. |

## Escalamiento

Escalone si el estado no cambia después de una recuperación normal o si el
resultado financiero es ambiguo. Incluya los datos saneados anteriores, el ID
local de operación, modelo/método, número de intentos y timestamps. No incluya
la clave API.

Una discrepancia de orden, pago o factura requiere reconciliación controlada;
no se resuelve borrando la instalación. Como el proyecto aún no ha sido puesto
en producción, cualquier reset durante desarrollo debe ser explícito y se
valida como instalación limpia, nunca como una migración de datos antiguos.
