# Tests Unitarios con Mocks

## 📋 Resumen

Esta carpeta contiene tests unitarios que demuestran la testabilidad mejorada después de aplicar **Dependency Inversion Principle (DIP)** con interfaces de datasources.

## 🎯 Beneficios de Usar Interfaces

### Antes (Sin Interfaces)
```dart
class ClientRepository {
  final PartnerDatasource _datasource; // ← Implementación concreta

  // Imposible crear mock sin base de datos real
}
```

### Después (Con Interfaces)
```dart
class ClientRepository {
  final IPartnerDatasource _datasource; // ← Interfaz abstracta

  // Fácil crear mock para testing
}
```

## 🚀 Ejecutar Tests

### Prerequisitos

1. Agregar dependencias de testing en `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

2. Instalar dependencias:
```bash
flutter pub get
```

### Generar Mocks

Los tests usan `mockito` para generar mocks automáticamente. Ejecuta:

```bash
# Generar archivos .mocks.dart
flutter pub run build_runner build --delete-conflicting-outputs
```

Esto creará archivos como:
- `client_repository_test.mocks.dart`
- `activity_repository_test.mocks.dart`

### Ejecutar Tests

```bash
# Ejecutar todos los tests
flutter test

# Ejecutar tests específicos
flutter test test/features/clients/repositories/client_repository_test.dart

# Ejecutar con coverage
flutter test --coverage
```

## 📁 Estructura de Tests

```
test/
├── features/
│   ├── clients/
│   │   └── repositories/
│   │       ├── client_repository_test.dart
│   │       └── client_repository_test.mocks.dart (generado)
│   ├── activities/
│   │   └── repositories/
│   │       ├── activity_repository_test.dart
│   │       └── activity_repository_test.mocks.dart (generado)
│   └── ...
└── README_TESTS.md (este archivo)
```

## 📝 Ejemplos de Tests

### Test Básico con Mock

```dart
test('getById returns client when datasource has data', () async {
  // Arrange - Preparar datos de prueba
  final testClient = Client(id: 1, name: 'Test Client');
  when(mockDatasource.getPartner(1))
      .thenAnswer((_) async => testClient);

  // Act - Ejecutar método bajo prueba
  final result = await repository.getById(1);

  // Assert - Verificar resultados
  expect(result?.name, equals('Test Client'));
  verify(mockDatasource.getPartner(1)).called(1);
});
```

### Test de Error Handling

```dart
test('getActivities returns Left with CacheFailure on error', () async {
  // Arrange
  when(mockDatasource.getAllActivities())
      .thenThrow(Exception('Database error'));

  // Act
  final result = await repository.getActivities();

  // Assert
  expect(result.isLeft(), true);
  result.fold(
    (failure) => expect(failure, isA<CacheFailure>()),
    (activities) => fail('Should return Left'),
  );
});
```

### Test de Múltiples Resultados

```dart
test('search returns multiple clients from datasource', () async {
  // Arrange
  final testClients = [
    Client(id: 1, name: 'John Doe'),
    Client(id: 2, name: 'Jane Doe'),
  ];

  when(mockDatasource.searchPartners(query: 'Doe', limit: 20))
      .thenAnswer((_) async => testClients);

  // Act
  final results = await repository.search('Doe', limit: 20);

  // Assert
  expect(results, hasLength(2));
});
```

## 🎓 Mejores Prácticas

### 1. Un Mock por Test
```dart
setUp(() {
  mockDatasource = MockIPartnerDatasource();
  repository = ClientRepository(
    partnerDatasource: mockDatasource,
  );
});
```

### 2. Arrange-Act-Assert (AAA Pattern)
```dart
test('description', () async {
  // Arrange - Setup
  when(...).thenAnswer(...);

  // Act - Execute
  final result = await method();

  // Assert - Verify
  expect(result, ...);
  verify(...).called(1);
});
```

### 3. Verificar Llamadas a Métodos
```dart
// Verificar que se llamó exactamente 1 vez
verify(mockDatasource.getPartner(1)).called(1);

// Verificar que nunca se llamó
verifyNever(mockDatasource.deletePartner(any));

// Verificar orden de llamadas
verifyInOrder([
  mockDatasource.getPartner(1),
  mockDatasource.upsertPartner(any),
]);
```

### 4. Usar Matchers Apropiados
```dart
expect(result, isNotNull);
expect(result, isA<Client>());
expect(result?.id, equals(1));
expect(results, hasLength(2));
expect(results, contains(testClient));
expect(failure, isA<CacheFailure>());
```

## 🔧 Crear Nuevos Tests

### Template para Repository Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show IDatasource;
import 'package:theos_pos/features/xxx/repositories/xxx_repository.dart';

@GenerateMocks([IDatasource])
import 'xxx_repository_test.mocks.dart';

void main() {
  group('XxxRepository Tests', () {
    late MockIDatasource mockDatasource;
    late XxxRepository repository;

    setUp(() {
      mockDatasource = MockIDatasource();
      repository = XxxRepository(datasource: mockDatasource);
    });

    test('description', () async {
      // Arrange
      when(mockDatasource.method())
          .thenAnswer((_) async => testData);

      // Act
      final result = await repository.method();

      // Assert
      expect(result, expected);
      verify(mockDatasource.method()).called(1);
    });
  });
}
```

## 📊 Coverage

Para ver cobertura de tests:

```bash
# Generar reporte de coverage
flutter test --coverage

# Ver reporte HTML (requiere lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 🐛 Troubleshooting

### Error: "Missing stub for method"
**Solución**: Agregar stub en el mock
```dart
when(mockDatasource.method(any))
    .thenAnswer((_) async => null);
```

### Error: "MockIto verification never called"
**Solución**: Asegurarse de que el método se ejecute antes de verify
```dart
await repository.method(); // Ejecutar primero
verify(mockDatasource.method()).called(1); // Luego verificar
```

### Error: "Build runner conflicts"
**Solución**: Limpiar y regenerar
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📚 Recursos

- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Clean Architecture Testing](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

## ✅ Checklist para Nuevos Tests

- [ ] Crear archivo `xxx_test.dart`
- [ ] Agregar anotación `@GenerateMocks([...])`
- [ ] Generar mocks con `build_runner`
- [ ] Crear grupo de tests `group('...', () {})`
- [ ] Setup en `setUp(() {})`
- [ ] Escribir tests con AAA pattern
- [ ] Verificar llamadas con `verify()`
- [ ] Ejecutar tests con `flutter test`
- [ ] Verificar coverage si es necesario

---

**Última actualización**: 2026-01-25
**Tests creados**: 2 archivos de ejemplo
**Coverage objetivo**: >80%
