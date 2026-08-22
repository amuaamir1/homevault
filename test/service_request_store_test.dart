import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_request.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/appliance_store.dart';

void main() {
  test('service request lifecycle persists through ApplianceStore', () async {
    final appliance = Appliance(
      id: 'appliance-1',
      name: 'Refrigerator',
      category: 'Refrigerator',
      brand: 'Test Brand',
      createdAt: DateTime(2026, 8, 1),
    );
    final repository = MemoryApplianceRepository(
      initialAppliances: [appliance],
    );
    final store = ApplianceStore(repository: repository);
    addTearDown(store.dispose);

    await store.initialize();
    final initialRevision = store.dataChangeRevision;

    final request = ServiceRequest.create(
      id: 'request-1',
      now: DateTime(2026, 8, 23),
      preferredDate: DateTime(2026, 8, 25),
      visitWindow: ServiceVisitWindow.morning,
      issueDescription: 'Not cooling',
      serviceAddress: '12 Test Street',
    );

    await store.addServiceRequest(appliance.id, request);

    expect(store.totalServiceRequestCount, 1);
    expect(store.activeServiceRequestCount, 1);
    expect(store.dataChangeRevision, initialRevision + 1);

    final confirmed = request.withStatus(
      ServiceRequestStatus.confirmed,
      changedAt: DateTime(2026, 8, 23, 12),
    );
    await store.updateServiceRequest(appliance.id, confirmed);

    expect(
      store.applianceById(appliance.id)!.serviceRequests.single.status,
      ServiceRequestStatus.confirmed,
    );
    expect(store.dataChangeRevision, initialRevision + 2);

    final reloaded = ApplianceStore(repository: repository);
    addTearDown(reloaded.dispose);
    await reloaded.initialize();

    expect(reloaded.totalServiceRequestCount, 1);
    expect(
      reloaded
          .applianceById(appliance.id)!
          .serviceRequests
          .single
          .statusHistory,
      hasLength(2),
    );

    await reloaded.removeServiceRequest(appliance.id, request.id);
    expect(reloaded.totalServiceRequestCount, 0);
  });
}
