import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_request.dart';
import 'package:homevault/models/support_directory_entry.dart';
import 'package:homevault/services/support_directory_service.dart';

void main() {
  const service = SupportDirectoryService();

  Appliance appliance() {
    return Appliance(
      id: 'ac-1',
      name: 'Living room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      supportProvider: 'Daikin Care',
      supportPhone: '1800-100-100',
      supportEmail: 'care@example.com',
      supportWebsite: 'support.example.com',
      warrantyProvider: 'Daikin Care',
      amcProvider: 'CoolFix Services',
      amcPhone: '9876543210',
      amcNotes: 'Annual maintenance partner',
      serviceRequests: [
        ServiceRequest.create(
          id: 'request-1',
          now: DateTime(2026, 8, 20),
          preferredDate: DateTime(2026, 8, 25),
          visitWindow: ServiceVisitWindow.morning,
          issueDescription: 'Not cooling',
          serviceAddress: '12 Park Road, Ranchi, Jharkhand, 834001',
          provider: 'CoolFix Services',
          providerPhone: '9876543210',
        ),
      ],
      createdAt: DateTime(2026, 8, 1),
    );
  }

  test(
    'directory aggregates manufacturer, support, warranty, AMC and usage',
    () {
      final entries = service.buildDirectory([appliance()]);

      final daikin = entries.firstWhere((entry) => entry.name == 'Daikin');
      expect(daikin.roles, contains(SupportProviderRole.manufacturer));
      expect(daikin.applianceNames, contains('Living room AC'));

      final care = entries.firstWhere((entry) => entry.name == 'Daikin Care');
      expect(care.roles, contains(SupportProviderRole.customerSupport));
      expect(care.roles, contains(SupportProviderRole.warrantyProvider));
      expect(care.phones, contains('1800-100-100'));
      expect(care.emails, contains('care@example.com'));

      final coolFix = entries.firstWhere(
        (entry) => entry.name == 'CoolFix Services',
      );
      expect(coolFix.roles, contains(SupportProviderRole.amcProvider));
      expect(coolFix.roles, contains(SupportProviderRole.serviceProvider));
      expect(coolFix.serviceRequestCount, 1);
      expect(coolFix.serviceLocations, isNotEmpty);
      expect(coolFix.lastUsedAt, DateTime(2026, 8, 20));
    },
  );

  test('provider names are deduplicated case-insensitively', () {
    final first = appliance();
    final second = Appliance(
      id: 'ac-2',
      name: 'Bedroom AC',
      category: 'Air Conditioner',
      brand: 'DAIKIN',
      supportProvider: 'daikin care',
      supportPhone: '1800-100-100',
      createdAt: DateTime(2026, 8, 2),
    );

    final entries = service.buildDirectory([first, second]);

    expect(
      entries.where((entry) => entry.name.toLowerCase() == 'daikin').length,
      1,
    );
    final care = entries.firstWhere(
      (entry) => entry.name.toLowerCase() == 'daikin care',
    );
    expect(care.applianceIds, hasLength(2));
  });

  test('search and role/category/location/contact filters combine', () {
    final entries = service.buildDirectory([appliance()]);
    final location = entries
        .firstWhere((entry) => entry.name == 'CoolFix Services')
        .serviceLocations
        .first;

    final filtered = service.filterEntries(
      entries,
      query: 'coolfix air',
      role: SupportProviderRole.serviceProvider,
      category: 'Air Conditioner',
      location: location,
      contactFilter: SupportContactFilter.phone,
    );

    expect(filtered, hasLength(1));
    expect(filtered.single.name, 'CoolFix Services');
  });

  test(
    'missing-contact filter surfaces manufacturer records needing details',
    () {
      final entries = service.buildDirectory([appliance()]);
      final filtered = service.filterEntries(
        entries,
        contactFilter: SupportContactFilter.missing,
      );

      expect(filtered.map((entry) => entry.name), contains('Daikin'));
      expect(filtered.any((entry) => entry.name == 'Daikin Care'), isFalse);
    },
  );
}
