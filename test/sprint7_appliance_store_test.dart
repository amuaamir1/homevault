import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/appliance_store.dart';

void main() {
  test('replaceAll replaces the persisted appliance database', () async {
    final repository = MemoryApplianceRepository(
      initialAppliances: [
        Appliance(
          id: 'old-1',
          name: 'Old appliance',
          category: 'Other',
          brand: '',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    final store = ApplianceStore(repository: repository);
    await store.initialize();

    final replacement = Appliance(
      id: 'new-1',
      name: 'New appliance',
      category: 'Other',
      brand: 'HomeVault',
      createdAt: DateTime(2026, 8, 2),
    );
    await store.replaceAll([replacement]);

    expect(store.totalCount, 1);
    expect(store.appliances.single.id, 'new-1');

    final reloaded = ApplianceStore(repository: repository);
    await reloaded.initialize();
    expect(reloaded.appliances.single.name, 'New appliance');

    store.dispose();
    reloaded.dispose();
  });

  test('mergeAppliances prevents duplicate IDs and serial numbers', () async {
    final existing = Appliance(
      id: 'existing-1',
      name: 'Existing fridge',
      category: 'Kitchen Appliance',
      brand: 'Samsung',
      serialNumber: 'SERIAL-1',
      createdAt: DateTime(2026, 8, 1),
    );
    final repository = MemoryApplianceRepository(initialAppliances: [existing]);
    final store = ApplianceStore(repository: repository);
    await store.initialize();

    final duplicateSerial = Appliance(
      id: 'other-id',
      name: 'Duplicate fridge',
      category: 'Kitchen Appliance',
      brand: 'Samsung',
      serialNumber: 'serial-1',
      createdAt: DateTime(2026, 8, 2),
    );
    final unique = Appliance(
      id: 'unique-1',
      name: 'Bedroom AC',
      category: 'Air Conditioner',
      brand: 'LG',
      serialNumber: 'AC-22',
      createdAt: DateTime(2026, 8, 2),
    );

    final imported = await store.mergeAppliances([
      existing,
      duplicateSerial,
      unique,
    ]);

    expect(imported, 1);
    expect(store.totalCount, 2);
    expect(store.applianceById('unique-1'), isNotNull);

    store.dispose();
  });
}
