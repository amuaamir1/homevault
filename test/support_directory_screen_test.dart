import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_request.dart';
import 'package:homevault/screens/support/support_screen.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';

Future<ApplianceStore> _store() async {
  final store = ApplianceStore(
    repository: MemoryApplianceRepository(
      initialAppliances: [
        Appliance(
          id: 'ac-1',
          name: 'Bedroom AC',
          category: 'Air Conditioner',
          brand: 'Daikin',
          supportProvider: 'Daikin Care',
          supportPhone: '1800100100',
          supportEmail: 'care@example.com',
          supportWebsite: 'support.example.com',
          amcProvider: 'CoolFix Services',
          amcPhone: '9876543210',
          serviceRequests: [
            ServiceRequest.create(
              id: 'sr-1',
              now: DateTime(2026, 8, 20),
              preferredDate: DateTime(2026, 8, 25),
              visitWindow: ServiceVisitWindow.morning,
              issueDescription: 'Not cooling',
              serviceAddress: 'Ranchi, Jharkhand, 834001',
              provider: 'CoolFix Services',
              providerPhone: '9876543210',
            ),
          ],
          createdAt: DateTime(2026, 8, 1),
        ),
      ],
    ),
  );
  await store.initialize();
  return store;
}

void main() {
  testWidgets('provider directory summarizes, searches and opens details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = await _store();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      AppScope(
        applianceStore: store,
        child: const MaterialApp(home: SupportScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Provider directory'), findsOneWidget);
    expect(find.textContaining('provider'), findsWidgets);
    expect(find.text('Daikin'), findsOneWidget);
    expect(find.text('Daikin Care'), findsOneWidget);
    expect(find.text('CoolFix Services'), findsOneWidget);

    final search = find.descendant(
      of: find.byKey(const Key('providerDirectorySearchField')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(search, 'coolfix ranchi');
    await tester.pumpAndSettle();

    expect(find.text('CoolFix Services'), findsOneWidget);
    expect(find.text('Daikin Care'), findsNothing);

    await tester.tap(find.text('CoolFix Services'));
    await tester.pumpAndSettle();

    expect(find.text('Provider details'), findsOneWidget);
    expect(find.text('AMC provider'), findsOneWidget);
    expect(find.text('Service provider'), findsOneWidget);
    expect(find.text('Bedroom AC'), findsOneWidget);
    expect(
      find.byKey(const Key('providerRequestServiceButton')),
      findsOneWidget,
    );
  });
}
