import 'package:cloud_firestore/cloud_firestore.dart';

import 'beta_feedback.dart';

enum FeedbackWorkflowStatus {
  newFeedback,
  inReview,
  planned,
  resolved,
  dismissed,
}

extension FeedbackWorkflowStatusDetails on FeedbackWorkflowStatus {
  String get label => switch (this) {
    FeedbackWorkflowStatus.newFeedback => 'New',
    FeedbackWorkflowStatus.inReview => 'In review',
    FeedbackWorkflowStatus.planned => 'Planned',
    FeedbackWorkflowStatus.resolved => 'Resolved',
    FeedbackWorkflowStatus.dismissed => 'Dismissed',
  };
}

enum FeedbackPriority { low, normal, high, urgent }

extension FeedbackPriorityDetails on FeedbackPriority {
  String get label => switch (this) {
    FeedbackPriority.low => 'Low',
    FeedbackPriority.normal => 'Normal',
    FeedbackPriority.high => 'High',
    FeedbackPriority.urgent => 'Urgent',
  };

  int get sortRank => switch (this) {
    FeedbackPriority.urgent => 0,
    FeedbackPriority.high => 1,
    FeedbackPriority.normal => 2,
    FeedbackPriority.low => 3,
  };
}

class AdminFeedbackItem {
  const AdminFeedbackItem({
    required this.id,
    required this.documentPath,
    required this.uid,
    required this.category,
    required this.message,
    required this.createdAt,
    this.userEmail = '',
    this.appVersion = '',
    this.buildNumber = '',
    this.releaseNumber = '',
    this.platform = '',
    this.deviceManufacturer = '',
    this.deviceModel = '',
    this.androidVersion = '',
    this.androidSdk,
    this.screenshotFileName,
    this.screenshotBase64,
    this.status = FeedbackWorkflowStatus.newFeedback,
    this.priority = FeedbackPriority.normal,
    this.adminNote = '',
    this.updatedAt,
    this.updatedBy = '',
    this.isLegacy = false,
  });

  final String id;
  final String documentPath;
  final String uid;
  final String userEmail;
  final FeedbackCategory category;
  final String message;
  final DateTime createdAt;
  final String appVersion;
  final String buildNumber;
  final String releaseNumber;
  final String platform;
  final String deviceManufacturer;
  final String deviceModel;
  final String androidVersion;
  final int? androidSdk;
  final String? screenshotFileName;
  final String? screenshotBase64;
  final FeedbackWorkflowStatus status;
  final FeedbackPriority priority;
  final String adminNote;
  final DateTime? updatedAt;
  final String updatedBy;
  final bool isLegacy;

  bool get hasScreenshot => screenshotBase64?.trim().isNotEmpty == true;

  String get submitterLabel {
    final email = userEmail.trim();
    return email.isNotEmpty ? email : uid;
  }

  AdminFeedbackItem copyWith({
    FeedbackWorkflowStatus? status,
    FeedbackPriority? priority,
    String? adminNote,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return AdminFeedbackItem(
      id: id,
      documentPath: documentPath,
      uid: uid,
      userEmail: userEmail,
      category: category,
      message: message,
      createdAt: createdAt,
      appVersion: appVersion,
      buildNumber: buildNumber,
      releaseNumber: releaseNumber,
      platform: platform,
      deviceManufacturer: deviceManufacturer,
      deviceModel: deviceModel,
      androidVersion: androidVersion,
      androidSdk: androidSdk,
      screenshotFileName: screenshotFileName,
      screenshotBase64: screenshotBase64,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      adminNote: adminNote ?? this.adminNote,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isLegacy: isLegacy,
    );
  }

  static AdminFeedbackItem fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required bool isLegacy,
  }) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return AdminFeedbackItem(
      id: snapshot.id,
      documentPath: snapshot.reference.path,
      uid: _string(data['uid']),
      userEmail: _string(data['userEmail']),
      category: _category(data['category']),
      message: _string(data['message']),
      createdAt:
          _dateTime(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      appVersion: _string(data['appVersion']),
      buildNumber: _string(data['buildNumber']),
      releaseNumber: _string(data['releaseNumber']),
      platform: _string(data['platform']),
      deviceManufacturer: _string(data['deviceManufacturer']),
      deviceModel: _string(data['deviceModel']),
      androidVersion: _string(data['androidVersion']),
      androidSdk: _int(data['androidSdk']),
      screenshotFileName: _nullableString(data['screenshotFileName']),
      screenshotBase64: _nullableString(data['screenshotBase64']),
      status: _status(data['status']),
      priority: _priority(data['priority']),
      adminNote: _string(data['adminNote']),
      updatedAt: _dateTime(data['updatedAt']),
      updatedBy: _string(data['updatedBy']),
      isLegacy: isLegacy,
    );
  }

  static FeedbackWorkflowStatus _status(Object? value) {
    final name = _string(value);
    return FeedbackWorkflowStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => FeedbackWorkflowStatus.newFeedback,
    );
  }

  static FeedbackPriority _priority(Object? value) {
    final name = _string(value);
    return FeedbackPriority.values.firstWhere(
      (priority) => priority.name == name,
      orElse: () => FeedbackPriority.normal,
    );
  }

  static FeedbackCategory _category(Object? value) {
    final name = _string(value);
    return FeedbackCategory.values.firstWhere(
      (category) => category.name == name,
      orElse: () => FeedbackCategory.other,
    );
  }

  static String _string(Object? value) => value is String ? value : '';

  static String? _nullableString(Object? value) {
    final text = _string(value).trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
