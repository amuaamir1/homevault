import 'stored_document.dart';

enum ServiceStatus { scheduled, open, inProgress, completed, cancelled }

extension ServiceStatusDetails on ServiceStatus {
  String get label => switch (this) {
    ServiceStatus.scheduled => 'Scheduled',
    ServiceStatus.open => 'Open',
    ServiceStatus.inProgress => 'In progress',
    ServiceStatus.completed => 'Completed',
    ServiceStatus.cancelled => 'Cancelled',
  };

  bool get isActive =>
      this == ServiceStatus.scheduled ||
      this == ServiceStatus.open ||
      this == ServiceStatus.inProgress;
}

class ServiceRecord {
  ServiceRecord({
    required this.id,
    required this.serviceDate,
    required this.createdAt,
    this.provider = '',
    this.technicianName = '',
    this.ticketNumber = '',
    this.problemDescription = '',
    this.workCompleted = '',
    this.partsReplaced = '',
    this.serviceCharge = 0,
    this.paymentMethod = '',
    this.nextServiceDate,
    this.status = ServiceStatus.completed,
    this.notes = '',
    this.reminderEnabled = false,
    this.reminderDaysBefore = 7,
    this.receiptDocument,
    this.reportDocument,
  });

  factory ServiceRecord.fromJson(Map<String, dynamic> json) {
    return ServiceRecord(
      id: json['id'] as String? ?? '',
      serviceDate:
          _dateFromJson(json['serviceDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      createdAt:
          _dateFromJson(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      provider: json['provider'] as String? ?? '',
      technicianName: json['technicianName'] as String? ?? '',
      ticketNumber: json['ticketNumber'] as String? ?? '',
      problemDescription: json['problemDescription'] as String? ?? '',
      workCompleted: json['workCompleted'] as String? ?? '',
      partsReplaced: json['partsReplaced'] as String? ?? '',
      serviceCharge: (json['serviceCharge'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? '',
      nextServiceDate: _dateFromJson(json['nextServiceDate']),
      status: _statusFromJson(json['status']),
      notes: json['notes'] as String? ?? '',
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      reminderDaysBefore: _reminderDaysFromJson(json['reminderDaysBefore']),
      receiptDocument: _documentFromJson(json['receiptDocument']),
      reportDocument: _documentFromJson(json['reportDocument']),
    );
  }

  final String id;
  final DateTime serviceDate;
  final DateTime createdAt;
  final String provider;
  final String technicianName;
  final String ticketNumber;
  final String problemDescription;
  final String workCompleted;
  final String partsReplaced;
  final double serviceCharge;
  final String paymentMethod;
  final DateTime? nextServiceDate;
  final ServiceStatus status;
  final String notes;
  final bool reminderEnabled;
  final int reminderDaysBefore;
  final StoredDocument? receiptDocument;
  final StoredDocument? reportDocument;

  List<StoredDocument> get documents =>
      List.unmodifiable([?receiptDocument, ?reportDocument]);

  bool get hasDocuments => documents.isNotEmpty;

  DateTime? reminderDateAt({int hour = 9}) {
    final nextDate = nextServiceDate;
    if (!reminderEnabled ||
        nextDate == null ||
        status == ServiceStatus.cancelled) {
      return null;
    }

    return DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
      hour,
    ).subtract(Duration(days: reminderDaysBefore));
  }

  int? daysUntilNextService(DateTime now) {
    final nextDate = nextServiceDate;
    if (nextDate == null) return null;

    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(nextDate.year, nextDate.month, nextDate.day);
    return dueDate.difference(today).inDays;
  }

  ServiceRecord copyWith({
    String? id,
    DateTime? serviceDate,
    DateTime? createdAt,
    String? provider,
    String? technicianName,
    String? ticketNumber,
    String? problemDescription,
    String? workCompleted,
    String? partsReplaced,
    double? serviceCharge,
    String? paymentMethod,
    DateTime? nextServiceDate,
    bool clearNextServiceDate = false,
    ServiceStatus? status,
    String? notes,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    StoredDocument? receiptDocument,
    bool setReceiptDocument = false,
    StoredDocument? reportDocument,
    bool setReportDocument = false,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      serviceDate: serviceDate ?? this.serviceDate,
      createdAt: createdAt ?? this.createdAt,
      provider: provider ?? this.provider,
      technicianName: technicianName ?? this.technicianName,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      problemDescription: problemDescription ?? this.problemDescription,
      workCompleted: workCompleted ?? this.workCompleted,
      partsReplaced: partsReplaced ?? this.partsReplaced,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      nextServiceDate: clearNextServiceDate
          ? null
          : nextServiceDate ?? this.nextServiceDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      receiptDocument: setReceiptDocument
          ? receiptDocument
          : this.receiptDocument,
      reportDocument: setReportDocument ? reportDocument : this.reportDocument,
    );
  }

  ServiceRecord replaceDocument(String documentId, StoredDocument replacement) {
    if (receiptDocument?.id == documentId) {
      return copyWith(
        receiptDocument: replacement.copyWith(
          type: DocumentType.serviceReceipt,
        ),
        setReceiptDocument: true,
      );
    }
    if (reportDocument?.id == documentId) {
      return copyWith(
        reportDocument: replacement.copyWith(type: DocumentType.serviceReport),
        setReportDocument: true,
      );
    }
    return this;
  }

  ServiceRecord withoutDocument(String documentId) {
    return copyWith(
      receiptDocument: receiptDocument?.id == documentId
          ? null
          : receiptDocument,
      setReceiptDocument: receiptDocument?.id == documentId,
      reportDocument: reportDocument?.id == documentId ? null : reportDocument,
      setReportDocument: reportDocument?.id == documentId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceDate': serviceDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'provider': provider,
      'technicianName': technicianName,
      'ticketNumber': ticketNumber,
      'problemDescription': problemDescription,
      'workCompleted': workCompleted,
      'partsReplaced': partsReplaced,
      'serviceCharge': serviceCharge,
      'paymentMethod': paymentMethod,
      'nextServiceDate': nextServiceDate?.toIso8601String(),
      'status': status.name,
      'notes': notes,
      'reminderEnabled': reminderEnabled,
      'reminderDaysBefore': reminderDaysBefore,
      'receiptDocument': receiptDocument?.toJson(),
      'reportDocument': reportDocument?.toJson(),
    };
  }

  static DateTime? _dateFromJson(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static StoredDocument? _documentFromJson(Object? value) {
    if (value is Map<String, dynamic>) {
      return StoredDocument.fromJson(value);
    }
    if (value is Map) {
      return StoredDocument.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  static ServiceStatus _statusFromJson(Object? value) {
    final name = value as String?;
    return ServiceStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => ServiceStatus.completed,
    );
  }

  static int _reminderDaysFromJson(Object? value) {
    final days = value is int ? value : int.tryParse('$value');
    if (days == null || days < 0) return 7;
    if (days > 365) return 365;
    return days;
  }
}
