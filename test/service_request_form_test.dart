import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/user_profile.dart';
import 'package:homevault/screens/service/add_service_request_screen.dart';

void main() {
  testWidgets('service request form uses profile and appliance defaults', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appliance = Appliance(
      id: 'ac-1',
      name: 'Bedroom AC',
      category: 'Air Conditioner',
      brand: 'Test Brand',
      amcProvider: 'AMC Care',
      amcPhone: '9876543210',
      amcExpiryDate: DateTime(2027, 8, 23),
      createdAt: DateTime(2026, 8, 1),
    );
    const profile = UserProfile(
      uid: 'user-1',
      fullName: 'Test User',
      phoneNumber: '+919876543210',
      addressLine1: '12 Test Street',
      addressLine2: 'Apartment 4',
      landmark: 'Near Park',
      state: 'Delhi',
      city: 'New Delhi',
      pinCode: '110001',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddServiceRequestScreen(
          appliances: [appliance],
          initialApplianceId: appliance.id,
          initialProfile: profile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addressForm = find.byKey(const Key('serviceRequestAddressField'));
    expect(addressForm, findsOneWidget);
    final addressTextField = find.descendant(
      of: addressForm,
      matching: find.byType(TextField),
    );
    expect(addressTextField, findsOneWidget);
    expect(
      tester.widget<TextField>(addressTextField).controller?.text,
      contains('12 Test Street'),
    );
    expect(
      tester.widget<TextField>(addressTextField).controller?.text,
      contains('110001'),
    );

    final providerForm = find.byKey(const Key('serviceRequestProviderField'));
    final providerTextField = find.descendant(
      of: providerForm,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(providerTextField).controller?.text,
      'AMC Care',
    );

    final phoneForm = find.byKey(const Key('serviceRequestContactPhoneField'));
    final phoneTextField = find.descendant(
      of: phoneForm,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(phoneTextField).controller?.text,
      '9876543210',
    );

    final phoneField = tester.widget<TextFormField>(phoneForm);
    expect(phoneField.validator?.call(''), isNull);
  });
}
