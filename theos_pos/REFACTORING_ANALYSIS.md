# Análisis de Refactorización - Migración Avanzada a theos_pos_core

## Enfoque: Arquitecto de Software especializado en Flutter y Clean Architecture

Fecha: 2026-01-24
Analista: Claude (Especialista en Refactorización)

---

## 📊 Situación Actual

**68 archivos restantes con imports locales:**
- 15 datasources (usan AppDatabase)
- 12 repositories (usan DatabaseHelper, BaseRepository)
- 19 services (dependencias variadas)
- 22 providers (Riverpod state management)

**Conclusión previa:** "NO migrables porque tienen dependencias obligatorias del database layer"

**Nueva perspectiva:** Con refactorización arquitectónica PROFUNDA, SÍ es posible migrar la mayoría.

---

## 🔍 Hallazgos Clave del Análisis

### 1. BaseRepository YA está abstraído

```dart
// lib/core/database/repositories/base_repository.dart
abstract class BaseRepository extends core.BaseRepository<DatabaseHelper> {
  BaseRepository({super.odooClient, required super.db});
}
```

**Observación:** BaseRepository extiende de `odoo_offline_core.BaseRepository<DatabaseHelper>`.
- El tipo `DatabaseHelper` es genérico en el package core
- `DatabaseHelper` implementa `IOdooDatabase` (interfaz común)
- **CONCLUSIÓN:** BaseRepository puede generalizarse fácilmente

### 2. Datasources usan solo AppDatabase

```dart
class PartnerDatasource {
  final AppDatabase _db;  // ← ÚNICA dependencia hard

  Future<Partner?> getPartner(int id) async {
    return await _db.partners.getSingle(id);  // ← Operación Drift
  }
}
```

**Observación:**
- AppDatabase es código generado por Drift
- Las operaciones son predecibles: `select()`, `insert()`, `update()`, `delete()`
- **CONCLUSIÓN:** Podemos abstraer con interfaces

### 3. Repositories usan Datasources por DI

```dart
class ClientRepository extends BaseRepository {
  final PartnerDatasource _partnerDatasource;  // ← Inyección de dependencias

  ClientRepository({
    required PartnerDatasource partnerDatasource,
    // ...
  }) : _partnerDatasource = partnerDatasource;
}
```

**Observación:**
- Ya usan dependency injection
- No acceden a AppDatabase directamente
- **CONCLUSIÓN:** Repositories pueden depender de interfaces abstractas

### 4. ResCompany: Importado pero poco usado

```bash
# Búsqueda de uso real de campos de ResCompany
$ grep "company\." lib/features/clients/services/*.dart
# Resultado: Solo imports, sin uso de campos en muchos casos
```

**Observación:**
- Muchos services importan ResCompany pero no lo usan
- Los que sí lo usan acceden a pocos campos (credit config)
- **CONCLUSIÓN:** Podemos usar interfaces solo con campos necesarios

### 5. Providers son específicos de Riverpod

**Observación:**
- Los providers son configuración/glue code
- No tienen lógica de negocio significativa
- **CONCLUSIÓN:** Deben permanecer en theos_pos (correcto como está)

---

## 🎯 Estrategias de Refactorización

### ESTRATEGIA 1: Abstracción de Datasources ⭐⭐⭐⭐⭐

**Concepto:** Definir interfaces abstractas en theos_pos_core, implementar en theos_pos

#### En theos_pos_core:

```dart
// lib/src/datasources/partner_datasource.dart
abstract class IPartnerDatasource {
  Future<List<Partner>> getPartners();
  Future<Partner?> getPartner(int id);
  Future<void> upsertPartner(Partner partner);
  Future<void> deletePartner(int id);
  Future<List<Partner>> searchPartners(String query, {int limit = 20});
}
```

#### En theos_pos:

```dart
// lib/features/clients/datasources/partner_datasource.dart
import 'package:theos_pos_core/theos_pos_core.dart' show IPartnerDatasource, Partner;
import '../../../core/database/database.dart';

class PartnerDatasource implements IPartnerDatasource {
  final AppDatabase _db;

  PartnerDatasource({required AppDatabase db}) : _db = db;

  @override
  Future<Partner?> getPartner(int id) async {
    final row = await _db.partners.getSingle(id);
    return row != null ? Partner.fromDrift(row) : null;
  }

  @override
  Future<List<Partner>> getPartners() async {
    final rows = await _db.partners.all().get();
    return rows.map((r) => Partner.fromDrift(r)).toList();
  }

  // ... resto de implementación
}
```

**Ventajas:**
- ✅ Lógica de negocio separada de acceso a datos
- ✅ Repositorios pueden migrar a core
- ✅ Testing más fácil (mock interfaces)
- ✅ Reutilización entre apps

**Desventajas:**
- ⚠️ Más código inicial (interfaces)
- ⚠️ Dos archivos por datasource (interfaz + implementación)

**Esfuerzo:** Alto (15 interfaces + modificar 15 implementaciones)
**Impacto:** Alto (habilita migración de repositories)
**Recomendación:** ⭐⭐⭐⭐⭐ ALTAMENTE RECOMENDADO

---

### ESTRATEGIA 2: Repository Pattern Mejorado ⭐⭐⭐⭐⭐

**Concepto:** Migrar repositories a core, que dependen de interfaces de datasources

#### En theos_pos_core:

```dart
// lib/src/repositories/base_repository.dart
abstract class BaseRepository<TDb extends IOdooDatabase>
    extends core.BaseRepository<TDb> {
  BaseRepository({super.odooClient, required super.db});
}

// lib/src/repositories/client_repository.dart
class ClientRepository<TDb extends IOdooDatabase>
    extends BaseRepository<TDb> {
  final IPartnerDatasource _partnerDatasource;
  final IUserDatasource _userDatasource;
  final ICompanyDatasource _companyDatasource;

  ClientRepository({
    required IPartnerDatasource partnerDatasource,
    required IUserDatasource userDatasource,
    required ICompanyDatasource companyDatasource,
    super.odooClient,
    required super.db,
  })  : _partnerDatasource = partnerDatasource,
        _userDatasource = userDatasource,
        _companyDatasource = companyDatasource;

  Future<Client?> getById(int clientId) async {
    return await _partnerDatasource.getPartner(clientId);
  }

  // ... resto de lógica de negocio
}
```

#### En theos_pos (provider/glue code):

```dart
// lib/features/clients/providers/client_repository_provider.dart
import 'package:theos_pos_core/theos_pos_core.dart' show ClientRepository;

final clientRepositoryProvider = Provider<ClientRepository<DatabaseHelper>?>((ref) {
  final odooClient = ref.watch(odooClientProvider);
  final db = ref.watch(databaseHelperProvider);

  if (db == null) return null;

  return ClientRepository<DatabaseHelper>(
    partnerDatasource: PartnerDatasource(db: DatabaseHelper.db),
    userDatasource: UserDatasource(db: DatabaseHelper.db),
    companyDatasource: CompanyDatasource(db: DatabaseHelper.db),
    odooClient: odooClient,
    db: db,
  );
});
```

**Ventajas:**
- ✅ Toda la lógica de negocio en core (testeable, reutilizable)
- ✅ Acceso a datos queda en app (específico de Drift)
- ✅ Clean Architecture perfecta (dependencias invertidas)
- ✅ Múltiples apps pueden reutilizar la misma lógica

**Desventajas:**
- ⚠️ Requiere Estrategia 1 primero
- ⚠️ Provider glue code en cada app

**Esfuerzo:** Medio-Alto (después de Estrategia 1)
**Impacto:** Muy Alto (12 repositories migrados)
**Recomendación:** ⭐⭐⭐⭐⭐ ALTAMENTE RECOMENDADO

---

### ESTRATEGIA 3: Interface-Based Company Config ⭐⭐⭐⭐

**Concepto:** Services dependen solo de interfaces con campos necesarios, no del modelo completo

#### En theos_pos_core:

```dart
// lib/src/config/company_config.dart
abstract class ICompanyConfig {
  // Credit control
  int get creditOverdueDaysThreshold;
  int get creditOverdueInvoicesThreshold;
  double get maxDiscountPercentage;
  int get creditOfflineSafetyMargin;
  int get creditDataMaxAgeHours;

  // Sales config
  int? get defaultPartnerId;
  int? get defaultPricelistId;
  int? get defaultPaymentTermId;
  int? get defaultWarehouseId;

  // Ecuador SRI
  double? get saleCustomerInvoiceLimitSri;
  bool get l10nEcProductionEnv;
}

// lib/src/services/credit_validation_service.dart
class CreditValidationService {
  final ICompanyConfig config;

  CreditValidationService(this.config);

  bool isOverdueRisky(int overdueDays) {
    return overdueDays > config.creditOverdueDaysThreshold;
  }

  bool hasExcessiveOverdueInvoices(int count) {
    return count > config.creditOverdueInvoicesThreshold;
  }

  bool isDiscountExcessive(double discount) {
    return discount > config.maxDiscountPercentage;
  }
}
```

#### En theos_pos:

```dart
// lib/shared/models/res_company.model.dart
@freezed
class ResCompany with _$ResCompany implements ICompanyConfig {
  const factory ResCompany({
    required int id,
    required String name,
    // Implementa ICompanyConfig
    @Default(30) int creditOverdueDaysThreshold,
    @Default(3) int creditOverdueInvoicesThreshold,
    @Default(100.0) double maxDiscountPercentage,
    @Default(10) int creditOfflineSafetyMargin,
    @Default(24) int creditDataMaxAgeHours,
    int? defaultPartnerId,
    int? defaultPricelistId,
    int? defaultPaymentTermId,
    int? defaultWarehouseId,
    double? saleCustomerInvoiceLimitSri,
    @Default(false) bool l10nEcProductionEnv,

    // Campos adicionales específicos de app
    @Default(false) bool pedirEndCustomerData,
    @Default(false) bool pedirSaleReferrer,
    @Default(false) bool pedirTipoCanalCliente,
    String? l10nEcLegalName,
    String? l10nEcComercialName,
    // ... más campos app-specific
  }) = _ResCompany;
}

// Provider
final companyConfigProvider = Provider<ICompanyConfig?>((ref) {
  final company = ref.watch(resCompanyProvider);
  return company; // ResCompany implementa ICompanyConfig
});
```

#### En theos_pos_core (services):

```dart
// Los services solo conocen ICompanyConfig
class ClientCreditService {
  final ICompanyConfig config;
  final ClientCalculatorService calculator;

  ClientCreditService({
    required this.config,
    required this.calculator,
  });

  CreditValidationResult validateCredit(Client client) {
    final overdueDays = calculator.calculateOverdueDays(client);

    if (overdueDays > config.creditOverdueDaysThreshold) {
      return CreditValidationResult.blocked(
        reason: 'Cliente tiene $overdueDays días de mora (límite: ${config.creditOverdueDaysThreshold})',
      );
    }

    return CreditValidationResult.approved();
  }
}
```

**Ventajas:**
- ✅ Services en core NO conocen ResCompany
- ✅ Solo dependen de lo que realmente necesitan (ISP - Interface Segregation)
- ✅ ResCompany puede tener campos app-specific sin afectar core
- ✅ Fácil testing (mock ICompanyConfig)

**Desventajas:**
- ⚠️ Interfaces adicionales
- ⚠️ Si se agregan campos, hay que actualizar interfaz

**Esfuerzo:** Medio (1 interfaz + actualizar 5 services)
**Impacto:** Medio-Alto (5 services migrados)
**Recomendación:** ⭐⭐⭐⭐ RECOMENDADO

---

### ESTRATEGIA 4: Generic Services (Alternativa) ⭐⭐⭐

**Concepto:** Services genéricos con callbacks para acceder a configuración

#### En theos_pos_core:

```dart
class CreditService<TCompany> {
  final TCompany Function() getCompany;
  final int Function(TCompany) getCreditThreshold;
  final int Function(TCompany) getOverdueInvoicesThreshold;

  CreditService({
    required this.getCompany,
    required this.getCreditThreshold,
    required this.getOverdueInvoicesThreshold,
  });

  bool checkCreditLimit(Client client) {
    final company = getCompany();
    final threshold = getCreditThreshold(company);
    return client.creditLimit > threshold;
  }
}
```

#### En theos_pos:

```dart
final creditService = CreditService<ResCompany>(
  getCompany: () => ref.read(resCompanyProvider)!,
  getCreditThreshold: (c) => c.creditOverdueDaysThreshold,
  getOverdueInvoicesThreshold: (c) => c.creditOverdueInvoicesThreshold,
);
```

**Ventajas:**
- ✅ Totalmente type-safe
- ✅ No requiere interfaces
- ✅ Muy flexible

**Desventajas:**
- ⚠️ Sintaxis verbose (muchos callbacks)
- ⚠️ Menos descubrible que interfaces
- ⚠️ Callbacks en cada provider

**Esfuerzo:** Medio
**Impacto:** Medio
**Recomendación:** ⭐⭐⭐ ACEPTABLE (alternativa si no queremos interfaces)

---

### ESTRATEGIA 5: Separación Company Base/Extended ⭐⭐

**Concepto:** Modelo base en core, modelo extendido en app

#### Problema con Freezed:

```dart
// ❌ NO FUNCIONA - Freezed no soporta herencia
@freezed
class ResCompany extends Company with _$ResCompany { ... }
```

#### Solución con Composición:

```dart
// En theos_pos_core:
@freezed
class Company with _$Company {
  const factory Company({
    required int id,
    required String name,
    @Default(30) int creditOverdueDaysThreshold,
    @Default(100.0) double maxDiscountPercentage,
    // ... campos básicos
  }) = _Company;
}

// En theos_pos:
@freezed
class ResCompany with _$ResCompany {
  const factory ResCompany({
    required Company base,
    @Default(false) bool pedirEndCustomerData,
    @Default(false) bool pedirSaleReferrer,
    // ... campos específicos Ecuador
  }) = _ResCompany;

  // Delegates para acceso conveniente
  int get id => base.id;
  String get name => base.name;
  int get creditOverdueDaysThreshold => base.creditOverdueDaysThreshold;
}
```

**Ventajas:**
- ✅ Separación clara base/extendido
- ✅ Reutilización de Company en otras apps

**Desventajas:**
- ⚠️ Muchos delegates (boilerplate)
- ⚠️ Composición vs herencia (menos natural)
- ⚠️ Migraciones complejas (cambiar toda la estructura)

**Esfuerzo:** Muy Alto
**Impacto:** Medio (solo beneficia si múltiples apps comparten Company)
**Recomendación:** ⭐⭐ NO RECOMENDADO (Estrategia 3 es mejor)

---

## 📋 Plan de Refactorización Recomendado

### FASE 1: Abstracción de Datasources (3-5 días)

**Objetivo:** Crear interfaces abstractas para todos los datasources

1. **Crear interfaces en theos_pos_core** (15 interfaces):
   - `IPartnerDatasource`
   - `IUserDatasource`
   - `IProductDatasource`
   - `ISaleOrderDatasource`
   - `ISaleOrderLineDatasource`
   - `IAdvanceDatasource`
   - `IActivityDatasource`
   - `IInvoiceDatasource`
   - `IUomDatasource`
   - `ICollectionSessionDatasource`
   - `ICollectionCashDatasource`
   - `ICollectionPaymentDatasource`
   - `ICollectionConfigDatasource`
   - `IPricelistDatasource`
   - `ITaxDatasource`

2. **Modificar implementaciones en theos_pos** (15 datasources):
   - Añadir `implements IDatasource` a cada clase
   - Verificar que todos los métodos de la interfaz estén implementados
   - Actualizar imports para usar `package:theos_pos_core`

3. **Testing:**
   - Verificar que cada datasource compila
   - Ejecutar tests existentes

**Archivos a modificar:** ~30 (15 interfaces nuevas + 15 implementaciones)

---

### FASE 2: Migración de Repositories (2-3 días)

**Objetivo:** Migrar repositories a theos_pos_core, usando interfaces de datasources

1. **Crear BaseRepository genérico en theos_pos_core**:
   ```dart
   abstract class BaseRepository<TDb extends IOdooDatabase>
       extends core.BaseRepository<TDb> {
     BaseRepository({super.odooClient, required super.db});
   }
   ```

2. **Migrar 12 repositories a theos_pos_core**:
   - ClientRepository
   - ProductRepository
   - SaleOrderRepository
   - AdvanceRepository
   - ActivityRepository
   - InvoiceRepository
   - CollectionRepository
   - UserRepository
   - PricelistRepository
   - TaxRepository
   - FiscalPositionRepository
   - UomRepository

3. **Crear providers en theos_pos** (glue code):
   - Provider instancia repository con datasources concretos
   - Inyecta DatabaseHelper como tipo genérico

4. **Testing:**
   - Verificar compilación
   - Tests de integración con datasources reales

**Archivos a modificar:** ~36 (12 repos migrados + 12 providers + 12 repos viejos eliminados)

---

### FASE 3: Interface Company Config (1 día)

**Objetivo:** Abstraer configuración de company para services

1. **Crear `ICompanyConfig` en theos_pos_core**:
   - Solo campos usados por services
   - ~12 getters

2. **Modificar `ResCompany` en theos_pos**:
   - Añadir `implements ICompanyConfig`
   - Verificar que todos los campos existan

3. **Actualizar 5 services**:
   - Cambiar dependencia de `ResCompany` a `ICompanyConfig`
   - Migrar a theos_pos_core

**Archivos a modificar:** ~8 (1 interfaz + 1 modelo + 5 services + 1 provider)

---

### FASE 4: Migración de Services (2-3 días)

**Objetivo:** Migrar 19 services restantes a theos_pos_core

**Categorización de services:**

**Grupo A - Pure Business Logic (ya migrados):**
- ✅ line_calculator
- ✅ sale_order_line_service
- ✅ line_operations_helper
- ✅ withhold_service
- ✅ conflict_detection_service

**Grupo B - Dependen de ICompanyConfig (Fase 3):**
- client_calculator_service
- client_credit_service
- client_validation_service
- sale_order_logic_engine
- order_defaults_service

**Grupo C - Dependen de Repositories (Fase 2):**
- advance_service
- cash_out_service
- session_service
- order_confirmation_service
- payment_service
- catalog_service
- product_service

**Grupo D - Servicios complejos (requieren análisis individual):**
- order_line_creation_service (usa taxes, prices services)
- order_service (orquestación)
- stock_sync_service (sync específico)

1. **Migrar Grupo B** (5 services):
   - Cambiar imports a `package:theos_pos_core`
   - Usar `ICompanyConfig` en lugar de `ResCompany`

2. **Migrar Grupo C** (7 services):
   - Cambiar dependencias a repositories de core
   - Usar interfaces de datasources

3. **Analizar Grupo D** (3 services):
   - Evaluar caso por caso
   - Puede requerir mini-estrategias

**Archivos a migrar:** ~19 services

---

### FASE 5: Providers - Permanecer Local ✅

**Decisión:** Los 22 providers DEBEN permanecer en theos_pos

**Razones:**
- Son glue code específico de Riverpod
- Configuran dependency injection
- Instancian servicios/repos con implementaciones concretas
- No tienen lógica de negocio reutilizable

**Acción:** Actualizar providers para usar servicios/repos de theos_pos_core

**Ejemplo:**
```dart
final clientServiceProvider = Provider<ClientCreditService>((ref) {
  final config = ref.watch(companyConfigProvider);
  final calculator = ref.watch(clientCalculatorServiceProvider);

  return ClientCreditService(
    config: config!,
    calculator: calculator,
  );
});
```

---

## 📊 Resumen de Impacto

| Fase | Archivos Afectados | Esfuerzo | Impacto | Prioridad |
|------|-------------------|----------|---------|-----------|
| 1. Datasource Interfaces | 30 (15 nuevos + 15 mod) | Alto | Muy Alto | ⭐⭐⭐⭐⭐ |
| 2. Repository Migration | 36 (12 migrados) | Medio-Alto | Muy Alto | ⭐⭐⭐⭐⭐ |
| 3. Company Config | 8 | Bajo | Alto | ⭐⭐⭐⭐ |
| 4. Services Migration | 19 | Medio | Alto | ⭐⭐⭐⭐ |
| 5. Providers (local) | 22 (actualizar) | Bajo | Bajo | ⭐⭐⭐ |
| **TOTAL** | **93 archivos** | **~10-14 días** | **Muy Alto** | - |

---

## 🎯 Resultado Final Esperado

### Después de la refactorización:

**En theos_pos_core:**
- ✅ 32 modelos
- ✅ 27 managers
- ✅ **15 interfaces de datasources** ← NUEVO
- ✅ **12 repositories** ← NUEVO
- ✅ **24 services** (5 actuales + 19 nuevos) ← NUEVO
- ✅ **1 interfaz ICompanyConfig** ← NUEVO
- ✅ BaseRepository genérico ← NUEVO

**En theos_pos (solo implementaciones y glue code):**
- 15 datasources (implementaciones)
- 22 providers (Riverpod glue code)
- 1 ResCompany (modelo extendido)
- AppDatabase, DatabaseHelper (específicos de app)

**Beneficios:**
1. ✅ **Reutilización máxima:** Otras apps pueden reutilizar toda la lógica
2. ✅ **Testing mejorado:** Mocks de interfaces son triviales
3. ✅ **Clean Architecture:** Dependencias invertidas correctamente
4. ✅ **Separación clara:** Core = lógica, App = infraestructura
5. ✅ **Mantenibilidad:** Cambios en lógica se hacen en un solo lugar

---

## ⚠️ Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Breaking changes en código existente | Alta | Alto | Fase por fase, con tests |
| Incompatibilidad de tipos | Media | Alto | TypeScript estricto, tests |
| Performance degradation | Baja | Medio | Profiling antes/después |
| Over-engineering | Media | Medio | Revisar cada interfaz (YAGNI) |
| Tiempo subestimado | Alta | Alto | Buffer de 25% en estimaciones |

---

## 🚀 Decisión Recomendada

**PROCEDER** con el plan de refactorización en 5 fases:

**ORDEN RECOMENDADO:**
1. ✅ Fase 1 (Datasources) - Habilita todo lo demás
2. ✅ Fase 3 (Company Config) - En paralelo con Fase 1 (independiente)
3. ✅ Fase 2 (Repositories) - Depende de Fase 1
4. ✅ Fase 4 (Services) - Depende de Fases 2 y 3
5. ✅ Fase 5 (Providers) - Al final, actualizar glue code

**Estimación total:** 10-14 días de trabajo (1 desarrollador senior)

**ROI esperado:**
- Reutilización de código: 80% de lógica compartible
- Reducción de bugs: Testing más fácil
- Desarrollo futuro: Nuevas apps 3x más rápidas

---

## 📝 Conclusión

La migración de los 68 archivos restantes **SÍ ES POSIBLE** mediante refactorización arquitectónica profunda con:
- Inversión de dependencias (Dependency Inversion Principle)
- Interfaces abstractas para datasources
- Repositories genéricos
- Config abstraído con interfaces

**El esfuerzo es significativo pero el beneficio a largo plazo es enorme** para un ecosistema de múltiples apps compartiendo lógica de negocio.

**Próximo paso:** Confirmar aprobación para proceder con Fase 1 (Datasource Interfaces).
