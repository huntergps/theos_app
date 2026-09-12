# Pendientes vivos de Orbi

Este archivo existe porque las cosas se estaban perdiendo en la conversación. Lo
que no está aquí, no está comprometido con nadie. Se actualiza en cuanto algo
entra o sale, no al final de la sesión.

Última actualización: 2026-09-12, mañana.

## Esperan una decisión del dueño

Nada de esto avanza hasta que él responda. No son tareas: son preguntas.

| # | Qué se le pregunta | Por qué importa |
| --- | --- | --- |
| D2 | ¿Autorizar la restricción de unicidad sobre el identificador de operación en el servidor? | Él tenía razón: **no se pueden emitir dos facturas con el mismo número**, lo impide el propio Odoo y encima el SRI. Pero sí se pueden emitir **dos facturas distintas para una sola venta** tras un reintento, y esa restricción es lo único que lo cierra. No hay que limpiar nada antes: ERP2 tiene cero casos |
| D3 | ¿Retirar o marcar como no funcional el despliegue web actual? | Lo publicado nunca pudo hablar con un Odoo. Retirar algo publicado es decisión suya |
| D5 | ¿La aplicación web se sirve siempre desde el propio dominio del Odoo? | Medido el 12-sep-2026: servida desde ahí, **el problema de dominios distintos desaparece entero** y la lista de bases funciona sin tocar el servidor. ERP2 ya la sirve así desde esta madrugada. Convertirlo en la forma oficial cierra varios frentes de golpe |
| D6 | ¿Se construye una ruta propia para listar las bases desde otro dominio? | **La recomendación es que no.** Ahorra escribir un nombre una vez, y a cambio normaliza en cada instalación un punto de entrada anónimo que enumera bases, justo lo contrario de por qué esa opción está apagada en producción. La aplicación de escritorio ya lo tiene resuelto |
| D4 | ¿Guardar la credencial en archivo cifrado o arreglar la firma de la aplicación? | Pidió lo primero; la investigación (C01) dice que en Windows ya es un archivo cifrado de fábrica, y que el fallo de Mac era un parámetro, no el llavero |

## Resueltas, para que no se vuelvan a preguntar

- **D1 — El listado de bases en ERP2 está encendido** desde el 12-sep-2026. Se
  cambió `list_db` en el archivo propio de esa instancia y se reinició solo su
  servicio. Devuelve una sola base porque el filtro sigue puesto, así que no
  expone las demás instancias del mismo equipo. Ninguna instalación de
  producción comparte ese archivo.
- **D-cert — La renovación automática de certificados NO estaba apagada.** El
  temporizador lleva desde el 3-ago funcionando dos veces al día sin fallar
  una sola vez. La lectura de «apagado» venía de mirar el servicio, que sale
  muerto entre ejecuciones **por diseño**, porque lo dispara un temporizador.
  Premisa falsa, defecto retirado. El de erp2 renueva bien en prueba en seco.
- **Los comentarios del kit sobre el origen cruzado ya dicen la verdad.** Eran
  tres, no uno, y mi propia corrección también estaba incompleta. Lo medido el
  12-sep-2026 por tres vías: Odoo puro **no** abre nada sobre la interfaz de
  datos; un complemento abre el origen; **otro complemento distinto** abre la
  cabecera, y sin ese segundo el navegador rechaza igual aunque el primero
  esté; y **el servidor web de delante no añade nada**, comprobado con un
  preflight que devolvió cero cabeceras. Yo llevaba horas repitiendo que las
  ponía él.
- **Las dos pantallas ausentes y el alta de PIN, cerradas.** Existencias de
  bodega era peor de lo descrito: **no tenía ni ruta**, no se llegaba ni
  escribiendo la dirección. El centro de turno sí la tenía pero ningún menú
  apuntaba a él. Y el alta de PIN ya vive en Configuración, dentro de
  Seguridad, sin subir de capacidades de vendedor. **Lo que más vale de esa
  entrega es la vigilancia nueva**: la prueba existente comprobaba que algún
  permiso abriera cada ruta, nunca que algún menú apuntara a ella. Ahora
  comprueba las dos cosas, verificada en rojo antes que en verde.
- 🟢 **El llavero de macOS funciona, y con él el desbloqueo sin conexión.** La
  causa era que el proyecto no usaba la cuenta de firma que sí existía. Con el
  equipo puesto y el permiso de llavero declarado, el acceso nativo completa y
  el derivado **sobrevive a cerrar y reabrir la aplicación**, medido con dos
  procesos distintos. Se refutaron cuatro hipótesis por el camino, tres mías.
- 🟢 **Se entra desde el navegador con usuario y contraseña**, medido desde un
  dominio ajeno y no desde el fácil. La credencial dura un día exacto y quien
  entra llega al escritorio con pedidos, productos, clientes y facturas
  legibles. Falta solo la comprobación visual en pantalla.
- **El navegador sí guarda credenciales.** Orden del dueño del 11-sep-2026:
  *«yo he dicho que navegador también guarda igual que escritorio»*. Revoca la
  parte de `W02` y `W03` que decía lo contrario. El diseño está encargado y
  quedará escrito en `W04`.

## En construcción ahora mismo

| Frente | Qué entrega |
| --- | --- |
| Desbloqueo sin conexión | Guardar un derivado de la contraseña para poder desbloquear sin red, decisión ya tomada por el dueño |
| Ruta de acceso en el conector | El punto de entrada en `l10n_ec_collection_box_pos` que recibe credenciales y devuelve la clave, aceptando cualquier dominio |
| Mensajes de acceso | Que el error diga la causa real y se presente con el sistema de avisos, no como texto plano |
| Credencial portable | Investigación sobre almacenamiento cifrado uniforme, plataforma por plataforma |
| Guardado en navegador | Llave no extraíble en el almacén del navegador, en vez de dejarla junto al dato |
| Despliegue en navegador | Levantar Orbi en local y medir dónde falla el acceso contra ERP2 |

## Defectos conocidos y sin arreglar

- **La pantalla de acceso por PIN de vendedor existe y es inalcanzable.** Tiene
  código y pruebas propias, y no la invoca nadie: ni el enrutador ni la pantalla
  de acceso. Ahora es más urgente, porque ya se puede dar de alta un PIN y no
  hay puerta que lo consuma.
- **No existe enrolamiento de dispositivo en ningún sitio del monorepo.** El PIN
  identifica una cuenta, no un equipo autorizado. Sin eso, «equipo compartido»
  es una etiqueta de documento y no algo que el sistema aplique o revoque.
- **Ningún lector de código de barras y ninguna impresión conectada**, aunque el
  paquete de impresión ya viaje en el árbol. Ni rastro de cajón de dinero.
- 🔴 **Las cuatro cuentas de prueba tienen la contraseña `12345`** por petición
  del dueño, para poder entrar a mano. La base está expuesta en internet y la
  ruta de acceso es pública. **Cambiarlas y cerrar la lista de orígenes antes de
  publicar nada.**

Ninguno de estos está encargado a nadie. Están aquí para que no se pierdan.

- **Cada acceso fallido deja una credencial huérfana en el servidor.** El
  retroceso borra la copia local y nunca revoca la remota. Hay cuatro de `admin`
  en ERP2 de esta madrugada, sin revocar.
- **Un fallo de conexión se interpreta como falta de red** sin comprobarlo. El
  paquete de conectividad ya está declarado y sin usar.
- **Los conflictos de sincronización llegan vacíos.** El trabajo que los calcula
  solo guarda cuántos hay y descarta el detalle, así que la pantalla nunca los
  puede mostrar.

- **El certificado de erp1 no se puede renovar.** Vence el 2026-11-04. La
  renovación falla porque el servicio de esa instancia está apagado, y sin
  servicio detrás el proxy devuelve error a todo ese dominio, incluida la
  comprobación que exige la autoridad de certificados. Que esté apagado parece
  deliberado, así que **nadie lo enciende sin decidirlo antes**.

## Configuración que falta en ERP2, y probablemente en producción

Medido el 11-sep-2026, solo lectura. **No es código, es configuración**, y por eso
es rápido de arreglar y fácil de olvidar.

- **Ningún diario de venta está marcado como numerado por el cliente** (tres de
  tres). Mientras siga así, toda emisión desde el punto de venta cae por el
  camino que el servidor numera, que es justo el desprotegido ante un reintento.
- **Ninguna configuración de caja tiene diario ni identificador de equipo**
  (cinco de cinco vacías). La exclusividad entre dispositivos existe en el
  esquema pero **está sin estrenar**, porque los índices que la garantizan no
  restringen los valores vacíos.
- Colateral: la aplicación vieja **se niega a emitir sin conexión** mientras
  falte esa marca, así que su camino sin conexión ni siquiera arranca en ERP2.

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
