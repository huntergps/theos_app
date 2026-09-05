# Especificación: Theos App — venta, cobro y facturación multiplataforma

> **Política de instalación:** este proyecto es nuevo y nunca ha estado en
> producción. Cada instalación crea directamente el esquema Drift vigente y
> sus scopes de servidor/base/usuario. Toolchain: Flutter global 3.47.1 / Dart
> 3.13.1.

## Estado del documento

- Fase: F3, F4, F5 y F7 completadas; F8 en regresión/build/E2E; F9 pendiente
- Fecha: 2026-08-26
- Repositorio independiente: `/Users/elmers/Documents/develop/2026/theos_app`
- Alcance funcional acordado: vendedores venden; cajeros cobran y facturan

## Suposiciones validadas

1. Debe funcionar contra Odoo 19.x y Odoo 20.x. Odoo 18 queda fuera del
   alcance porque el producto parte de la API JSON-2 introducida en 19.x.
2. Las plataformas se priorizan así: iPad, Android, macOS, Windows y web.
3. No se agregarán módulos ERP ajenos al flujo de venta, cobro y facturación.
4. El entorno `/Users/elmers/Documents/dev_odoo20` y la instancia `erp2`
   aportan código, configuración y datos de referencia para validar integración.
5. Ninguna credencial se copiará al repositorio, documentos, fixtures ni logs.

## Objetivo

Entregar una versión productiva de Theos App que permita completar, con una
interfaz adaptada a cada plataforma, estos dos recorridos:

### Vendedor

1. Iniciar sesión en un servidor Odoo configurado.
2. Sincronizar y consultar clientes, productos, precios, impuestos, unidades y
   disponibilidad por bodega.
3. Crear o seleccionar un cliente.
4. Crear una orden, agregar productos, modificar cantidades, unidades,
   descuentos autorizados y observaciones.
5. Guardar y confirmar la venta, o enviarla al flujo de aprobación cuando el
   crédito o descuento lo requieran.
6. Seguir operando sin conexión cuando la operación sea apta para cola offline.

### Cajero

1. Abrir o recuperar su sesión/punto de cobro.
2. Localizar una venta confirmada o crear una venta rápida.
3. Registrar uno o varios medios de pago admitidos por la configuración Odoo.
4. Cobrar, crear la factura y dejarla vinculada a la orden y al cobro.
5. Mostrar el resultado fiscal disponible, generar el documento PDF y permitir
   imprimirlo o compartirlo.
6. Si se pierde conexión, guardar una operación idempotente y completarla al
   recuperar conectividad sin duplicar órdenes, cobros ni facturas.
7. Cerrar la sesión de caja con totales consistentes entre dispositivo y Odoo.

## Usuarios y permisos

- Vendedor: grupos de ventas de Odoo y permisos mínimos para clientes,
  catálogo y órdenes.
- Cajero: grupos del módulo de colección y permisos para sesiones, pagos y
  facturación.
- Supervisor: métricas, aprobaciones y consulta de sesiones.
- Administrador: configuración, sincronización, conflictos y diagnóstico.

La interfaz debe ocultar y bloquear rutas no autorizadas. Odoo continúa siendo
la autoridad final y debe rechazar operaciones sin ACL o record rules válidas.

## Compatibilidad Odoo

### Transporte

El SDK expondrá un contrato único para CRUD y métodos de modelo:

```dart
abstract interface class OdooTransport {
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic> domain = const [],
    int? limit,
    int? offset,
    String? order,
  });

  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  });
}
```

- Odoo 19.x y 20.x: transporte JSON-2.
- El login detectará versión y capacidades antes de construir repositorios.
- La selección no dependerá solamente del número de versión: se comprobarán
  endpoints, modelos y campos cuando exista una diferencia funcional.
- Ninguna feature podrá construir directamente URLs `/json/2`; deberá usar el
  transporte o `OdooClient` unificado.

### Capacidades por versión

Se mantendrá una matriz probada para, al menos:

- existencia de `res.bank` y modelos bancarios;
- nombres y semántica de unidades de medida;
- firmas de `create`, `write`, `search_read` y métodos de recordset;
- sesión Bearer, conectividad HTTP y restauración segura por plataforma;
- modelos custom de caja, pagos, anticipos y retenciones;
- wizard o método utilizado para cobrar y facturar una venta;
- campos de factura y localización ecuatoriana necesarios para el documento.

Cuando una capacidad no exista en una versión, la UI deberá deshabilitarla con
una explicación; nunca enviará silenciosamente campos incompatibles.

## Compatibilidad de plataformas

### 1. iPad

- Objetivo principal de interacción y aceptación visual.
- Uso táctil, orientación horizontal y vertical, teclado virtual y escáner
  compatible con entrada de teclado/cámara.
- Build iOS sin firma reproducible en CI; distribución firmada se configura
  cuando existan certificados y perfil de Apple.

### 2. Android

- Diseño táctil para tablet y teléfono.
- APK/App Bundle release reproducible.
- Persistencia SQLite, reconexión y reanudación tras suspender la app.

### 3. macOS

- Ventana, teclado, atajos, impresión/compartir y almacenamiento local.
- Build release reproducible.

### 4. Windows

- Ventana, teclado, impresión y SQLite.
- Build release verificado en runner Windows de CI.

### 5. Web

- Diseño adaptativo y base Drift/WASM.
- Autenticación web Bearer sobre JSON-2, sin cookies ni `withCredentials`, con
  CORS y HTTPS; polling HTTP autenticado como mecanismo de reconciliación.
- Build release reproducible para hosting configurable, sin codificar un
  `base-href` específico dentro de la aplicación.

## Arquitectura objetivo

```text
theos_pos (UI y composición)
  ├── features (venta, caja, facturación, sincronización)
  ├── Riverpod (estado e inyección)
  └── GoRouter + guards de sesión y permisos
             │
             ▼
theos_pos_core (dominio y persistencia Dart)
  ├── modelos Freezed
  ├── servicios de negocio
  ├── managers/repositorios
  └── Drift/SQLite
             │
             ▼
odoo_sdk
  ├── OdooTransport
  │     └── Json2Transport (19/20)
  ├── sesión, seguridad y conectividad
  ├── cola offline, idempotencia y conflictos
  └── health checks y primitivas de polling HTTP

odoo_widgets: componentes visuales reutilizables
flutter_qweb: interpretación QWeb y documentos PDF
```

### Runtime de sesión y datos

- La app mantiene un solo `OdooClient` Bearer por `SessionScope`; no usa
  sesiones del webclient, cookies, XML-RPC ni WebSocket.
- En nativo, la metadata no sensible referencia la API key almacenada en el
  vault de la plataforma. Un cold-start restaura credencial, scope, identidad y
  permisos antes de publicar la sesión al router. Web mantiene la clave solo en
  memoria y requiere login después de un refresh.
- Login online, login offline y restauración abren primero el Drift scoped y
  luego llaman a `initializeModelManagers(client, db, queueStore)`. El binding
  reemplaza cliente, base, cola y caches del scope anterior; logout/expiración
  ejecutan `resetModelManagersSession` antes de cerrar Drift.
- La reconciliación remota es HTTP JSON-2. El orquestador drena primero la cola
  durable y después ejecuta sync incremental al iniciar, al recuperar conexión
  y por polling periódico. El sync completo es manual.
- Los upserts Drift y sus streams actualizan listas, contadores y formularios.
  La app no necesita un canal push adicional para propagar el estado local.

### Reglas de dependencia

- `odoo_sdk` no depende de Flutter ni del dominio Theos.
- `theos_pos_core` depende de `odoo_sdk`, no de `theos_pos`.
- La UI depende de interfaces/providers y no crea clientes HTTP directamente.
- La lógica tributaria, de totales y de estados no vive en widgets.
- Las diferencias Odoo se encapsulan en transportes/adaptadores, no en
  condicionales dispersos por pantallas.

## Estructura del proyecto

```text
docs/
  specs/                 Especificaciones vivas
  runbooks/              Operación, release y soporte
odoo_sdk/
  lib/src/api/           Cliente y transportes Odoo
  lib/src/model/         Contratos y managers genéricos
  lib/src/sync/          Cola, sync, conflictos e idempotencia
  test/                  Unitarias e integración del SDK
theos_pos_core/
  lib/src/models/        Entidades y mapeos Odoo
  lib/src/database/      Drift, tablas y esquema técnico clean-install
  lib/src/managers/      Acceso local/remoto por modelo
  lib/src/services/      Reglas puras de negocio
  test/                  Unitarias y persistencia
theos_pos/
  lib/core/              Composición específica Flutter
  lib/features/          Features verticales
  lib/shared/            UI compartida
  integration_test/      Recorridos completos de la app
  test/                  Unitarias y widgets
odoo_widgets/            Widgets agnósticos de dominio
flutter_qweb/            QWeb/PDF
```

## Stack técnico

- Dart 3.13.1 o superior compatible con el Flutter fijado por el proyecto.
- Flutter 3.47.1 como versión reproducible de CI y desarrollo.
- Riverpod 3 y generación por anotaciones.
- GoRouter 17.
- Fluent UI con adaptación táctil y de escritorio.
- Drift/SQLite y Drift Web/WASM.
- Dio para HTTP.
- Freezed y JSON Serializable para modelos.
- `flutter_test`, `test` y Mocktail.

Las dependencias están resueltas mediante lockfiles reproducibles y se
actualizan junto con una regresión completa del monorepo.

## Comandos de trabajo

Desde la raíz del repositorio:

```bash
# Dependencias
(cd odoo_sdk && dart pub get)
(cd flutter_qweb && flutter pub get)
(cd odoo_widgets && flutter pub get)
(cd theos_pos_core && dart pub get)
(cd theos_pos && flutter pub get)

# Generación
(cd theos_pos_core && dart run build_runner build --delete-conflicting-outputs)
(cd theos_pos && dart run build_runner build --delete-conflicting-outputs)

# Análisis
(cd odoo_sdk && dart analyze)
(cd theos_pos_core && dart analyze)
(cd odoo_widgets && flutter analyze)
(cd flutter_qweb && flutter analyze)
(cd theos_pos && flutter analyze)

# Pruebas
(cd odoo_sdk && dart test)
(cd theos_pos_core && dart test)
(cd odoo_widgets && flutter test)
(cd flutter_qweb && flutter test)
(cd theos_pos && flutter test)

# Builds prioritarios
(cd theos_pos && flutter build ios --release --no-codesign)
(cd theos_pos && flutter build appbundle --release)
(cd theos_pos && flutter build macos --release)
(cd theos_pos && flutter build windows --release)
(cd theos_pos && flutter build web --release)
```

El build Windows se ejecutará en Windows. Los comandos repetitivos podrán
envolverse después en scripts de verificación, sin ocultar sus pasos.

## Estilo de código

- Dos espacios, `lower_snake_case.dart`, `UpperCamelCase` para tipos y
  `lowerCamelCase` para miembros.
- Analyzer sin warnings ni errores en código manual.
- Estado compartido inmutable; callbacks usan `ref.read`, render usa
  `ref.watch`.
- Excepciones tipadas y mensajes traducibles para fallos de negocio.
- No se registran claves, tokens, cookies, contraseñas ni cuerpos sensibles.

Ejemplo esperado:

```dart
final saleCheckoutProvider = AsyncNotifierProvider.family<
    SaleCheckoutNotifier,
    CheckoutState,
    int>(SaleCheckoutNotifier.new);

class SaleCheckoutNotifier extends FamilyAsyncNotifier<CheckoutState, int> {
  @override
  Future<CheckoutState> build(int orderId) async {
    final repository = ref.watch(checkoutRepositoryProvider);
    return repository.load(orderId);
  }
}
```

## Estrategia de pruebas

### Unitarias

- Cálculo de líneas, impuestos, redondeo, descuentos, pagos y totales.
- Selección de transporte y capacidades por versión.
- Mapeos Odoo 19 y 20 con fixtures sin información real.
- Idempotencia, reintentos, dependencias de cola y resolución de conflictos.

### Persistencia

- El esquema Drift y sus artefactos generados se validan desde una instalación
  limpia; no se admite como entrada una base creada por una versión anterior.
- Aislamiento por servidor/base/usuario dentro de la instalación actual.
- Recuperación tras cierre durante una sincronización iniciada en la
  instalación actual.

### Widgets y adaptación

- Golden/widget tests de venta y caja en tamaños representativos de iPad,
  Android phone/tablet, macOS/Windows y web.
- Navegación por teclado, foco, scroll y objetivos táctiles.
- Guards de autenticación y permisos por ruta.

### Integración Odoo

- Suite separada para Odoo 19.x y 20.x.
- Variables `ODOO19_*` y `ODOO20_*` inyectadas fuera de Git.
- Los tests crean registros con prefijo único, registran sus IDs y limpian o
  revierten únicamente sus propios datos.
- Producción/`erp2` es de solo lectura durante diagnóstico. Cualquier prueba
  que cree, cobre, contabilice o facture requiere autorización explícita y un
  usuario/empresa de pruebas.

### Recorridos E2E obligatorios

1. Vendedor crea y confirma una venta al contado.
2. Cajero abre sesión, encuentra la venta, cobra y genera factura.
3. Venta a crédito dentro del límite.
4. Crédito excedido entra en aprobación y no factura prematuramente.
5. Venta offline se sincroniza una sola vez al recuperar conexión.
6. Pago offline no duplica pago ni factura tras varios reintentos.
7. Cierre de caja coincide con pagos y diferencias registradas.
8. Usuario sin grupo no puede abrir una ruta protegida ni ejecutar la acción.

## Límites operativos

### Hacer siempre

- Añadir o actualizar pruebas junto con cada cambio.
- Ejecutar analyzer y pruebas del paquete afectado.
- Ejecutar la suite completa antes de considerar una fase terminada.
- Regenerar y validar el esquema local clean-install cuando cambie Drift.
- Sanitizar logs y mantener secretos fuera del repositorio.
- Actualizar esta especificación cuando cambie una decisión.

### Consultar primero

- Escrituras o pruebas transaccionales en `erp2` o cualquier producción.
- Cambios de esquema Odoo o instalación/actualización de módulos.
- Agregar dependencias o servicios externos.
- Publicar en App Store, Play Store, Microsoft Store o hosting público.
- Firmar builds con certificados reales.

### No hacer nunca

- Guardar credenciales, API keys, cookies o dumps reales en Git.
- Ejecutar limpieza masiva o unlink genérico en un servidor compartido.
- Eliminar pruebas para obtener un build verde.
- Ignorar una incompatibilidad de versión enviando campos a prueba y error.
- Duplicar una operación financiera para comprobar reintentos.

## Criterios de éxito

El proyecto se considerará terminado cuando:

1. Los ocho recorridos E2E pasan en entornos controlados de Odoo 19.x y 20.x,
   excepto capacidades documentadas como inexistentes en el servidor.
2. Vendedor y cajero completan el recorrido principal sin abrir el backend web
   de Odoo.
3. Una pérdida de red en cada punto seguro conserva el trabajo y no duplica
   documentos al reconectar.
4. Orden, pagos, factura, sesión de caja y totales coinciden entre Drift y Odoo.
5. Las rutas y acciones respetan autenticación, grupos y modo desarrollador.
6. Analyzer y todas las suites de los cinco paquetes terminan en verde.
7. CI genera builds de iOS sin firma, Android App Bundle, macOS, Windows y web.
8. No hay secretos en el repositorio ni en artefactos/logs de CI.
9. README y runbooks explican configuración, desarrollo, pruebas, release,
   diagnóstico offline y recuperación de colas/conflictos.
10. Los TODO funcionales del recorrido principal están implementados o
    eliminados porque la capacidad se declaró explícitamente fuera de alcance.

## Fuera de alcance de esta versión

- Reemplazar todo el backend de Odoo o sus flujos contables.
- Compatibilidad con Odoo 18 o versiones anteriores.
- Incorporar compras, manufactura, nómina o CRM completo.
- Certificar hardware fiscal específico no disponible para pruebas.
- Publicar en tiendas sin cuentas, contratos y certificados suministrados.
- Garantizar compatibilidad con módulos custom distintos de los presentes en
  los entornos de referencia sin una matriz adicional.

## Preguntas abiertas no bloqueantes para la planificación

1. Qué servidores/base controlados se usarán como matriz Odoo 19 y 20.
2. Qué empresa y diario de pruebas permiten facturar sin afectar contabilidad
   o numeración productiva.
3. Qué impresoras/formatos físicos deben certificarse además del PDF.
4. Qué cuentas y certificados se usarán para distribución firmada.
