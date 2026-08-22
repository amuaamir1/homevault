import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/screens/service/add_service_request_screen.dart';

void main() {
  testWidgets('directory provider prefills a new service request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appliance = Appliance(
      id: 'ac-1',
      name: 'Living room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      supportProvider: 'Default Support',
      supportPhone: '1111111111',
      createdAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddServiceRequestScreen(
          appliances: [appliance],
          initialApplianceId: appliance.id,
          initialProviderName: 'CoolFix Services',
          initialProviderPhone: '9876543210',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final providerField = find.descendant(
      of: find.byKey(const Key('serviceRequestProviderField')),
      matching: find.byType(EditableText),
    );
    expect(providerField, findsOneWidget);
    expect(
      tester.widget<EditableText>(providerField).controller.text,
      'CoolFix Services',
    );

    final phoneField = find.byKey(
      const Key('serviceRequestProviderPhoneField'),
    );
    await tester.ensureVisible(phoneField);
    await tester.pumpAndSettle();
    final phoneEditable = find.descendant(
      of: phoneField,
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(phoneEditable).controller.text,
      '9876543210',
    );
  });
}
