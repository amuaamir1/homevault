import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_request.dart';
import 'package:homevault/screens/service/service_center_screen.dart';
import 'package:homevault/screens/service/service_requests_screen.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';

Future<ApplianceStore> _storeWithRequests() async {
  final requested = ServiceRequest.create(
    id: 'request-active',
    now: DateTime(2026, 8, 22),
    preferredDate: DateTime(2026, 8, 25),
    visitWindow: ServiceVisitWindow.morning,
    issueDescription: 'Not cooling',
    serviceAddress: '12 Test Street',
    provider: 'Cool Care',
  );
  final completed =
      ServiceRequest.create(
        id: 'request-completed',
        now: DateTime(2026, 8, 20),
        preferredDate: DateTime(2026, 8, 21),
        visitWindow: ServiceVisitWindow.afternoon,
        issueDescription: 'Noise issue',
        serviceAddress: '12 Test Street',
      ).withStatus(
        ServiceRequestStatus.completed,
        changedAt: DateTime(2026, 8, 21, 15),
      );

  final appliance = Appliance(
    id: 'appliance-1',
    name: 'Living room AC',
    category: 'Air Conditioner',
    brand: 'Test Brand',
    serviceRequests: [requested, completed],
    createdAt: DateTime(2026, 8, 1),
  );

  final store = ApplianceStore(
    repository: MemoryApplianceRepository(initialAppliances: [appliance]),
  );
  await store.initialize();
  return store;
}

void main() {
  testWidgets('service requests screen summarizes and filters requests', (
    tester,
  ) async {
    final store = await _storeWithRequests();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      AppScope(
        applianceStore: store,
        child: MaterialApp(
          home: ServiceRequestsScreen(now: DateTime(2026, 8, 23)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Service requests'), findsOneWidget);
    expect(find.byKey(const Key('serviceRequestsList')), findsOneWidget);
    expect(find.text('Not cooling'), findsOneWidget);
    expect(find.text('Noise issue'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
    await tester.pumpAndSettle();

    expect(find.text('Not cooling'), findsOneWidget);
    expect(find.text('Noise issue'), findsNothing);

    final completedChip = find.widgetWithText(ChoiceChip, 'Completed');
    expect(completedChip, findsOneWidget);

    await tester.ensureVisible(completedChip);
    await tester.pumpAndSettle();
    await tester.tap(completedChip);
    await tester.pumpAndSettle();

    expect(find.text('Not cooling'), findsNothing);
    expect(find.text('Noise issue'), findsOneWidget);
  });

  testWidgets('service center exposes the service request entry point', (
    tester,
  ) async {
    final store = await _storeWithRequests();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      AppScope(
        applianceStore: store,
        child: const MaterialApp(home: ServiceCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('serviceRequestsCard')), findsOneWidget);
    expect(find.text('1 active request'), findsOneWidget);
    expect(
      find.byKey(const Key('serviceRequestsAppBarButton')),
      findsOneWidget,
    );
  });
}
