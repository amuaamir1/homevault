enum ServiceRequestStatus {
  requested,
  confirmed,
  technicianAssigned,
  inProgress,
  completed,
  cancelled,
}

extension ServiceRequestStatusDetails on ServiceRequestStatus {
  String get label => switch (this) {
    ServiceRequestStatus.requested => 'Requested',
    ServiceRequestStatus.confirmed => 'Confirmed',
    ServiceRequestStatus.technicianAssigned => 'Technician assigned',
    ServiceRequestStatus.inProgress => 'In progress',
    ServiceRequestStatus.completed => 'Completed',
    ServiceRequestStatus.cancelled => 'Cancelled',
  };

  bool get isActive =>
      this != ServiceRequestStatus.completed &&
      this != ServiceRequestStatus.cancelled;

  int get sortPriority => switch (this) {
    ServiceRequestStatus.inProgress => 0,
    ServiceRequestStatus.technicianAssigned => 1,
    ServiceRequestStatus.confirmed => 2,
    ServiceRequestStatus.requested => 3,
    ServiceRequestStatus.completed => 4,
    ServiceRequestStatus.cancelled => 5,
  };

  List<ServiceRequestStatus> get nextStatuses => switch (this) {
    ServiceRequestStatus.requested => const [
      ServiceRequestStatus.confirmed,
      ServiceRequestStatus.cancelled,
    ],
    ServiceRequestStatus.confirmed => const [
      ServiceRequestStatus.technicianAssigned,
      ServiceRequestStatus.inProgress,
      ServiceRequestStatus.completed,
      ServiceRequestStatus.cancelled,
    ],
    ServiceRequestStatus.technicianAssigned => const [
      ServiceRequestStatus.inProgress,
      ServiceRequestStatus.completed,
      ServiceRequestStatus.cancelled,
    ],
    ServiceRequestStatus.inProgress => const [
      ServiceRequestStatus.completed,
      ServiceRequestStatus.cancelled,
    ],
    ServiceRequestStatus.completed ||
    ServiceRequestStatus.cancelled => const [],
  };
}

enum ServiceVisitWindow { morning, afternoon, evening, flexible }

extension ServiceVisitWindowDetails on ServiceVisitWindow {
  String get label => switch (this) {
    ServiceVisitWindow.morning => 'Morning',
    ServiceVisitWindow.afternoon => 'Afternoon',
    ServiceVisitWindow.evening => 'Evening',
    ServiceVisitWindow.flexible => 'Flexible',
  };

  String get timeLabel => switch (this) {
    ServiceVisitWindow.morning => '9:00 AM – 12:00 PM',
    ServiceVisitWindow.afternoon => '12:00 PM – 4:00 PM',
    ServiceVisitWindow.evening => '4:00 PM – 7:00 PM',
    ServiceVisitWindow.flexible => 'Any suitable time',
  };
}

class ServiceRequestStatusEvent {
  const ServiceRequestStatusEvent({
    required this.status,
    required this.changedAt,
    this.note = '',
  });

  factory ServiceRequestStatusEvent.fromJson(Map<String, dynamic> json) {
    return ServiceRequestStatusEvent(
      status: _statusFromJson(json['status']),
      changedAt:
          DateTime.tryParse(json['changedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      note: json['note'] as String? ?? '',
    );
  }

  final ServiceRequestStatus status;
  final DateTime changedAt;
  final String note;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'changedAt': changedAt.toIso8601String(),
    'note': note,
  };
}

class ServiceRequest {
  ServiceRequest({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.preferredDate,
    required this.visitWindow,
    required this.issueDescription,
    required this.serviceAddress,
    this.contactName = '',
    this.contactPhone = '',
    this.provider = '',
    this.providerPhone = '',
    this.ticketNumber = '',
    this.technicianName = '',
    this.linkedServiceRecordId = '',
    this.status = ServiceRequestStatus.requested,
    DateTime? statusUpdatedAt,
    this.notes = '',
    List<ServiceRequestStatusEvent> statusHistory = const [],
  }) : statusUpdatedAt = statusUpdatedAt ?? updatedAt,
       statusHistory = List.unmodifiable(statusHistory);

  factory ServiceRequest.create({
    required String id,
    required DateTime now,
    required DateTime preferredDate,
    required ServiceVisitWindow visitWindow,
    required String issueDescription,
    required String serviceAddress,
    String contactName = '',
    String contactPhone = '',
    String provider = '',
    String providerPhone = '',
    String ticketNumber = '',
    String technicianName = '',
    String notes = '',
  }) {
    return ServiceRequest(
      id: id,
      createdAt: now,
      updatedAt: now,
      preferredDate: preferredDate,
      visitWindow: visitWindow,
      issueDescription: issueDescription,
      serviceAddress: serviceAddress,
      contactName: contactName,
      contactPhone: contactPhone,
      provider: provider,
      providerPhone: providerPhone,
      ticketNumber: ticketNumber,
      technicianName: technicianName,
      linkedServiceRecordId: '',
      notes: notes,
      status: ServiceRequestStatus.requested,
      statusUpdatedAt: now,
      statusHistory: [
        ServiceRequestStatusEvent(
          status: ServiceRequestStatus.requested,
          changedAt: now,
          note: 'Service request created.',
        ),
      ],
    );
  }

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    final historyJson = json['statusHistory'];
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final updatedAt =
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt;
    final status = _statusFromJson(json['status']);
    final statusUpdatedAt =
        DateTime.tryParse(json['statusUpdatedAt'] as String? ?? '') ??
        updatedAt;
    final parsedHistory = historyJson is List
        ? historyJson
              .whereType<Map>()
              .map(
                (item) => ServiceRequestStatusEvent.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <ServiceRequestStatusEvent>[];

    return ServiceRequest(
      id: json['id'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      preferredDate:
          DateTime.tryParse(json['preferredDate'] as String? ?? '') ??
          createdAt,
      visitWindow: _visitWindowFromJson(json['visitWindow']),
      issueDescription: json['issueDescription'] as String? ?? '',
      serviceAddress: json['serviceAddress'] as String? ?? '',
      contactName: json['contactName'] as String? ?? '',
      contactPhone: json['contactPhone'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      providerPhone: json['providerPhone'] as String? ?? '',
      ticketNumber: json['ticketNumber'] as String? ?? '',
      technicianName: json['technicianName'] as String? ?? '',
      linkedServiceRecordId: json['linkedServiceRecordId'] as String? ?? '',
      status: status,
      statusUpdatedAt: statusUpdatedAt,
      notes: json['notes'] as String? ?? '',
      statusHistory: parsedHistory.isEmpty
          ? [
              ServiceRequestStatusEvent(
                status: status,
                changedAt: statusUpdatedAt,
              ),
            ]
          : parsedHistory,
    );
  }

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime preferredDate;
  final ServiceVisitWindow visitWindow;
  final String issueDescription;
  final String serviceAddress;
  final String contactName;
  final String contactPhone;
  final String provider;
  final String providerPhone;
  final String ticketNumber;
  final String technicianName;
  final String linkedServiceRecordId;
  final ServiceRequestStatus status;
  final DateTime statusUpdatedAt;
  final String notes;
  final List<ServiceRequestStatusEvent> statusHistory;

  bool get isActive => status.isActive;

  int daysUntilPreferredDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(
      preferredDate.year,
      preferredDate.month,
      preferredDate.day,
    );
    return date.difference(today).inDays;
  }

  ServiceRequest copyWith({
    DateTime? updatedAt,
    DateTime? preferredDate,
    ServiceVisitWindow? visitWindow,
    String? issueDescription,
    String? serviceAddress,
    String? contactName,
    String? contactPhone,
    String? provider,
    String? providerPhone,
    String? ticketNumber,
    String? technicianName,
    String? linkedServiceRecordId,
    ServiceRequestStatus? status,
    DateTime? statusUpdatedAt,
    String? notes,
    List<ServiceRequestStatusEvent>? statusHistory,
  }) {
    return ServiceRequest(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferredDate: preferredDate ?? this.preferredDate,
      visitWindow: visitWindow ?? this.visitWindow,
      issueDescription: issueDescription ?? this.issueDescription,
      serviceAddress: serviceAddress ?? this.serviceAddress,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      provider: provider ?? this.provider,
      providerPhone: providerPhone ?? this.providerPhone,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      technicianName: technicianName ?? this.technicianName,
      linkedServiceRecordId:
          linkedServiceRecordId ?? this.linkedServiceRecordId,
      status: status ?? this.status,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      notes: notes ?? this.notes,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }

  ServiceRequest withStatus(
    ServiceRequestStatus nextStatus, {
    required DateTime changedAt,
    String note = '',
  }) {
    if (nextStatus == status) return this;

    return copyWith(
      updatedAt: changedAt,
      status: nextStatus,
      statusUpdatedAt: changedAt,
      statusHistory: [
        ...statusHistory,
        ServiceRequestStatusEvent(
          status: nextStatus,
          changedAt: changedAt,
          note: note.trim().isEmpty
              ? 'Status changed to ${nextStatus.label}.'
              : note.trim(),
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'preferredDate': preferredDate.toIso8601String(),
    'visitWindow': visitWindow.name,
    'issueDescription': issueDescription,
    'serviceAddress': serviceAddress,
    'contactName': contactName,
    'contactPhone': contactPhone,
    'provider': provider,
    'providerPhone': providerPhone,
    'ticketNumber': ticketNumber,
    'technicianName': technicianName,
    'linkedServiceRecordId': linkedServiceRecordId,
    'status': status.name,
    'statusUpdatedAt': statusUpdatedAt.toIso8601String(),
    'notes': notes,
    'statusHistory': statusHistory.map((event) => event.toJson()).toList(),
  };
}

ServiceRequestStatus _statusFromJson(Object? value) {
  final name = value as String?;
  return ServiceRequestStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => ServiceRequestStatus.requested,
  );
}

ServiceVisitWindow _visitWindowFromJson(Object? value) {
  final name = value as String?;
  return ServiceVisitWindow.values.firstWhere(
    (window) => window.name == name,
    orElse: () => ServiceVisitWindow.flexible,
  );
}
