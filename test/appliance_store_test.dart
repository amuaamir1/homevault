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
      supportProvider: 'Daikin Care',
      supportPhone: '+966 11 123 4567',
      supportEmail: 'care@example.com',
      supportWebsite: 'support.example.com',
      supportNotes: 'Sunday to Thursday, 9 AM to 5 PM',
      purchaseDate: DateTime(2026, 1, 15),
      warrantyExpiryDate: DateTime(2028, 1, 15),
      invoiceDocument: StoredDocument(
        id: 'invoice-1',
        type: DocumentType.invoice,
        title: 'Purchase invoice',
        reference: 'INV-100',
        fileName: 'invoice.pdf',
        localPath: '/documents/invoice.pdf',
        sizeBytes: 2048,
        attachedAt: DateTime(2026, 1, 15, 10, 30),
      ),
      additionalDocuments: [
        StoredDocument(
          id: 'manual-1',
          type: DocumentType.userManual,
          title: 'AC user manual',
          fileName: 'manual.pdf',
          localPath: '/documents/manual.pdf',
          sizeBytes: 4096,
          attachedAt: DateTime(2026, 1, 15, 10, 40),
        ),
      ],
      createdAt: DateTime(2026, 1, 15, 10),
    );

    final restored = Appliance.fromJson(appliance.toJson());

    expect(restored.id, appliance.id);
    expect(restored.name, appliance.name);
    expect(restored.purchaseDate, appliance.purchaseDate);
    expect(restored.warrantyExpiryDate, appliance.warrantyExpiryDate);
    expect(restored.supportProvider, 'Daikin Care');
    expect(restored.supportPhone, '+966 11 123 4567');
    expect(restored.supportEmail, 'care@example.com');
    expect(restored.supportWebsite, 'support.example.com');
    expect(restored.supportNotes, 'Sunday to Thursday, 9 AM to 5 PM');
    expect(restored.invoiceDocument?.fileName, 'invoice.pdf');
    expect(restored.invoiceDocument?.type, DocumentType.invoice);
    expect(restored.invoiceDocument?.reference, 'INV-100');
    expect(restored.additionalDocuments.single.type, DocumentType.userManual);
    expect(restored.documentCount, 2);
  });

  test('legacy invoice JSON is upgraded with invoice metadata', () {
    final restored = Appliance.fromJson({
      'id': 'legacy-1',
      'name': 'Legacy appliance',
      'category': 'Other',
      'brand': '',
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'invoiceDocument': {
        'fileName': 'old-invoice.pdf',
        'localPath': '/documents/old-invoice.pdf',
        'sizeBytes': 100,
        'attachedAt': DateTime(2026, 1, 1).toIso8601String(),
      },
    });

    expect(restored.invoiceDocument?.type, DocumentType.invoice);
    expect(restored.invoiceDocument?.displayTitle, 'Invoice');
    expect(restored.invoiceDocument?.id, '/documents/old-invoice.pdf');
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

  test('document add and delete operations are persisted', () async {
    final original = Appliance(
      id: 'fridge-1',
      name: 'Kitchen fridge',
      category: 'Kitchen Appliance',
      brand: 'Samsung',
      createdAt: DateTime(2026, 8, 1),
    );
    final repository = MemoryApplianceRepository(initialAppliances: [original]);
    final store = ApplianceStore(repository: repository);
    await store.initialize();

    final document = StoredDocument(
      id: 'manual-1',
      type: DocumentType.userManual,
      title: 'Fridge manual',
      fileName: 'manual.pdf',
      localPath: '/documents/manual.pdf',
      sizeBytes: 2048,
      attachedAt: DateTime(2026, 8, 1, 11),
    );

    await store.addDocument(original.id, document);
    expect(store.appliances.single.additionalDocuments.single.id, 'manual-1');

    final updatedDocument = document.copyWith(
      title: 'Updated fridge manual',
      reference: 'MAN-2026',
    );
    await store.replaceDocument(original.id, document.id, updatedDocument);
    expect(
      store.appliances.single.additionalDocuments.single.displayTitle,
      'Updated fridge manual',
    );

    final reloadedAfterAdd = ApplianceStore(repository: repository);
    await reloadedAfterAdd.initialize();
    expect(reloadedAfterAdd.appliances.single.documentCount, 1);
    expect(
      reloadedAfterAdd.appliances.single.additionalDocuments.single.reference,
      'MAN-2026',
    );

    await store.removeDocument(original.id, document.id);
    expect(store.appliances.single.allDocuments, isEmpty);

    final reloadedAfterDelete = ApplianceStore(repository: repository);
    await reloadedAfterDelete.initialize();
    expect(reloadedAfterDelete.appliances.single.allDocuments, isEmpty);

    store.dispose();
    reloadedAfterAdd.dispose();
    reloadedAfterDelete.dispose();
  });

  test('update and delete are persisted', () async {
    final original = Appliance(
      id: 'fridge-1',
      name: 'Kitchen fridge',
      category: 'Kitchen Appliance',
      brand: 'Samsung',
      createdAt: DateTime(2026, 8, 1),
    );
    final repository = MemoryApplianceRepository(initialAppliances: [original]);
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
