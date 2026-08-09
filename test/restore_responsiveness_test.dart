import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/warranty_notification_service.dart';
import 'package:homevault/state/appliance_store.dart';

class _HangingReminderScheduler implements WarrantyReminderScheduler {
  final Completer<void> _syncCompleter = Completer<void>();

  @override
  Future<void> syncAll(List<Appliance> appliances) => _syncCompleter.future;

  @override
  Future<void> scheduleFor(Appliance appliance) async {}

  @override
  Future<void> cancelFor(String applianceId) async {}
}

Appliance _appliance(String id, String name) => Appliance(
  id: id,
  name: name,
  category: 'Other',
  brand: 'Test',
  createdAt: DateTime(2026, 8, 9),
);

void main() {
  test('replace restore does not wait for reminder synchronization', () async {
    final store = ApplianceStore(
      repository: MemoryApplianceRepository(
        initialAppliances: [_appliance('old', 'Old appliance')],
      ),
      reminderScheduler: _HangingReminderScheduler(),
    );
    await store.initialize();

    await store
        .replaceAll([_appliance('new', 'Restored appliance')])
        .timeout(const Duration(seconds: 1));

    expect(store.appliances, hasLength(1));
    expect(store.appliances.single.id, 'new');
    store.dispose();
  });

  test('merge restore does not wait for reminder synchronization', () async {
    final store = ApplianceStore(
      repository: MemoryApplianceRepository(
        initialAppliances: [_appliance('old', 'Existing appliance')],
      ),
      reminderScheduler: _HangingReminderScheduler(),
    );
    await store.initialize();

    final imported = await store
        .mergeAppliances([_appliance('new', 'Imported appliance')])
        .timeout(const Duration(seconds: 1));

    expect(imported, 1);
    expect(
      store.appliances.map((item) => item.id),
      containsAll(['old', 'new']),
    );
    store.dispose();
  });
}
