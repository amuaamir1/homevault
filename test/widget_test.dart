import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/app.dart';

void main() {
  testWidgets('HomeVault starts on the dashboard', (tester) async {
    await tester.pumpWidget(const HomeVaultApp());

    expect(find.text('HomeVault'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Appliances'), findsWidgets);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Support'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('user can open the add appliance form', (tester) async {
    await tester.pumpWidget(const HomeVaultApp());
    await tester.pumpAndSettle();

    final addApplianceButton = find.text('Add appliance').first;

    expect(addApplianceButton, findsOneWidget);

    await tester.ensureVisible(addApplianceButton);
    await tester.pumpAndSettle();

    await tester.tap(addApplianceButton);
    await tester.pumpAndSettle();

    expect(find.text('Appliance details'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Appliance name *'),
      findsOneWidget,
    );

    final applianceForm = find.byType(ListView);
    final saveButton = find.text('Save appliance');

    expect(applianceForm, findsOneWidget);

    await tester.dragUntilVisible(
      saveButton,
      applianceForm,
      const Offset(0, -500),
      maxIteration: 10,
    );

    await tester.pumpAndSettle();

    expect(saveButton, findsOneWidget);
  });
}