# 📋 Plan de Migración Completa a theos_pos_core

## Fecha: 2026-01-25

---

## 🎯 Objetivo

Migrar todo el contenido duplicado de `theos_pos/core/` a `theos_pos_core` y eliminar los archivos conflictivos en `theos_pos`, consolidando la arquitectura en un único package compartido.

---

## ✅ Cambios Completados (Fase 1)

### 1. Arreglar Conflictos de Exports en theos_pos_core

**Archivo**: `/theos_pos_core/lib/src/managers/managers.dart`

**Problema**: Tipos duplicados exportados desde managers Y modelos

**Solución Aplicada**:
```dart
// Sales
export 'sales/team_manager.dart' hide SalesTeam;

// Taxes
export 'taxes/fiscal_position_manager.dart' hide FiscalPosition, FiscalPositionTax;

// Warehouses
export 'warehouses/warehouse_manager.dart' hide Warehouse;
```

**Resultado**: ✅ Conflictos de nombres resueltos

---

### 2. Eliminar PartnerRepository Duplicado

**Archivos Modificados**:
- ✅ Eliminado: `lib/features/sales/repositories/partner_repository.dart` (duplicado viejo)
- ✅ Actualizado: `lib/core/database/repositories/repository_providers.dart` → usa ClientRepository
- ✅ Actualizado: `lib/features/sales/repositories/repositories.dart` → removido export
- ✅ Actualizado: `lib/features/sales/utils/partner_utils.dart` → usa ClientRepository

**Resultado**: ✅ Repositorio consolidado, usa interfaz IPartnerDatasource

---

## ⚠️ Problemas Pendientes

### Problema 1: Duplicación de Database Schema

**Situación Actual**:
- `theos_pos/core/database/database.dart` (3,087 líneas) - 59 tablas
- `theos_pos_core/src/database/database.dart` - Mismo schema

**Problema**:
```
Error: 'SaleOrderData' is from both:
  - 'package:theos_pos/core/database/database.dart'
  - 'package:theos_pos_core/src/database/database.dart'
```

**Impacto**: Build falla con ~18 errores de tipos conflictivos

**Solución Requerida**:
1. Consolidar schema SOLO en theos_pos_core
2. Eliminar theos_pos/core/database/database.dart completamente
3. Importar AppDatabase desde theos_pos_core en toda la app

**Complejidad**: ALTA - Requiere regenerar database.g.dart

---

### Problema 2: Datasource Implementations Duplicadas

**Situación Actual**:
- Interfaces en `theos_pos_core/src/datasources/` (13 interfaces: I*Datasource)
- Implementaciones en `theos_pos/features/*/datasources/` (16 implementaciones)
- Algunas implementaciones TAMBIÉN en `theos_pos_core/src/database/datasources/` (2)

**Estado**:
- ✅ **Arquitectura correcta**: App usa interfaces desde core
- ⚠️ **Ubicación subóptima**: Implementaciones deberían estar en core

**Pregunta Arquitectónica**:
¿Las implementaciones de datasources deben estar en:
- **Opción A**: `theos_pos_core` (reutilizables entre apps)
- **Opción B**: Cada app (theos_pos, theos_mobile, etc.) implementa según sus necesidades

**Recomendación**: Opción A - Mover implementaciones a core para máxima reutilización

---

## 📊 Contenido a Migrar

### De theos_pos/core/ a theos_pos_core/

#### 1. Database Layer (CRÍTICO)

**Fuente**: `/theos_pos/lib/core/database/`

**Destino**: `/theos_pos_core/lib/src/database/`

**Archivos**:
- ✅ `database.dart` - Ya existe en core (verificar sincronización)
- ✅ `database_helper.dart` - Ya existe como `database.dart` en core
- ⚠️ `database.g.dart` - Auto-generado, requiere regeneración

**Acción**:
1. Comparar schemas entre ambos
2. Consolidar en theos_pos_core
3. Eliminar de theos_pos
4. Regenerar con `dart run build_runner build`

---

#### 2. Datasource Implementations

**Fuente**: `/theos_pos/lib/features/*/datasources/`

**Destino**: `/theos_pos_core/lib/src/database/datasources/`

**Implementaciones a Migrar** (16 total):

| Datasource | Líneas | Estado | Prioridad |
|-----------|--------|--------|-----------|
| PartnerDatasource | 334 | ✅ Usa interfaz | Alta |
| SaleOrderDatasource | 700 | ✅ Usa interfaz | Alta |
| SaleOrderLineDatasource | ~300 | ✅ Usa interfaz | Alta |
| CollectionSessionDatasource | 824 | ✅ Usa interfaz | Alta |
| CollectionPaymentDatasource | ~200 | ✅ Usa interfaz | Alta |
| CollectionConfigDatasource | ~150 | ✅ Usa interfaz | Alta |
| CollectionCashDatasource | ~150 | ✅ Usa interfaz | Alta |
| InvoiceDatasource | ~300 | ✅ Usa interfaz | Media |
| ProductDatasource | ~400 | ⚠️ Sin interfaz | Media |
| UomDatasource | ~200 | ✅ Usa interfaz | Media |
| UserDatasource | ~200 | ✅ Usa interfaz | Media |
| ActivityDatasource | ~150 | ✅ Usa interfaz | Baja |
| AdvanceDatasource | ~150 | ✅ Usa interfaz | Baja |
| CompanyDatasource | ~200 | ⚠️ Sin interfaz | Baja |
| WarehouseDatasource | ~100 | ⚠️ Sin interfaz | Baja |
| BankDatasource | ~100 | ⚠️ Sin interfaz | Baja |

**Total**: ~4,300 líneas de código

**Beneficio**: Reutilización entre theos_pos, theos_mobile, theos_web

---

#### 3. Base Repository Classes

**Fuente**: `/theos_pos/lib/core/database/repositories/`

**Destino**: `/theos_pos_core/lib/src/database/repositories/`

**Archivos**:
- ⚠️ `base_repository.dart` - Existe en AMBOS, verificar cuál es más completo
- ⚠️ `common_repository.dart` - Existe en core (STUB), implementación en app

**Acción**:
1. Comparar implementaciones
2. Consolidar en core
3. Eliminar de app

---

#### 4. Services Layer

**Fuente**: `/theos_pos/lib/core/services/`

**Destino**: `/theos_pos_core/lib/src/services/`

**Servicios a Migrar**:

| Servicio | Dependencias UI | Migreable |
|----------|-----------------|-----------|
| OdooService | No | ✅ Sí |
| ConfigService | No | ✅ Sí |
| LoggerService | No | ✅ Sí |
| DeviceService | Sí (device_info_plus) | ⚠️ Condicional |
| ServerConnectivityService | No | ✅ Sí |
| ServerDatabaseService | No | ✅ Sí |
| WebSocketService | No | ✅ Sí |
| WebSocket Event Handlers | No | ✅ Sí |
| RelatedRecordResolver | No | ✅ Sí |

**Total**: ~2,000 líneas

---

#### 5. Error Handling & Constants

**Fuente**: `/theos_pos/lib/core/errors/` y `/core/constants/`

**Destino**: `/theos_pos_core/lib/src/utils/` o `/src/errors/`

**Archivos**:
- `exceptions.dart` - Definiciones de excepciones
- `failures.dart` - Clases de errores
- `app_constants.dart` - Constantes de aplicación
- `odoo_models.dart` - Nombres de modelos y campos Odoo

**Migrables**: ✅ Todos (no dependen de UI)

---

## 🚀 Plan de Implementación

### FASE 2: Consolidar Database Schema (CRÍTICO)

**Tiempo Estimado**: 2-3 horas

**Pasos**:

1. **Comparar Schemas**
   ```bash
   diff theos_pos/lib/core/database/database.dart \
        theos_pos_core/lib/src/database/database.dart
   ```

2. **Identificar Diferencias**
   - Tablas que existen en uno pero no en otro
   - Campos diferentes entre versiones
   - Versiones de schema

3. **Consolidar en Core**
   - Actualizar `theos_pos_core/lib/src/database/database.dart`
   - Incluir TODAS las tablas de ambos

4. **Regenerar database.g.dart**
   ```bash
   cd theos_pos_core
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Eliminar de App**
   - Borrar `theos_pos/lib/core/database/database.dart`
   - Borrar `theos_pos/lib/core/database/database.g.dart`

6. **Actualizar Imports**
   - Buscar: `import '../core/database/database.dart'`
   - Reemplazar con: `import 'package:theos_pos_core/src/database/database.dart'`

7. **Actualizar DatabaseHelper**
   - Modificar para usar AppDatabase de core

8. **Verificar Compilación**
   ```bash
   flutter clean
   flutter pub get
   flutter build macos --debug
   ```

**Riesgos**:
- ⚠️ Posibles diferencias de schema entre versiones
- ⚠️ Migraciones de base de datos existentes
- ⚠️ Conflictos en database.g.dart

**Mitigación**:
- Hacer backup del database.dart actual
- Probar en branch separado
- Verificar tests pasan

---

### FASE 3: Migrar Datasource Implementations

**Tiempo Estimado**: 4-6 horas

**Pasos**:

1. **Crear Estructura en Core**
   ```bash
   mkdir -p theos_pos_core/lib/src/database/datasources/{sales,clients,collection,products}
   ```

2. **Migrar Por Módulo**:

   **Sales** (Alta Prioridad):
   - Mover `sale_order_datasource.dart` a core
   - Mover `sale_order_line_datasource.dart` a core
   - Actualizar imports en app

   **Clients** (Alta Prioridad):
   - Mover `partner_datasource.dart` a core
   - Actualizar imports en app

   **Collection** (Alta Prioridad):
   - Mover 4 datasources de collection a core
   - Actualizar imports en app

   **Products** (Media Prioridad):
   - Mover `product_datasource.dart` a core
   - Mover `uom_datasource.dart` a core

3. **Actualizar Providers**
   - Modificar `features/*/providers/datasource_providers.dart`
   - Importar desde core en lugar de local

4. **Verificar Tests**
   ```bash
   flutter test
   ```

**Beneficio**: Datasources reutilizables en theos_mobile, theos_web, etc.

---

### FASE 4: Migrar Services Layer

**Tiempo Estimado**: 3-4 horas

**Pasos**:

1. **Migrar Servicios Core**:
   - OdooService
   - ConfigService
   - LoggerService
   - ServerConnectivityService
   - WebSocketService

2. **Migrar Handlers**:
   - ModelRecordHandler
   - RelatedRecordResolver
   - WebSocket event handlers

3. **Actualizar Providers**:
   - Mover service providers a core
   - Actualizar imports en app

---

### FASE 5: Cleanup Final

**Tiempo Estimado**: 1-2 horas

**Pasos**:

1. **Eliminar Archivos Duplicados**:
   ```bash
   rm -rf theos_pos/lib/core/database/
   rm -rf theos_pos/lib/core/services/
   rm -rf theos_pos/lib/core/errors/
   ```

2. **Consolidar Providers**:
   - Mover providers comunes a core
   - Mantener solo providers UI-específicos en app

3. **Actualizar Documentación**:
   - Actualizar ARCHITECTURE.md
   - Documentar exports de theos_pos_core
   - Actualizar README

4. **Verificación Final**:
   ```bash
   flutter analyze
   flutter test
   flutter build macos --release
   ```

---

## 📊 Resumen de Impacto

### Archivos a Migrar

| Categoría | Archivos | Líneas | Prioridad |
|-----------|----------|--------|-----------|
| Database Schema | 1 + generated | 3,087 | 🔴 CRÍTICA |
| Datasources | 16 | ~4,300 | 🟡 Alta |
| Services | ~10 | ~2,000 | 🟢 Media |
| Repositories | 2 | ~500 | 🟢 Media |
| Utils/Errors | ~6 | ~400 | 🟢 Baja |
| **TOTAL** | **~35** | **~10,287** | - |

### Archivos a Eliminar

| Directorio | Archivos | Razón |
|------------|----------|-------|
| `core/database/` | 5+ | Duplicado en core |
| `core/services/` | 10+ | Duplicado en core |
| `core/errors/` | 4 | Duplicado en core |
| `core/constants/` | 3 | Duplicado en core |
| `sales/repositories/partner_repository.dart` | 1 | ✅ YA ELIMINADO |
| **TOTAL** | **~23** | - |

---

## 🎯 Criterios de Éxito

- [ ] **Build exitoso**: `flutter build macos --debug` sin errores
- [ ] **0 conflictos de tipos**: No más errores de tipos duplicados
- [ ] **Tests pasan**: `flutter test` sin fallas
- [ ] **Database funciona**: App se ejecuta y accede a datos
- [ ] **Imports limpios**: Solo imports de theos_pos_core, no de core/
- [ ] **Documentación actualizada**: ARCHITECTURE.md refleja nueva estructura

---

## ⚠️ Riesgos y Consideraciones

### Riesgos Técnicos

1. **Schema Migrations**: Cambios en schema pueden romper bases de datos existentes
   - **Mitigación**: Probar con database nueva primero

2. **Breaking Changes**: Apps que dependen de theos_pos_core pueden romperse
   - **Mitigación**: Versionar package correctamente

3. **Performance**: Centralizar todo en core puede aumentar tamaño del package
   - **Mitigación**: Usar tree-shaking, lazy loading

### Consideraciones Arquitectónicas

1. **¿Core debe incluir UI?**: NO - Solo modelos, datasources, servicios
2. **¿Core debe incluir providers?**: Riverpod providers pueden estar en core si no dependen de UI
3. **¿Core debe incluir database?**: SÍ - Schema completo debe estar en core

---

## 📝 Próximos Pasos Inmediatos

### Paso 1: Verificar Build Actual

```bash
flutter build macos --debug 2>&1 | grep "^Error:"
```

**Objetivo**: Confirmar cuántos errores de database quedan

---

### Paso 2: Comparar Database Schemas

```bash
diff -u \
  theos_pos/lib/core/database/database.dart \
  theos_pos_core/lib/src/database/database.dart
```

**Objetivo**: Identificar diferencias exactas

---

### Paso 3: Ejecutar Fase 2

Consolidar database schema según plan arriba.

---

## 📚 Referencias

- **Documentos Relacionados**:
  - COMPILATION_FIXES_COMPLETE.md - Fixes de errores originales
  - OPCION3_WIDGETS_COMPLETE.md - Migración de widgets a barrel files
  - ARCHITECTURE.md - Arquitectura del proyecto

- **Package theos_pos_core**:
  - Location: `/Users/elmers/Documents/dev_odoo18/app/theos_pos_core`
  - Exports: `lib/theos_pos_core.dart`

- **App theos_pos**:
  - Location: `/Users/elmers/Documents/dev_odoo18/app/theos_pos`
  - Dependencies: `pubspec.yaml`

---

**Creado por**: Claude Code
**Fecha**: 2026-01-25
**Estado**: ✅ Fase 1 Completada, Fase 2 Pendiente
