# C01 — ¿Archivo cifrado universal en vez del llavero del sistema?

## 🟢 Conclusión, primero: el llavero funciona en las cinco plataformas

**Estado: cerrado el 12-sep-2026.** `flutter_secure_storage` —el paquete que ya se usaba
desde el principio, y que resultó ser el "paquete universal" que pedía el dueño (ver el
malentendido, justo debajo)— funciona hoy en macOS, Windows, Linux, Android e iOS. El
bloqueo de macOS no era el llavero: era que el proyecto compilaba con firma improvisada
teniendo una cuenta de Apple Developer real y activa (`W8V3ANSPKT`) sin usarla. Configurada
la firma y añadido el permiso de grupo de llavero (§4), **otro agente corrió la prueba de
durabilidad del llavero real: cinco de cinco en verde, sin un solo −34018.**

**El envoltorio cifrado que se construyó por el camino (§8) no se conecta en macOS.** Se
queda únicamente como pieza interna del respaldo de Linux sin servicio de secretos (§8.6),
que es donde siempre tuvo sentido y donde no hay alternativa. Un respaldo nativo alternativo
para macOS, ahora que el llavero funciona, se descartó a propósito: **un respaldo que casi
nunca se ejerce es un respaldo que se pudre** — si la firma llegara a fallar en la máquina
de otra persona, debe fallar y verse, no caer en silencio a un mecanismo más débil que
nadie ha probado en meses.

**Este documento no se resume ni se borra.** Es el registro de cuatro hipótesis medidas y
refutadas —el parámetro del plugin, el confinamiento, que no se compilaba Linux, y qué
pedía en realidad el dueño— antes de llegar a la causa real. Vale más como evidencia de que
se midió que como una conclusión sola.

---

Estado original de apertura, para el registro: **para decidir**. Encargo del dueño
(11-sep-2026): *«sobre las credenciales deja en un archivo encriptado un paquete universal
para no usar algo específico como el llavero de Mac»*. Paquetes consultados ese día en
pub.dev, no de memoria.

> ### 🔴 El malentendido que sostuvo todo §8 hasta hoy — aclarado por el dueño, 12-sep-2026
>
> El team-lead leyó el encargo de arriba como "construir un archivo cifrado a mano,
> Argon2id + AES-256-GCM, en todas las plataformas" — y así se lo encargó a este agente en
> §8. **Eso era una lectura suya, no lo que pidió el dueño.** El dueño, preguntado
> directamente, aclaró que **«el paquete universal» al que se refería es `flutter_secure_storage`
> mismo** — el que este documento ya usa desde el §1, el que envuelve
> `FlutterSecureCredentialBackend` desde el principio. Su modelo mental: un solo paquete,
> una sola interfaz, sin necesidad de saber que por debajo usa el llavero en Apple, el
> gestor de credenciales en Windows, el servicio de secretos en Linux, el almacén de claves
> en Android y el navegador en web. **Eso es exactamente lo que §7 ya documentó que existe
> y funciona**, salvo el hueco real: Linux sin servicio de secretos.
>
> **Lo que esto cambia:** no hace falta construir nada nuevo para Windows, Android, iOS ni
> desktop en general — ya lo tienen. El envoltorio de Argon2id + AES-256-GCM que se
> construyó en §8 (con sus vectores publicados y su prueba de unicidad de nonce, que no se
> tiran) **se queda exactamente donde tenía sentido antes de este malentendido: como el
> respaldo interno de Linux sin servicio de secretos** (§8.6), no como sustituto de
> `flutter_secure_storage` en ninguna otra plataforma. Universalizarlo a las cinco
> plataformas — que es lo que este documento estuvo a punto de encargar — queda cancelado.
>
> La respuesta real al encargo del dueño es: **`flutter_secure_storage` ya es el paquete
> universal que pidió; el bloqueo era la firma de macOS (§4), no el paquete.** Arreglada la
> firma, no queda ningún hueco salvo Linux sin escritorio — ver la pregunta cerrada al
> final de §8.

## La respuesta corta, y no es la que se pidió

**Un archivo cifrado no elimina el llavero: lo mueve de sitio.** El archivo necesita una
llave, y la llave tiene que vivir en algún lado. Los paquetes serios que hacen esto en
Flutter —Hive CE y su documentación, `vault_storage`— **guardan esa llave en
`flutter_secure_storage`**, o sea, en el llavero del sistema. El único que no lo hace obliga
al usuario a escribir una contraseña en cada arranque.

~~**Y el fallo de macOS no es culpa del llavero:** es un parámetro del plugin, medido abajo
(§4), que se arregla con una línea y sin cambiar de paquete.~~ **Corregido el 11-sep-2026 por
la tarde: sí es el llavero.** Se probó ese parámetro compilando y ejecutando de verdad, y el
fallo persiste idéntico. La causa es la firma ad-hoc sin cuenta de desarrollador — ver §4, que
quedó marcado como refutado con la evidencia.

**Recomiendo** conseguir la cuenta de firma real y quedarse con `flutter_secure_storage` en
escritorio y móvil (§4, §7); no hay atajo de código. El navegador es el único sitio sin
llavero de verdad, y ahí ya hay decisión tomada (§3). Sobre las demás plataformas de
escritorio y móvil, ver §7: ninguna se libra de depender de un almacén nativo equivalente.

## 1. Los paquetes, medidos en pub.dev

| Paquete | Última versión | Nativo | Cifrado | Veredicto |
|---|---|---|---|---|
| `flutter_secure_storage` | **11.1.1, hace 8 horas** · 4,4k likes · 4,12M descargas | Sí, por plataforma | El del sistema | **Vivísimo.** Es lo que ya usamos |
| `hive_ce` | 2.19.3, hace 7 meses · 564 likes · 957k descargas | **No, Dart puro** | AES-256-CBC | Sano. **Su propia doc dice que guardes la llave en `flutter_secure_storage`** |
| `sembast` | 3.8.10, **hace 36 horas** · 1,2k likes | **No, Dart puro** | El códec que tú pongas | Sano. No trae cifrado: trae el enchufe |
| `cryptography_plus` | 3.0.0, hace 6 meses · 130 pts | No (usa Web Crypto) | AES-GCM, PBKDF2, **Argon2id** | Sano. La pieza que falta para derivar bien. Alternativa: `pointycastle` 4.0.0, Dart puro, 3,52M descargas |
| `vault_storage` | 5.0.0, hace 21 días · **8 likes, 232 descargas** | Hive + `flutter_secure_storage` | AES-GCM 256 | **Descartar por tracción**, pero mírale el diseño: es exactamente el híbrido |
| `get_secure_storage` | 1.0.5, **hace 2 años** · 2,24k descargas | Dart puro | AES-128-CTR | **Abandonado. Descartado.** Además AES-128 y llave = contraseña del dev |

Lo que la tabla dice de verdad: **ninguno resuelve el problema de la llave.** `hive_ce` y
`sembast` son buenos contenedores Dart puro —cumplen «universal»— pero los dos te devuelven
la pregunta: ¿con qué llave abro la caja?

## 2. Dónde vive la llave: las cuatro opciones, con su precio

Las dos preguntas de la prueba: **(D)** se llevan el disco; **(O)** otro usuario o programa
del mismo equipo mira.

| | Dónde está la llave | Se llevan el disco (D) | Otro del mismo equipo (O) | Precio real |
|---|---|---|---|---|
| **A. Derivada de la contraseña** | En ningún lado: se recalcula de lo que el usuario escribe | **No pueden leerla** | **No pueden** | Hay que **pedir la contraseña en cada arranque**. Mata el arranque offline desatendido y la caja que abre a las 6am |
| **B. Junto al archivo** | En un archivo al lado, o dentro del binario | **Sí pueden** | **Sí pueden** | Ofuscación, no cifrado. Detiene a quien mire por encima del hombro, a nadie más |
| **C. Híbrido: llave en el llavero, datos en archivo** | Llavero del sistema | **No** (el llavero va atado al equipo y al usuario) | **No** | **Sigue dependiendo del llavero.** Añade piezas sin quitar la dependencia |
| **D. Sólo el llavero (hoy)** | Llavero del sistema | **No** | **No** | Lo que ya tenemos. En Mac exige firma correcta con cuenta de desarrollador real — no hay parámetro que lo evite, ver §4 |

Sin jerga: **A** es la única que protege contra alguien que se lleva el equipo **encendido y
con el usuario abierto**, y cuesta que la cajera escriba su contraseña cada mañana — en un
mostrador compartido entre turnos eso hasta puede ser bueno. **B** no protege de nada que
importe. **C** y **D** protegen lo mismo porque la llave está en el mismo sitio: **C es D con
más código**, y su única ventaja —llevarse los datos a otro equipo— no la necesitamos.

## 3. El navegador es un caso aparte, y ahí sí cambia todo

En navegador **no hay llavero**, y `flutter_secure_storage` guarda ahí su llave AES en
`localStorage` junto al texto cifrado — la opción B de la tabla, ofuscación. Eso ya está
escrito en `workspace_unlock_store.dart`, que por eso devuelve `unavailable` en `kIsWeb`, y
`W02`/`W03` decidieron **no persistir nada en web**. **No se toca.** Si algún día se
persiste, será lo de `W03` §4: una clave API de alcance `rpc` **con caducidad corta y
revocable desde Odoo**, nunca la contraseña.

## 4. 🔴 Causa raíz del fallo de Mac — REFUTADO el 11-sep-2026, ver abajo

`theos_panel/macos/Runner/DebugProfile.entitlements` lleva el diagnóstico escrito: firma
ad-hoc, sin `DEVELOPMENT_TEAM`, sin `keychain-access-groups` → `SecItemAdd` devuelve
**-34018** y el login muere **después** de que el servidor ya aceptó la contraseña. Para
evitarlo se apagó el sandbox en debug, y así debug dejó de parecerse a release.

> ### Lo que se escribió aquí primero (11-sep-2026, de mañana) — **FALSO, medido esa misma
> ### tarde. Queda para que se vea qué se pensó y por qué no aguantó la prueba.**
>
> **Pero hay un arreglo de una línea, y lo verifiqué en el código del plugin instalado**
> (`flutter_secure_storage_darwin` 0.4.0, que es el que resuelve `pubspec.lock`):
>
> ```
> FlutterSecureStorage.swift:228   if #available(macOS 10.15, *), params.usesDataProtectionKeychain {
> FlutterSecureStorage.swift:229       query[kSecUseDataProtectionKeychain] = true
> ```
>
> `MacOsOptions.usesDataProtectionKeychain` está en `true` por omisión
> (`macos_options.dart:24`). **Puesto en `false`, la consulta deja de pedir el llavero de
> protección de datos y usa el clásico de archivo, que NO exige `keychain-access-groups`** —
> justo lo que una firma ad-hoc no puede dar. El CHANGELOG de 0.4.0 confirma que ese parámetro
> pasó a ser condicional precisamente por esto.
>
> Ojo con la trampa que reporta la comunidad: en la versión 9 el parámetro se llamaba
> `useDataProtectionKeyChain` y en la 10/11 `usesDataProtectionKeychain`; escribirlo mal no da
> error de compilación y el síntoma es exactamente ese -34018 «de entitlements». Estamos en 11.
>
> **Lo que esto significa:** *no tenemos evidencia de que el llavero de Mac no sirva*, sino de
> que lo pedimos con la opción equivocada para una app sin firma de equipo. Cambiar de paquete
> por esto sería arreglar el síntoma. En release, con cuenta de desarrollador de verdad, el
> valor correcto vuelve a ser `true`.

**Esto es falso, y se comprobó falso ese mismo día compilando y ejecutando, no leyendo
código nada más.** Un agente aplicó el cambio de arriba (`usesDataProtectionKeychain:
false`), repuso el sandbox en `DebugProfile.entitlements` y corrió `theos_panel` de verdad
en macOS con una prueba de integración contra el llavero real (no mockeado). Resultado:
**sigue fallando, con -34018, exactamente igual.** Y con el sandbox puesto o quitado.

La prueba no se quedó en la excepción de Flutter: se leyó `log show` para ver qué dice el
propio daemon de seguridad del sistema, `secd`, en el momento del fallo:

```
secd: [com.apple.securityd:SecError] Orbi ERP[PID]/1#4 LF=0 delete Error Domain=NSOSStatusErrorDomain
Code=-34018 "Client has neither com.apple.application-identifier nor
com.apple.security.application-groups nor keychain-access-groups entitlements"
```

Ese mensaje es idéntico con el flag en `true` o en `false`, y con o sin
`com.apple.security.app-sandbox`. Es decir: **no es el llavero protegido contra el clásico,
y no es el sandbox.** En esta versión de macOS, `secd` exige una de esas tres entitlements
(`com.apple.application-identifier`, `com.apple.security.application-groups`,
`keychain-access-groups`) para **cualquier** llamada a Keychain Services desde un binario
firmado ad-hoc — protegido o clásico, sandboxed o no. Ninguna de las tres se puede producir
sin una cuenta de Apple Developer con equipo real.

**Lo que esto cambia:** la cuenta de desarrollador de Apple no es un detalle de firma para
distribuir en la App Store — es el bloqueo desde el día uno para que el llavero nativo
funcione en debug, con o sin sandbox. No hay arreglo de una línea. `credential_store.dart`
quedó sin la opción de macOS (revertido a `FlutterSecureStorage()` simple), con un
comentario que enlaza a esta sección para que nadie repita la prueba.

## 5. La mitad del trabajo ya está hecha

`theos_panel/lib/features/auth/secret_derivation.dart` (escrito anoche) ya tiene sal
aleatoria por alta, 10 000 iteraciones HMAC-SHA256, comparación en tiempo constante y formato
versionado. **Es la mitad de la opción A**: sirve para *verificar* un secreto, no para
*cifrar* con él. Faltaría usar el derivado como llave de 32 bytes y poner encima un cifrado
autenticado — `cryptography_plus` con **Argon2id + AES-GCM**, que aguanta un ataque con GPU
sobre un archivo robado mucho mejor que 10 000 rondas de HMAC. Subir ese coste exige antes
sacar el hashing del isolate de UI, cosa que el propio archivo advierte en
`kSecretDerivationIterations`.

## 6. Recomendación

1. ~~**Arreglar Mac primero** (§4): `usesDataProtectionKeychain: false` en debug, devolver
   el sandbox a `DebugProfile.entitlements` y comprobar que el login guarda. Una línea, y si
   funciona **el encargo cambia de motivo**: ya no es «el llavero no sirve» sino «prefiero
   no depender de él».~~ **REFUTADO (§4): no es una línea.** Se probó exactamente ese cambio,
   compilando y ejecutando, con el sandbox puesto y quitado, y el llavero nativo sigue
   fallando igual en debug: `secd` exige una entitlement de firma real
   (`com.apple.application-identifier` o equivalente) para cualquier acceso, y una firma
   ad-hoc no puede darla. La recomendación correcta hoy es: **conseguir una cuenta de Apple
   Developer con equipo** (arregla el llavero nativo de raíz en debug y en release), o
   **aceptar que el login nativo en debug sigue roto** hasta que exista esa cuenta — no hay
   parche de código que lo resuelva. Que el dueño decida entre esas dos, no una tercera de
   "archivo cifrado universal": ver §7, esa opción tampoco depende menos de un almacén nativo
   en las plataformas donde sí hay uno.
2. **Si el dueño igual quiere el archivo cifrado**, la única variante que añade seguridad
   real es **A**, y su precio es escribir la contraseña en cada arranque frío — la misma
   disciplina del PIN de ACC-02. Implementación: `hive_ce` o `sembast` de contenedor (Dart
   puro, cero nativo, web incluida) + `cryptography_plus` (Argon2id → AES-GCM) para la llave.
3. **No implementar C**: es el llavero con más piezas encima, y `vault_storage` demuestra
   que ese diseño acaba dependiendo de `flutter_secure_storage` igual.
4. **Web sigue sin persistir**, por `W02`/`W03`. Eso no lo cambia ningún paquete.

**La frase para el dueño:** *cifrar el archivo no quita el llavero, sólo lo esconde detrás de
una puerta más; la única forma de quitarlo de verdad es que alguien escriba una contraseña
cada vez que arranca el equipo.* ~~Y el fallo de Mac es un interruptor mal puesto, no el
llavero.~~ **Corregido: el fallo de Mac SÍ es el llavero — concretamente, que no hay cuenta
de firma real. No hay interruptor de código que lo arregle; ver §4.**

## 7. Las otras plataformas

Pregunta del dueño, literal: *«¿y qué pasa con las otras plataformas que no tienen un
llavero como la de OSX?»*. Se verificó leyendo el código nativo de cada complemento
instalado (no la documentación de pub.dev), contra las versiones que realmente resuelve
`theos_panel/pubspec.lock`: `flutter_secure_storage_windows` **4.2.2**,
`flutter_secure_storage_linux` **3.0.2**, `flutter_secure_storage_web` **2.1.1**, y el
código Android embebido en `flutter_secure_storage` **11.0.0** (no tiene paquete separado
por plataforma). Un hallazgo tumba una hipótesis previa de este mismo turno; se deja
marcado igual que en §4.

| Plataforma | Dónde acaba el dato | Dónde acaba la llave | Sin almacén del sistema |
|---|---|---|---|
| **macOS** | Llavero (Keychain Services) | — (es el propio llavero) | Ver §4: sin cuenta de firma real, falla siempre, con sandbox o sin él |
| **Windows** | Fichero `<clave>.secure` en la carpeta de datos de la app, AES-**GCM** (autenticado) | Clave simétrica de **16 bytes → AES-128** (no 256), generada al azar con `BCryptGenRandom` y guardada en el Administrador de Credenciales (`CredWriteW`, `CRED_TYPE_GENERIC`, `CRED_PERSIST_LOCAL_MACHINE`, persiste por máquina) | Si `CredWriteW` falla al crear la llave, el código nativo hace `throw std::runtime_error(...)` — y el único `catch` de `HandleMethodCall` es `catch (DWORD e)`, que **no atrapa `std::runtime_error`**. La excepción sale sin capturar del despachador de método del plugin: no le llega a Dart ni una `PlatformException` ni un silencio con dato sin cifrar — lo esperable es que **tumbe el proceso** (excepción de C++ no manejada). No se pudo reproducir en esta máquina (no hay Windows aquí); es lectura directa del código, marcado como tal |
| **Linux** | Depende de si `secret_service_get_sync` logra conectar al Secret Service por D-Bus, dentro de `SecretStorage::warmupKeyring()` | La propia colección por omisión de `libsecret` (gnome-keyring o kwallet, lo que provea `org.freedesktop.secrets` en la sesión) | Dos fallos distintos, no uno solo — **verificado leyendo el código fuente, no la documentación del paquete**: (1) **al compilar**, si faltan las cabeceras: `linux/CMakeLists.txt:15` declara `pkg_check_modules(LIBSECRET REQUIRED IMPORTED_TARGET libsecret-1>=0.18.4)`, y `REQUIRED` aborta la configuración de CMake si `libsecret-1-dev` no está instalado — **la app no llega a construirse**. (2) **al primer guardado**, con las cabeceras presentes pero sin ningún servicio de secretos vivo en la sesión (terminal sin escritorio, o escritorio sin `gnome-keyring-daemon`/`kwallet`): `secret_service_get_sync` devuelve error, `Secret.hpp` lo envuelve en `LibsecretError`, y el `.cc` principal SÍ lo atrapa (`catch (const LibsecretError& e)`) y lo convierte en una respuesta de error normal del canal de método. **Lo que ve el usuario es una `PlatformException` de Dart con código `"Libsecret error"` (o `"KeyringLocked"` si hay un ítem huérfano en otra colección) y el texto del error de D-Bus dentro del mensaje** — no un crash, no un cuelgue, no un silencio. Esta segunda ruta se verificó leyendo `Secret.hpp` completo (los `throw LibsecretError(...)` y los tres `catch` del `.cc`); el texto exacto del error de D-Bus no se pudo capturar en vivo porque este entorno no tiene Linux |
| **Android** | `SharedPreferences`, valor AES-**GCM** en Base64 | Llave AES de sesión envuelta (RSA-OAEP-SHA256) por un par de llaves que **sí vive en el `AndroidKeyStore` real** (`KeyCipherImplementationRSAOAEP.java`, `KEYSTORE_PROVIDER_ANDROID = "AndroidKeyStore"`) — hardware-backed cuando el equipo lo soporta | El `KeyGenParameterSpec.Builder` que crea el par RSA **no llama a `setUserAuthenticationRequired(true)`**. Confirmado leyendo `makeAlgorithmParameterSpec()`: no exige biometría ni PIN para usar la llave, así que **en un equipo sin bloqueo de pantalla configurado sigue funcionando exactamente igual**, sin excepción ni degradación — la protección que pierde ese equipo es la de "alguien con el teléfono desbloqueado en la mano", no la del guardado en sí |
| **Navegador** | `localStorage`, mismo origen | Llave `CryptoKey` AES-**GCM 256** (Web Crypto API), envuelta y guardada **en el mismo `localStorage`**, junto al texto cifrado y al IV | No hace falta almacén del sistema porque no se pretende que lo haya: llave y dato conviven en el mismo sitio (opción **B** de §2, ofuscación). Ya decidido no persistir nada aquí (§3, `W02`/`W03`); esto no cambia con este análisis |

**Sobre el Makefile — se verificó y la lectura previa estaba incompleta.** Se dijo que
existían objetivos para iOS, Android, macOS, Windows y navegador, y **ninguno para Linux**.
Eso es cierto **solo para `theos_pos`** (líneas 95-108 del `Makefile`: no hay
`build-linux`, aunque la carpeta `theos_pos/linux/` existe). **Para `theos_panel` (Orbi) sí
hay objetivo**: `make build-orbi-linux` (`Makefile:80-81`, `flutter build linux --release`).
Y hay más: `.github/workflows/ci.yml:196-228` trae un job real,
`build-orbi-linux-android`, que corre en `ubuntu-latest` con una matriz `[linux,
appbundle]` y ejecuta `flutter build linux --release` sobre `theos_panel`. El hueco de
Linux **no es teórico para Orbi** — hay ruta de build declarada en dos sitios.

Con una salvedad que si vale la pena mirar antes de confiar en ese job: el paso "Install
Linux desktop dependencies" de ese CI (`ci.yml:215-219`) instala
`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev` y **no incluye
`libsecret-1-dev`**, que es justo el paquete que `linux/CMakeLists.txt:15` exige con
`REQUIRED`. Si `ubuntu-latest` no lo trae preinstalado (no es lo habitual), ese job
fallaría en la configuración de CMake, no en el guardado — sería el primer fallo de la
tabla de arriba, no el segundo. **No se pudo confirmar en vivo**: este `ci.yml` no está
registrado todavía como workflow activo en GitHub (`gh api .../actions/workflows` no lo
lista; existe en `main` local pero no en `origin/main`), así que nunca ha corrido de
verdad. Es una alerta fundada en la lectura del propio YAML y del `CMakeLists.txt`, no una
medición — hay que confirmarla la primera vez que ese job se dispare.

**La respuesta corta a la pregunta del dueño:** ninguna plataforma que compilemos hoy deja
la credencial sin cifrar o con la llave al lado del dato **salvo el navegador, y eso ya
estaba decidido y aceptado** (§3). Windows y Android usan almacenes del sistema reales
(Administrador de Credenciales, AndroidKeyStore) exactamente como Mac y Linux. La diferencia
entre plataformas no es "cuál tiene llavero y cuál no": todas excepto el navegador lo
tienen. La diferencia real es **qué le pasa al usuario cuando ese almacén no está
disponible** — y ahí Windows es el peor caso verificado (riesgo de caída del proceso, no
un error manejable) y Linux el mejor manejado (una `PlatformException` legible), con la
condición de tener las cabeceras de `libsecret` en el build.

## 8. Diseño: el envoltorio cifrado — hoy, sólo el respaldo de Linux (12-sep-2026)

Estado: **cerrado, con alcance recortado por el malentendido de arriba.** Se escribió
originalmente pensando en macOS al completo (ver el razonamiento tachado abajo, que se
deja para que se vea qué se pensó y por qué se corrigió). Con la aclaración del dueño —
«paquete universal» = `flutter_secure_storage`, ya en uso— y con la firma de macOS
arreglándose de raíz (§4, cuenta `W8V3ANSPKT` activa), **este envoltorio deja de aplicarse
a macOS**: una vez la firma esté configurada, macOS vuelve a `FlutterSecureCredentialBackend`
igual que Windows, Android e iOS. Lo único que sobrevive de este diseño es §8.6, el
respaldo de Linux sin servicio de secretos — el único hueco real que `flutter_secure_storage`
no cubre por sí solo.

> ~~El dueño ya pidió esto explícitamente —«sobre las credenciales deja en un archivo
> encriptado, busca en pub.dev un paquete universal para no usar algo específico como el
> llavero de Mac»— y §4/§7 acaban de demostrar que tenía razón: en macOS, hoy, con o sin
> sandbox, el llavero nativo no funciona ni en debug ni en release... Esto es el reemplazo
> mientras esa cuenta no exista.~~ **REFUTADO por el propio dueño, 12-sep-2026: el "paquete
> universal" que pedía era `flutter_secure_storage`, no un archivo construido a mano.** El
> razonamiento técnico de §4 sobre la firma seguía siendo correcto — sólo la conclusión de
> "por tanto hay que sustituir el llavero" estaba de más.

### 8.1 Alcance histórico de este diseño — ya NO es sólo macOS, ya NO es macOS en absoluto

Esto **no sustituye** `FlutterSecureCredentialBackend` en ningún otro sitio. Windows y
Android usan de fábrica un almacén de sistema real (§7); iOS también, y además su modelo
de distribución (TestFlight/App Store) obliga tarde o temprano a una firma real, a
diferencia del escritorio de macOS que hoy no la tiene ni en release. Linux tiene su propio
fallo, ya bien manejado (`PlatformException` legible, §7) y no necesita esto. El navegador
lo lleva otro agente (`desbloqueo-offline`, llave no extraíble de Web Crypto) — no se toca.

El punto de conexión real es uno solo: `theos_panel/lib/app/bootstrap.dart:456-458`, donde
hoy se construye `CredentialStore(FlutterSecureCredentialBackend(), durability:
CredentialDurability.secureStore)` para el API key de Odoo. La propuesta es una nueva
implementación de `CredentialBackend` (la interfaz ya existe en
`orbi_runtime/lib/src/auth/credential_store.dart:8-12`, `write`/`read`/`delete`) que se
selecciona en vez de `FlutterSecureCredentialBackend()` según la plataforma — mismo patrón
de fábrica que ya usa `unlock_backend_factory_io.dart` / `_web.dart` para el desbloqueo,
sólo que aquí la elección va dentro de `bootstrap.dart`, no en un archivo `_io` separado de
uno `_web`.

**Corrección del 12-sep-2026, medida por `desbloqueo-offline` antes de aplicar el
fragmento:** esta sección decía `Platform.isMacOS` (de `dart:io`). **Eso compila para web
sin error y truena en tiempo de ejecución** (`UnsupportedError:
Platform._operatingSystem`), porque `bootstrap.dart` construye la rama nativa
incondicionalmente antes de elegir entre `webService`/`service` con `kIsWeb`. El mecanismo
correcto, verificado compilando y ejecutando de verdad (no sólo compilando), es
`!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS` — el guardia `!kIsWeb` es
obligatorio porque un Mac corriendo Chrome también reporta
`defaultTargetPlatform == TargetPlatform.macOS`.

**Y esto entero queda cancelado por el malentendido de arriba.** No se conecta nada de
esto en `bootstrap.dart`: macOS no usa `EncryptedFileCredentialBackend` — usa
`FlutterSecureCredentialBackend()` sin condición de plataforma, igual que Windows, Android
e iOS, en cuanto la firma de §4 esté configurada (ya lo está: equipo `W8V3ANSPKT`). El
párrafo de arriba se deja porque el hallazgo de `desbloqueo-offline` sobre
`Platform.isMacOS` sigue siendo correcto y reutilizable si algún día hace falta
seleccionar por plataforma en `bootstrap.dart` por otro motivo — pero no por éste.

**Un archivo que NO se toca en este encargo, pero que hay que nombrar:**
`unlock_backend_factory_io.dart` hoy devuelve `FlutterSecureCredentialBackend()` para
**cualquier** plataforma nativa, macOS incluido — así que la pantalla de bloqueo offline
(`workspace_unlock_store.dart`, de `desbloqueo-offline`) hoy también está silenciosamente
inactiva en macOS (`_reportUnavailable`, ya lo dice su propio comentario: *"a macOS
keychain without the signing entitlements (SecItemAdd −34018)"*).

~~El backend que aquí se propone, una vez exista, **podría** arreglar ese síntoma también
como efecto colateral.~~ **REFUTADO por `desbloqueo-offline`, 12-sep-2026, y con razón:**
`WorkspaceUnlockStore` sólo necesita *verificar* una contraseña candidata (un `SecretDerivation`
de un solo sentido), nunca *recuperar* un secreto real. Enchufar aquí
`EncryptedFileCredentialBackend` sería circular — para leer el `SecretDerivation` guardado
haría falta descifrar con la MISMA contraseña candidata que se quiere comprobar, y un fallo
de autenticación de AES-GCM llegaría como "nada inscrito" en vez de "contraseña
incorrecta", perdiendo el contador de intentos que es la única defensa real de un derivado
en reposo contra un ataque sin límite de ritmo. No es un efecto colateral gratis: es un
diseño aparte que nadie ha hecho todavía, y no le corresponde a este encargo improvisarlo.
**El desbloqueo sin conexión seguirá muerto en macOS** aunque el llavero nativo vuelva a
funcionar algún día con firma real, salvo que alguien diseñe a propósito una variante de
verificación por descifrado.

### 8.2 La pieza que hay que decirle al dueño sin adornos: **esto mata el arranque desatendido en macOS**

`orbi_runtime`'s `restoreOnce()` (`odoo_sdk`/`orbi_runtime`, invocado "normally cold
start" según su propio comentario) hoy reconecta **sin pedir nada a nadie**: lee el API key
del backend seguro y reintenta, primero en línea y si falla, offline. Esa es la
"conexión desatendida" de hoy en toda plataforma con llavero utilizable.

**Con la llave derivada de una contraseña, `restoreOnce()` ya no puede completar solo.**
No hay contraseña que derivar si nadie la escribió en ese arranque. La única forma de que
el archivo cifrado sirva de algo es que la persona escriba su contraseña **en cada arranque
en frío del proceso en macOS** — con o sin red, porque el archivo cifrado es precisamente lo
que permite un arranque **offline** cuando antes (hoy, roto) no había ninguna forma de
arrancar offline en macOS al no poder guardarse nada.

Dicho de otro modo, y es la frase que hay que llevarle al dueño: **hoy en macOS un cierre y
reapertura del proceso sin red dejaría al operador totalmente bloqueado** (no hay llavero,
no hay red). Con este diseño, ese mismo escenario se resuelve **con una contraseña escrita**,
no con cero interacción. No hay una tercera opción sin inventar un secreto nuevo que
recordar (ver §2 — B es ofuscación, C sigue dependiendo del llavero que aquí ya se probó
roto).

Coincido con tu criterio: es un precio razonable para un mostrador, porque quien abre caja
en la mañana escribe su contraseña de todos modos — pero es una **regresión frente a lo
que hoy funciona en Windows/Android**, y el dueño debe oírlo en esos términos antes de
aprobar, no como "una mejora de seguridad" sin más.

**Sugerencia de bajo costo, no bloqueante:** `CredentialDurability` (`credential_store.dart:112`)
ya distingue `secureStore` de `webSessionOnly`, declarado pero sin consumidor todavía.
Añadir un tercer valor (p. ej. `passwordDerivedFile`) le daría a la capa de UI un lugar
único desde donde decidir si avisar "esta plataforma pide tu contraseña en cada arranque"
en vez de inferirlo por la comprobación de plataforma dispersa por el código.

### 8.3 KDF y cifrado: Argon2id + AES-256-GCM — dos paquetes candidatos, no uno solo

**Reverificado hoy en pub.dev, no de memoria** (la tabla de §1 se consultó ayer; esto la
confirma, no la reemplaza):

| Paquete | Versión hoy | Adopción | Nativo | Argon2id | Veredicto |
|---|---|---|---|---|---|
| `cryptography_plus` | 3.0.0 (sin cambio) | **13 likes, 130 pts, 25,5k descargas** | No por defecto (Dart puro vía `DartCryptography`; `FlutterCryptography` nativo es opcional, para velocidad) | Sí, API de alto nivel (`Argon2id`, `AesGcm`) | Sano técnicamente, **adopción baja** |
| `pointycastle` | 4.0.0 (sin cambio) | **414 likes, 140 pts, 3,52M descargas** | No, Dart puro siempre (puerto de BouncyCastle) | Sí, vía `KeyDerivator('argon2')` + `Argon2Parameters`, API de más bajo nivel (registro por nombre, params manuales) | Sano y **mucho más adoptado**, API más fácil de usar mal (nonce/parámetros a mano) |

**Esta es justo la clase de decisión que no debo tomar callado.** `cryptography_plus` tiene
menos tracción que lo que este mismo documento usó para *descartar* `vault_storage` en §1
(8 likes, 232 descargas) — no está en ese terreno, pero tampoco es cómodo. Mi
recomendación es **`cryptography_plus`** de todos modos, porque su API (`Argon2id(...)`,
`AesGcm.with256bits()`) hace mucho más difícil el error clásico de cifrado casero — reusar
un nonce, mezclar parámetros de KDF a mano — que es exactamente el tipo de bug que no se ve
en un test y sí en producción. Si el criterio del dueño pesa más la tracción del paquete
que la ergonomía de la API, `pointycastle` es la alternativa razonable y ya está
verificado que sirve. Lo decido si nadie contradice esto; si alguien prefiere
`pointycastle`, dígalo antes de que haya código escrito.

Parámetros de partida (a confirmar con una medición de tiempo real en el hardware más
lento que use un mostrador, no adivinados): Argon2id con memoria ≥ 19 MiB, 2 iteraciones,
paralelismo 1 (mínimo recomendado por OWASP para uso interactivo). **Igual que
`kSecretDerivationIterations`** (`secret_derivation.dart:28-32`), esto debe correr fuera
del isolate de UI (`compute()` o isolate propio) antes de subir el costo — no es una
sugerencia, es la misma advertencia que ya existe en ese archivo para otro derivado.

### 8.4 Formato: un archivo por credencial, sin motor de base de datos

**No se usa Hive CE ni Sembast.** `CredentialStore` ya direcciona por
`(appId, scope, reference)` (`credential_store.dart:115-143`) y hoy son pocas entradas por
identidad (el API key, quizá alguna más). Meter un motor de base de datos completo por
esa cantidad de registros reproduce exactamente la pregunta que §2 ya hizo sobre
`hive_ce`/`sembast`: "¿con qué llave abro la caja?" — y la respuesta seguiría siendo la
misma llave derivada, sin que el motor de base de datos aporte nada. El **paquete
universal** que pidió el dueño lo aporta la librería de cifrado (Dart puro, corre en
cualquier plataforma); el contenedor no necesita ser un paquete aparte.

Propuesta de formato, un archivo por `key` de `CredentialStore` (mismo patrón que ya usa
`flutter_secure_storage_windows` con su `<clave>.secure`, §7):

- Ubicación: `getApplicationSupportDirectory()` (`path_provider`), subcarpeta propia.
- Nombre de archivo: hash del `key` ya ofuscado que produce `CredentialStore._key()` —
  nunca el scope en claro, mismo cuidado que ya tiene esa clase hoy.
- Contenido, versionado igual que `SecretDerivation.encode()` (`secret_derivation.dart:105-110`)
  para poder subir el costo de Argon2id sin invalidar lo que ya hay en disco: versión,
  parámetros de Argon2id, sal (16 bytes), nonce de AES-GCM (12 bytes), texto cifrado +
  etiqueta de autenticación.
- **Sin hash de verificación aparte.** A diferencia de `SecretDerivation` (que sólo
  necesita comprobar, nunca recuperar), aquí el AEAD ya es su propia verificación: una
  contraseña equivocada produce una etiqueta que no cuadra, `decrypt()` lanza, y eso se
  trata igual que "contraseña incorrecta". Un segundo hash sería trabajo duplicado.

### 8.5 Lo que este diseño no resuelve, y no pretende resolver

- No evita que alguien con el proceso corriendo y sesión ya abierta pueda ver el API key en
  memoria — ningún diseño de este tipo lo evita; eso es fuera de alcance de C01 desde el
  principio (§2 lo dice: contra un equipo "encendido y con el usuario abierto" sólo protege
  la opción A, y sólo mientras el archivo está cifrado en reposo, no en uso).
- No es una mejora de seguridad neta frente al llavero nativo cuando el llavero nativo
  funciona — es **estrictamente peor en comodidad** (pide contraseña) a cambio de
  **funcionar donde hoy no funciona nada**. La razón de construirlo es que hoy, en macOS,
  la alternativa no es "llavero vs. archivo": es "archivo vs. nada".

### 8.6 Extensión pedida después: Linux sin servicio de secretos — y aquí el diseño cambia de forma, no sólo de alcance

Petición nueva del 12-sep-2026: que esto sirva también para Linux sin `gnome-keyring` ni
`kwallet` corriendo (§7). **No es el mismo caso que macOS y el diseño no puede ser
idéntico**, por una razón concreta: en macOS el fallo es **incondicional y ya probado
cuatro veces** (§4, y ahora confirmado por otro agente desde la aplicación) — no hay
ninguna combinación que funcione hoy, así que elegir el backend según la plataforma
(`!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS` — ver la corrección de §8.1
sobre por qué no es `Platform.isMacOS`) es correcto. En Linux el fallo es **condicional**: la mayoría de
escritorios (GNOME, KDE) sí tienen un servicio de secretos corriendo, y ahí
`FlutterSecureCredentialBackend` funciona exactamente igual que hoy, con reconexión
desatendida incluida. Sólo falla la minoría real: una terminal sin escritorio, un servidor,
un contenedor. Fijar Linux al archivo cifrado igual que macOS **rompería el camino que hoy
funciona** para la mayoría de usuarios de Linux — soy yo quien estaría degradando algo que
no estaba roto, exactamente lo que la primera regla de este proyecto prohíbe.

**Propuesta: un backend de respaldo en tiempo de EJECUCIÓN, no de compilación, sólo para
Linux.** Un `CredentialBackend` que intenta primero `FlutterSecureCredentialBackend()`
(libsecret) y, sólo si esa llamada falla, cae al archivo cifrado de §8.3/§8.4:

- **`write`**: intenta libsecret; si lanza, escribe en el archivo cifrado en su lugar.
- **`read`**: intenta libsecret; si lanza (o si libsecret contesta "no existe" pero el
  archivo cifrado sí tiene algo — el caso de "el escritorio se cayó entre el `write` y este
  `read`"), intenta el archivo cifrado antes de rendirse.
- **`delete`**: intenta borrar en los dos sitios, sin fallar si uno de los dos no tiene nada
  que borrar — un huérfano en cualquiera de los dos lados es peor que un borrado de más.

Esto es más complejo que el interruptor de macOS y traía una pregunta que no se decidió a
mitad de la implementación: **¿qué error concreto de libsecret dispara la caída al
archivo?** §7 ya identificó dos códigos reales (`"Libsecret error"` genérico y
`"KeyringLocked"`); caer al archivo ante *cualquier* excepción es más simple pero también
esconde errores que no son "no hay servicio" (un permiso de archivo, un disco lleno) detrás
del mismo camino silencioso.

**Decidido por el team-lead, 12-sep-2026: acotado a esos dos códigos exactos, nunca
"cualquier excepción".** Implementado en
`orbi_runtime/lib/src/auth/linux_secret_service_fallback_credential_backend.dart`: un
código no reconocido se relanza tal cual — falla y se ve, no cae en silencio al respaldo.
Cada caída real dispara un aviso en el registro (`logger.w`, sin secretos) con el código
que la provocó. Diez pruebas cubren esto, incluida una que verifica explícitamente que el
respaldo nunca se llama ante un código desconocido.

**Consecuencia para la pregunta de "arranque desatendido", que ahora es distinta por
plataforma:** en macOS, la respuesta sigue siendo **no**, siempre, sin condición. En Linux,
la respuesta es **depende**: **sí** sigue arrancando sin que nadie escriba nada en
cualquier escritorio con servicio de secretos activo (la inmensa mayoría hoy), y **no** —
exactamente como macOS — sólo en la minoría sin ese servicio, que es el caso que de todos
modos hoy ya estaba roto (§7: ese caso hoy no persiste nada en absoluto, sólo devuelve un
error legible). El respaldo no empeora nada que funcionara: sólo convierte un "no se puede"
en un "se puede, con contraseña".

---

~~**Respuesta directa a tu pregunta de cierre:** macOS, no — con este diseño, no puede
arrancar y conectarse sin que alguien escriba su contraseña... Linux, depende.~~ **Sin
objeto tras el malentendido de arriba: macOS no usa este diseño.** La única pregunta de
arranque desatendido que sigue en pie es la de Linux, y la respuesta no cambió: sigue
arrancando sin contraseña en cualquier escritorio con servicio de secretos activo, y sólo
la pide donde hoy ya no había nada que arrancar.

### 8.7 La pregunta que queda, cerrada

**¿Hay alguna plataforma, aparte de Linux sin servicio de secretos, donde
`flutter_secure_storage` no baste?** No. §7, medido leyendo el código nativo de cada
complemento, no la documentación: Windows (Administrador de Credenciales, AES-128 sobre un
archivo, con el riesgo de excepción sin atrapar ya documentado como lectura de código, no
medición en vivo), Android (`AndroidKeyStore` real, hardware-backed) e iOS funcionan de
fábrica. El navegador tiene su propia pieza — la llave no extraíble de Web Crypto de
`desbloqueo-offline`, ya construida y en uso, ajena a todo lo de este documento. El único
hueco real es Linux sin escritorio, y §8.6 ya lo cubre. **Cerrado.**

---
pub.dev consultado el 11-sep-2026, y `cryptography_plus`/`pointycastle`/`hive_ce`
reverificados en vivo el 12-sep-2026 para §8 (cifras iguales o mayores; ninguna conclusión
de §1 cambió). Código del plugin leído en
`~/.pub-cache/.../flutter_secure_storage_darwin-0.4.0`,
`flutter_secure_storage_windows-4.2.2`, `flutter_secure_storage_linux-3.0.2`,
`flutter_secure_storage_web-2.1.1` y `flutter_secure_storage-11.0.0/android` (Keystore),
las versiones que fijan `theos_panel/pubspec.lock`. No se escribió código: esta fase es de
propuesta.
