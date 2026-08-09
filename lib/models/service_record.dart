import 'stored_document.dart';

enum ServiceStatus { scheduled, open, inProgress, completed, cancelled }

enum ServiceIntervalUnit { months, years }

extension ServiceIntervalUnitDetails on ServiceIntervalUnit {
  String get label => switch (this) {
    ServiceIntervalUnit.months => 'Month',
    ServiceIntervalUnit.years => 'Year',
  };

  String labelFor(int value) => switch (this) {
    ServiceIntervalUnit.months => value == 1 ? 'month' : 'months',
    ServiceIntervalUnit.years => value == 1 ? 'year' : 'years',
  };
}

extension ServiceStatusDetails on ServiceStatus {
  String get label => switch (this) {
    ServiceStatus.scheduled => 'Scheduled',
    ServiceStatus.open => 'Open',
    ServiceStatus.inProgress => 'Open',
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
    this.serviceIntervalValue,
    this.serviceIntervalUnit = ServiceIntervalUnit.months,
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
      serviceIntervalValue: _positiveIntFromJson(json['serviceIntervalValue']),
      serviceIntervalUnit: _intervalUnitFromJson(json['serviceIntervalUnit']),
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
  final int? serviceIntervalValue;
  final ServiceIntervalUnit serviceIntervalUnit;
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

  /// Returns the service status that should be presented for [now].
  ///
  /// Open/Scheduled are date-driven:
  /// - a future service date is Scheduled;
  /// - on the service date, and afterwards, it is Open until the user marks
  ///   it Completed or Cancelled.
  ///
  /// This also repairs older records that may have been persisted as Open
  /// even after their service date was moved into the future. Legacy
  /// in-progress records follow the same date-driven rule.
  ServiceStatus effectiveStatus(DateTime now) {
    return resolveStatus(status: status, serviceDate: serviceDate, now: now);
  }

  static ServiceStatus resolveStatus({
    required ServiceStatus status,
    required DateTime serviceDate,
    required DateTime now,
  }) {
    if (status == ServiceStatus.completed ||
        status == ServiceStatus.cancelled) {
      return status;
    }

    final today = DateTime(now.year, now.month, now.day);
    final serviceDay = DateTime(
      serviceDate.year,
      serviceDate.month,
      serviceDate.day,
    );

    return serviceDay.isAfter(today)
        ? ServiceStatus.scheduled
        : ServiceStatus.open;
  }

  int? get serviceIntervalMonths {
    final value = serviceIntervalValue;
    if (value == null || value <= 0) return null;
    return switch (serviceIntervalUnit) {
      ServiceIntervalUnit.months => value,
      ServiceIntervalUnit.years => value * 12,
    };
  }

  String? get serviceFrequencyLabel {
    final value = serviceIntervalValue;
    if (value == null || value <= 0) return null;
    return 'Every $value ${serviceIntervalUnit.labelFor(value)}';
  }

  DateTime? get calculatedNextServiceDate {
    final months = serviceIntervalMonths;
    if (months == null) return null;
    return _addCalendarMonths(serviceDate, months);
  }

  static DateTime calculateNextServiceDate({
    required DateTime serviceDate,
    required int intervalValue,
    required ServiceIntervalUnit intervalUnit,
  }) {
    if (intervalValue <= 0) {
      throw ArgumentError.value(
        intervalValue,
        'intervalValue',
        'Service interval must be greater than zero.',
      );
    }

    final months = switch (intervalUnit) {
      ServiceIntervalUnit.months => intervalValue,
      ServiceIntervalUnit.years => intervalValue * 12,
    };
    return _addCalendarMonths(serviceDate, months);
  }

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
    int? serviceIntervalValue,
    bool clearServiceInterval = false,
    ServiceIntervalUnit? serviceIntervalUnit,
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
      serviceIntervalValue: clearServiceInterval
          ? null
          : serviceIntervalValue ?? this.serviceIntervalValue,
      serviceIntervalUnit: serviceIntervalUnit ?? this.serviceIntervalUnit,
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
      'serviceIntervalValue': serviceIntervalValue,
      'serviceIntervalUnit': serviceIntervalValue == null
          ? null
          : serviceIntervalUnit.name,
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

  static int? _positiveIntFromJson(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static ServiceIntervalUnit _intervalUnitFromJson(Object? value) {
    final name = value as String?;
    return ServiceIntervalUnit.values.firstWhere(
      (unit) => unit.name == name,
      orElse: () => ServiceIntervalUnit.months,
    );
  }

  static DateTime _addCalendarMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final targetYear = date.year + monthIndex ~/ 12;
    final targetMonth = monthIndex % 12 + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day <= lastDayOfTargetMonth
        ? date.day
        : lastDayOfTargetMonth;

    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
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
