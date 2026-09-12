# W04 — El navegador también guarda, igual que el escritorio

> **Este documento REVOCA la parte de `W02-web-clave-api-pegada.md` y de
> `W03-web-usuario-y-contrasena.md` que daba por buena una credencial que no
> sobrevive a la recarga, por orden del dueño del 11-sep-2026:**
>
> > *«yo he dicho que navegador también guarda igual que escritorio»*
>
> No se rediscute. Lo que este documento decide es **cómo** se cumple, porque
> «igual que escritorio» es una garantía, no un mecanismo.

Estado: **implementado y medido en un Chrome real** (sección 4).

## 1. Qué queda revocado, con precisión

| Dónde | Lo que decía | Estado |
|---|---|---|
| `W02` §«Lo que falta», punto 2 | «Hace falta un `CredentialBackend` **en memoria** y usar `CredentialDurability.webSessionOnly`» | **Revocado.** En memoria no sobrevive a un F5, y eso ya no es aceptable |
| `W03` §4, encabezado | «No hay caja fuerte del sistema» | **Revocado en parte.** No hay llavero, pero sí existe algo con una garantía comparable: una llave **no extraíble** |
| `W03` §4, postura recomendada | «Clave acotada en IndexedDB/`localStorage` — la lee cualquier script de nuestro dominio» | **Revocado como única opción.** Esa frase describe el mecanismo por omisión del paquete, no el único posible |
| `W03` §5, punto 2 | Respaldo de `localStorage`/IndexedDB con `webSessionOnly` | **Revocado.** `webSessionOnly` es justo lo que el dueño descartó |

Lo que **no** se revoca de `W03`: el dominio propio, el bearer sin cookies, y que
el dominio propio aísla mejor el secreto que el dominio de Odoo. Todo eso sigue en pie
y de hecho refuerza lo de abajo.

## 2. Las tres opciones, con lo que cada una aguanta

| Opción | ¿Sobrevive a un F5 y a cerrar el navegador? | Ataque: equipo robado o perfil volcado | Ataque: guion inyectado en la página (XSS, extensión) | ¿La llave es legible por el código? |
|---|---|---|---|---|
| **A. Almacén local con la llave al lado** — `flutter_secure_storage_web` por omisión | Sí | ❌ **No aguanta.** El texto cifrado y su llave AES están en el mismo almacén: quien lee uno lee el otro | ❌ No aguanta | **Sí.** Es la llave bajo el felpudo |
| **B. Llave AES-GCM no extraíble en IndexedDB** ← **elegida** | Sí | ✅ **Aguanta.** La llave nunca existe como bytes en ningún sitio que se pueda copiar. Sin ejecutar código en este origen, el texto cifrado no sirve de nada | ❌ **No aguanta, y hay que decirlo.** Un guion en la página puede *llamar* a `decrypt`. No puede llevarse la llave a otra máquina | **No.** `exportKey` falla en `raw` y en `jwk` |
| **C. No persistir** — lo revocado | No | ✅ Aguanta (no hay nada) | ✅ Aguanta | — |

La diferencia entre A y B es real y medible, no retórica: en A el atacante necesita
**leer un archivo**; en B necesita **ejecutar código dentro de este origen**. Son dos
clases de ataque distintas, y la segunda es mucho más cara.

Lo que B **no** arregla: si alguien logra ejecutar código en nuestra página, la llave
es utilizable por definición y se acabó. Contra eso no protege el almacenamiento, protege
no tener un XSS: cabeceras de seguridad de contenido, y no meter dependencias de terceros
en el origen que sirve Orbi. Eso es trabajo aparte y no lo resuelve este documento.

## 3. Qué se guarda, y aquí corrijo el criterio del encargo

El encargo decía «en el navegador se guarda la clave API de alcance restringido y
revocable, **nunca la contraseña**». La segunda mitad se cumple y la primera mezcla dos
cosas que conviene separar, porque son dos secretos con dos naturalezas distintas:

| Qué | Qué es | ¿Se puede usar contra Odoo si te lo roban? | Dónde se decide |
|---|---|---|---|
| **Derivado de la contraseña** — lo que guarda `WorkspaceUnlockStore` | Un hash con sal e iteraciones. **No es la contraseña y no es una credencial** | **No.** No se puede reproducir contra ningún servidor. Sólo sabe responder «¿es la misma cadena?» | Este documento |
| **Clave API** — la credencial de sesión | Una credencial de verdad, que abre el servidor | **Sí.** Por eso tiene que ser de alcance acotado y revocable | `W02`/`W03`, `_WebSessionAuthService` |

O sea: **el derivado es estrictamente más seguro que la clave API**, porque un derivado
robado no abre nada. «Nunca la contraseña» se cumple de sobra: la contraseña no se guarda
en ninguna parte, ni cifrada.

**Y el respaldo que construí es genérico.** `WebCryptoCredentialBackend` implementa
`CredentialBackend`, el mismo contrato que usa `CredentialStore` para la clave API. Quien
cierre `W02`/`W03` no tiene que escribir otro: enchufa este mismo y **desaparece la
necesidad de `CredentialDurability.webSessionOnly`**. Lo dejo recomendado, no hecho: la
persistencia de la sesión web es de esos documentos, no de este.

## 4. Lo que está medido, no supuesto

`test/web/web_crypto_key_guarantee_test.dart`, en un Chrome real
(`flutter test --platform chrome test/web/`). No prueba nuestro código: prueba **la
garantía de la plataforma** de la que nuestro código depende, para que si un navegador
futuro deja de respetar `extractable: false`, se caiga la prueba en vez de evaporarse la
garantía en silencio.

1. Una llave AES-GCM de 256 bits creada con `extractable: false`.
2. El **objeto** de la llave guardado en IndexedDB — no sus bytes, que no existen.
3. Cerrada y reabierta la base: la llave vuelve, y vuelve no extraíble.
4. Sigue cifrando y descifrando.
5. **`crypto.subtle.exportKey` falla, tanto en `raw` como en `jwk`.**

Y sobre nuestro propio respaldo, `test/web/web_crypto_unlock_backend_test.dart`:
escribe/lee/borra; lo persistido **no contiene el texto en claro ni su base64**; cada
escritura usa un vector de inicialización distinto, así que el mismo valor nunca se ve
igual dos veces; otra instancia sobre la misma base lo lee (sobrevive a recargar); otra
base no lo lee; un registro manipulado **no se descifra y se descarta**, nunca devuelve
basura como si fuera válida; el desbloqueo sin conexión funciona en el navegador igual
que en el escritorio; y el derivado desaparece al cerrar sesión.

**Lo que NO está medido:** sólo se ha corrido en Chrome. Safari y Firefox implementan las
dos normas, pero no lo he comprobado con mis manos y no lo voy a afirmar. Safari además
borra el almacenamiento de sitios poco visitados a los siete días, lo que en ese navegador
convierte esto en «dura una semana sin usarse». Hay que medirlo antes de prometer paridad
en Safari.

## 5. Cuándo se borra

| Cuándo | Quién lo hace |
|---|---|
| Al cerrar sesión y al cambiar de usuario | `AuthNotifier.close()`, el único camino detrás de las dos salidas |
| Cuando el servidor acepta **otra** contraseña | `attemptWorkspaceUnlock` reemplaza el derivado en el acto |
| Cuando el registro no se puede descifrar — manipulado, o escrito bajo una llave anterior | El propio respaldo lo descarta al leerlo |
| Cuando el usuario borra los datos del sitio | El navegador se lleva la llave; todo registro queda ilegible y se trata como «no hay nada» |

Falta una, y es deuda declarada: **cuando el servidor rechaza la credencial.** Hoy un
rechazo autoritativo del servidor no borra el derivado, a propósito, porque un dedo
equivocado en línea también es un rechazo y borrarlo dejaría sin desbloqueo sin conexión a
un usuario legítimo por una errata. Distinguir «contraseña mal escrita» de «credencial
revocada» exige que el servidor lo diga con claridad, y eso es trabajo de
`login_failure_messages.dart`, que otro agente acaba de escribir. Cuando eso esté, esta
regla se puede cerrar bien.

## 6. Lo que no se arregla aquí

**El llavero de macOS, y es peor de lo que escribí en la primera versión de este
documento.** Dije que afectaba solo a la distribución. **Es falso, y lo corrijo con una
medición mía del 11-sep-2026 sobre un macOS de depuración real:**

```
[WARN] [WorkspaceUnlock] Desbloqueo sin conexión INACTIVO: el almacén seguro rechazó
la escritura. La pantalla de bloqueo seguirá exigiendo red (PlatformException(Unexpected
security result code, Code: -34018, Message: A required entitlement isn't present.)).
```

Con el confinamiento **apagado**. `remember()` devuelve `false` y `verify()` responde
`notEnrolled`: **en macOS el desbloqueo sin conexión no existe hoy, ni en depuración ni en
distribución**. No es un problema de durabilidad, es que nunca llega a guardarse.

La causa está verificada contra los registros de `secd` del propio sistema (comentario de
`macos/Runner/DebugProfile.entitlements`): `secd` exige un `keychain-access-group` para
**cualquier** llamada a Keychain Services desde un binario de firma improvisada, con o sin
confinamiento, y con `usesDataProtectionKeychain` en verdadero o en falso. **No hay arreglo
por código.** Hace falta un equipo de firma de Apple. Queda registrado como bloqueante, y
no solo de distribución.

Consecuencia que conviene tener presente: **en macOS, hoy, el único desbloqueo sin conexión
que funciona de verdad es el del navegador** — el de este documento. Lo cual es irónico y
vale la pena decirlo, porque la postura revocada era justamente que el navegador no podía
guardar nada.

La constancia en el registro (sección anterior) es lo que convierte esto en un hallazgo en
vez de un misterio: sin esa línea, el desbloqueo sin conexión habría estado muerto en macOS
sin que nadie se enterara.

Lo que sí se arregló es que **no sea silencioso**: cuando el almacén rechaza guardar, queda
constancia en el registro de la aplicación diciendo que el desbloqueo sin conexión quedó
inactivo y por qué, sin el secreto dentro
(`WorkspaceUnlockStore._reportUnavailable`, probado en
`test/features/auth/workspace_unlock_store_test.dart`). Al usuario no se le avisa: no puede
hacer nada con un problema de permisos de firma, y un diálogo sería ruido.

## 7. Las pruebas de navegador no están en la compuerta

`make verify` corre `flutter test`, que usa la máquina virtual de Dart, y las pruebas de
`test/web/` llevan `@TestOn('browser')`: **ahí se saltan**. Hay que añadir un objetivo que
las corra con `--platform chrome` o esta garantía no la vigila nadie. El `Makefile` no es
mío; lo dejo pedido.
