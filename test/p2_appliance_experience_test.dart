import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/stored_document.dart';
import 'package:homevault/models/backup_models.dart';
import 'package:homevault/services/homevault_backup_service.dart';
import 'package:homevault/services/warranty_notification_service.dart';

StoredDocument _document({
  required String id,
  required DocumentType type,
  required String fileName,
}) {
  return StoredDocument(
    id: id,
    type: type,
    title: type.label,
    fileName: fileName,
    localPath: '/documents/$fileName',
    sizeBytes: 1024,
    attachedAt: DateTime(2026, 8, 10),
  );
}

void main() {
  test('P2 appliance fields survive JSON round trip', () {
    final appliance = Appliance(
      id: 'ac-p2',
      name: 'Living room AC',
      category: 'Air Conditioner',
      brand: 'Daikin',
      appliancePhotoDocument: _document(
        id: 'photo-1',
        type: DocumentType.appliancePhoto,
        fileName: 'ac.jpg',
      ),
      warrantyExpiryDate: DateTime(2027, 5, 1),
      extendedWarrantyProvider: 'Retail Protect',
      extendedWarrantyReference: 'EXT-20',
      extendedWarrantyStartDate: DateTime(2027, 5, 2),
      extendedWarrantyExpiryDate: DateTime(2029, 5, 1),
      extendedWarrantyCost: 2499,
      extendedWarrantyDocument: _document(
        id: 'extended-1',
        type: DocumentType.extendedWarranty,
        fileName: 'extended.pdf',
      ),
      amcProvider: 'Daikin Care',
      amcReference: 'AMC-100',
      amcPhone: '+919876543210',
      amcStartDate: DateTime(2026, 8, 10),
      amcExpiryDate: DateTime(2027, 8, 9),
      amcCost: 3600,
      amcIncludedServices: 4,
      amcUsedServices: 1,
      amcReminderEnabled: true,
      amcReminderDaysBefore: 30,
      amcDocument: _document(
        id: 'amc-1',
        type: DocumentType.amcContract,
        fileName: 'amc.pdf',
      ),
      amcNotes: 'Four preventive maintenance visits included.',
      createdAt: DateTime(2026, 8, 10),
    );

    final restored = Appliance.fromJson(appliance.toJson());

    expect(restored.appliancePhotoDocument?.type, DocumentType.appliancePhoto);
    expect(restored.extendedWarrantyStartDate, DateTime(2027, 5, 2));
    expect(restored.extendedWarrantyCost, 2499);
    expect(
      restored.extendedWarrantyDocument?.type,
      DocumentType.extendedWarranty,
    );
    expect(restored.amcProvider, 'Daikin Care');
    expect(restored.amcReference, 'AMC-100');
    expect(restored.amcPhone, '+919876543210');
    expect(restored.amcExpiryDate, DateTime(2027, 8, 9));
    expect(restored.amcCost, 3600);
    expect(restored.amcIncludedServices, 4);
    expect(restored.amcUsedServices, 1);
    expect(restored.amcRemainingServices, 3);
    expect(restored.amcReminderEnabled, isTrue);
    expect(restored.amcReminderDaysBefore, 30);
    expect(restored.amcDocument?.type, DocumentType.amcContract);
    expect(restored.hasAmc, isTrue);
    expect(restored.hasExtendedWarranty, isTrue);
  });

  test(
    'photo is synced/backed up as an attachment but not counted as a document',
    () {
      final appliance = Appliance(
        id: 'photo-count',
        name: 'Refrigerator',
        category: 'Kitchen Appliance',
        brand: 'Samsung',
        appliancePhotoDocument: _document(
          id: 'photo-1',
          type: DocumentType.appliancePhoto,
          fileName: 'fridge.png',
        ),
        invoiceDocument: _document(
          id: 'invoice-1',
          type: DocumentType.invoice,
          fileName: 'invoice.pdf',
        ),
        createdAt: DateTime(2026, 8, 10),
      );

      expect(appliance.documentCount, 1);
      expect(appliance.allDocuments.single.type, DocumentType.invoice);
      expect(appliance.allAttachments, hasLength(2));
      expect(appliance.allAttachments.first.type, DocumentType.appliancePhoto);
    },
  );

  test('AMC reminder date and notification id are stable', () {
    final appliance = Appliance(
      id: 'amc-reminder',
      name: 'Bedroom AC',
      category: 'Air Conditioner',
      brand: 'LG',
      amcExpiryDate: DateTime(2027, 8, 31),
      amcReminderEnabled: true,
      amcReminderDaysBefore: 30,
      createdAt: DateTime(2026, 8, 10),
    );

    expect(appliance.amcReminderDateAt(), DateTime(2027, 8, 1, 9));

    final first = WarrantyNotificationService.amcNotificationIdFor(
      appliance.id,
    );
    final again = WarrantyNotificationService.amcNotificationIdFor(
      appliance.id,
    );
    final warranty = WarrantyNotificationService.notificationIdFor(
      appliance.id,
    );

    expect(first, again);
    expect(first, isNot(warranty));
  });

  test(
    'replacing and removing the appliance photo uses attachment helpers',
    () {
      final photo = _document(
        id: 'photo-old',
        type: DocumentType.appliancePhoto,
        fileName: 'old.jpg',
      );
      final replacement = _document(
        id: 'photo-new',
        type: DocumentType.appliancePhoto,
        fileName: 'new.jpg',
      );
      final appliance = Appliance(
        id: 'photo-edit',
        name: 'TV',
        category: 'Television',
        brand: 'Sony',
        appliancePhotoDocument: photo,
        createdAt: DateTime(2026, 8, 10),
      );

      final replaced = appliance.replaceDocument(photo.id, replacement);
      expect(replaced.appliancePhotoDocument?.id, 'photo-new');
      expect(
        replaced.appliancePhotoDocument?.type,
        DocumentType.appliancePhoto,
      );

      final removed = replaced.withoutDocument('photo-new');
      expect(removed.appliancePhotoDocument, isNull);
      expect(removed.allAttachments, isEmpty);
    },
  );

  test(
    'P2 photo and coverage documents are included in backup restore',
    () async {
      final sourceDirectory = await Directory.systemTemp.createTemp(
        'homevault_p2_source_',
      );
      final restoreDirectory = await Directory.systemTemp.createTemp(
        'homevault_p2_restore_',
      );

      try {
        Future<StoredDocument> fileDocument(
          String name,
          DocumentType type,
          List<int> bytes,
        ) async {
          final file = File('${sourceDirectory.path}/$name');
          await file.writeAsBytes(bytes);
          return StoredDocument(
            id: name,
            type: type,
            title: type.label,
            fileName: name,
            localPath: file.path,
            sizeBytes: bytes.length,
            attachedAt: DateTime(2026, 8, 10),
          );
        }

        final photo = await fileDocument(
          'photo.jpg',
          DocumentType.appliancePhoto,
          [1, 2, 3],
        );
        final extended = await fileDocument(
          'extended.pdf',
          DocumentType.extendedWarranty,
          [4, 5, 6],
        );
        final amc = await fileDocument('amc.pdf', DocumentType.amcContract, [
          7,
          8,
          9,
        ]);

        final appliance = Appliance(
          id: 'backup-p2',
          name: 'P2 AC',
          category: 'Air Conditioner',
          brand: 'Daikin',
          appliancePhotoDocument: photo,
          extendedWarrantyDocument: extended,
          amcDocument: amc,
          createdAt: DateTime(2026, 8, 10),
        );

        final service = HomeVaultBackupService(
          documentsDirectoryProvider: () async => restoreDirectory,
        );
        final archive = await service.buildBackup([appliance]);
        final selection = service.inspectBackupBytes(
          archive.bytes,
          fileName: 'p2-backup.zip',
        );
        final restored = await service.prepareRestore(
          selection: selection,
          existingAppliances: const [],
          mode: RestoreMode.replace,
        );

        expect(selection.preview.documentCount, 3);
        expect(restored.restoredDocuments, 3);
        expect(restored.missingDocuments, 0);
        expect(restored.appliances.single.appliancePhotoDocument, isNotNull);
        expect(restored.appliances.single.extendedWarrantyDocument, isNotNull);
        expect(restored.appliances.single.amcDocument, isNotNull);
      } finally {
        await sourceDirectory.delete(recursive: true);
        await restoreDirectory.delete(recursive: true);
      }
    },
  );
}
