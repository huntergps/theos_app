import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/app/theme/orbi_theme.dart';
import 'package:theos_panel/ui/bindings/field_binding.dart';
import 'package:theos_panel/ui/components/orbi_bound_fields.dart';

void main() {
  testWidgets('edits, saves on Enter, and preserves focus across rebuild', (
    tester,
  ) async {
    final binding = FieldBinding<String>(
      initialValue: 'old',
      onSave: (_) async {},
    );
    addTearDown(binding.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: OrbiTheme.light,
        home: Scaffold(
          body: OrbiBoundTextField(binding: binding, label: 'Nombre'),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'edited');
    expect(binding.status, FieldBindingStatus.dirty);
    expect(tester.binding.focusManager.primaryFocus, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: OrbiTheme.dark,
        home: Scaffold(
          body: OrbiBoundTextField(binding: binding, label: 'Nombre'),
        ),
      ),
    );
    expect(find.text('edited'), findsOneWidget);
    expect(tester.binding.focusManager.primaryFocus, isNotNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(binding.status, FieldBindingStatus.saved);
  });

  testWidgets('shows error and does not lose text while save is pending', (
    tester,
  ) async {
    final completer = Completer<void>();
    final binding = FieldBinding<String>(
      initialValue: '',
      onSave: (_) async {
        await completer.future;
        throw StateError('not accepted');
      },
    );
    addTearDown(binding.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: OrbiTheme.light,
        home: Scaffold(
          body: OrbiBoundTextField(binding: binding, label: 'Código'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'draft');
    // Trigger the same injected command used by the suffix action; the
    // callback stays deterministic while the widget remains mounted.
    unawaited(binding.save());
    await tester.pump();
    expect(binding.status, FieldBindingStatus.saving);
    expect(find.text('draft'), findsOneWidget);
    completer.complete();
    await tester.pump();
    await tester.pump();
    expect(binding.status, FieldBindingStatus.error);
    expect(find.textContaining('not accepted'), findsOneWidget);
  });
}
