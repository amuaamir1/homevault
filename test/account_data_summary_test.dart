import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/account_data_summary.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/models/service_record.dart';
import 'package:homevault/models/service_request.dart';
import 'package:homevault/models/stored_document.dart';

void main() {
  test('account data summary counts user-owned HomeVault records', () {
    final now = DateTime(2026, 8, 23, 12);
    final invoice = _document('invoice.pdf', now);
    final photo = _document(
      'photo.jpg',
      now,
      type: DocumentType.appliancePhoto,
    );
    final manual = _document('manual.pdf', now, type: DocumentType.userManual);
    final receipt = _document(
      'receipt.pdf',
      now,
      type: DocumentType.serviceReceipt,
    );

    final appliances = <Appliance>[
      Appliance(
        id: 'ac-1',
        name: 'Living room AC',
        category: 'Air conditioner',
        brand: 'Example',
        createdAt: now,
        appliancePhotoDocument: photo,
        invoiceDocument: invoice,
        additionalDocuments: [manual],
        serviceRecords: [
          ServiceRecord(
            id: 'service-1',
            serviceDate: now,
            createdAt: now,
            receiptDocument: receipt,
          ),
        ],
        serviceRequests: [_request('request-1', now)],
      ),
      Appliance(
        id: 'fridge-1',
        name: 'Kitchen fridge',
        category: 'Refrigerator',
        brand: 'Example',
        createdAt: now,
        serviceRequests: [_request('request-2', now)],
      ),
    ];

    final summary = AccountDataSummary.fromAppliances(appliances);

    expect(summary.applianceCount, 2);
    expect(summary.documentCount, 4);
    expect(summary.serviceRecordCount, 1);
    expect(summary.serviceRequestCount, 2);
    expect(summary.isEmpty, isFalse);
  });

  test('empty account data summary reports zero counts', () {
    final summary = AccountDataSummary.fromAppliances(const <Appliance>[]);

    expect(summary.applianceCount, 0);
    expect(summary.documentCount, 0);
    expect(summary.serviceRecordCount, 0);
    expect(summary.serviceRequestCount, 0);
    expect(summary.isEmpty, isTrue);
  });
}

StoredDocument _document(
  String fileName,
  DateTime attachedAt, {
  DocumentType type = DocumentType.invoice,
}) {
  return StoredDocument(
    type: type,
    fileName: fileName,
    localPath: '/tmp/$fileName',
    sizeBytes: 128,
    attachedAt: attachedAt,
  );
}

ServiceRequest _request(String id, DateTime now) {
  return ServiceRequest(
    id: id,
    createdAt: now,
    updatedAt: now,
    preferredDate: now,
    visitWindow: ServiceVisitWindow.flexible,
    issueDescription: 'Routine service',
    serviceAddress: 'Test address',
  );
}
