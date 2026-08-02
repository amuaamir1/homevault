import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/appliance.dart';
import '../models/service_record.dart';

class HomeVaultExportService {
  const HomeVaultExportService();

  Future<bool> exportApplianceInventory(Iterable<Appliance> appliances) async {
    final now = DateTime.now();
    final rows = <List<Object?>>[
      [
        'Appliance name',
        'Category',
        'Brand',
        'Model number',
        'Serial number',
        'Purchase date',
        'Warranty expiry',
        'Warranty status',
        'Support provider',
        'Support phone',
        'Documents',
        'Service records',
        'Total service cost',
        'Notes',
      ],
      ...appliances.map(
        (appliance) => <Object?>[
          appliance.name,
          appliance.category,
          appliance.brand,
          appliance.modelNumber,
          appliance.serialNumber,
          _date(appliance.purchaseDate),
          _date(appliance.effectiveWarrantyExpiryDate),
          _warrantyStatusLabel(appliance.warrantyStatusAt(now)),
          appliance.supportProvider,
          appliance.supportPhone,
          appliance.documentCount,
          appliance.serviceRecordCount,
          appliance.totalServiceCost.toStringAsFixed(2),
          appliance.notes,
        ],
      ),
    ];

    return _saveCsv(
      fileName: 'HomeVault_Appliance_Inventory_${_dateStamp()}.csv',
      rows: rows,
    );
  }

  Future<bool> exportWarrantyReport(Iterable<Appliance> appliances) async {
    final now = DateTime.now();
    final rows = <List<Object?>>[
      [
        'Appliance name',
        'Brand',
        'Model number',
        'Standard warranty expiry',
        'Extended warranty expiry',
        'Effective expiry',
        'Days remaining',
        'Warranty status',
        'Warranty provider',
        'Warranty reference',
        'Extended provider',
        'Extended reference',
        'Claim number',
        'Claim status',
        'Reminder enabled',
        'Reminder days before',
      ],
      ...appliances.map(
        (appliance) => <Object?>[
          appliance.name,
          appliance.brand,
          appliance.modelNumber,
          _date(appliance.warrantyExpiryDate),
          _date(appliance.extendedWarrantyExpiryDate),
          _date(appliance.effectiveWarrantyExpiryDate),
          appliance.warrantyDaysRemainingAt(now) ?? '',
          _warrantyStatusLabel(appliance.warrantyStatusAt(now)),
          appliance.warrantyProvider,
          appliance.warrantyReference,
          appliance.extendedWarrantyProvider,
          appliance.extendedWarrantyReference,
          appliance.warrantyClaimNumber,
          appliance.warrantyClaimStatus.label,
          appliance.warrantyReminderEnabled ? 'Yes' : 'No',
          appliance.warrantyReminderDaysBefore,
        ],
      ),
    ];

    return _saveCsv(
      fileName: 'HomeVault_Warranty_Report_${_dateStamp()}.csv',
      rows: rows,
    );
  }

  Future<bool> exportServiceCostReport(Iterable<Appliance> appliances) async {
    final rows = <List<Object?>>[
      [
        'Appliance name',
        'Brand',
        'Service date',
        'Provider',
        'Technician',
        'Ticket number',
        'Status',
        'Problem',
        'Work completed',
        'Parts replaced',
        'Service charge',
        'Payment method',
        'Next service date',
        'Notes',
      ],
    ];

    for (final appliance in appliances) {
      for (final record in appliance.serviceRecords) {
        rows.add([
          appliance.name,
          appliance.brand,
          _date(record.serviceDate),
          record.provider,
          record.technicianName,
          record.ticketNumber,
          record.status.label,
          record.problemDescription,
          record.workCompleted,
          record.partsReplaced,
          record.serviceCharge.toStringAsFixed(2),
          record.paymentMethod,
          _date(record.nextServiceDate),
          record.notes,
        ]);
      }
    }

    return _saveCsv(
      fileName: 'HomeVault_Service_Cost_Report_${_dateStamp()}.csv',
      rows: rows,
    );
  }

  Future<bool> exportAppliancePdf(Appliance appliance) async {
    final document = pw.Document(
      title: '${_pdfSafe(appliance.name)} - HomeVault',
      author: 'HomeVault',
      subject: 'Appliance summary',
    );
    final now = DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'HomeVault',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Appliance summary'),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            _pdfSafe(appliance.name),
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _pdfSafe(
              [
                appliance.brand,
                appliance.category,
              ].where((value) => value.trim().isNotEmpty).join(' - '),
            ),
          ),
          pw.SizedBox(height: 18),
          _pdfSection('Appliance details', [
            _pdfRow('Model number', appliance.modelNumber),
            _pdfRow('Serial number', appliance.serialNumber),
            _pdfRow('Purchase date', _date(appliance.purchaseDate)),
            _pdfRow('Created in HomeVault', _date(appliance.createdAt)),
            _pdfRow('Notes', appliance.notes),
          ]),
          _pdfSection('Warranty', [
            _pdfRow(
              'Status',
              _warrantyStatusLabel(appliance.warrantyStatusAt(now)),
            ),
            _pdfRow('Standard expiry', _date(appliance.warrantyExpiryDate)),
            _pdfRow(
              'Extended expiry',
              _date(appliance.extendedWarrantyExpiryDate),
            ),
            _pdfRow('Provider', appliance.warrantyProvider),
            _pdfRow('Reference', appliance.warrantyReference),
            _pdfRow('Extended provider', appliance.extendedWarrantyProvider),
            _pdfRow('Extended reference', appliance.extendedWarrantyReference),
            _pdfRow('Claim number', appliance.warrantyClaimNumber),
            _pdfRow('Claim status', appliance.warrantyClaimStatus.label),
            _pdfRow('Terms', appliance.warrantyTerms),
            _pdfRow('Coverage notes', appliance.warrantyCoverageNotes),
          ]),
          _pdfSection('Support', [
            _pdfRow('Provider', appliance.supportProvider),
            _pdfRow('Phone', appliance.supportPhone),
            _pdfRow('Email', appliance.supportEmail),
            _pdfRow('Website', appliance.supportWebsite),
            _pdfRow('Notes', appliance.supportNotes),
          ]),
          _pdfSection(
            'Documents (${appliance.documentCount})',
            appliance.allDocuments.isEmpty
                ? [pw.Text('No documents saved.')]
                : appliance.allDocuments
                      .map(
                        (document) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 5),
                          child: pw.Text(
                            '- ${_pdfSafe(document.displayTitle)} '
                            '(${_pdfSafe(document.fileName)})',
                          ),
                        ),
                      )
                      .toList(),
          ),
          _pdfSection(
            'Service history (${appliance.serviceRecordCount})',
            appliance.serviceRecords.isEmpty
                ? [pw.Text('No service records saved.')]
                : appliance.serviceRecords.map(_serviceRecordBlock).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total recorded service cost: '
            '${appliance.totalServiceCost.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Generated ${_date(DateTime.now())}. This report is based on data stored locally in HomeVault.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    final fileName =
        'HomeVault_${_safeFilePart(appliance.name)}_${_dateStamp()}.pdf';
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save appliance summary',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
    return savedPath != null;
  }

  Future<bool> _saveCsv({
    required String fileName,
    required List<List<Object?>> rows,
  }) async {
    final csv = rows.map(_csvRow).join('\r\n');
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save HomeVault export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: bytes,
    );
    return savedPath != null;
  }

  String _csvRow(List<Object?> values) {
    return values
        .map((value) {
          final text = '${value ?? ''}'.replaceAll('"', '""');
          return '"$text"';
        })
        .join(',');
  }

  pw.Widget _pdfSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 7),
        ...children,
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    final displayed = value.trim().isEmpty ? '-' : _pdfSafe(value);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 125,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(displayed)),
        ],
      ),
    );
  }

  pw.Widget _serviceRecordBlock(ServiceRecord record) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${_date(record.serviceDate)} - ${_pdfSafe(record.status.label)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Provider: ${_pdfSafe(record.provider)}'),
          pw.Text('Ticket: ${_pdfSafe(record.ticketNumber)}'),
          pw.Text('Problem: ${_pdfSafe(record.problemDescription)}'),
          pw.Text('Work completed: ${_pdfSafe(record.workCompleted)}'),
          pw.Text('Parts replaced: ${_pdfSafe(record.partsReplaced)}'),
          pw.Text('Charge: ${record.serviceCharge.toStringAsFixed(2)}'),
          pw.Text('Next service: ${_date(record.nextServiceDate)}'),
        ],
      ),
    );
  }

  String _warrantyStatusLabel(WarrantyStatus status) => switch (status) {
    WarrantyStatus.active => 'Active',
    WarrantyStatus.expiringSoon => 'Expiring soon',
    WarrantyStatus.expired => 'Expired',
    WarrantyStatus.notProvided => 'No expiry date',
  };

  String _date(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _dateStamp() => _date(DateTime.now());

  String _safeFilePart(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safe.isEmpty ? 'Appliance' : safe;
  }

  String _pdfSafe(String value) {
    return value.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '?');
  }
}
