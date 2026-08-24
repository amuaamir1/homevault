import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/accessibility/homevault_form_accessibility.dart';

void main() {
  testWidgets(
    'accessible form uses ordered keyboard traversal and autovalidation',
    (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeVaultAccessibleForm(
              formKey: formKey,
              child: const Column(
                children: [
                  TextField(key: ValueKey('firstField')),
                  TextField(key: ValueKey('secondField')),
                ],
              ),
            ),
          ),
        ),
      );

      final orderedGroups = tester
          .widgetList<FocusTraversalGroup>(find.byType(FocusTraversalGroup))
          .where((group) => group.policy is OrderedTraversalPolicy);

      expect(orderedGroups, hasLength(1));

      final form = tester.widget<Form>(find.byType(Form));
      expect(form.autovalidateMode, AutovalidateMode.onUserInteraction);
    },
  );

  testWidgets('validation summary is a semantic live region', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HomeVaultFormValidationSummary(visible: true)),
      ),
    );

    const summaryKey = ValueKey('p19FormValidationSummary');
    expect(find.byKey(summaryKey), findsOneWidget);

    final semantics = tester.widget<Semantics>(find.byKey(summaryKey));
    expect(semantics.properties.liveRegion, isTrue);
    expect(
      semantics.properties.label,
      contains('Check the highlighted fields'),
    );
  });
}
