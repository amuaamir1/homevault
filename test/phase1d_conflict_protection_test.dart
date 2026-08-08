import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/appliance_store.dart';

class _ConflictRepository
    implements ApplianceRepository, ConflictProtectedApplianceRepository {
  _ConflictRepository(this.current);

  List<Appliance> current;
  bool forceOverwriteSeen = false;

  @override
  Future<List<Appliance>> loadAppliances() async =>
      List<Appliance>.from(current);

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {
    current = List<Appliance>.from(appliances);
  }

  @override
  Future<List<Appliance>> saveAppliancesProtected(
    List<Appliance> appliances, {
    bool forceOverwrite = false,
  }) async {
    forceOverwriteSeen = forceOverwrite;
    current = appliances
        .map(
          (item) => item.withCloudSyncMetadata(
            cloudRevision: item.cloudRevision + 1,
            cloudUpdatedByDevice: 'test-device',
          ),
        )
        .toList(growable: false);
    return List<Appliance>.from(current);
  }
}

void main() {
  test('appliance cloud revision survives JSON round trip', () {
    final original = Appliance(
      id: 'ac-1',
      name: 'AC',
      category: 'Air Conditioner',
      brand: 'LG',
      cloudRevision: 7,
      cloudUpdatedByDevice: 'device-a',
      createdAt: DateTime(2026, 8, 8),
    );

    final restored = Appliance.fromJson(original.toJson());

    expect(restored.cloudRevision, 7);
    expect(restored.cloudUpdatedByDevice, 'device-a');
  });

  test(
    'store uses revision returned by conflict protected repository',
    () async {
      final repository = _ConflictRepository([
        Appliance(
          id: 'ac-1',
          name: 'AC',
          category: 'Air Conditioner',
          brand: 'LG',
          cloudRevision: 3,
          cloudUpdatedByDevice: 'device-a',
          createdAt: DateTime(2026, 8, 8),
        ),
      ]);
      final store = ApplianceStore(repository: repository);
      await store.initialize();

      await store.update(
        Appliance(
          id: 'ac-1',
          name: 'Bedroom AC',
          category: 'Air Conditioner',
          brand: 'LG',
          cloudRevision: 3,
          cloudUpdatedByDevice: 'device-a',
          createdAt: DateTime(2026, 8, 8),
        ),
      );

      expect(store.appliances.single.cloudRevision, 4);
      expect(store.appliances.single.cloudUpdatedByDevice, 'test-device');

      store.dispose();
    },
  );

  test('explicit replace requests force overwrite', () async {
    final repository = _ConflictRepository(const []);
    final store = ApplianceStore(repository: repository);
    await store.initialize();

    await store.replaceAll([
      Appliance(
        id: 'restored-1',
        name: 'Restored appliance',
        category: 'Other',
        brand: 'Test',
        createdAt: DateTime(2026, 8, 8),
      ),
    ]);

    expect(repository.forceOverwriteSeen, isTrue);
    store.dispose();
  });
}
