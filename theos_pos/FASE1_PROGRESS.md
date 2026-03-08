# FASE 1: Datasource Interfaces - Progreso

## Estado: EN PROGRESO

Fecha inicio: 2026-01-24

---

## Interfaces Creadas en theos_pos_core ✅

1. ✅ `IPartnerDatasource` - Partner/Client data access
2. ✅ `IUserDatasource` - User data access
3. ✅ `IUomDatasource` - Unit of Measure data access
4. ✅ `IAdvanceDatasource` - Customer payment advances

---

## Hallazgos Importantes

### Patrón A: Datasources que retornan modelos ✅

Estos datasources YA convierten tipos Drift a modelos de negocio:

- ✅ **PartnerDatasource** → retorna `Client`
- ✅ **UserDatasource** → retorna `User`
- ✅ **UomDatasource** → retorna `Uom`
- ✅ **AdvanceDatasource** → retorna `Advance`
- ⏳ **ActivityDatasource** → verificar
- ⏳ **InvoiceDatasource** → verificar
- ⏳ **SaleOrderDatasource** → verificar
- ⏳ **CollectionSessionDatasource** → verificar

**Acción:** Crear interfaces directamente, implementar en datasources existentes

### Patrón B: Repositorios sin Datasources ❌

Estos features NO tienen datasources separados, los repositorios acceden directamente a DB:

- ❌ **ProductRepository** → accede directamente `_db.productProduct`
- ⏳ **WarehouseRepository** → verificar

**Problema:** No hay capa de abstracción de datos

**Solución:**
1. **Opción A (Recomendada):** Crear datasources nuevos, mover lógica de acceso a datos
2. **Opción B:** Las interfaces tendrán implementación nueva en datasource

---

## Plan Actualizado

### PARTE A: Datasources que retornan modelos (4/8)

**Interfaces a crear:**
- [x] IPartnerDatasource
- [x] IUserDatasource
- [x] IUomDatasource
- [x] IAdvanceDatasource
- [ ] IActivityDatasource
- [ ] IInvoiceDatasource
- [ ] ISaleOrderDatasource
- [ ] ISaleOrderLineDatasource

**Tiempo estimado:** 1 día

### PARTE B: Datasources para collection (0/4)

**Interfaces a crear:**
- [ ] ICollectionSessionDatasource
- [ ] ICollectionCashDatasource
- [ ] ICollectionPaymentDatasource
- [ ] ICollectionConfigDatasource

**Tiempo estimado:** 1 día

### PARTE C: Crear datasources nuevos (0/2)

**Para repositorios sin datasource:**
- [ ] ProductDatasource (nuevo)
- [ ] WarehouseDatasource (verificar si existe)

**Tiempo estimado:** 2 días

### PARTE D: Company (Especial)

**Problema:** ResCompany es modelo extendido app-specific

**Soluciones:**
1. No crear datasource interface (mantener local) ✅ RECOMENDADO
2. O crear interface para Company base (si se migra modelo base a core)

**Decisión:** Posponer hasta Fase 3 (ICompanyConfig)

---

## Siguientes Pasos Inmediatos

1. ✅ Crear 4 interfaces restantes (PARTE A)
2. ✅ Crear 4 interfaces collection (PARTE B)
3. ⏳ Decidir: ¿Crear ProductDatasource nuevo o dejar para después?
4. ⏳ Implementar interfaces en datasources existentes
5. ⏳ Verificar compilación

---

## Decisiones Pendientes

### Pregunta 1: ¿Crear ProductDatasource ahora?

**Opción A:** Crear ahora (más trabajo pero arquitectura limpia)
- Pros: Arquitectura consistente, habilita migración completa
- Contras: Más tiempo (refactorizar ProductRepository)

**Opción B:** Posponer (enfoque incremental)
- Pros: Menos cambios, progreso más rápido
- Contras: Arquitectura incompleta, Product no migrable aún

**Recomendación:** Opción B (posponer), enfocarse en lo que ya funciona

### Pregunta 2: ¿Scope de Fase 1?

**Scope Mínimo:** 8 interfaces + implementaciones para datasources existentes
**Scope Completo:** 16 interfaces + crear datasources nuevos

**Recomendación:** Scope mínimo primero, evaluar después

---

## Métricas

| Métrica | Objetivo | Actual | % |
|---------|----------|--------|---|
| Interfaces creadas | 8-12 | 4 | 33-50% |
| Datasources migrados | 8-12 | 0 | 0% |
| Compilación exitosa | ✅ | ⏳ | - |

---

## Próxima Acción

**AHORA:** Crear 4 interfaces restantes PARTE A:
- IActivityDatasource
- IInvoiceDatasource
- ISaleOrderDatasource
- ISaleOrderLineDatasource

**Esfuerzo estimado:** 30-60 minutos
