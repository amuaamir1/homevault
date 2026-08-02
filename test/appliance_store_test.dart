import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/warranty_notification_service.dart';
import 'package:homevault/state/appliance_store.dart';

class _RecordingReminderScheduler implements WarrantyReminderScheduler {
  final List<List<Appliance>> synced = [];
  final List<Appliance> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> syncAll(List<Appliance> appliances) async {
    synced.add(List<Appliance>.from(appliances));
  }

  @override
  Future<void> scheduleFor(Appliance appliance) async {
    scheduled.add(appliance);
  }

  @override
  Future<void> cancelFor(String applianceId) async {
    cancelled.add(applianceId);
  }
}

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
      warrantyTerms: 'Two-year comprehensive warranty',
      warrantyCoverageNotes: 'Compressor and electrical components',
      extendedWarrantyProvider: 'Retailer Protect',
      extendedWarrantyReference: 'EXT-100',
      extendedWarrantyExpiryDate: DateTime(2030, 1, 15),
      warrantyClaimNumber: 'CLM-10',
      warrantyClaimStatus: WarrantyClaimStatus.inReview,
      warrantyMarkedExpired: false,
      warrantyReminderEnabled: true,
      warrantyReminderDaysBefore: 60,
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
    expect(restored.warrantyTerms, 'Two-year comprehensive warranty');
    expect(
      restored.warrantyCoverageNotes,
      'Compressor and electrical components',
    );
    expect(restored.extendedWarrantyProvider, 'Retailer Protect');
    expect(restored.extendedWarrantyReference, 'EXT-100');
    expect(restored.extendedWarrantyExpiryDate, DateTime(2030, 1, 15));
    expect(restored.effectiveWarrantyExpiryDate, DateTime(2030, 1, 15));
    expect(restored.warrantyClaimNumber, 'CLM-10');
    expect(restored.warrantyClaimStatus, WarrantyClaimStatus.inReview);
    expect(restored.warrantyMarkedExpired, isFalse);
    expect(restored.warrantyReminderEnabled, isTrue);
    expect(restored.warrantyReminderDaysBefore, 60);
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

  test('extended warranty drives status and reminder date', () {
    final appliance = Appliance(
      id: 'tv-1',
      name: 'Living room TV',
      category: 'Television',
      brand: 'LG',
      warrantyExpiryDate: DateTime(2026, 1, 1),
      extendedWarrantyExpiryDate: DateTime(2027, 3, 31),
      warrantyReminderEnabled: true,
      warrantyReminderDaysBefore: 30,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(
      appliance.warrantyStatusAt(DateTime(2026, 8, 1)),
      WarrantyStatus.active,
    );
    expect(appliance.warrantyReminderDateAt(), DateTime(2027, 3, 1, 9));
    expect(appliance.warrantyDaysRemainingAt(DateTime(2027, 3, 1)), 30);
  });

  test(
    'store synchronizes, schedules, and cancels warranty reminders',
    () async {
      final existing = Appliance(
        id: 'ac-existing',
        name: 'Existing AC',
        category: 'Air Conditioner',
        brand: 'Daikin',
        warrantyExpiryDate: DateTime(2028, 8, 1),
        warrantyReminderEnabled: true,
        createdAt: DateTime(2026, 8, 1),
      );
      final repository = MemoryApplianceRepository(
        initialAppliances: [existing],
      );
      final scheduler = _RecordingReminderScheduler();
      final store = ApplianceStore(
        repository: repository,
        reminderScheduler: scheduler,
      );

      await store.initialize();
      expect(scheduler.synced.single.single.id, existing.id);

      final added = Appliance(
        id: 'fridge-new',
        name: 'New fridge',
        category: 'Kitchen Appliance',
        brand: 'Samsung',
        warrantyExpiryDate: DateTime(2029, 8, 1),
        warrantyReminderEnabled: true,
        createdAt: DateTime(2026, 8, 1),
      );
      await store.add(added);
      expect(scheduler.scheduled.last.id, added.id);

      final updated = Appliance.fromJson({
        ...added.toJson(),
        'warrantyReminderDaysBefore': 60,
      });
      await store.update(updated);
      expect(scheduler.scheduled.last.warrantyReminderDaysBefore, 60);

      await store.delete(added.id);
      expect(scheduler.cancelled.last, added.id);

      store.dispose();
    },
  );

  test('notification ids are stable and appliance-specific', () {
    final first = WarrantyNotificationService.notificationIdFor('appliance-1');
    final again = WarrantyNotificationService.notificationIdFor('appliance-1');
    final second = WarrantyNotificationService.notificationIdFor('appliance-2');

    expect(first, again);
    expect(first, isNot(second));
    expect(first, greaterThanOrEqualTo(0));
  });

  test('manual out-of-warranty status disables reminder scheduling date', () {
    final appliance = Appliance(
      id: 'voided-1',
      name: 'Voided appliance',
      category: 'Other',
      brand: '',
      warrantyExpiryDate: DateTime(2030, 1, 1),
      warrantyMarkedExpired: true,
      warrantyReminderEnabled: true,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(
      appliance.warrantyStatusAt(DateTime(2026, 8, 1)),
      WarrantyStatus.expired,
    );
    expect(appliance.warrantyReminderDateAt(), isNull);
  });

  test('service history is serialized and included in document totals', () {
    final receipt = StoredDocument(
      id: 'receipt-1',
      type: DocumentType.serviceReceipt,
      title: 'Service receipt',
      fileName: 'receipt.pdf',
      localPath: '/documents/receipt.pdf',
      sizeBytes: 512,
      attachedAt: DateTime(2026, 8, 2),
    );
    final record = ServiceRecord(
      id: 'service-1',
      serviceDate: DateTime(2026, 8, 2),
      createdAt: DateTime(2026, 8, 2),
      provider: 'Cool Care',
      technicianName: 'Aamir',
      ticketNumber: 'SR-100',
      problemDescription: 'Cooling reduced',
      workCompleted: 'Coil cleaned',
      partsReplaced: 'Air filter',
      serviceCharge: 1500,
      paymentMethod: 'Card',
      nextServiceDate: DateTime(2027, 2, 2),
      status: ServiceStatus.completed,
      reminderEnabled: true,
      reminderDaysBefore: 7,
      receiptDocument: receipt,
    );
    final appliance = Appliance(
      id: 'ac-service-1',
      name: 'Family room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      serviceRecords: [record],
      createdAt: DateTime(2026, 8, 1),
    );

    final restored = Appliance.fromJson(appliance.toJson());

    expect(restored.serviceRecordCount, 1);
    expect(restored.totalServiceCost, 1500);
    expect(restored.nextServiceDate, DateTime(2027, 2, 2));
    expect(restored.serviceRecords.single.provider, 'Cool Care');
    expect(restored.serviceRecords.single.status, ServiceStatus.completed);
    expect(restored.serviceRecords.single.receiptDocument?.id, 'receipt-1');
    expect(restored.documentCount, 1);
    expect(
      restored.serviceRecords.single.reminderDateAt(),
      DateTime(2027, 1, 26, 9),
    );
  });

  test(
    'service record add, update, and delete operations are persisted',
    () async {
      final appliance = Appliance(
        id: 'geyser-1',
        name: 'Bathroom geyser',
        category: 'Geyser / Water Heater',
        brand: 'Bajaj',
        createdAt: DateTime(2026, 8, 2),
      );
      final repository = MemoryApplianceRepository(
        initialAppliances: [appliance],
      );
      final store = ApplianceStore(repository: repository);
      await store.initialize();

      final record = ServiceRecord(
        id: 'service-1',
        serviceDate: DateTime(2026, 8, 2),
        createdAt: DateTime(2026, 8, 2),
        provider: 'Water Heat Services',
        problemDescription: 'Water is not heating',
        serviceCharge: 500,
        status: ServiceStatus.open,
      );
      await store.addServiceRecord(appliance.id, record);
      expect(store.totalServiceRecordCount, 1);
      expect(store.totalServiceCost, 500);

      final updated = record.copyWith(
        status: ServiceStatus.completed,
        workCompleted: 'Heating element replaced',
        serviceCharge: 850,
      );
      await store.updateServiceRecord(appliance.id, updated);
      expect(
        store.appliances.single.serviceRecords.single.status,
        ServiceStatus.completed,
      );
      expect(store.totalServiceCost, 850);

      final reloaded = ApplianceStore(repository: repository);
      await reloaded.initialize();
      expect(
        reloaded.appliances.single.serviceRecords.single.workCompleted,
        'Heating element replaced',
      );

      await store.removeServiceRecord(appliance.id, record.id);
      expect(store.totalServiceRecordCount, 0);

      final reloadedAfterDelete = ApplianceStore(repository: repository);
      await reloadedAfterDelete.initialize();
      expect(reloadedAfterDelete.appliances.single.serviceRecords, isEmpty);

      store.dispose();
      reloaded.dispose();
      reloadedAfterDelete.dispose();
    },
  );

  test('service reminder notification ids are stable and record-specific', () {
    final first = WarrantyNotificationService.serviceNotificationIdFor(
      'appliance-1',
      'service-1',
    );
    final again = WarrantyNotificationService.serviceNotificationIdFor(
      'appliance-1',
      'service-1',
    );
    final second = WarrantyNotificationService.serviceNotificationIdFor(
      'appliance-1',
      'service-2',
    );

    expect(first, again);
    expect(first, isNot(second));
    expect(first, greaterThanOrEqualTo(0));
  });
}
