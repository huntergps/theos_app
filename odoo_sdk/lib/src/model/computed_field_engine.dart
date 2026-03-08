/// Computed Field Engine
///
/// Automatic recalculation of computed fields based on dependency graph.
/// Similar to Odoo's @api.depends mechanism.
///
/// The engine:
/// 1. Tracks field dependencies
/// 2. Detects when dependencies change
/// 3. Recalculates affected computed fields in correct order
/// 4. Supports nested dependencies (field depends on computed field)
///
/// ## Usage
///
/// ```dart
/// final engine = ComputedFieldEngine<SaleOrder>();
///
/// // Register compute methods
/// engine.registerCompute('amountTotal', ['orderLines.priceSubtotal'],
///   (order) => order.orderLines.fold(0.0, (sum, l) => sum + l.priceSubtotal));
///
/// // When a field changes
/// final updated = engine.recompute(order, {'orderLines'});
/// ```
library;

import 'dart:collection';

import 'field_definition.dart';
import 'smart_model_config.dart';

/// Function type for compute methods.
///
/// Takes the current model instance and returns the computed value.
typedef ComputeFunction<T, V> = V Function(T model);

/// Function type for applying computed values.
///
/// Takes the model and computed values, returns updated model.
typedef ApplyComputedFunction<T> = T Function(T model, Map<String, dynamic> values);

/// Engine for managing computed field recalculation.
///
/// Maintains the dependency graph and handles recalculation order.
class ComputedFieldEngine<T> {
  /// Dependency graph: field -> list of computed fields that depend on it.
  final Map<String, Set<String>> _dependencyGraph = {};

  /// Reverse graph: computed field -> fields it depends on.
  final Map<String, Set<String>> _reverseDependencies = {};

  /// Compute functions by field name.
  final Map<String, ComputeFunction<T, dynamic>> _computeFunctions = {};

  /// Function to apply computed values to model.
  ApplyComputedFunction<T>? _applyFunction;

  /// Cached topological order for recomputation.
  List<String>? _computeOrder;

  ComputedFieldEngine();

  /// Create from a SmartModelConfig.
  factory ComputedFieldEngine.fromConfig(SmartModelConfig config) {
    final engine = ComputedFieldEngine<T>();

    // Build dependency graph from field definitions
    for (final field in config.fieldDefinitions) {
      if (field.isComputed && field.depends.isNotEmpty) {
        engine.registerDependencies(field.name, field.depends);
      }
    }

    // Also register computed fields from computedFields list
    for (final computed in config.computedFields) {
      if (computed.depends.isNotEmpty) {
        engine.registerDependencies(computed.name, computed.depends);
      }
    }

    return engine;
  }

  /// Create from a FieldRegistry.
  factory ComputedFieldEngine.fromRegistry(FieldRegistry registry) {
    final engine = ComputedFieldEngine<T>();

    for (final field in registry.computed) {
      if (field.depends.isNotEmpty) {
        engine.registerDependencies(field.name, field.depends);
      }
    }

    return engine;
  }

  /// Register dependencies for a computed field.
  void registerDependencies(String computedField, List<String> dependencies) {
    _reverseDependencies[computedField] = dependencies.toSet();

    for (final dep in dependencies) {
      // Handle nested dependencies (e.g., 'orderLines.priceSubtotal')
      final baseDep = dep.contains('.') ? dep.split('.').first : dep;

      _dependencyGraph[baseDep] ??= {};
      _dependencyGraph[baseDep]!.add(computedField);
    }

    // Invalidate cached order
    _computeOrder = null;
  }

  /// Register a compute function for a field.
  void registerCompute(
    String field,
    List<String> dependencies,
    ComputeFunction<T, dynamic> compute,
  ) {
    registerDependencies(field, dependencies);
    _computeFunctions[field] = compute;
  }

  /// Set the function to apply computed values.
  void setApplyFunction(ApplyComputedFunction<T> apply) {
    _applyFunction = apply;
  }

  /// Get computed fields that depend on a field.
  Set<String> getDependents(String field) {
    return _dependencyGraph[field] ?? {};
  }

  /// Get all computed fields that need recalculation when [fields] change.
  ///
  /// Includes transitive dependencies (field A depends on field B,
  /// field B depends on field C -> changing C affects A and B).
  Set<String> getAffectedFields(Set<String> changedFields) {
    final affected = <String>{};
    final queue = Queue<String>();

    // Start with direct dependents
    for (final field in changedFields) {
      final dependents = getDependents(field);
      for (final dep in dependents) {
        if (!affected.contains(dep)) {
          affected.add(dep);
          queue.add(dep);
        }
      }
    }

    // Follow transitive dependencies
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final dependents = getDependents(current);
      for (final dep in dependents) {
        if (!affected.contains(dep)) {
          affected.add(dep);
          queue.add(dep);
        }
      }
    }

    return affected;
  }

  /// Get the topological order for computing fields.
  ///
  /// Fields are ordered so that dependencies are computed before dependents.
  List<String> get computeOrder {
    if (_computeOrder != null) return _computeOrder!;

    final order = <String>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(String field) {
      if (visited.contains(field)) return;
      if (visiting.contains(field)) {
        throw StateError('Circular dependency detected involving $field');
      }

      visiting.add(field);

      // Visit dependencies first
      final deps = _reverseDependencies[field] ?? {};
      for (final dep in deps) {
        // Only visit if it's also a computed field
        if (_reverseDependencies.containsKey(dep)) {
          visit(dep);
        }
      }

      visiting.remove(field);
      visited.add(field);
      order.add(field);
    }

    // Visit all computed fields
    for (final field in _reverseDependencies.keys) {
      visit(field);
    }

    _computeOrder = order;
    return order;
  }

  /// Recompute affected fields after [changedFields] changed.
  ///
  /// Returns a map of field name -> new value.
  /// The caller is responsible for applying these values to the model.
  Map<String, dynamic> computeAffected(T model, Set<String> changedFields) {
    final affected = getAffectedFields(changedFields);
    if (affected.isEmpty) return {};

    final results = <String, dynamic>{};

    // Compute in topological order
    for (final field in computeOrder) {
      if (affected.contains(field)) {
        final compute = _computeFunctions[field];
        if (compute != null) {
          results[field] = compute(model);
        }
      }
    }

    return results;
  }

  /// Recompute and apply changes to the model.
  ///
  /// Returns updated model with computed values applied.
  /// Requires [setApplyFunction] to be called first.
  T recompute(T model, Set<String> changedFields) {
    if (_applyFunction == null) {
      throw StateError(
        'Apply function not set. Call setApplyFunction() first.',
      );
    }

    final computed = computeAffected(model, changedFields);
    if (computed.isEmpty) return model;

    return _applyFunction!(model, computed);
  }

  /// Compute all computed fields.
  ///
  /// Useful when loading from database or creating new records.
  Map<String, dynamic> computeAll(T model) {
    final results = <String, dynamic>{};

    for (final field in computeOrder) {
      final compute = _computeFunctions[field];
      if (compute != null) {
        results[field] = compute(model);
      }
    }

    return results;
  }

  /// Recompute all computed fields and apply.
  T recomputeAll(T model) {
    if (_applyFunction == null) {
      throw StateError(
        'Apply function not set. Call setApplyFunction() first.',
      );
    }

    final computed = computeAll(model);
    if (computed.isEmpty) return model;

    return _applyFunction!(model, computed);
  }

  /// Check if a field is computed.
  bool isComputed(String field) => _reverseDependencies.containsKey(field);

  /// Get dependencies for a computed field.
  Set<String> getDependencies(String field) =>
      _reverseDependencies[field] ?? {};

  /// Clear all registered computes and dependencies.
  void clear() {
    _dependencyGraph.clear();
    _reverseDependencies.clear();
    _computeFunctions.clear();
    _computeOrder = null;
  }
}

/// Global registry of compute engines by model type.
class ComputeEngineRegistry {
  static final Map<Type, ComputedFieldEngine> _engines = {};

  /// Register an engine for a model type.
  static void register<T>(ComputedFieldEngine<T> engine) {
    _engines[T] = engine;
  }

  /// Register an engine by Type (for dynamic registration).
  static void registerByType(Type type, ComputedFieldEngine engine) {
    _engines[type] = engine;
  }

  /// Get the engine for a model type.
  static ComputedFieldEngine<T>? get<T>() {
    return _engines[T] as ComputedFieldEngine<T>?;
  }

  /// Check if an engine exists for a type.
  static bool has<T>() => _engines.containsKey(T);

  /// Create and register an engine from config.
  static ComputedFieldEngine<T> createFromConfig<T>(SmartModelConfig config) {
    final engine = ComputedFieldEngine<T>.fromConfig(config);
    register<T>(engine);
    return engine;
  }

  /// Clear all engines.
  static void clear() => _engines.clear();
}

/// Extension to help with computed fields in models.
extension ComputedFieldExtension<T> on T {
  /// Recompute all affected fields after changes.
  ///
  /// Uses the registered compute engine for this type.
  T recomputeFields(Set<String> changedFields) {
    final engine = ComputeEngineRegistry.get<T>();
    if (engine == null) return this;
    return engine.recompute(this, changedFields);
  }

  /// Recompute all computed fields.
  T recomputeAllFields() {
    final engine = ComputeEngineRegistry.get<T>();
    if (engine == null) return this;
    return engine.recomputeAll(this);
  }
}

/// Mixin for models with computed fields.
///
/// Provides automatic recomputation via the compute engine.
mixin ComputedFieldsMixin<T extends ComputedFieldsMixin<T>> {
  /// Get the compute engine for this model.
  ComputedFieldEngine<T>? get computeEngine => ComputeEngineRegistry.get<T>();

  /// Recompute fields affected by changes.
  T onFieldsChanged(Set<String> changedFields) {
    final engine = computeEngine;
    if (engine == null) return this as T;
    return engine.recompute(this as T, changedFields);
  }

  /// Recompute all computed fields.
  T refreshComputedFields() {
    final engine = computeEngine;
    if (engine == null) return this as T;
    return engine.recomputeAll(this as T);
  }

  /// Get value of a computed field.
  V? getComputedValue<V>(String fieldName) {
    final engine = computeEngine;
    if (engine == null || !engine.isComputed(fieldName)) return null;

    final results = engine.computeAffected(this as T, {});
    return results[fieldName] as V?;
  }
}
