import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/appliance_store.dart';

void main() {
  test('appliance JSON preserves dates and document details', () {
    final appliance = Appliance(
      id: 'ac-1',
      name: 'Living room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      modelNumber: 'FTKM50',
      serialNumber: 'SN-100',
      purchaseDate: DateTime(2026, 1, 15),
      warrantyExpiryDate: DateTime(2028, 1, 15),
      invoiceDocument: StoredDocument(
        fileName: 'invoice.pdf',
        localPath: '/documents/invoice.pdf',
        sizeBytes: 2048,
        attachedAt: DateTime(2026, 1, 15, 10, 30),
      ),
      createdAt: DateTime(2026, 1, 15, 10),
    );

    final restored = Appliance.fromJson(appliance.toJson());

    expect(restored.id, appliance.id);
    expect(restored.name, appliance.name);
    expect(restored.purchaseDate, appliance.purchaseDate);
    expect(restored.warrantyExpiryDate, appliance.warrantyExpiryDate);
    expect(restored.invoiceDocument?.fileName, 'invoice.pdf');
    expect(restored.invoiceDocument?.sizeBytes, 2048);
  });

  test('saved appliances are available to a newly initialized store', () async {
    final repository = MemoryApplianceRepository();
    final firstStore = ApplianceStore(repository: repository);
    await firstStore.initialize();

    final appliance = Appliance(
      id: 'ac-1',
      name: 'Bedroom AC',
      category: 'Air Conditioner',
      brand: 'LG',
      createdAt: DateTime(2026, 8, 1),
    );

    await firstStore.add(appliance);

    final reloadedStore = ApplianceStore(repository: repository);
    await reloadedStore.initialize();

    expect(reloadedStore.totalCount, 1);
    expect(reloadedStore.appliances.single.name, 'Bedroom AC');

    firstStore.dispose();
    reloadedStore.dispose();
  });

  test('update and delete are persisted', () async {
    final original = Appliance(
      id: 'fridge-1',
      name: 'Kitchen fridge',
      category: 'Kitchen Appliance',
      brand: 'Samsung',
      createdAt: DateTime(2026, 8, 1),
    );
    final repository = MemoryApplianceRepository(
      initialAppliances: [original],
    );
    final store = ApplianceStore(repository: repository);
    await store.initialize();

    final updated = Appliance(
      id: original.id,
      name: 'Main kitchen fridge',
      category: original.category,
      brand: original.brand,
      createdAt: original.createdAt,
    );

    await store.update(updated);
    expect(store.appliances.single.name, 'Main kitchen fridge');

    await store.delete(updated.id);
    expect(store.appliances, isEmpty);

    final reloadedStore = ApplianceStore(repository: repository);
    await reloadedStore.initialize();
    expect(reloadedStore.appliances, isEmpty);

    store.dispose();
    reloadedStore.dispose();
  });
}
