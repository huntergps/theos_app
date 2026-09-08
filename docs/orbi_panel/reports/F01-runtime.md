# F01-B · Runtime C01/C05

## Alcance

Se creó únicamente `orbi_runtime/` y este informe. No se abrieron bases de
datos, no se añadieron providers ni se importaron apps, widgets o Fluent.

## Implementación

- `AppScope` valida identidad positiva y campos no vacíos, normaliza URLs HTTP(S),
  elimina credenciales/query/fragmento y produce una `scopeKey` JSON estable,
  sin concatenación ambigua ni secretos.
- `CompanyContext` mantiene la partición de compañía dentro del scope, ordena y
  valida compañías permitidas y registra `capabilityRevision`.
- `SessionLease` vincula scope y generación para rechazar respuestas tardías.
- C05 materializa `NetworkSignal`, `BackendHealth`, `AuthStatus`, `SyncSnapshot`,
  razones tipadas y la interfaz `SyncCoordinator`; no contiene implementación
  que declare sincronización exitosa.

## Verificación

Entorno: Flutter 3.47.1 / Dart 3.13.1. El paquete declara Dart `>=3.13.0 <4.0.0`
y Flutter `>=3.47.0`.

- `cd orbi_runtime && flutter pub get` — correcto.
- `cd orbi_runtime && flutter analyze` — correcto, 0 issues.
- `cd orbi_runtime && flutter test` — correcto, 5 pruebas.

Las pruebas cubren canonicalización/igualdad de scope, aislamiento por app,
instalación y usuario, validación de compañía, lease/generación y estados de
red/sincronización; `NetworkSignal` hace `none` exclusivo y ordena transportes,
y los contadores de `SyncSnapshot` rechazan valores negativos también en release,
sin depender de `assert`. No se verificaron plataformas ni integración ERP; quedan
para tareas posteriores.
