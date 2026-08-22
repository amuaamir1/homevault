import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
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
import 'firebase_error_message.dart';
import 'support_action_service.dart';

/// Converts technical/application exceptions into short user-facing messages.
///
/// This is the single presentation boundary for unexpected HomeVault errors.
/// Callers may provide a context-specific fallback, but should not expose
/// [Object.toString] to users.
String friendlyHomeVaultError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is ApplianceConflictException) return error.message;
  if (error is ApplianceStorageException) return error.message;
  if (error is BackupFormatException) return error.message;
  if (error is CloudBackupException) return error.message;
  if (error is CloudDocumentStorageException) return error.message;
  if (error is CloudDocumentSyncJournalException) return error.message;
  if (error is DocumentStorageException) return error.message;
  if (error is AccountDeletionException) return error.message;
  if (error is FeedbackSubmissionException) return error.message;
  if (error is SupportActionException) return error.message;
  if (error is PinReuseException) return error.message;

  if (error is FirebaseException) {
    return friendlyFirebaseError(error, fallback: fallback);
  }

  if (error is TimeoutException) {
    return 'This is taking longer than expected. Check your connection and try again.';
  }

  if (error is SocketException) {
    return 'HomeVault could not connect right now. Check your internet connection and try again.';
  }

  if (error is FileSystemException) {
    return 'HomeVault could not access a required file on this device. Check available storage and try again.';
  }

  if (error is FormatException) {
    return 'HomeVault found saved data it could not read. Try again or restore from a recent backup.';
  }

  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    if (code.contains('permission')) {
      return 'HomeVault does not have the required device permission. Check app permissions and try again.';
    }
    if (code.contains('network') || code.contains('unavailable')) {
      return 'This feature is temporarily unavailable. Check your connection and try again.';
    }
  }

  // Some plugins wrap the underlying exception. Use technical text only for
  // classification; never return it to the user.
  final value = error.toString().toLowerCase();
  if (value.contains('permission-denied') ||
      value.contains('permission denied') ||
      value.contains('unauthorized')) {
    return 'HomeVault does not have permission to complete this action. Sign in again and try once more.';
  }
  if (value.contains('unauthenticated') ||
      value.contains('session expired') ||
      value.contains('token expired')) {
    return 'Your HomeVault session has expired. Sign in again.';
  }
  if (value.contains('object-not-found') || value.contains('file not found')) {
    return 'The requested file could not be found. It may have been removed on another device.';
  }
  if (value.contains('quota-exceeded') ||
      value.contains('resource-exhausted') ||
      value.contains('no space left')) {
    return 'There is not enough cloud or device storage to complete this action.';
  }
  if (value.contains('network') ||
      value.contains('unavailable') ||
      value.contains('deadline-exceeded') ||
      value.contains('timed out') ||
      value.contains('timeout')) {
    return 'HomeVault could not connect right now. Check your internet connection and try again.';
  }

  return fallback;
}
