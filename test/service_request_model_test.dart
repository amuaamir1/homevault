import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_request.dart';

void main() {
  test('service request round-trips with status history', () {
    final createdAt = DateTime(2026, 8, 23, 9, 30);
    final request =
        ServiceRequest.create(
          id: 'request-1',
          now: createdAt,
          preferredDate: DateTime(2026, 8, 25),
          visitWindow: ServiceVisitWindow.morning,
          issueDescription: 'Cooling is weak',
          serviceAddress: '12 Test Street\nNew Delhi 110001',
          contactName: 'Test User',
          contactPhone: '+919876543210',
          provider: 'Cool Care',
          providerPhone: '1800123456',
        ).withStatus(
          ServiceRequestStatus.confirmed,
          changedAt: DateTime(2026, 8, 23, 10),
        );

    final restored = ServiceRequest.fromJson(request.toJson());

    expect(restored.id, 'request-1');
    expect(restored.status, ServiceRequestStatus.confirmed);
    expect(restored.visitWindow, ServiceVisitWindow.morning);
    expect(restored.statusHistory, hasLength(2));
    expect(restored.statusHistory.first.status, ServiceRequestStatus.requested);
    expect(restored.statusHistory.last.status, ServiceRequestStatus.confirmed);
    expect(restored.contactPhone, '+919876543210');
  });

  test(
    'status changes append history and terminal states have no next status',
    () {
      final request = ServiceRequest.create(
        id: 'request-2',
        now: DateTime(2026, 8, 23),
        preferredDate: DateTime(2026, 8, 24),
        visitWindow: ServiceVisitWindow.flexible,
        issueDescription: 'Annual service',
        serviceAddress: 'Riyadh Road',
      );

      final completed = request
          .withStatus(
            ServiceRequestStatus.confirmed,
            changedAt: DateTime(2026, 8, 23, 11),
          )
          .withStatus(
            ServiceRequestStatus.completed,
            changedAt: DateTime(2026, 8, 24, 15),
          );

      expect(completed.isActive, isFalse);
      expect(completed.statusHistory, hasLength(3));
      expect(completed.status.nextStatuses, isEmpty);
    },
  );

  test('appliance persists service requests with normal appliance data', () {
    final appliance = Appliance(
      id: 'appliance-1',
      name: 'Living room AC',
      category: 'Air Conditioner',
      brand: 'Test Brand',
      createdAt: DateTime(2026, 8, 1),
      serviceRequests: [
        ServiceRequest.create(
          id: 'request-3',
          now: DateTime(2026, 8, 23),
          preferredDate: DateTime(2026, 8, 26),
          visitWindow: ServiceVisitWindow.afternoon,
          issueDescription: 'Water leakage',
          serviceAddress: '12 Test Street',
        ),
      ],
    );

    final restored = Appliance.fromJson(appliance.toJson());

    expect(restored.serviceRequestCount, 1);
    expect(restored.activeServiceRequestCount, 1);
    expect(restored.serviceRequests.single.issueDescription, 'Water leakage');
  });
}
