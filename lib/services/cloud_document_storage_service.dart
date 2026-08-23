import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/stored_document.dart';
import '../security/homevault_file_security.dart';
import 'document_storage_service.dart';

abstract class CloudDocumentStorage {
  bool get isAvailable;

  Future<void> bindOwner(String? uid);

  Future<StoredDocument> upload({
    required String applianceId,
    required StoredDocument document,
  });

  Future<StoredDocument> download({
    required StoredDocument document,
    required String destinationPath,
  });

  Future<void> delete(StoredDocument document);

  Future<void> deletePath(String cloudStoragePath);
}

class NoOpCloudDocumentStorage implements CloudDocumentStorage {
  const NoOpCloudDocumentStorage();

  @override
  bool get isAvailable => false;

  @override
  Future<void> bindOwner(String? uid) async {}

  @override
  Future<StoredDocument> upload({
    required String applianceId,
    required StoredDocument document,
  }) {
    throw const CloudDocumentStorageException(
      'Cloud document storage is not available in this build.',
    );
  }

  @override
  Future<StoredDocument> download({
    required StoredDocument document,
    required String destinationPath,
  }) {
    throw const CloudDocumentStorageException(
      'Cloud document storage is not available in this build.',
    );
  }

  @override
  Future<void> delete(StoredDocument document) async {}

  @override
  Future<void> deletePath(String cloudStoragePath) async {}
}

class FirebaseCloudDocumentStorage implements CloudDocumentStorage {
  FirebaseCloudDocumentStorage({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  String? _ownerUid;

  @override
  bool get isAvailable => true;

  String get _requiredOwnerUid {
    final uid = _ownerUid;
    if (uid == null || uid.trim().isEmpty) {
      throw const CloudDocumentStorageException(
        'Sign in before synchronizing HomeVault documents.',
      );
    }
    return uid;
  }

  @override
  Future<void> bindOwner(String? uid) async {
    final normalized = uid?.trim();
    _ownerUid = normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  Future<StoredDocument> upload({
    required String applianceId,
    required StoredDocument document,
  }) async {
    if (!document.isAvailableOnDevice) {
      throw const CloudDocumentStorageException(
        'The document file is not available on this device.',
      );
    }

    final source = File(document.localPath);
    if (!await source.exists()) {
      throw const CloudDocumentStorageException(
        'The document file could not be found on this device.',
      );
    }

    final maximumBytes = document.type == DocumentType.appliancePhoto
        ? DocumentStorageService.maximumPhotoSizeBytes
        : DocumentStorageService.maximumFileSizeBytes;

    late final int size;
    late final String contentType;
    try {
      size = await source.length();
      contentType = await HomeVaultFileSecurity.validateFile(
        source,
        fileName: document.fileName,
        maximumBytes: maximumBytes,
        allowedExtensions: document.type == DocumentType.appliancePhoto
            ? DocumentStorageService.allowedPhotoExtensions.toSet()
            : DocumentStorageService.allowedExtensions.toSet(),
      );
    } on HomeVaultFileSecurityException catch (error) {
      throw CloudDocumentStorageException(error.message, error);
    }

    try {
      final digest = await sha256.bind(source.openRead()).first;
      final contentHash = digest.toString().substring(0, 24);
      final safeFileName = _sanitiseFileName(document.fileName);
      final fullPath =
          'users/$_requiredOwnerUid/appliances/'
          '${_sanitisePathPart(applianceId)}/documents/'
          '${_sanitisePathPart(document.id)}/'
          '${contentHash}_$safeFileName';

      final reference = _storage.ref().child(fullPath);
      await reference.putFile(
        source,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'applianceId': applianceId,
            'documentId': document.id,
            'originalFileName': document.fileName,
          },
        ),
      );

      return document.copyWith(
        sizeBytes: size,
        cloudStoragePath: fullPath,
        cloudContentType: contentType,
      );
    } on FirebaseException catch (error) {
      throw CloudDocumentStorageException(_friendlyMessage(error), error);
    }
  }

  @override
  Future<StoredDocument> download({
    required StoredDocument document,
    required String destinationPath,
  }) async {
    final cloudPath = document.cloudStoragePath.trim();
    if (cloudPath.isEmpty) {
      throw const CloudDocumentStorageException(
        'This document has not been uploaded to cloud storage yet.',
      );
    }

    try {
      final destination = File(destinationPath);
      await destination.parent.create(recursive: true);
      if (await destination.exists()) {
        await destination.delete();
      }

      await _storage.ref().child(cloudPath).writeToFile(destination);

      final maximumBytes = document.type == DocumentType.appliancePhoto
          ? DocumentStorageService.maximumPhotoSizeBytes
          : DocumentStorageService.maximumFileSizeBytes;
      try {
        await HomeVaultFileSecurity.validateFile(
          destination,
          fileName: document.fileName,
          maximumBytes: maximumBytes,
          allowedExtensions: document.type == DocumentType.appliancePhoto
              ? DocumentStorageService.allowedPhotoExtensions.toSet()
              : DocumentStorageService.allowedExtensions.toSet(),
        );
      } on HomeVaultFileSecurityException catch (error) {
        try {
          if (await destination.exists()) {
            await destination.delete();
          }
        } catch (_) {
          // Best-effort cleanup of a rejected cloud file.
        }
        throw CloudDocumentStorageException(error.message, error);
      }

      final downloadedSize = await destination.length();
      return document.copyWith(
        localPath: destination.path,
        sizeBytes: downloadedSize,
      );
    } on FirebaseException catch (error) {
      throw CloudDocumentStorageException(_friendlyMessage(error), error);
    }
  }

  @override
  Future<void> delete(StoredDocument document) {
    return deletePath(document.cloudStoragePath);
  }

  @override
  Future<void> deletePath(String cloudStoragePath) async {
    final cloudPath = cloudStoragePath.trim();
    if (cloudPath.isEmpty) return;

    final ownerUid = _requiredOwnerUid;
    final expectedPrefix = 'users/$ownerUid/appliances/';
    if (!cloudPath.startsWith(expectedPrefix) ||
        !cloudPath.contains('/documents/')) {
      throw const CloudDocumentStorageException(
        'This cloud document belongs to a different HomeVault account.',
      );
    }

    try {
      await _storage.ref().child(cloudPath).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }
      throw CloudDocumentStorageException(_friendlyMessage(error), error);
    }
  }

  static String _sanitiseFileName(String fileName) {
    final sanitised = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitised.isEmpty ? 'document' : sanitised;
  }

  static String _sanitisePathPart(String value) {
    final sanitised = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return sanitised.isEmpty ? 'item' : sanitised;
  }

  static String _friendlyMessage(FirebaseException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Sign in again before synchronizing this document.';
      case 'unauthorized':
      case 'permission-denied':
        return 'HomeVault does not have permission to access this cloud document.';
      case 'object-not-found':
        return 'The cloud copy of this document could not be found.';
      case 'bucket-not-found':
        return 'HomeVault cloud document storage has not been configured yet.';
      case 'quota-exceeded':
        return 'The HomeVault cloud storage quota has been reached.';
      case 'retry-limit-exceeded':
      case 'network-request-failed':
      case 'unavailable':
        return 'Cloud document storage is temporarily unavailable. Try again when you are online.';
      case 'canceled':
        return 'The cloud document transfer was cancelled.';
      default:
        return 'HomeVault could not synchronize this document with cloud storage.';
    }
  }
}

class CloudDocumentStorageException implements Exception {
  const CloudDocumentStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
