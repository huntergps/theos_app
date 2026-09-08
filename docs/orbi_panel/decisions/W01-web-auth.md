# W01 — acceso web simple y reinicio offline

Estado: **bloqueado por decisión de backend/despliegue**.

## Problema comprobado

En iOS, Android y escritorio, Orbi puede autenticar con usuario/contraseña una
vez, crear una clave API personal y guardarla en el almacén seguro del sistema.
Ese bootstrap está rechazado deliberadamente en web: el navegador no debe
recibir una contraseña para crear y conservar una clave administrativa de larga
vida, y una PWA no dispone de un Keychain/Keystore equivalente.

El build web ya compila. Este pendiente es de identidad y restauración, no de
renderizado ni de Drift.

## Opción recomendada

Publicar la PWA bajo el mismo origen de cada Odoo de cliente, por ejemplo
`https://erp2.tecnosmart.com.ec/orbi/`, y añadir en un addon conector un
bootstrap de sesión de alcance mínimo:

1. El usuario entra mediante la sesión web normal de Odoo; la cookie sigue
   siendo `HttpOnly` y la app nunca recibe una clave API.
2. Un endpoint autenticado devuelve identidad, compañía y capacidades del
   usuario actual; no acepta un `user_id` elegido por el cliente.
3. La PWA guarda perfil, catálogos y operaciones en IndexedDB por
   servidor/base/usuario/compañía.
4. Un reinicio sin red abre únicamente el scope previamente aprovisionado. Las
   operaciones quedan locales y se revalidan contra la misma sesión al volver la
   conexión.
5. Si la sesión expiró, la cola no se borra ni se envía con otra identidad; se
   solicita reautenticación y luego se reanuda el replay.

Esto evita CORS entre servidores, no expone una API key y conserva el modelo
offline-first. Cada dominio instala la misma compilación y su configuración de
origen.

## Cambio que requeriría autorización

- Destino: `l10n_ec_collection_box_pos` como conector opcional de Orbi, sin
  dependencia de `l10n_ec_collection_panel`.
- Alcance: ruta estática de la PWA y endpoint de bootstrap de sesión de solo
  lectura; no se modifica Odoo core/Enterprise ni una regla financiera.
- Riesgos: cachear el shell equivocado entre bases, mezclar scopes al cambiar de
  compañía y ejecutar una cola después de cambiar de usuario.
- Compuertas: aislamiento por scope, cierre de sesión, sesión expirada,
  actualización de service worker, reinicio totalmente offline y replay sin
  duplicados en ERP2.

No se implementa este cambio hasta recibir autorización explícita para editar y
desplegar el addon conector. `newerp` queda siempre fuera de las pruebas.

## Alternativas descartadas como experiencia final

- Pegar una clave API larga en el navegador.
- Guardar usuario/contraseña en `SharedPreferences`, LocalStorage o IndexedDB.
- Usar al administrador como sustituto del vendedor/cajero.
- Un proxy general que reciba y conserve contraseñas sin un contrato de sesión
  limitado y auditable.
