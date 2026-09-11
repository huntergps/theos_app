import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/ui/bindings/field_binding.dart';

void main() {
  test('tracks dirty and saved state through the injected callback', () async {
    final saved = <String>[];
    final binding = FieldBinding<String>(
      initialValue: 'old',
      onSave: (value) async => saved.add(value),
    );

    binding.edit('new');
    expect(binding.status, FieldBindingStatus.dirty);
    expect(await binding.save(), isTrue);
    expect(saved, ['new']);
    expect(binding.persistedValue, 'new');
    expect(binding.status, FieldBindingStatus.saved);
    binding.dispose();
  });

  test('external update becomes a conflict without replacing local work', () {
    final binding = FieldBinding<String>(
      initialValue: 'base',
      onSave: (_) async {},
    );
    binding.edit('local');
    binding.setExternalValue('remote');

    expect(binding.value, 'local');
    expect(binding.remoteValue, 'remote');
    expect(binding.status, FieldBindingStatus.conflict);
    binding.dispose();
  });

  test('late save failure cannot change a disposed binding', () async {
    final completer = Completer<void>();
    final binding = FieldBinding<String>(
      initialValue: 'base',
      onSave: (_) => completer.future,
    );
    binding.edit('local');
    final result = binding.save();
    binding.dispose();
    completer.completeError(StateError('late'));

    expect(await result, isFalse);
  });

  test('editing while saving never starts a concurrent write', () async {
    final first = Completer<void>();
    var writes = 0;
    final binding = FieldBinding<String>(
      initialValue: 'base',
      onSave: (_) async {
        writes++;
        await first.future;
      },
    );
    binding.edit('one');
    final firstSave = binding.save();
    binding.edit('two');
    expect(await binding.save(), isFalse);
    expect(writes, 1);
    first.complete();
    expect(await firstSave, isFalse);
    expect(binding.value, 'two');
    expect(binding.status, FieldBindingStatus.dirty);
    binding.dispose();
  });

  test('old external snapshot is ignored and conflicts cannot save', () async {
    var writes = 0;
    final binding = FieldBinding<String>(
      initialValue: 'base',
      onSave: (_) async => writes++,
    );
    binding.edit('local');
    binding.setExternalValue('base');
    expect(binding.status, FieldBindingStatus.dirty);
    binding.setExternalValue('remote');
    expect(binding.status, FieldBindingStatus.conflict);
    binding.edit('new local attempt');
    expect(binding.status, FieldBindingStatus.conflict);
    expect(await binding.save(), isFalse);
    expect(writes, 0);
    binding.acceptExternal();
    expect(binding.value, 'remote');
    expect(binding.status, FieldBindingStatus.pristine);
    binding.dispose();
  });

  test(
    'completion after a concurrent edit notifies the final dirty state',
    () async {
      final completer = Completer<void>();
      final states = <FieldBindingStatus>[];
      final binding = FieldBinding<String>(
        initialValue: 'base',
        onSave: (_) => completer.future,
      );
      binding.addListener(() => states.add(binding.status));
      binding.edit('first');
      final operation = binding.save();
      binding.edit('second');
      completer.complete();
      expect(await operation, isFalse);
      expect(binding.isSaving, isFalse);
      expect(states.last, FieldBindingStatus.dirty);
      binding.dispose();
    },
  );

  test('revert during save records a durable result as a conflict', () async {
    final completer = Completer<void>();
    final binding = FieldBinding<String>(
      initialValue: 'base',
      onSave: (_) => completer.future,
    );
    binding.edit('saved remotely');
    final operation = binding.save();
    binding.revert();
    completer.complete();
    expect(await operation, isFalse);
    expect(binding.value, 'base');
    expect(binding.persistedValue, 'saved remotely');
    expect(binding.status, FieldBindingStatus.conflict);
    binding.dispose();
  });
}
