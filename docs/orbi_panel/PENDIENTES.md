# Pendientes vivos de Orbi

Este archivo existe porque las cosas se estaban perdiendo en la conversación. Lo
que no está aquí, no está comprometido con nadie. Se actualiza en cuanto algo
entra o sale, no al final de la sesión.

Última actualización: 2026-09-11, madrugada.

## Esperan una decisión del dueño

Nada de esto avanza hasta que él responda. No son tareas: son preguntas.

| # | Qué se le pregunta | Por qué importa |
| --- | --- | --- |
| D1 | ¿Encender el listado de bases en ERP2? | Está apagado por configuración. Hasta que se encienda, la base de datos se seguirá escribiendo a mano contra ese servidor, aunque el código ya sepa pedirla |
| D2 | ¿Autorizar la restricción de unicidad sobre el identificador de operación en el servidor? | Es lo único que impediría de verdad duplicar una factura tras un reintento sin conexión. Él ya confirmó que hoy no hay duplicados, que era el requisito previo |
| D3 | ¿Retirar o marcar como no funcional el despliegue web actual? | Lo publicado nunca pudo hablar con un Odoo. Retirar algo publicado es decisión suya |
| D4 | ¿Guardar la credencial en archivo cifrado o arreglar la firma de la aplicación? | Pidió lo primero; la investigación dirá si de verdad protege más o solo es más portátil |

## En construcción ahora mismo

| Frente | Qué entrega |
| --- | --- |
| Desbloqueo sin conexión | Guardar un derivado de la contraseña para poder desbloquear sin red, decisión ya tomada por el dueño |
| Ruta de acceso en el conector | El punto de entrada en `l10n_ec_collection_box_pos` que recibe credenciales y devuelve la clave, aceptando cualquier dominio |
| Mensajes de acceso | Que el error diga la causa real y se presente con el sistema de avisos, no como texto plano |
| Credencial portable | Investigación sobre almacenamiento cifrado uniforme |

## Defectos conocidos y sin arreglar

Ninguno de estos está encargado a nadie. Están aquí para que no se pierdan.

- **Cada acceso fallido deja una credencial huérfana en el servidor.** El
  retroceso borra la copia local y nunca revoca la remota. Hay cuatro de `admin`
  en ERP2 de esta madrugada, sin revocar.
- **La firma de la aplicación en macOS.** Sin equipo de firma ni permiso de
  llavero, el acceso falla al guardar la credencial. Se quitó el confinamiento
  solo en depuración; en distribución el problema sigue entero.
- **Un fallo de conexión se interpreta como falta de red** sin comprobarlo. El
  paquete de conectividad ya está declarado y sin usar.
- **Los conflictos de sincronización llegan vacíos.** El trabajo que los calcula
  solo guarda cuántos hay y descarta el detalle, así que la pantalla nunca los
  puede mostrar.
- **Dos pantallas construidas no están en el menú**: existencias de bodega y el
  centro de turno de caja. Se llega por dirección, no navegando.
- **El kit afirma en un comentario que la interfaz de datos permite una cabecera
  concreta desde otro dominio.** Es falso: lo permite el servidor web que tiene
  delante, no Odoo. Quien lo lea dará por resuelto algo que depende de cada
  instalación.
- **El certificado de ERP2 vence el 2026-11-01** y el componente que lo renueva
  está apagado. Cincuenta días de margen.
- **El enrolamiento del PIN no existe.** El almacén sabe dar de alta un PIN pero
  ninguna pantalla lo invoca, así que hoy nadie puede configurarse uno.

## Trabajo grande, pendiente de prioridad

- **Dieciséis pantallas aprobadas sin código.** Dos son imposibles hoy sin
  trabajo de servidor: cobrar contra varias facturas de un cliente, y el conteo
  físico con aprobación de supervisor.
- **Paridad fiscal.** Nueve decisiones propuestas y seis verificaciones que
  exigen una instancia. Es el único bloqueo formal para cerrar el plan.
- **Recepción y transferencia en bodega** siguen sin decisión de producto sobre
  si deben llevar candado, como sí lo lleva la entrega.

## Reglas de este archivo

Se actualiza al vuelo, no al final. Una promesa hecha en la conversación y no
escrita aquí se considera perdida. Cuando algo se cierra, se borra de aquí y su
evidencia queda en `reports/` o en `decisions/`.
