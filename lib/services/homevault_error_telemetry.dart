import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../models/backup_models.dart';
import '../security/pin_security_service.dart';
import 'account_deletion_service.dart';
import 'appliance_repository.dart';
import 'beta_feedback_service.dart';
import 'cloud_backup_service.dart';
import 'cloud_document_storage_service.dart';
import 'cloud_document_sync_journal.dart';
import 'document_storage_service.dart';
import 'support_action_service.dart';

enum HomeVaultErrorCategory {
  authentication,
  authorization,
  connectivity,
  timeout,
  conflict,
  cloudStorage,
  deviceStorage,
  backupRestore,
  feedback,
  devicePermission,
  validation,
  data,
  unknown,
}

extension HomeVaultErrorCategoryKey on HomeVaultErrorCategory {
  String get key => switch (this) {
    HomeVaultErrorCategory.authentication => 'authentication',
    HomeVaultErrorCategory.authorization => 'authorization',
    HomeVaultErrorCategory.connectivity => 'connectivity',
    HomeVaultErrorCategory.timeout => 'timeout',
    HomeVaultErrorCategory.conflict => 'conflict',
    HomeVaultErrorCategory.cloudStorage => 'cloud_storage',
    HomeVaultErrorCategory.deviceStorage => 'device_storage',
    HomeVaultErrorCategory.backupRestore => 'backup_restore',
    HomeVaultErrorCategory.feedback => 'feedback',
    HomeVaultErrorCategory.devicePermission => 'device_permission',
    HomeVaultErrorCategory.validation => 'validation',
    HomeVaultErrorCategory.data => 'data',
    HomeVaultErrorCategory.unknown => 'unknown',
  };
}

HomeVaultErrorCategory classifyHomeVaultError(Object error) {
  if (error is ApplianceConflictException) {
    return HomeVaultErrorCategory.conflict;
  }
  if (error is FirebaseAuthException) {
    final code = error.code.toLowerCase();
    if (_isConnectivityCode(code)) return HomeVaultErrorCategory.connectivity;
    if (_isTimeoutCode(code)) return HomeVaultErrorCategory.timeout;
    return HomeVaultErrorCategory.authentication;
  }
  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    if (code == 'permission-denied' ||
        code == 'unauthorized' ||
        code == 'unauthenticated') {
      return HomeVaultErrorCategory.authorization;
    }
    if (_isConnectivityCode(code)) return HomeVaultErrorCategory.connectivity;
    if (_isTimeoutCode(code)) return HomeVaultErrorCategory.timeout;
    if (code == 'object-not-found' ||
        code == 'quota-exceeded' ||
        code == 'resource-exhausted' ||
        code == 'retry-limit-exceeded' ||
        code == 'canceled') {
      return HomeVaultErrorCategory.cloudStorage;
    }
    return HomeVaultErrorCategory.data;
  }
  if (error is TimeoutException) return HomeVaultErrorCategory.timeout;
  if (error is SocketException) return HomeVaultErrorCategory.connectivity;
  if (error is FileSystemException || error is DocumentStorageException) {
    return HomeVaultErrorCategory.deviceStorage;
  }
  if (error is CloudDocumentStorageException ||
      error is CloudDocumentSyncJournalException) {
    return HomeVaultErrorCategory.cloudStorage;
  }
  if (error is BackupFormatException || error is CloudBackupException) {
    return HomeVaultErrorCategory.backupRestore;
  }
  if (error is FeedbackSubmissionException) {
    return HomeVaultErrorCategory.feedback;
  }
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    if (code.contains('permission')) {
      return HomeVaultErrorCategory.devicePermission;
    }
    if (code.contains('network') || code.contains('unavailable')) {
      return HomeVaultErrorCategory.connectivity;
    }
    return HomeVaultErrorCategory.unknown;
  }
  if (error is PinReuseException) return HomeVaultErrorCategory.validation;
  if (error is FormatException || error is ApplianceStorageException) {
    return HomeVaultErrorCategory.data;
  }
  if (error is AccountDeletionException) {
    return HomeVaultErrorCategory.authentication;
  }
  if (error is SupportActionException) {
    return HomeVaultErrorCategory.unknown;
  }

  // Wrapped plugin exceptions are classified from technical text, but this
  // value is never returned to the user or attached as telemetry metadata.
  final value = error.toString().toLowerCase();
  if (value.contains('permission-denied') ||
      value.contains('permission denied') ||
      value.contains('unauthorized')) {
    return HomeVaultErrorCategory.authorization;
  }
  if (value.contains('unauthenticated') ||
      value.contains('token expired') ||
      value.contains('session expired')) {
    return HomeVaultErrorCategory.authentication;
  }
  if (value.contains('timeout') ||
      value.contains('timed out') ||
      value.contains('deadline-exceeded')) {
    return HomeVaultErrorCategory.timeout;
  }
  if (value.contains('network') || value.contains('unavailable')) {
    return HomeVaultErrorCategory.connectivity;
  }
  if (value.contains('object-not-found') ||
      value.contains('quota-exceeded') ||
      value.contains('resource-exhausted')) {
    return HomeVaultErrorCategory.cloudStorage;
  }

  return HomeVaultErrorCategory.unknown;
}

String normalizeHomeVaultOperationKey(String operation) {
  var value = operation.trim().toLowerCase();
  if (value.isEmpty) return 'unspecified';
  value = value.replaceAll(RegExp(r'[^a-z0-9]+'), '.');
  value = value.replaceAll(RegExp(r'\.{2,}'), '.');
  value = value.replaceAll(RegExp(r'^\.|\.$'), '');
  if (value.isEmpty) return 'unspecified';
  return value.length <= 80 ? value : value.substring(0, 80);
}

Map<String, String> safeHomeVaultTelemetryContext(
  Map<String, Object?> context,
) {
  const allowedStringKeys = <String>{
    'flow',
    'mode',
    'phase',
    'screen',
    'source',
    'state',
    'type',
  };
  final result = <String, String>{};

  for (final entry in context.entries) {
    final key = normalizeHomeVaultOperationKey(entry.key);
    if (key == 'unspecified' || _isSensitiveTelemetryKey(key)) continue;

    final value = entry.value;
    if (value == null) continue;
    if (value is bool || value is num) {
      result[key] = value.toString();
      continue;
    }
    if (value is Enum) {
      result[key] = normalizeHomeVaultOperationKey(value.name);
      continue;
    }
    if (value is String && allowedStringKeys.contains(key)) {
      final normalized = normalizeHomeVaultOperationKey(value);
      if (normalized != 'unspecified') result[key] = normalized;
    }
  }

  return Map.unmodifiable(result);
}

class HomeVaultErrorTelemetry {
  const HomeVaultErrorTelemetry({
    required this.category,
    required this.operationKey,
    this.context = const <String, String>{},
  });

  factory HomeVaultErrorTelemetry.fromError(
    Object error, {
    required String operation,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return HomeVaultErrorTelemetry(
      category: classifyHomeVaultError(error),
      operationKey: normalizeHomeVaultOperationKey(operation),
      context: safeHomeVaultTelemetryContext(context),
    );
  }

  final HomeVaultErrorCategory category;
  final String operationKey;
  final Map<String, String> context;

  String get crashReason => '${category.key}:$operationKey';

  String get logLine {
    final buffer = StringBuffer(
      'HOMEVAULT_NONFATAL category=${category.key} operation=$operationKey',
    );
    for (final entry in context.entries) {
      buffer.write(' ${entry.key}=${entry.value}');
    }
    return buffer.toString();
  }
}

bool _isConnectivityCode(String code) =>
    code == 'network-request-failed' || code == 'unavailable';

bool _isTimeoutCode(String code) =>
    code == 'deadline-exceeded' || code == 'retry-limit-exceeded';

bool _isSensitiveTelemetryKey(String key) {
  const fragments = <String>{
    'address',
    'email',
    'file',
    'name',
    'password',
    'path',
    'phone',
    'pin',
    'secret',
    'token',
    'uid',
    'url',
  };
  return fragments.any(key.contains);
}
