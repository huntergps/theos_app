# odoo_sdk — Analisis de Casos de Uso y Flujos

## Indice

1. [Arquitectura General](#1-arquitectura-general)
2. [Caso de Uso: Login y Autenticacion](#2-caso-de-uso-login-y-autenticacion)
3. [Caso de Uso: Gestion de Sesiones Multi-Tenant](#3-caso-de-uso-gestion-de-sesiones-multi-tenant)
4. [Caso de Uso: Definicion de Modelos Base](#4-caso-de-uso-definicion-de-modelos-base)
5. [Caso de Uso: CRUD Offline-First](#5-caso-de-uso-crud-offline-first)
6. [Caso de Uso: Sincronizacion Bidireccional](#6-caso-de-uso-sincronizacion-bidireccional)
7. [Caso de Uso: WebSocket en Tiempo Real](#7-caso-de-uso-websocket-en-tiempo-real)
8. [Caso de Uso: Cola Offline y Reintentos](#8-caso-de-uso-cola-offline-y-reintentos)
9. [Caso de Uso: Multi-Contexto (POS + Back-Office)](#9-caso-de-uso-multi-contexto-pos--back-office)
10. [Caso de Uso: Resolucion de Conflictos](#10-caso-de-uso-resolucion-de-conflictos)
11. [Caso de Uso: Interceptores HTTP](#11-caso-de-uso-interceptores-http)
12. [Caso de Uso: Busqueda Fuzzy y Paginacion](#12-caso-de-uso-busqueda-fuzzy-y-paginacion)
13. [Caso de Uso: Monitoreo de Conectividad](#13-caso-de-uso-monitoreo-de-conectividad)
14. [Caso de Uso: Metricas de Sincronizacion](#14-caso-de-uso-metricas-de-sincronizacion)
15. [Caso de Uso: Seguridad](#15-caso-de-uso-seguridad)
16. [Caso de Uso: Sync Avanzado](#16-caso-de-uso-sync-avanzado)
17. [API Completa por Capa](#17-api-completa-por-capa)
18. [Gaps y Mejoras Pendientes](#18-gaps-y-mejoras-pendientes)

---

## 1. Arquitectura General

```
+----------------------------------------------------------------+
|                        App Flutter                              |
+----------------------------------------------------------------+
        |                    |                    |
        v                    v                    v
+----------------+  +------------------+  +-----------------+
| DataLayerBridge|  |  OdooDataLayer   |  | DataSync-       |
| (API simple)   |  | (multi-contexto) |  | Orchestrator    |
+-------+--------+  +--------+---------+  +--------+--------+
        |                     |                     |
        +----------+----------+---------------------+
                   |
                   v
        +--------------------+
        |    DataContext      |  (uno por sesion)
        |--------------------|
        | OdooClient         |
        | Drift Database     |
        | OfflineQueueWrapper|
        | SyncMetricsCollector|
        | 4 Registries:      |
        |  - configs         |
        |  - managers        |
        |  - fields          |
        |  - computes        |
        +----+---------------+
             |
    +--------+---------+
    |                  |
    v                  v
+----------+   +---------------+
|OdooModel-|   | Offline Queue |
|Manager<T>|   | (Drift table) |
|----------|   +-------+-------+
| fromOdoo |           |
| toOdoo   |           v
| CRUD     |   +---------------+
| search   |   | Queue         |
| sync     |   | Processor     |
| watch    |   +---------------+
+----+-----+
     |
     v
+--------------------+     +--------------------+
| OdooCrudApi        |     | WebSocket Service  |
| (JSON-2 API)       |     | (tiempo real)      |
| POST /json/2/...   |     | wss://odoo/ws      |
+----+---------------+     +----+---------------+
     |                          |
     +-----+--------------------+
           |
     +-----v-----------+     +---------------------+
     | ServerHealth-    |     | Security Layer       |
     | Service          |     |---------------------|
     | (conectividad)   |     | CertificatePinning  |
     +-----+------------+     | LogSanitizer        |
           |                  | CredentialGuard     |
           |                  +-----+---------------+
           |                        |
           +-------+----------------+
                   |
                   v
+--------------------------------------------+
|              Odoo 19+ Server               |
+--------------------------------------------+
```

### Grafo de Dependencias de Paquetes

```
flutter_qweb          (standalone - QWeb templates)
      ^
odoo_sdk               (todo el framework)
```

---

## 2. Caso de Uso: Login y Autenticacion

### 2.1 Flujo Basico de Login

```
Usuario ingresa credenciales
        |
        v
+---------------------------+
| OdooClient(config:        |
|   OdooClientConfig(       |
|     baseUrl, apiKey,      |
|     database))            |
+------------+--------------+
             |
             v
+---------------------------+
| client.authenticateSession|
| (login?, password?)       |
+------------+--------------+
             |
     +-------+-------+
     |               |
     v               v
+-----------+  +-----------+
| Mobile    |  | JsonRpc   |
| Strategy  |  | Strategy  |
| (1ro)     |  | (fallback)|
+-----------+  +-----------+
     |               |
     v               v
res.users.         POST /web/session/
mobile_get_        authenticate
websocket_session  {db, login, password}
     |               |
     +-------+-------+
             |
             v
  OdooSessionResult
  {sessionId, uid, partnerId}
             |
     +-------+-------+
     |               |
     v               v
  Guardar en      client.getSessionInfo()
  SessionPersistence  -> {uid, partner_id,
  (si configurado)      company_id, ...}
```

### 2.2 Codigo de Ejemplo

```dart
// 1. Crear cliente con persistencia de sesion
final client = OdooClient(config: OdooClientConfig(
  baseUrl: 'https://odoo.example.com',
  apiKey: 'api_key_abc123',
  database: 'production',
  defaultLanguage: 'es_EC',
  sessionPersistence: MySecureSessionPersistence(),
));

// 2. Intentar restaurar sesion previa
final restored = await client.session.initializeFromStorage();
if (restored != null) {
  print('Sesion restaurada: UID ${restored.uid}');
} else {
  // 3. Autenticar (obtener session_id para WebSocket)
  await client.createWebSession();
  final session = await client.authenticateSession(
    login: 'admin@example.com',
    password: 'admin',
  );
  // Sesion auto-guardada en persistence
}

// 4. Info de sesion (company, contexto, etc.)
final info = await client.getSessionInfo();
print('Company: ${info?['company_id']}');

// 5. Verificar validez de sesion
final valid = await client.session.isSessionValid();
if (!valid) {
  print('Sesion expirada, re-autenticando...');
}
```

### 2.3 Token Refresh Automatico

```
Request -> 401 Unauthorized
        |
        v
AuthInterceptor detecta 401
        |
        v
tokenRefreshHandler.refreshToken()
        |
    +---+---+
    |       |
    v       v
 Success  Failed
    |       |
    v       v
 Retry    Propagar
 request  error 401
 con
 nuevo
 token
```

Configuracion:

```dart
final client = OdooClient(config: OdooClientConfig(
  baseUrl: 'https://odoo.example.com',
  apiKey: 'old_key',
  database: 'production',
  tokenRefreshHandler: MyTokenRefresher(),
  onApiKeyRefreshed: (newKey) {
    // Guardar nuevo key en storage seguro
    secureStorage.write('api_key', newKey);
  },
));
```

### 2.4 Logout (Server-side + Local)

```
client.session.logout()
        |
        v
+---------------------------+
| POST /web/session/destroy |  (best-effort, ignora errores)
+---------------------------+
        |
        v
+---------------------------+
| Limpiar _currentSession   |
| Limpiar sessionInfoCache  |
| persistence.clearSession()|
+---------------------------+
```

```dart
// Logout completo (servidor + local + persistence)
await client.session.logout();

// Verificar
print(client.session.hasSession); // false
```

### 2.5 Persistencia de Sesion

```dart
/// Interfaz abstracta — la app provee la implementacion
abstract class SessionPersistence {
  Future<void> saveSession(OdooSessionResult session);
  Future<OdooSessionResult?> loadSession();
  Future<void> clearSession();
}

// Ejemplo de implementacion con FlutterSecureStorage:
class SecureSessionPersistence implements SessionPersistence {
  final FlutterSecureStorage _storage;
  SecureSessionPersistence(this._storage);

  @override
  Future<void> saveSession(OdooSessionResult session) async {
    await _storage.write(key: 'session', value: jsonEncode(session.toMap()));
  }

  @override
  Future<OdooSessionResult?> loadSession() async {
    final data = await _storage.read(key: 'session');
    if (data == null) return null;
    return OdooSessionResult.fromMap(jsonDecode(data));
  }

  @override
  Future<void> clearSession() async {
    await _storage.delete(key: 'session');
  }
}
```

### 2.6 Flujo de Restauracion al Iniciar App

```
App se inicia
     |
     v
session.initializeFromStorage()
     |
     v
persistence.loadSession()
     |
     +--- null --> No hay sesion guardada
     |              (ir a login)
     |
     +--- OdooSessionResult
              |
              v
         session.isSessionValid()
              |
         +----+----+
         |         |
         v         v
       true      false
         |         |
         v         v
      Sesion     Limpiar sesion
      valida     persistida
      (continuar) (ir a login)
```

---

## 3. Caso de Uso: Gestion de Sesiones Multi-Tenant

### 3.1 Flujo Multi-Tenant

```
App soporta multiples empresas/bases de datos
        |
        v
+-------------------------------+
| MultiTenantManager            |
|-------------------------------|
| registerTenant('emp_a', cfgA) |
| registerTenant('emp_b', cfgB) |
+-------------------------------+
        |
        v
switchTenant('emp_a')
        |
    +---+---+
    |       |
    v       v
onBefore  onAfter
Switch    Switch
(puede    (actualizar
 vetar)    UI)
        |
        v
TenantChangedEvent
{previousId, newId, newConfig}
        |
        v
Stream<TenantChangedEvent>
-> Actualizar OdooClient
```

### 3.2 Codigo de Ejemplo

```dart
final tenantManager = MultiTenantManager();

// Registrar tenants
tenantManager.registerTenant(
  'ferreteria',
  OdooClientConfig(
    baseUrl: 'https://ferreteria.odoo.com',
    apiKey: 'key_1',
    database: 'ferreteria2020',
  ),
  name: 'Ferreteria S.A.',
);

tenantManager.registerTenant(
  'tecnosmart',
  OdooClientConfig(
    baseUrl: 'https://tecnosmart.odoo.com',
    apiKey: 'key_2',
    database: 'tecnosmart',
  ),
  name: 'TecnoSmart',
);

// Callback antes de cambiar
tenantManager.onBeforeTenantSwitch = (oldId, newId) async {
  await saveCurrentState(); // Guardar estado actual
  return true; // permitir cambio
};

// Escuchar cambios
tenantManager.tenantChanges.listen((event) {
  client.http.updateConfig(event.newConfig);
  print('Cambiado a: ${event.newTenantId}');
});

// Cambiar tenant
await tenantManager.switchTenant('tecnosmart');
```

---

## 4. Caso de Uso: Definicion de Modelos Base

### 4.1 res.partner (Contactos)

```dart
@OdooModel('res.partner', tableName: 'res_partners')
@freezed
abstract class Partner with _$Partner {
  const Partner._();

  const factory Partner({
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,
    @OdooLocalOnly() @Default(false) bool isSynced,

    // Datos basicos
    @OdooString() required String name,
    @OdooString() String? email,
    @OdooString() String? phone,
    @OdooString() String? mobile,
    @OdooString(odooName: 'street') String? street,
    @OdooString(odooName: 'street2') String? street2,
    @OdooString() String? city,
    @OdooString() String? zip,
    @OdooString(odooName: 'vat') String? vat,

    // Tipo
    @OdooBoolean(odooName: 'is_company') @Default(false) bool isCompany,
    @OdooBoolean() @Default(true) bool active,
    @OdooBoolean() @Default(false) bool customer,
    @OdooBoolean() @Default(false) bool supplier,

    // Relaciones
    @OdooMany2One('res.country', odooName: 'country_id') int? countryId,
    @OdooMany2OneName(sourceField: 'country_id') String? countryName,
    @OdooMany2One('res.country.state', odooName: 'state_id') int? stateId,
    @OdooMany2OneName(sourceField: 'state_id') String? stateName,
    @OdooMany2One('res.partner', odooName: 'parent_id') int? parentId,
    @OdooMany2OneName(sourceField: 'parent_id') String? parentName,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,

    // Imagen
    @OdooBinary(odooName: 'image_128', fetchByDefault: false) String? image128,

    // Metadata
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Partner;

  // Getters computados
  String get displayName => isCompany ? name : '$name${email != null ? ' <$email>' : ''}';
  bool get hasAddress => street != null || city != null;
  bool get hasVat => vat != null && vat!.isNotEmpty;
}
```

### 4.2 res.company (Empresas)

```dart
@OdooModel('res.company', tableName: 'res_companies')
@freezed
abstract class Company with _$Company {
  const Company._();

  const factory Company({
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,
    @OdooLocalOnly() @Default(false) bool isSynced,

    @OdooString() required String name,
    @OdooString(odooName: 'vat') String? vat,
    @OdooString() String? email,
    @OdooString() String? phone,
    @OdooString() String? website,
    @OdooString(odooName: 'street') String? street,
    @OdooString() String? city,
    @OdooString() String? zip,

    @OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,
    @OdooMany2OneName(sourceField: 'currency_id') String? currencyName,
    @OdooMany2One('res.country', odooName: 'country_id') int? countryId,
    @OdooMany2OneName(sourceField: 'country_id') String? countryName,
    @OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,

    @OdooBinary(odooName: 'logo', fetchByDefault: false) String? logo,

    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Company;
}
```

### 4.3 res.users (Usuarios)

```dart
@OdooModel('res.users', tableName: 'res_users')
@freezed
abstract class User with _$User {
  const User._();

  const factory User({
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,
    @OdooLocalOnly() @Default(false) bool isSynced,

    @OdooString() required String name,
    @OdooString() required String login,
    @OdooBoolean() @Default(true) bool active,

    @OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,
    @OdooMany2OneName(sourceField: 'partner_id') String? partnerName,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooMany2Many('res.company', odooName: 'company_ids') List<int>? companyIds,
    @OdooMany2Many('res.groups', odooName: 'groups_id') List<int>? groupIds,

    @OdooBinary(odooName: 'image_128', fetchByDefault: false) String? image128,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _User;

  bool get isAdmin => groupIds?.contains(1) ?? false;
}
```

### 4.4 Anotaciones Disponibles

| Anotacion | Tipo Dart | Tipo Odoo | Uso |
|-----------|-----------|-----------|-----|
| `@OdooId()` | int | id | PK, siempre requerido |
| `@OdooString()` | String | Char/Text | Texto |
| `@OdooInteger()` | int | Integer | Enteros |
| `@OdooFloat(precision:)` | double | Float | Decimales |
| `@OdooBoolean()` | bool | Boolean | Flags |
| `@OdooDate()` | DateTime | Date | Solo fecha |
| `@OdooDateTime()` | DateTime | Datetime | Fecha y hora |
| `@OdooMonetary()` | double | Monetary | Dinero |
| `@OdooSelection(options:)` | String | Selection | Enums |
| `@OdooBinary()` | String | Binary | Imagenes base64 |
| `@OdooHtml()` | String | Html | HTML |
| `@OdooJson()` | Map | Json | JSON libre |
| `@OdooMany2One(model)` | int | Many2one | FK (ID) |
| `@OdooMany2OneName(source)` | String | - | Nombre display |
| `@OdooOne2Many(model)` | List\<int\> | One2many | Lineas |
| `@OdooMany2Many(model)` | List\<int\> | Many2many | Relacion N:N |
| `@OdooLocalOnly()` | any | - | Solo local |
| `@OdooComputed(depends:)` | any | - | Campo calculado |
| `@OdooStoredComputed()` | any | - | Calculado + sync |
| `@OdooOnchange(fields:)` | - | - | Handler onchange |
| `@OdooConstraint(fields:)` | - | - | Validacion |
| `@OdooStateMachine()` | - | - | Maquina de estados |

---

## 5. Caso de Uso: CRUD Offline-First

### 5.1 Flujo de Operaciones

```
                    CREAR REGISTRO
                    ==============

App llama: manager.create(partner)
        |
        v
  +-----+------+
  | Generar ID |
  | negativo   |
  | + UUID     |
  +-----+------+
        |
        v
  Guardar en Drift (local)
  id: -12345, uuid: "abc-123"
  isSynced: false
        |
        v
  +-----+----------+
  | Online?        |
  +--+----------+--+
     |          |
     v          v
   SI          NO
     |          |
     v          v
  Enviar a    Encolar en
  Odoo API    OfflineQueue
     |          |
     v          |
  Obtener      |
  ID real      |
  (ej: 789)    |
     |          |
     v          |
  Actualizar   |
  local:       |
  id: 789      |
  isSynced: t  |
     |          |
     +----+-----+
          |
          v
  RecordChangeEvent
  {type: create, id, record}
```

```
                    LEER REGISTRO
                    =============

App llama: manager.read(123)
        |
        v
  Leer de Drift (local) <-- SIEMPRE primero
        |
        v
  Retornar inmediatamente
        |
        v (en background, si online)
  Fetch de Odoo API
        |
        v
  Actualizar local si hay cambios
        |
        v
  RecordChangeEvent{type: sync}
```

```
                    ACTUALIZAR
                    ==========

App llama: manager.update(partner.copyWith(name: 'Nuevo'))
        |
        v
  Actualizar en Drift (local)
  isSynced: false
        |
        v
  +-----+----------+
  | Online?        |
  +--+----------+--+
     |          |
     v          v
   SI          NO
     |          |
     v          v
  write() en  Encolar
  Odoo API    'write'
     |          |
     v          v
  isSynced:t  Esperar
              sync
```

### 5.2 Codigo de Ejemplo

```dart
// Buscar partners activos
final partners = await partnerManager.search(
  domain: [['active', '=', true], ['customer', '=', true]],
  orderBy: 'name asc',
  limit: 100,
);

// Crear nuevo partner (funciona offline)
final newId = await partnerManager.create(Partner(
  id: 0,
  name: 'Juan Perez',
  email: 'juan@example.com',
  phone: '+593 999 999 999',
  isCompany: false,
  customer: true,
));
// newId = -12345 (offline) o 789 (online)

// Actualizar
final partner = await partnerManager.read(789);
await partnerManager.update(partner!.copyWith(
  phone: '+593 888 888 888',
));

// Eliminar
await partnerManager.delete(789);

// Batch
final ids = await partnerManager.createBatch([partner1, partner2, partner3]);

// Observar cambios reactivos (Drift .watch())
partnerManager.watchLocalSearch(
  domain: [['customer', '=', true]],
).listen((partners) {
  setState(() => _partners = partners);
});

// Observar un registro especifico
partnerManager.watchLocalRecord(789).listen((partner) {
  if (partner != null) {
    setState(() => _currentPartner = partner);
  }
});
```

---

## 6. Caso de Uso: Sincronizacion Bidireccional

### 6.1 Flujo Download (Servidor -> Local)

```
syncFromOdoo()
     |
     v
  Obtener lastSyncDate
     |
     v
  searchCount(domain + [write_date > lastSync])
  -> total: 150
     |
     v
  +------------------+
  | Paginar:         |
  | batch 1: 0-199   |  searchRead(limit: 200, offset: 0)
  | batch 2: 200-399 |  (si hay mas)
  +------------------+
     |
     v
  Por cada registro:
  +-------------------------+
  | fromOdoo(data)          |  Parsear API -> Modelo
  | upsertLocal(record)     |  Guardar en Drift
  | emit ChangeType.sync    |  Notificar UI
  +-------------------------+
     |
     v (cada 50 registros)
  SyncProgress{model, synced: 50, total: 150, phase: downloading}
     |
     v
  SyncResult{model, status: success, synced: 150}
     |
     v (si metrics habilitado)
  SyncMetricsCollector.record(metric)
```

### 6.2 Flujo Upload (Local -> Servidor)

```
syncToOdoo() / processQueue()
     |
     v
  getPendingOperations()
     |
     v
  Ordenar por:
  1. Prioridad (critical > high > normal > low)
  2. Dependencia padre (padres primero)
  3. Tipo (create > write > unlink)
  4. FIFO (por fecha creacion)
     |
     v
  Por cada operacion:
  +----------------------------+
  | Verificar baseWriteDate    |
  | vs server write_date       |
  +-------+--------------------+
          |
    +-----+-----+
    |           |
    v           v
  Sin         Conflicto
  conflicto   detectado
    |           |
    v           v
  Ejecutar   ConflictInfo
  en Odoo    -> resolver
    |
    v
  markCompleted()
  -> Eliminar de cola
```

### 6.3 Sync Multi-Modelo Coordinado

```
SyncCoordinator.syncOptimized()
     |
     v
  +---------------------------+
  | Fase 1: Secuencial        |
  | (modelos con dependencia) |
  |                           |
  | 1. res.company            |
  | 2. res.partner            |
  | 3. res.users              |
  +---------------------------+
     |
     v
  +---------------------------+
  | Fase 2: Paralelo          |
  | (modelos independientes)  |
  |                           |
  | product.product ---|      |
  | account.tax    ---|-> wait|
  | uom.uom        ---|      |
  +---------------------------+
     |
     v
  +---------------------------+
  | Fase 3: Secuencial        |
  | (resto de modelos)        |
  |                           |
  | sale.order                |
  | sale.order.line           |
  +---------------------------+
     |
     v
  SyncReport{results[], startTime, endTime}
  -> totalSynced, totalFailed, allSuccess
```

### 6.4 Codigo de Ejemplo

```dart
// Sync de un modelo
final result = await partnerManager.syncFromOdoo(
  onProgress: (progress) {
    print('${progress.synced}/${progress.total} (${progress.phase})');
  },
);

// Sync de todos los modelos (via contexto)
final report = await bridge.syncAll();
print('Total: ${report.totalSynced}, Errores: ${report.totalFailed}');

// Sync con cancelacion
final token = CancellationToken();

// En otro lugar (ej: boton cancelar)
cancelButton.onPressed = () => token.cancel();

final result = await bridge.syncAll(cancellation: token);

// Sync incremental (solo cambios desde ultima vez)
final result = await bridge.syncModel(
  'res.partner',
  since: DateTime.now().subtract(Duration(hours: 1)),
);

// Metricas automaticas (si habilitado en DataContext)
final metrics = context.metrics.getGlobalMetrics();
print('Total ops: ${metrics.totalOperations}');
print('Avg time: ${metrics.averageDurationMs}ms');
print('Conflict rate: ${metrics.overallConflictRate}%');
```

---

## 7. Caso de Uso: WebSocket en Tiempo Real

### 7.1 Flujo de Conexion

```
                    CONEXION WEBSOCKET
                    ==================

1. Autenticar primero (obtener sessionId)
         |
         v
2. OdooWebSocketService.connect(info)
         |
         v
   +------------------------+
   | Validar HTTPS -> WSS   |
   | (SEC-04)               |
   +------------------------+
         |
         v
   Establecer WebSocket
   wss://odoo.example.com/websocket
         |
         v
   Heartbeat cada 30s (ping)
         |
         v
   Suscribir a canales:
   - {db}.res.partner
   - {db}.sale.order
   - mail.presence
         |
         v
   OdooConnectionEvent{isConnected: true}
```

### 7.2 Flujo de Eventos

```
         Odoo Server
         (otro usuario modifica partner 123)
              |
              v
         Notificacion broadcast
              |
              v
   +------------------------+
   | WebSocket Event Parser |
   | - Detectar tipo        |
   | - Extraer modelo, ID   |
   | - Mapear campos        |
   +------------------------+
              |
              v
   OdooRecordEvent
   {model: 'res.partner',
    recordId: 123,
    action: updated,
    values: {name: 'Nuevo Nombre'},
    changedFields: ['name']}
              |
              v
   App listener:
   -> Refresh local record
   -> Actualizar UI
```

### 7.3 Tipos de Eventos

```
OdooWebSocketEvent (sealed)
  |
  +-- OdooConnectionEvent    (connect/disconnect/reconnect)
  +-- OdooErrorEvent         (errores de conexion)
  +-- OdooPresenceEvent      (online/away/offline de usuarios)
  +-- OdooRecordEvent        (CRUD de registros)
  +-- OdooOrderLineEvent     (lineas de pedido)
  +-- OdooCatalogEvent       (precios, UoM)
  +-- OdooCompanyConfigEvent (config de empresa)
  +-- OdooRawNotificationEvent (otros)
```

### 7.4 Codigo de Ejemplo

```dart
final wsService = OdooWebSocketService();

// Conectar
await wsService.connect(OdooWebSocketConnectionInfo(
  baseUrl: 'https://odoo.example.com',
  database: 'production',
  sessionId: session.sessionId,
  partnerId: session.partnerId,
));

// Escuchar eventos de registro
wsService.eventsOfType<OdooRecordEvent>().listen((event) {
  print('${event.action} en ${event.model} #${event.recordId}');

  // Refrescar registro local
  if (event.model == 'res.partner') {
    partnerManager.read(event.recordId); // trigger background sync
  }
});

// Escuchar presencia de usuarios
wsService.eventsOfType<OdooPresenceEvent>().listen((event) {
  print('Partner ${event.partnerId}: ${event.imStatus}');
});

// Escuchar estado de conexion
wsService.eventsOfType<OdooConnectionEvent>().listen((event) {
  if (!event.isConnected) {
    showSnackBar('Conexion perdida');
  }
});

// Agregar canales
wsService.addChannels(['production.custom.channel']);

// Desconectar
wsService.disconnect();
```

---

## 8. Caso de Uso: Cola Offline y Reintentos

### 8.1 Ciclo de Vida de una Operacion

```
          OPERACION ENCOLADA
                |
                v
  +--------------------------+
  | OfflineQueue (Drift)     |
  | status: pending          |
  | priority: normal         |
  | retryCount: 0            |
  | nextRetryAt: null        |
  +--------------------------+
                |
                v (cuando hay red)
  processQueue()
                |
         +------+------+
         |             |
         v             v
      Exito         Error
         |             |
         v             v
  markCompleted()  markFailed()
  -> Eliminar      retryCount: 1
                   nextRetryAt: +2s
                        |
                        v (siguiente ciclo)
                   retryCount: 2
                   nextRetryAt: +4s
                        |
                        v
                   retryCount: 3
                   nextRetryAt: +8s
                        |
                        v
                   retryCount: 4
                   nextRetryAt: +16s
                        |
                        v
                   retryCount: 5 (MAX)
                        |
                        v
                   DEAD LETTER QUEUE
                   (requiere intervencion manual)
```

### 8.2 Prioridades

```
Prioridad 0 (critical):  Sesiones, caja
Prioridad 1 (high):      Pagos, crear partners
Prioridad 2 (normal):    Actualizar pedidos
Prioridad 3 (low):       Actualizaciones no urgentes

Orden de procesamiento:
  critical -> high -> normal -> low
  (dentro de cada nivel: padres antes que hijos, FIFO)
```

### 8.3 Mantenimiento de Cola

```
                LIMPIEZA AUTOMATICA
                ===================

OfflineQueueConfig:
  maxQueueSize: 10000         (maximo operaciones en cola)
  maxOperationAge: 30 dias    (operaciones mas viejas se eliminan)

Metodos de mantenimiento:
  |
  +-- cleanupStaleOperations()
  |     Elimina operaciones > maxOperationAge
  |
  +-- compressQueue()
  |     Fusiona writes consecutivos al mismo record
  |     Ejemplo: 3 writes a partner#123 -> 1 write con valores merged
  |
  +-- purgeDeadLetterQueue()
  |     Elimina todas las operaciones fallidas
  |
  +-- enforceMaxSize()
        Si cola > maxQueueSize, elimina las mas antiguas
        de baja prioridad primero
```

```dart
// Configurar limites de cola
final queue = OfflineQueueWrapper(store, config: OfflineQueueConfig(
  maxRetries: 5,
  maxQueueSize: 10000,
  maxOperationAge: Duration(days: 30),
));

// Mantenimiento manual
final staleRemoved = await queue.cleanupStaleOperations();
final compressed = await queue.compressQueue();
final deadRemoved = await queue.purgeDeadLetterQueue();
final sizeEnforced = await queue.enforceMaxSize();

print('Limpieza: $staleRemoved stale, $compressed compressed, '
    '$deadRemoved dead, $sizeEnforced oversized');
```

### 8.4 Streams Reactivos

```dart
// Observar cola desde la UI
queue.pendingCount.listen((count) {
  badge.text = '$count pendientes';
});

queue.isProcessing.listen((processing) {
  spinner.visible = processing;
});

queue.deadLetterCount.listen((count) {
  if (count > 0) {
    showWarning('$count operaciones fallidas');
  }
});
```

---

## 9. Caso de Uso: Multi-Contexto (POS + Back-Office)

### 9.1 Arquitectura

```
+-------------------------------------------------------+
|                   OdooDataLayer                        |
|-------------------------------------------------------|
|                                                       |
|  +------------------+     +---------------------+     |
|  | DataContext       |     | DataContext          |     |
|  | "pos-store-1"    |     | "back-office"       |     |
|  |------------------|     |---------------------|     |
|  | OdooClient       |     | OdooClient          |     |
|  | (apiKey POS)     |     | (apiKey admin)      |     |
|  |                  |     |                     |     |
|  | Managers:        |     | Managers:           |     |
|  | - Product        |     | - SaleOrder         |     |
|  | - Partner        |     | - Invoice           |     |
|  | - Tax            |     | - Partner           |     |
|  | - Uom            |     | - Payment           |     |
|  |                  |     |                     |     |
|  | SyncMetrics      |     | SyncMetrics         |     |
|  +------------------+     +---------------------+     |
|          ^                          ^                  |
|          |                          |                  |
|    setActiveContext()         setActiveContext()        |
|                                                       |
+-------------------------------------------------------+
                      |
                      v
           Global OdooRecordRegistry
           (se sincroniza con contexto activo)
```

### 9.2 Codigo de Ejemplo

```dart
final layer = OdooDataLayer();
final bridge = DataLayerBridge(layer);

// Sesion POS
final posSession = DataSession(
  id: 'pos-store-1',
  label: 'POS Tienda 1',
  baseUrl: 'https://odoo.example.com',
  database: 'production',
  apiKey: 'pos_api_key',
  defaultLanguage: 'es_EC',
);

// Sesion Back-Office
final boSession = DataSession(
  id: 'back-office',
  label: 'Administracion',
  baseUrl: 'https://odoo.example.com',
  database: 'production',
  apiKey: 'admin_api_key',
);

// Inicializar POS
await layer.createAndInitializeContext(
  session: posSession,
  database: posDb,
  queueStore: posQueue,
  registerModels: (ctx) {
    ctx.registerConfig<Product>(Product.config);
    ctx.registerManager<Product>(ProductManager());
    ctx.registerConfig<Partner>(Partner.config);
    ctx.registerManager<Partner>(PartnerManager());
    ctx.enableMetrics(); // Habilitar metricas de sync
  },
  setActive: true,
);

// Inicializar Back-Office
await layer.createAndInitializeContext(
  session: boSession,
  database: boDb,
  queueStore: boQueue,
  registerModels: (ctx) {
    ctx.registerConfig<SaleOrder>(SaleOrder.config);
    ctx.registerManager<SaleOrder>(SaleOrderManager());
  },
  setActive: false,
);

// Cambiar contexto
layer.setActiveContext('back-office');

// Sync multi-contexto en paralelo
final orchestrator = DataSyncOrchestrator(layer);
final result = await orchestrator.syncAll(
  config: MultiContextSyncConfig.parallel(maxParallel: 2),
);
print('Todos exitosos: ${result.allSuccessful}');

// Escuchar cambios de contexto
layer.contextChanges.listen((contextId) {
  print('Contexto activo: $contextId');
});
```

---

## 10. Caso de Uso: Resolucion de Conflictos

### 10.1 Flujo de Deteccion

```
Local: Partner 123, write_date: 10:00, name: "Juan (local)"
Server: Partner 123, write_date: 10:15, name: "Juan (server)"
                    ^^^^^^^^^^^^
                    MAS RECIENTE

              CONFLICTO DETECTADO
                     |
                     v
           SyncConflict<Partner>
           {localRecord, serverRecord,
            conflictingFields: ['name'],
            isServerNewer: true}
                     |
                     v
        +------------+------------+
        |            |            |
        v            v            v
   serverWins   localWins    merge
        |            |            |
        v            v            v
   Descartar   Sobreescribir  Combinar
   local       servidor      campos
```

### 10.2 Estrategias

| Estrategia | Comportamiento |
|------------|----------------|
| `serverWins` | Descartar cambios locales, usar server |
| `localWins` | Sobreescribir server con local |
| `lastWriteWins` | Comparar write_date, el mas reciente gana |
| `merge` | Funcion custom para combinar campos |
| `askUser` | Mostrar UI para que el usuario decida |
| `createCopy` | Crear copia para revision manual |

### 10.3 Codigo de Ejemplo

```dart
// Configurar handler de conflictos
final conflictHandler = DefaultConflictHandler<Partner>(
  defaultStrategy: SyncConflictStrategy.lastWriteWins,
  getWriteDate: (p) => p.writeDate,
  mergeFunction: (local, server) {
    // Merge inteligente: tomar nombre del server, telefono del local
    return server.copyWith(phone: local.phone);
  },
);
```

---

## 11. Caso de Uso: Interceptores HTTP

### 11.1 Cadena de Interceptores

```
Request sale -->
        |
  +-----v-----------+
  | RateLimiter      |  Controlar req/seg por ruta
  | (token bucket)   |  write: 2/s, read: 10/s
  +-----+------------+
        |
  +-----v-----------+
  | Compression      |  Gzip si > 1KB
  | (gzip)           |
  +-----+------------+
        |
  +-----v-----------+
  | Cache            |  Verificar cache local
  | (LRU + TTL)      |  fields_get: 1h, search_read: 2min
  +-----+------------+
        |
  +-----v-----------+
  | Auth             |  Agregar Authorization header
  | (bearer token)   |  Refresh si 401
  +-----+------------+
        |
  +-----v-----------+
  | Retry            |  Reintentar si 500/503/timeout
  | (exponential)    |  3 intentos, backoff
  +-----+------------+
        |
  +-----v-----------+
  | Metrics          |  Medir latencia, tracking
  | (collector)      |  p50, p95, p99
  +-----+------------+
        |
        v
     Odoo Server
```

### 11.2 Presets de Configuracion

**RetryConfig:**
- `production` — 3 reintentos, 1s initial, 30s max
- `aggressive` — 5 reintentos, 500ms initial
- `minimal` — 2 reintentos, 200ms initial

**CacheConfig:**
- `odooDefault` — fields_get: 1h, search_read: 2min
- `aggressive` — 24h TTL, 500 entries (offline-first)
- `minimal` — 50 entries

**RateLimitConfig:**
- `odooDefault` — writes: 2-3/s, reads: 10/s
- `conservative` — 1/s global
- `moderate` — 5/s global

---

## 12. Caso de Uso: Busqueda Fuzzy y Paginacion

### 12.1 Busqueda Fuzzy

```dart
final searcher = FuzzySearch<Partner>(
  items: allPartners,
  searchableStrings: (p) => [p.name, p.email ?? '', p.vat ?? ''],
  threshold: 0.3,
  limit: 20,
);

final results = searcher.search('Juan Prez');
// Encuentra "Juan Perez" por distancia Levenshtein
// score: 0.85, matchType: levenshtein

for (final r in results) {
  print('${r.item.name} (score: ${r.score})');
}
```

Algoritmos (en orden de prioridad):
1. Match exacto (1.0)
2. Starts-with (0.9+)
3. Word starts-with (0.8+)
4. Contains (0.7+)
5. Levenshtein distance
6. Jaro-Winkler similarity

### 12.2 Paginacion

```dart
final controller = PaginatedController<Partner>(
  config: PaginatedConfig.medium, // 50 items, 500 max
  loader: (offset, limit) async {
    return partnerManager.search(
      domain: [['active', '=', true]],
      offset: offset,
      limit: limit,
      orderBy: 'name asc',
    );
  },
);

// Cargar primera pagina
await controller.loadInitial();

// Auto-cargar mas al hacer scroll
controller.onScrollPosition(0.85); // 85% scrolled -> load more

// Estado reactivo
controller.stateStream.listen((state) {
  setState(() {
    _items = state.items;
    _hasMore = state.hasMore;
    _isLoading = state.isLoading;
  });
});
```

---

## 13. Caso de Uso: Monitoreo de Conectividad

### 13.1 Arquitectura de Conectividad

```
+----------------------------+
| PollingConnectivityMonitor |  (pure Dart, sin Flutter)
| checkUrl: google/204       |
| checkInterval: 30s         |
| timeout: 5s                |
+------------+---------------+
             |
             v
+----------------------------+
| ServerHealthService        |
|----------------------------|
| Monitoreo pasivo:          |
| - recordSuccess()          |  <- intercept exitoso
| - recordFailure()          |  <- intercept fallido
|                            |
| Monitoreo activo:          |
| - healthCheck HTTP         |  <- timer periodico
| - WebSocket state          |  <- eventos WS
|                            |
| Modo offline manual:       |
| - setManualOfflineMode()   |
|                            |
| Estado:                    |
| - ConnectivityStatus       |
| - statusStream             |
+------------+---------------+
             |
             v
+----------------------------+
| ConnectivityStatus         |
|----------------------------|
| hasNetwork: bool           |
| serverState: enum          |
| webSocketConnected: bool   |
| sessionValid: bool         |
| isManualOffline: bool      |
| consecutiveFailures: int   |
| latencyMs: int?            |
|                            |
| Derivados:                 |
| .canAttemptRemote          |
| .shouldSkipRemote          |
| .isFullyOnline             |
| .needsReauth               |
+----------------------------+
```

### 13.2 Estados de Conexion

```
ServerConnectionState:
  |
  +-- online           Servidor respondiendo OK
  +-- degraded         Servidor lento o errores intermitentes
  +-- unreachable      No se puede contactar (timeout, DNS, etc.)
  +-- maintenance      502/503/504 (servidor en mantenimiento)
  +-- sessionExpired   401/403 (sesion expirada)
  +-- unknown          Estado inicial
```

### 13.3 Modo Offline Manual

```
setManualOfflineMode(true)
        |
        v
  +-----------------------------+
  | Parar timers de health check|
  | Marcar isManualOffline: true|
  | serverState: unreachable    |
  +-----------------------------+
        |
        v
  canAttemptRemote -> false
  shouldSkipRemote -> true
  (todas las ops van a cola offline)
        |
        v (usuario reactiva)
  setManualOfflineMode(false)
        |
        v
  +-----------------------------+
  | Reanudar health check timer |
  | checkHealth() inmediato     |
  | isManualOffline: false      |
  +-----------------------------+
```

### 13.4 Codigo de Ejemplo

```dart
// Monitor basico (pure Dart, sin Flutter)
final monitor = PollingConnectivityMonitor(
  checkUrl: 'https://odoo.example.com/web/health',
  checkInterval: Duration(seconds: 30),
  timeout: Duration(seconds: 5),
);
monitor.start();

// ServerHealthService completo
final healthService = ServerHealthService(
  config: ServerHealthConfig(
    normalCheckInterval: Duration(seconds: 120),
    recoveryCheckInterval: Duration(seconds: 30),
    failureThreshold: 3,
  ),
  healthCheck: () => client.searchCount(model: 'res.users', domain: []),
  getWebSocketState: () => wsService.isConnected,
  subscribeToWebSocket: (cb) => wsService.eventStream.listen(cb),
  networkMonitor: monitor,
);
await healthService.initialize();

// Escuchar estado
healthService.statusStream.listen((status) {
  if (status.isFullyOnline) {
    // Trigger sync
  } else if (status.needsReauth) {
    // Mostrar login
  } else if (status.shouldSkipRemote) {
    // Modo offline
  }
});

// Toggle modo avion manual
healthService.setManualOfflineMode(true);
print(healthService.isManualOffline); // true
print(healthService.status.canAttemptRemote); // false

// Verificacion puntual
final status = await healthService.forceCheck();
print('Server: ${status.serverState.name}');
print('Latency: ${status.latencyMs}ms');
```

---

## 14. Caso de Uso: Metricas de Sincronizacion

### 14.1 Arquitectura de Metricas

```
DataContext
  |
  +-- SyncMetricsCollector (lazy, habilitado con enableMetrics())
        |
        +-- record(SyncOperationMetric)
        |     por cada sync completado
        |
        +-- timed(model, () => syncOp)
        |     auto-timing wrapper
        |
        +-- getModelMetrics(model)
        |     -> ModelSyncMetrics
        |        totalOps, successRate, conflictRate
        |        avgDuration, p50, p95, p99
        |
        +-- getGlobalMetrics()
              -> GlobalSyncMetrics
                 byModel, totalOps, overallSuccessRate
```

### 14.2 Codigo de Ejemplo

```dart
// Habilitar metricas en el contexto
context.enableMetrics(maxMetrics: 1000);

// Los syncs registran metricas automaticamente
await context.syncAll();
await context.syncModel('res.partner');

// Consultar metricas por modelo
final partnerMetrics = context.metrics.getModelMetrics('res.partner');
if (partnerMetrics != null) {
  print('Total syncs: ${partnerMetrics.totalOperations}');
  print('Success rate: ${partnerMetrics.successRate}%');
  print('Avg duration: ${partnerMetrics.averageDurationMs}ms');
  print('P95 latency: ${partnerMetrics.p95DurationMs}ms');
  print('Conflict rate: ${partnerMetrics.conflictRate}%');
}

// Metricas globales
final global = context.metrics.getGlobalMetrics(
  window: Duration(hours: 24), // ultimas 24h
);
print('Total ops: ${global.totalOperations}');
print('Records synced: ${global.totalRecordsSynced}');
print('Overall success: ${global.overallSuccessRate}%');

// Modelos mas lentos
for (final m in global.modelsByDuration.take(3)) {
  print('${m.model}: avg ${m.averageDurationMs}ms');
}

// Escuchar metricas en tiempo real
context.metrics.addCallback((metric) {
  print('Sync: ${metric.model} in ${metric.durationMs}ms '
      '(${metric.recordsSynced} records)');
});
```

---

## 15. Caso de Uso: Seguridad

### 15.1 Certificate Pinning (SHA-256)

```
OdooClientConfig
  |
  +-- certificatePinning: CertificatePinningConfig?
        |
        +-- sha256Pins: Set<String>     (Base64-encoded SHA-256 hashes)
        +-- allowSystemCertificates: bool (default: false)
```

```
Request HTTPS
     |
     v
Dio IOHttpClientAdapter
     |
     v
badCertificateCallback
     |
     v
+----------------------------+
| Calcular SHA-256 del cert  |
| DER → sha256 → base64     |
+----------------------------+
     |
     v
  ¿Pin match?
  +---+---+
  |       |
  v       v
 SI      NO
  |       |
  v       v
ACCEPT  ¿allowSystemCertificates?
          +---+---+
          |       |
          v       v
         SI      NO
          |       |
          v       v
        system  REJECT
        validate (MITM blocked)
```

```dart
// Configurar certificate pinning
final client = OdooClient(config: OdooClientConfig(
  baseUrl: 'https://odoo.example.com',
  apiKey: 'key_abc123',
  database: 'production',
  certificatePinning: CertificatePinningConfig(
    sha256Pins: {
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // cert actual
      'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // backup/rotacion
    },
    allowSystemCertificates: false, // solo confiar en pins
  ),
));

// Sin pinning (default) — usa validacion del sistema
final client = OdooClient(config: OdooClientConfig(
  baseUrl: 'https://odoo.example.com',
  apiKey: 'key_abc123',
  database: 'production',
  // certificatePinning: null (default)
));
```

### 15.2 Sanitizacion Automatica de Logs

```
                PIPELINE DE SANITIZACION
                ========================

Codigo genera log:
  logger.e('[Sync]', 'Error: user john@mail.com token=abc123xyz...');
     |
     v
AppLogger._log() [_sanitizeEnabled = true]
     |
     v
ErrorSanitizer.sanitize(message)
  - Email: john@mail.com → [REDACTED]
  - Token: abc123xyz... → [REDACTED]
  - Passwords: password=xxx → [REDACTED]
  - IPs: 192.168.1.1 → [REDACTED]
  - Credit cards → [REDACTED]
     |
     v
Output: '[Sync] Error: user [REDACTED] [REDACTED]'
```

```
OdooException.toString()
     |
     v
data map → CredentialMasker.maskMap(data)
  - apiKey: "secret123" → "se*****23"
  - password: "xxx" → "********"
  - token: "abc" → "***"
```

```
DataSession.toString()
     |
     v
'DataSession(pos-1, POS, https://odoo.com/prod, key: ke********23)'
                                                       ^^^^^^^^^^^^
                                                   CredentialMasker.mask()
```

```dart
// Sanitizacion habilitada por defecto
logger.e('[Auth]', 'Login failed for admin@example.com');
// Output: '[Auth] Login failed for [REDACTED]'

// Desactivar para debugging local
logger.setSanitization(false);
logger.e('[Auth]', 'Login failed for admin@example.com');
// Output: '[Auth] Login failed for admin@example.com'

// Sanitizar headers HTTP para logging
final safeHeaders = LogSanitizerInterceptor.sanitizeHeaders({
  'Authorization': 'bearer my_secret_api_key_12345',
  'Content-Type': 'application/json',
  'Cookie': 'session_id=abc123',
});
// {Authorization: my*****************45, Content-Type: application/json, Cookie: se*****23}

// Sanitizar URLs con query params sensibles
final safeUrl = LogSanitizerInterceptor.sanitizeUrl(
  'https://api.example.com/data?api_key=secret123&page=1',
);
// https://api.example.com/data?api_key=se*****23&page=1
```

### 15.3 Almacenamiento Seguro de Credenciales

```
                ARQUITECTURA DE CREDENCIALES
                ============================

+----------------------------------------------+
|  App Flutter                                  |
|  +----------------------------------------+  |
|  | FlutterSecureStore                      |  |
|  | implements SecureCredentialStore         |  |
|  | (iOS Keychain / Android Keystore)       |  |
|  +-------------------+--------------------+  |
+----------------------|------------------------+
                       |
                       v
+----------------------------------------------+
|  odoo_sdk                                     |
|                                               |
|  SecureCredentialStore (interfaz abstracta)    |
|    store(key, value)                          |
|    retrieve(key) → String?                    |
|    delete(key)                                |
|    deleteAll()                                |
|    containsKey(key)                           |
|                                               |
|  CredentialKeys (constantes)                  |
|    .apiKey         = 'odoo_api_key'           |
|    .sessionId      = 'odoo_session_id'        |
|    .sessionToken   = 'odoo_session_token'     |
|    .refreshToken   = 'odoo_refresh_token'     |
|    .scoped(ctxId, key) = 'ctxId:key'          |
|                                               |
|  CredentialGuard (cache + auto-clear)         |
|    get(key) → lazy load from store            |
|    set(key, value) → cache + store            |
|    clearMemoryCache() → solo RAM              |
|    deleteAll() → RAM + store                  |
|    autoClearAfter: 5 min (configurable)       |
+----------------------------------------------+
```

```
CredentialGuard lifecycle:
     |
     v
  get('odoo_api_key')
     |
  ¿En cache?
  +---+---+
  |       |
  v       v
 SI      NO
  |       |
  v       v
Return  store.retrieve(scoped_key)
cached     |
value      v
        Cache + start timer
           |
           v
        Return value
           |
           v (5 min sin acceso)
        Auto-clear cache
        (store intacto)
```

```dart
// 1. La app implementa la interfaz
class MySecureStore implements SecureCredentialStore {
  final storage = FlutterSecureStorage();

  @override
  Future<void> store(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<String?> retrieve(String key) =>
      storage.read(key: key);

  @override
  Future<void> delete(String key) =>
      storage.delete(key: key);

  @override
  Future<void> deleteAll() => storage.deleteAll();

  @override
  Future<bool> containsKey(String key) =>
      storage.containsKey(key: key);
}

// 2. Crear guard por contexto
final guard = CredentialGuard(
  store: MySecureStore(),
  contextId: 'pos-store-1',
  autoClearAfter: Duration(minutes: 5),
);

// 3. Usar
await guard.setApiKey('my_secret_api_key');
final key = await guard.getApiKey(); // lazy-load from store

// 4. Limpiar en logout / app pause
guard.clearMemoryCache(); // solo RAM, store intacto

// 5. Eliminar todo en logout definitivo
await guard.deleteAll(); // RAM + store

// Multi-contexto: cada guard tiene su scope
final posGuard = CredentialGuard(store: store, contextId: 'pos');
final boGuard = CredentialGuard(store: store, contextId: 'back-office');
// Almacena como 'pos:odoo_api_key' y 'back-office:odoo_api_key'
// No se interfieren entre si
```

---

## 16. Caso de Uso: Sync Avanzado

### 16.1 Sync Selectivo de Campos

```
                SYNC COMPLETO (default)
                =======================

syncFromOdoo()  →  fields: odooFields  →  TODOS los campos configurados
                   (id, name, email, phone, street, city,
                    country_id, write_date, create_date, ...)

                SYNC SELECTIVO
                ==============

syncFromOdoo(selectedFields: ['name', 'email'])
     |
     v
_resolveFields(['name', 'email'])
     |
     v
  1. Intersectar con odooFields (ignorar campos invalidos)
  2. Agregar campos mandatorios: {id, write_date, create_date}
     |
     v
  fields: ['id', 'write_date', 'create_date', 'name', 'email']
     |
     v
  searchRead(fields: ...) → menos datos, mas rapido
```

```
Jerarquia de filtrado de campos:

1. FieldDefinition (definicion del modelo)
   syncFromOdoo: true/false     ← Excluir campo del sync permanentemente
   localOnly: true/false         ← Campo solo local, nunca se sincroniza
   isComputed: true/false        ← Calculado, no se fetchea

2. SyncConfig (configuracion del modelo)
   alwaysFetchFields: [...]      ← Siempre incluir estos
   excludeFromSync: [...]        ← Nunca incluir estos

3. Runtime (por llamada)
   selectedFields: [...]         ← Solo estos en ESTA llamada
   + mandatoryFields: {id, write_date, create_date}  (siempre)
```

```dart
// Sync completo (default — todos los campos)
final result = await partnerManager.syncFromOdoo();

// Sync selectivo — solo nombre y email (mas rapido, menos bandwidth)
final result = await partnerManager.syncFromOdoo(
  selectedFields: ['name', 'email'],
);
// Internamente: fields = ['id', 'write_date', 'create_date', 'name', 'email']

// Sync selectivo + incremental
final result = await partnerManager.syncFromOdoo(
  since: lastSyncDate,
  selectedFields: ['name', 'phone', 'email'],
);

// Bidireccional selectivo (upload completo + download selectivo)
final result = await partnerManager.sync(
  selectedFields: ['name', 'email', 'phone'],
);

// Descubrir campos disponibles
final fields = partnerManager.selectableFields;
// ['id', 'name', 'email', 'phone', 'street', 'city', ...]

// Campos invalidos se ignoran silenciosamente
final result = await partnerManager.syncFromOdoo(
  selectedFields: ['name', 'campo_inexistente'],
);
// Solo sincroniza: ['id', 'write_date', 'create_date', 'name']
```

### 16.2 Persistencia de Metricas

```
                METRICAS IN-MEMORY (default)
                ============================

SyncMetricsCollector()  →  _metrics: List<SyncOperationMetric>
                           (se pierde al reiniciar app)

                METRICAS CON PERSISTENCIA
                =========================

SyncMetricsCollector(persistence: myPersistence)
     |
     v
record(metric)
     |
     +→ _metrics.add(metric)       (in-memory)
     +→ persistence.saveMetric()   (write-through, fire-and-forget)

loadFromPersistence()
     |
     v
persistence.loadMetrics() → _metrics
     (restaurar metricas al reiniciar)

clear(clearPersistence: true)
     |
     +→ _metrics.clear()           (in-memory)
     +→ persistence.clearMetrics() (storage)
```

```
SyncOperationMetric serialization:

  toJson() → {
    'model': 'res.partner',
    'startTime': '2026-02-08T10:00:00.000',
    'endTime': '2026-02-08T10:00:02.500',
    'status': 'success',
    'recordsSynced': 150,
    'recordsFailed': 0,
    'conflictsDetected': 2,
  }

  fromJson(map) → SyncOperationMetric(...)

Round-trip: metric → toJson() → fromJson() → metric igual
```

```dart
// 1. La app implementa la interfaz
class DriftMetricsPersistence implements SyncMetricsPersistence {
  final MyDatabase _db;
  DriftMetricsPersistence(this._db);

  @override
  Future<void> saveMetric(SyncOperationMetric metric) async {
    await _db.syncMetricsTable.insertOne(metric.toJson());
  }

  @override
  Future<List<SyncOperationMetric>> loadMetrics({DateTime? since}) async {
    final rows = since != null
        ? await _db.syncMetricsTable.where((t) => t.startTime.isAfter(since))
        : await _db.syncMetricsTable.all();
    return rows.map((r) => SyncOperationMetric.fromJson(r)).toList();
  }

  @override
  Future<void> clearMetrics({DateTime? before}) async {
    if (before == null) {
      await _db.syncMetricsTable.deleteAll();
    } else {
      await _db.syncMetricsTable.where((t) => t.startTime.isBefore(before)).delete();
    }
  }

  @override
  Future<int> metricsCount() async =>
      await _db.syncMetricsTable.count();
}

// 2. Crear collector con persistencia
final collector = SyncMetricsCollector(
  maxMetrics: 1000,
  persistence: DriftMetricsPersistence(db),
);

// 3. Restaurar metricas al iniciar app
final loaded = await collector.loadFromPersistence(
  since: DateTime.now().subtract(Duration(days: 7)), // ultima semana
);
print('Restauradas $loaded metricas');

// 4. Las metricas se persisten automaticamente via write-through
await context.syncAll(); // record() → saveMetric() automatico

// 5. Limpiar
collector.clear(); // solo memoria
collector.clear(clearPersistence: true); // memoria + storage

// 6. Sin persistencia (backward compatible)
final collector = SyncMetricsCollector(); // funciona como antes
print(collector.hasPersistence); // false
```

---

## 17. API Completa por Capa

### Capa 1: HTTP (OdooClient)

| Metodo | Descripcion |
|--------|-------------|
| `searchRead()` | Buscar + leer con dominio |
| `searchCount()` | Contar registros |
| `read()` | Leer por IDs |
| `write()` | Actualizar registros |
| `create()` | Crear registro |
| `unlink()` | Eliminar registros |
| `call()` | Llamar metodo arbitrario |
| `fieldsGet()` | Metadata de campos |
| `getModifiedSince()` | Sync incremental |
| `createBatch()` | Crear multiples |
| `updateBatch()` | Actualizar multiples |
| `deleteBatch()` | Eliminar multiples |
| `executeBatch()` | Operaciones mixtas |

### Capa 2: Session (OdooSessionManager)

| Metodo | Descripcion |
|--------|-------------|
| `authenticateSession()` | Autenticar con strategy chain + auto-persist |
| `logout()` | Server-side destroy + limpiar local + persistence |
| `isSessionValid()` | Verificar sesion valida contra servidor |
| `restoreSession()` | Restaurar sesion desde persistence |
| `initializeFromStorage()` | Restore + validate (para startup) |
| `getSessionInfo()` | Info de sesion (cached 5 min) |
| `createWebSession()` | Establecer cookies para WebSocket |
| `callJsonRpc()` | Llamar endpoint JSON-RPC |
| `clearSession()` | Limpiar sesion local |

### Capa 3: Manager (OdooModelManager\<T\>)

| Metodo | Descripcion |
|--------|-------------|
| `create(T)` | Crear (offline-first) |
| `read(id)` | Leer local + refresh |
| `update(T)` | Actualizar local + sync |
| `delete(id)` | Eliminar local + sync |
| `search()` | Buscar local |
| `all()` | Todos los registros |
| `first()` | Primer match |
| `exists(id)` | Verificar existencia |
| `findByIds()` | Buscar por lista de IDs |
| `createBatch()` | Crear multiples |
| `updateBatch()` | Actualizar multiples |
| `deleteBatch()` | Eliminar multiples |
| `syncFromOdoo()` | Download del servidor |
| `syncToOdoo()` | Upload al servidor |
| `watchLocalRecord()` | Stream de un registro |
| `watchLocalSearch()` | Stream de busqueda |
| `recordChanges` | Stream de cambios |
| `unsyncedCount` | Cambios pendientes |
| `syncInProgress` | Flag de sync activo |

### Capa 4: DataContext

| Metodo | Descripcion |
|--------|-------------|
| `registerConfig<T>()` | Registrar config modelo |
| `registerManager<T>()` | Registrar manager |
| `initialize()` | Inicializar contexto |
| `managerFor<T>()` | Obtener manager por tipo |
| `managerByModel()` | Obtener por nombre |
| `syncAll()` | Sync todos los modelos (con metricas) |
| `syncModel()` | Sync un modelo (con metricas) |
| `enableMetrics()` | Habilitar colector de metricas |
| `metrics` | Acceso al SyncMetricsCollector |
| `handleWebSocketEvent()` | Procesar evento WS |
| `dispose()` | Liberar recursos |

### Capa 5: OdooDataLayer

| Metodo | Descripcion |
|--------|-------------|
| `createContext()` | Crear contexto |
| `createAndInitializeContext()` | Crear + init |
| `getContext()` | Obtener por ID |
| `setActiveContext()` | Cambiar activo |
| `disposeContext()` | Eliminar contexto |
| `contextChanges` | Stream de cambios |
| `dispose()` | Liberar todo |

### Capa 6: Offline Queue

| Metodo | Descripcion |
|--------|-------------|
| `enqueue()` | Agregar operacion a cola |
| `processQueue()` | Procesar operaciones pendientes |
| `getPending()` | Obtener operaciones pendientes |
| `cleanupStaleOperations()` | Eliminar operaciones antiguas |
| `compressQueue()` | Fusionar writes duplicados |
| `purgeDeadLetterQueue()` | Eliminar dead letters |
| `enforceMaxSize()` | Limitar tamano de cola |
| `getStats()` | Estadisticas de cola |

### Capa 7: Conectividad

| Metodo | Descripcion |
|--------|-------------|
| `ServerHealthService.initialize()` | Iniciar monitoreo |
| `ServerHealthService.checkHealth()` | Health check activo |
| `ServerHealthService.forceCheck()` | Forzar verificacion |
| `ServerHealthService.recordSuccess()` | Registrar exito (pasivo) |
| `ServerHealthService.recordFailure()` | Registrar fallo (pasivo) |
| `ServerHealthService.setManualOfflineMode()` | Toggle offline manual |
| `PollingConnectivityMonitor.start()` | Iniciar polling |
| `PollingConnectivityMonitor.checkConnectivity()` | Check puntual |

### Capa 8: Seguridad

| Metodo | Descripcion |
|--------|-------------|
| `CertificatePinningConfig(sha256Pins)` | Config de SHA-256 pins para HTTPS |
| `OdooClientConfig(certificatePinning:)` | Activar pinning en cliente HTTP |
| `AppLogger.setSanitization(bool)` | Toggle sanitizacion automatica de logs |
| `ErrorSanitizer.sanitize(message)` | Redactar PII de un string |
| `ErrorSanitizer.sanitizeStackTrace(st)` | Redactar paths de stack trace |
| `CredentialMasker.mask(value)` | Enmascarar credencial (show 2+2 chars) |
| `CredentialMasker.maskMap(map)` | Enmascarar mapa con keys sensibles |
| `LogSanitizerInterceptor.sanitizeHeaders()` | Enmascarar headers Authorization/Cookie |
| `LogSanitizerInterceptor.sanitizeUrl()` | Enmascarar query params sensibles en URL |
| `SecureCredentialStore` | Interfaz abstracta para almacenamiento seguro |
| `CredentialGuard(store, contextId)` | Cache con auto-clear y context scoping |
| `CredentialGuard.getApiKey()` | Obtener API key (lazy-load from store) |
| `CredentialGuard.clearMemoryCache()` | Limpiar cache (store intacto) |
| `CredentialKeys.scoped(ctxId, key)` | Generar key con scope de contexto |

### Capa 9: Sync Avanzado

| Metodo | Descripcion |
|--------|-------------|
| `syncFromOdoo(selectedFields:)` | Sync selectivo de campos |
| `sync(selectedFields:)` | Bidireccional con campos selectivos |
| `selectableFields` | Lista de campos disponibles para sync selectivo |
| `SyncOperationMetric.toJson()` | Serializar metrica a JSON |
| `SyncOperationMetric.fromJson(map)` | Deserializar metrica de JSON |
| `SyncMetricsCollector(persistence:)` | Crear collector con persistencia |
| `SyncMetricsCollector.loadFromPersistence()` | Restaurar metricas de storage |
| `SyncMetricsCollector.hasPersistence` | Verificar si persistence esta configurado |
| `SyncMetricsPersistence` | Interfaz abstracta para persistir metricas |

---

## 18. Gaps y Mejoras Pendientes

No hay gaps pendientes. Todas las mejoras identificadas han sido implementadas.

---

## Flujo Completo: Inicializacion de App

```
1. SPLASH SCREEN
   |
   v
2. Crear DataSession con credenciales
   |   session = DataSession(id, label, baseUrl, database, apiKey)
   |   errores = session.validate()
   |
   v
3. Configurar seguridad
   |   guard = CredentialGuard(store: MySecureStore(), contextId: session.id)
   |   await guard.setApiKey(apiKey)
   |   // Certificate pinning via OdooClientConfig.certificatePinning
   |
   v
4. Crear OdooDataLayer + DataLayerBridge
   |   layer = OdooDataLayer()
   |   bridge = DataLayerBridge(layer)
   |
   v
5. Inicializar contexto con modelos
   |   await bridge.initialize(
   |     session: session,
   |     database: driftDb,
   |     queueStore: queueStore,
   |     registerModels: (ctx) {
   |       ctx.registerConfig<Partner>(Partner.config);
   |       ctx.registerManager<Partner>(PartnerManager());
   |       ctx.enableMetrics();
   |       // ... mas modelos
   |     },
   |   );
   |
   v
6. Restaurar metricas (si hay persistence)
   |   await context.metrics.loadFromPersistence(
   |     since: DateTime.now().subtract(Duration(days: 7)),
   |   );
   |
   v
7. Restaurar sesion (si hay persistence)
   |   restored = await client.session.initializeFromStorage();
   |   if (restored == null) -> LOGIN SCREEN
   |
   v
8. Iniciar monitoreo de conectividad
   |   monitor = PollingConnectivityMonitor(...)
   |   healthService = ServerHealthService(networkMonitor: monitor)
   |   await healthService.initialize()
   |
   v
9. Conectar WebSocket (opcional)
   |   wsService.connect(connectionInfo);
   |
   v
10. Sync inicial (selectivo o completo)
   |   report = await bridge.syncAll();
   |   // o selectivo: manager.syncFromOdoo(selectedFields: ['name', 'email'])
   |
   v
11. Limpieza de cola offline
   |   await queue.cleanupStaleOperations();
   |   await queue.compressQueue();
   |
   v
12. HOME SCREEN (datos locales + sync background)
```
