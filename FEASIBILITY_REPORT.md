# Informe de Factibilidad: odoo_reactive_widgets + Boilerplate Login/Session

## Estado: FACTIBLE con ajuste arquitectonico clave

---

## 1. Resumen Ejecutivo

Se analizaron 3 codebases:

| Fuente | Archivos Dart | Lineas | Hallazgo clave |
|--------|--------------|--------|----------------|
| `theos_pos` (app) | ~200+ | ~50K+ | 17 widgets reactivos acoplados a Riverpod |
| `theos_pos_core` (data layer) | 199 | ~103K | 50+ modelos Freezed, 30+ managers, Drift DB |
| `odoo_sdk` (nuevo SDK) | ~80 | ~25K | Ya provee streams reactivos **agnosticos** via `manager.watch()` |

**Conclusion**: El `odoo_sdk` ya tiene la infraestructura reactiva necesaria (`watch()`, `watchAll()`, `recordChanges`). Los widgets solo necesitan consumir `Stream<T>` puro, no Riverpod.

---

## 2. Analisis de Reactividad: Como funciona hoy vs Como debe funcionar

### 2.1 Cadena actual en theos_pos (ACOPLADA a Riverpod)

```
Drift .watch() → StreamProvider (Riverpod) → ref.watch() → ConsumerWidget
```

Cada widget usa `ConsumerWidget` + `WidgetRef ref` + `ref.watch(provider)`. Esto obliga a usar Riverpod.

### 2.2 Cadena propuesta (AGNOSTICA)

```
OdooModelManager.watch(id) → Stream<T?> → StreamBuilder (Flutter puro) → StatelessWidget
```

O con cualquier state manager:

```
// Riverpod
final orderProvider = StreamProvider((ref) => manager.watch(orderId));

// Bloc
class OrderCubit extends Cubit<Order?> {
  OrderCubit(int id) : super(null) {
    manager.watch(id).listen(emit);
  }
}

// GetX
final order = Rx<Order?>(null);
manager.watch(id).listen((v) => order.value = v);

// Vanilla Flutter
StreamBuilder<Order?>(
  stream: manager.watch(orderId),
  builder: (ctx, snap) => ...,
)
```

### 2.3 El odoo_sdk YA soporta esto

En `odoo_model_manager.dart` lineas 300-319:

```dart
// Reactive Watch - Database-level reactivity via Drift .watch()
Stream<T?> watchLocalRecord(int id);
Stream<List<T>> watchLocalSearch({List<dynamic>? domain, int? limit, ...});
```

Y en `manager_watch_mixin.dart`:

```dart
mixin _ManagerWatchMixin<T> on _OdooModelManagerBase<T> {
  Stream<T?> watch(int id) => watchLocalRecord(id);
  Stream<List<T>> watchMany(List<int> ids) { ... }
  Stream<List<T>> watchAll({List<dynamic>? domain, int? limit}) { ... }
}
```

**Conclusion**: Los managers ya exponen `Stream<T?>` y `Stream<List<T>>` puras de Dart. No hay dependencia de Riverpod.

---

## 3. Inventario de Widgets a Extraer

### 3.1 Widgets Primitivos (FACTIBLE, esfuerzo bajo)

| Widget | Clases | Dependencias externas | Complejidad |
|--------|--------|-----------------------|-------------|
| `ReactiveTextField` | `ReactiveTextField`, `ReactiveInlineTextField` | fluent_ui | Baja |
| `ReactiveNumberField` | `ReactiveNumberField`, `ReactiveMoneyField`, `ReactivePercentField`, `ReactiveNumberInput` | fluent_ui, intl | Baja |
| `ReactiveDateField` | `ReactiveDateField`, `ReactiveDateRangeField` | fluent_ui, intl | Baja |
| `ReactiveBooleanField` | `ReactiveBooleanField`, `ReactiveTristateBooleanField` | fluent_ui | Baja |
| `ReactiveSelectionField` | `ReactiveSelectionField<T>`, `ReactiveStatusField<T>` | fluent_ui | Media |
| `ReactiveMultilineField` | `ReactiveMultilineField`, `ReactiveCollapsibleTextField` | fluent_ui | Baja |

**Total**: 6 archivos, ~15 clases. Adaptacion: eliminar `ConsumerWidget` → `StatelessWidget`, eliminar `WidgetRef ref`.

### 3.2 Widgets Compuestos (FACTIBLE, esfuerzo medio)

| Widget | Dependencia critica | Cambio requerido |
|--------|---------------------|------------------|
| `ReactiveMasterSelector<T>` | `StreamProvider<List<T>>` de Riverpod | Cambiar a `Stream<List<T>>` puro como parametro |
| `ReactiveSummaryRow` | Solo fluent_ui | Eliminar ConsumerWidget → StatelessWidget |
| `AsyncContentBuilder<T>` | `AsyncValue<T>` de Riverpod | Crear `AsyncSnapshot`-compatible o aceptar `Stream<T>` |

### 3.3 Widgets EXCLUIDOS (acoplados a dominio POS)

| Widget | Razon de exclusion |
|--------|--------------------|
| `ReactivePartnerCard` | Modelo Partner especifico de POS |
| `ReactiveCashCountField` | Denominaciones Ecuador, dominio POS |
| `ReactiveSaleOrderLine` | Modelo SaleOrderLine especifico |
| `ReactiveDataGrid` | Requiere Syncfusion (licencia comercial) |
| `ReactiveSearchBar` | Demasiado complejo, requiere refactoring significativo |

### 3.4 Infraestructura a Extraer

| Componente | Cambio |
|------------|--------|
| `Spacing` | Eliminar `spacingFactorProvider` y `themedSpacingProvider` (Riverpod). Mantener clases puras |
| `ResponsiveValues` | Eliminar import de `ScreenBreakpoints`. Hardcodear breakpoints (600/1200) |
| `ReactiveFieldConfig` | Ya es puro Dart, sin cambios |
| `ReactiveFieldBase<T>` | `ConsumerWidget` → `StatelessWidget`, eliminar `WidgetRef ref` de metodos |
| `NumberInputBase` | Ya es `StatefulWidget` puro, sin cambios |

---

## 4. Patron de Reactividad Agnostico Propuesto

### 4.1 Para widgets primitivos (sin datos remotos)

Los widgets como `ReactiveTextField`, `ReactiveNumberField`, etc. NO necesitan streams. Reciben `value` + `onChanged` como parametros. La reactividad la maneja el **padre** (con el state manager que quiera).

```dart
// El widget es "tonto" — recibe datos, emite cambios
ReactiveTextField(
  config: ReactiveFieldConfig(label: 'Nombre', isEditing: true),
  value: currentName,           // String puro
  onChanged: (v) => ...,        // Callback puro
)
```

**Verificacion de reactividad**: Cuando el padre hace `setState()` / `state = newState` / `emit(newValue)`, Flutter reconstruye el widget con el nuevo `value`. Esto funciona con CUALQUIER state manager.

### 4.2 Para widgets con datos remotos (MasterSelector)

Cambiar de `StreamProvider<List<T>>` a `Stream<List<T>>` puro:

```dart
// ANTES (acoplado a Riverpod):
ReactiveMasterSelector<Warehouse>(
  itemsProvider: warehousesStreamProvider,  // StreamProvider de Riverpod
  ...
)

// DESPUES (agnostico):
ReactiveMasterSelector<Warehouse>(
  itemsStream: warehouseManager.watchAll(),  // Stream<List<Warehouse>> puro
  ...
)
```

Internamente usa `StreamBuilder` de Flutter:

```dart
class ReactiveMasterSelector<T> extends StatelessWidget {
  final Stream<List<T>> itemsStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: itemsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildError(snapshot.error!);
        if (!snapshot.hasData) return _buildLoading();
        return _buildComboBox(context, snapshot.data!);
      },
    );
  }
}
```

### 4.3 Para AsyncContentBuilder

Reemplazar `AsyncValue<T>` (Riverpod) con `AsyncSnapshot<T>` (Flutter) o con un tipo propio:

```dart
// Opcion A: Acepta Stream<T> directamente
AsyncContentBuilder<T>(
  stream: manager.watchAll(),
  builder: (data) => ProductList(products: data),
  onRetry: () => manager.syncFromRemote(),
)

// Opcion B: Acepta AsyncSnapshot<T> (vanilla Flutter)
StreamBuilder<List<Product>>(
  stream: manager.watchAll(),
  builder: (ctx, snap) => AsyncContentBuilder.fromSnapshot(
    snapshot: snap,
    builder: (data) => ProductList(products: data),
  ),
)
```

---

## 5. Flujo de Login / Session (Boilerplate)

### 5.1 Lo que ya provee odoo_sdk

```dart
// 1. Crear cliente
final client = OdooClient(config: OdooClientConfig(
  baseUrl: 'https://odoo.example.com',
  apiKey: 'api_key_abc123',
  database: 'production',
  sessionPersistence: MySecureSessionPersistence(),
));

// 2. Restaurar sesion previa
final restored = await client.session.initializeFromStorage();

// 3. O autenticar nueva sesion
final session = await client.authenticateSession(
  login: 'admin@example.com',
  password: 'admin',
);

// 4. Crear contexto de datos (multi-tenant)
final layer = OdooDataLayer();
await layer.createAndInitializeContext(
  session: DataSession(id: 'main', label: 'Main', ...),
  database: db,
  queueStore: store,
  registerModels: (ctx) {
    ctx.registerConfig<Product>(Product.config);
    ctx.registerManager<Product>(productManager);
  },
);

// 5. Monitorear conectividad
final health = ServerHealthService(client);
health.statusStream.listen((status) {
  if (status.shouldSkipRemote) { /* modo offline */ }
});
```

### 5.2 Lo que falta para un boilerplate completo

| Componente | Estado | Donde vive |
|------------|--------|------------|
| `OdooClient` + `OdooClientConfig` | Listo en odoo_sdk | `package:odoo_sdk/core.dart` |
| `SessionPersistence` | Interface en SDK, impl en app | App implementa |
| `DataSession` / `DataContext` / `OdooDataLayer` | Listo en odoo_sdk | `package:odoo_sdk/odoo_sdk.dart` |
| `OdooModelManager.watch()` / `watchAll()` | Listo en odoo_sdk | `package:odoo_sdk/odoo_sdk.dart` |
| `SyncCoordinator` | Listo en odoo_sdk | Sync bidireccional |
| `ServerHealthService` | Listo en odoo_sdk | Conectividad |
| `WebSocketService` | Listo en odoo_sdk | Tiempo real |
| **Login Screen (UI)** | NO existe en SDK | Necesita boilerplate |
| **Splash/Auth Router** | NO existe en SDK | Necesita boilerplate |
| **User Provider/Service** | NO existe en SDK | Necesita boilerplate |

### 5.3 Flujo de Login propuesto (agnostico)

```
App Start
  |
  v
SplashScreen: await client.session.initializeFromStorage()
  |
  +-- Sesion valida? --> MainScreen
  |
  +-- No sesion? --> LoginScreen
                      |
                      v
                    User enters: server URL, API key (o login/password)
                      |
                      v
                    client.authenticateSession(...)
                      |
                      v
                    layer.createAndInitializeContext(...)
                      |
                      v
                    syncCoordinator.syncAll()
                      |
                      v
                    Navigate to MainScreen
```

Este flujo no depende de ningun state manager. El boilerplate provee:
- `LoginScreen` widget (fluent_ui)
- `AuthService` clase pura con `Stream<AuthState>` para que el app lo consuma con lo que quiera

---

## 6. Verificaciones de Reactividad

### 6.1 Test: Cambio en DB local se refleja en UI

```dart
// VERIFICACION: Insertar registro → widget muestra nuevo valor
testWidgets('widget updates when DB record changes', (tester) async {
  final manager = TestProductManager(inMemoryDb);

  // Widget escucha stream
  await tester.pumpWidget(
    StreamBuilder<Product?>(
      stream: manager.watch(1),
      builder: (ctx, snap) => Text(snap.data?.name ?? 'loading'),
    ),
  );

  // Inicialmente no hay datos
  expect(find.text('loading'), findsOneWidget);

  // Insertar producto en DB
  await manager.createLocal(Product(id: 1, name: 'Test Product'));
  await tester.pump(); // Esperar rebuild

  // Widget debe mostrar nuevo valor
  expect(find.text('Test Product'), findsOneWidget);

  // Actualizar producto
  await manager.updateLocal(Product(id: 1, name: 'Updated Product'));
  await tester.pump();

  // Widget debe reflejar cambio
  expect(find.text('Updated Product'), findsOneWidget);
});
```

### 6.2 Test: Sync remoto → UI actualiza

```dart
testWidgets('remote sync updates UI automatically', (tester) async {
  final manager = TestProductManager(inMemoryDb);

  await tester.pumpWidget(
    StreamBuilder<List<Product>>(
      stream: manager.watchAll(),
      builder: (ctx, snap) => Text('Count: ${snap.data?.length ?? 0}'),
    ),
  );

  expect(find.text('Count: 0'), findsOneWidget);

  // Simular sync que inserta 3 productos
  await manager.syncFromRemote(); // Esto escribe en Drift DB
  await tester.pump();

  // UI se actualiza automaticamente via Drift .watch()
  expect(find.text('Count: 3'), findsOneWidget);
});
```

### 6.3 Test: WebSocket push → DB update → UI rebuild

```dart
testWidgets('websocket push triggers UI update', (tester) async {
  // WebSocket recibe: { model: 'product.product', id: 1, fields: { name: 'WS Updated' } }
  // → Manager aplica cambio a Drift DB
  // → Drift .watch() emite nueva version
  // → StreamBuilder reconstruye widget
  // → UI muestra 'WS Updated'
});
```

### 6.4 Garantia de reactividad por capa

| Capa | Mecanismo | Auto-reactivo? |
|------|-----------|----------------|
| SQLite/Drift | `.watch()` emite en cualquier INSERT/UPDATE/DELETE | SI |
| Manager | `watch(id)` / `watchAll()` expone Stream puro | SI |
| Widget | `StreamBuilder` reconstruye en cada emision | SI |
| Sync | Escribe en Drift → triggers `.watch()` | SI |
| WebSocket | Escribe en Drift → triggers `.watch()` | SI |
| Offline Queue | Procesa queue → escribe en Drift → triggers `.watch()` | SI |

**Conclusion**: La cadena completa es reactiva end-to-end SIN necesitar Riverpod. Drift `.watch()` es el motor de reactividad.

---

## 7. Casos de Uso del Paquete

### CU-01: Formulario de Venta con campos reactivos

```dart
class SaleOrderForm extends StatelessWidget {
  final SaleOrder order;
  final ValueChanged<SaleOrder> onChanged;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ReactiveTextField(
        config: ReactiveFieldConfig(label: 'Cliente', isEditing: isEditing),
        value: order.partnerName,
        onChanged: (v) => onChanged(order.copyWith(partnerName: v)),
      ),
      ReactiveNumberField(
        config: ReactiveFieldConfig(label: 'Total', isEditing: false),
        value: order.amountTotal,
        decimals: 2,
        suffix: 'USD',
      ),
      ReactiveDateField(
        config: ReactiveFieldConfig(label: 'Fecha', isEditing: isEditing),
        value: order.dateOrder,
        onChanged: (v) => onChanged(order.copyWith(dateOrder: v)),
      ),
      ReactiveSelectionField<String>(
        config: ReactiveFieldConfig(label: 'Estado', isEditing: false),
        value: order.state,
        options: [
          SelectionOption(value: 'draft', label: 'Borrador'),
          SelectionOption(value: 'sale', label: 'Confirmado', color: Colors.green),
        ],
      ),
    ]);
  }
}
```

### CU-02: Selector de bodega con datos reactivos del DB

```dart
// En cualquier pantalla, sin importar el state manager:
ReactiveMasterSelector<Warehouse>(
  config: ReactiveFieldConfig(label: 'Bodega', isEditing: true),
  value: selectedWarehouseId,
  displayValue: selectedWarehouseName,
  itemsStream: warehouseManager.watchAll(),  // Stream puro de Drift
  getId: (w) => w.id,
  getName: (w) => w.name,
  onChanged: (id) => updateWarehouse(id),
)
```

### CU-03: Lista de productos con auto-refresh

```dart
AsyncContentBuilder<List<Product>>(
  stream: productManager.watchAll(domain: [['active', '=', true]]),
  builder: (products) => ListView.builder(
    itemCount: products.length,
    itemBuilder: (ctx, i) => ProductTile(product: products[i]),
  ),
  onRetry: () => productManager.syncFromRemote(),
)
// Cuando sync descarga nuevos productos → DB cambia → stream emite → lista se actualiza
```

### CU-04: Detalle de pedido con actualizacion en tiempo real

```dart
StreamBuilder<SaleOrder?>(
  stream: orderManager.watch(orderId),
  builder: (ctx, snap) {
    if (!snap.hasData) return ProgressRing();
    final order = snap.data!;
    return SaleOrderForm(
      order: order,
      isEditing: isEditMode,
      onChanged: (updated) => orderManager.updateLocal(updated),
    );
  },
)
// WebSocket push cambia estado de pedido → Drift .watch() emite → form se actualiza
```

---

## 8. Estructura Propuesta del Paquete

```
odoo_reactive_widgets/
├── pubspec.yaml                          # Solo: flutter, fluent_ui, intl
├── lib/
│   ├── odoo_reactive_widgets.dart        # Barrel export
│   └── src/
│       ├── theme/
│       │   ├── spacing.dart              # Escala 4px, sin Riverpod
│       │   └── responsive.dart           # DeviceType + ResponsiveValues
│       ├── config/
│       │   └── reactive_field_config.dart # Config pura
│       ├── base/
│       │   ├── reactive_field_base.dart   # StatelessWidget (NO ConsumerWidget)
│       │   └── number_input_base.dart     # StatefulWidget puro
│       ├── fields/
│       │   ├── reactive_text_field.dart
│       │   ├── reactive_number_field.dart
│       │   ├── reactive_date_field.dart
│       │   ├── reactive_boolean_field.dart
│       │   ├── reactive_selection_field.dart
│       │   └── reactive_multiline_field.dart
│       ├── composite/
│       │   ├── reactive_master_selector.dart   # Usa Stream<List<T>> (no StreamProvider)
│       │   └── reactive_summary_row.dart
│       └── builders/
│           └── async_content_builder.dart      # Usa Stream<T> (no AsyncValue)
└── test/
    └── ...
```

**Dependencias del paquete** (CERO state managers):

```yaml
dependencies:
  flutter:
    sdk: flutter
  fluent_ui: ^4.9.1    # UI framework
  intl: ^0.20.0        # Formateo numeros/fechas
```

---

## 9. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigacion |
|--------|-------------|---------|------------|
| Widgets dependen de `WidgetRef ref` en metodos internos | Alta | Medio | Eliminar param, usar solo `BuildContext` |
| `ReactiveMasterSelector` usa `StreamProvider.family` | Alta | Alto | Cambiar a `Stream<List<T>>` como param |
| `AsyncContentBuilder` usa `AsyncValue<T>` (Riverpod) | Alta | Alto | Crear version con `Stream<T>` + `StreamBuilder` |
| Textos hardcoded en espanol | Media | Bajo | Parametros con defaults en espanol |
| `ReactiveTextField` usa `ConsumerStatefulWidget` | Alta | Medio | Cambiar a `StatefulWidget` |
| Performance: `StreamBuilder` reconstruye mas que `ref.watch` con `select` | Baja | Bajo | Drift `.watch()` ya es eficiente, granularidad por widget |

---

## 10. Plan de Implementacion

### Fase 1: Paquete base (1 sesion)
1. Crear estructura de directorios
2. `pubspec.yaml` sin Riverpod
3. `spacing.dart`, `responsive.dart` auto-contenidos
4. `reactive_field_config.dart`, `reactive_field_base.dart` como `StatelessWidget`
5. `number_input_base.dart` (ya es StatefulWidget puro)

### Fase 2: Widgets primitivos (1 sesion)
6. `reactive_text_field.dart` — `StatefulWidget` (maneja TextEditingController)
7. `reactive_number_field.dart` + `MoneyField` + `PercentField`
8. `reactive_date_field.dart` + `DateRangeField`
9. `reactive_boolean_field.dart` + `TristateBooleanField`
10. `reactive_selection_field.dart` + `StatusField`
11. `reactive_multiline_field.dart` + `CollapsibleTextField`

### Fase 3: Widgets compuestos (1 sesion)
12. `reactive_master_selector.dart` — acepta `Stream<List<T>>`
13. `reactive_summary_row.dart` — `StatelessWidget` puro
14. `async_content_builder.dart` — acepta `Stream<T>` directamente

### Fase 4: Tests + Validacion
15. Widget tests para cada componente
16. Verificar: `flutter pub get`, `dart analyze`, `flutter test`
17. Verificar: 0 imports a Riverpod, theos_pos, syncfusion

---

## 11. Conclusion

**FACTIBLE**. La clave es que `odoo_sdk` ya provee `Stream<T>` reactivos via Drift `.watch()`. Los widgets solo necesitan:

1. **Parametros primitivos** (`value: T`, `onChanged: ValueChanged<T>`) para campos simples
2. **`Stream<List<T>>`** para selectores de datos maestros
3. **`StreamBuilder`** de Flutter puro para consumir streams

Esto garantiza:
- Cualquier cambio en la DB local (por CRUD, sync, WebSocket, o cola offline) se refleja automaticamente en la UI
- El paquete funciona con Riverpod, Bloc, GetX, Provider, MobX, o `setState` puro
- Cero dependencias de state management
