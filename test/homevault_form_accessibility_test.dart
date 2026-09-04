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

      final accessibleForm = find.byType(HomeVaultAccessibleForm);
      expect(accessibleForm, findsOneWidget);

      final orderedGroup = find.descendant(
        of: accessibleForm,
        matching: find.byType(FocusTraversalGroup),
      );
      expect(orderedGroup, findsOneWidget);
      expect(
        tester.widget<FocusTraversalGroup>(orderedGroup).policy,
        isA<OrderedTraversalPolicy>(),
      );

      final form = tester.widget<Form>(find.byType(Form));
      expect(form.autovalidateMode, AutovalidateMode.onUserInteraction);
    },
  );

  testWidgets('validation summary is a semantic live region', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HomeVaultFormValidationSummary(visible: true)),
        ),
      );

      const summaryKey = ValueKey('p19FormValidationSummary');
      expect(find.byKey(summaryKey), findsOneWidget);

      expect(
        tester.getSemantics(find.byKey(summaryKey)),
        isSemantics(
          label:
              'Check the highlighted fields. Correct the errors, then try again.',
          isLiveRegion: true,
        ),
      );
    } finally {
      semanticsHandle.dispose();
    }
  });
}
