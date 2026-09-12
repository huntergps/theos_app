# Se entra a Orbi desde otro dominio, en un navegador de verdad

Fecha: 2026-09-12. Origen del navegador: `http://127.0.0.1:8099`, servido con
`make run-orbi-web`. Servidor: `https://erp2.tecnosmart.com.ec`. Usuario: el
actor de pruebas `seller`.

**El origen es ajeno de verdad.** No es el dominio del Odoo ni una página
servida por él, así que el navegador aplica las reglas de origen cruzado
completas, incluido el preflight.

⚠️ **Quien recogió esta evidencia se cayó antes de escribir su informe**, por un
fallo de conexión, no por un fallo de la medición. Las capturas quedaron en
disco y las leí yo una por una. Lo que sigue es lo que se ve en ellas, no lo que
dijo el agente: no llegó a decir nada.

## Lo que funciona

| Captura | Qué demuestra |
| --- | --- |
| `orbi-web-127001-login-screen.jpg` | La pantalla de acceso carga desde el origen ajeno |
| `orbi-web-127001-db-discovery-cross-origin.jpg` | El descubrimiento de bases funciona **dentro de la aplicación**, no sólo por consola: *«Se detectó una sola base de datos y fue seleccionada»* |
| `orbi-web-127001-dashboard-logged-in.jpg` | Se entra con usuario y contraseña y se llega al escritorio |
| `orbi-web-127001-reload-con-guardar-clave-sigue-dentro.jpg` | **Recargando la página se sigue dentro**, sin volver a escribir la contraseña |
| `orbi-web-127001-reload-sin-guardar-clave-pide-password.jpg` | Sin marcar guardar, la recarga pide la contraseña. El guardado es una elección, no un descuido |

Esto cierra la parte que faltaba de la decisión del dueño de servir desde
cualquier dominio: antes estaba medido el servidor con peticiones directas, y
ahora está medida la aplicación.

## Lo que se ve mal en esas mismas capturas

- 🔴 **Inicio está vacío.** Dice «No hay trabajo pendiente» y nada más. La
  lámina aprobada `ACC-03` tiene cuatro tarjetas de resumen, tres pestañas y una
  tabla filtrable. Es la primera pantalla que ve cualquiera al entrar.
- 🔴 **El pie dice «5 con error».** Cinco operaciones de sincronización fallaron
  y la aplicación no dice cuáles ni por qué. Sin explicación, ese número asusta y
  no sirve.
- 🔴 **«Red sin verificar»** con el punto ámbar. Es el defecto ya fichado: un
  fallo de conexión se interpreta como falta de red sin comprobarlo.
- **«Hora del servidor: Hora del servidor no disponible»** — el valor repetía la
  etiqueta. **Corregido el mismo día**: ahora dice «Hora servidor: sin dato», que
  además es el nombre corto que fija el contrato del pie.

## Lo que esta evidencia NO cubre

No se contaron las peticiones de red al pulsar entrar. Importa porque el fallo
que tuvo el cliente el 11-sep fue hacer **cero peticiones**, y eso se parece a un
fallo de red sin serlo. Que ahora se entre demuestra que hay peticiones, pero no
cuántas ni si alguna falla por el camino.
