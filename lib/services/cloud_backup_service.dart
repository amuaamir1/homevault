import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/appliance.dart';
import '../models/backup_models.dart';
import 'firebase_error_message.dart';
import 'homevault_backup_service.dart';

class CloudBackupService {
  CloudBackupService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    HomeVaultBackupService? backupService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _backupService = backupService ?? HomeVaultBackupService();

  static const int maxBackupBytes = 250 * 1024 * 1024;

  /// HomeVault keeps only the two newest cloud restore points for each user.
  static const int cloudRetention = 2;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final HomeVaultBackupService _backupService;

  Future<List<CloudBackupSnapshot>> listBackups(String uid) async {
    final ownerUid = _requiredUid(uid);

    try {
      final snapshot = await _backupCollection(
        ownerUid,
      ).orderBy('createdAt', descending: true).get();

      return snapshot.docs
          .map((document) => _snapshotFromDocument(document))
          .whereType<CloudBackupSnapshot>()
          .toList(growable: false);
    } catch (error) {
      throw CloudBackupException(
        friendlyFirebaseError(
          error,
          fallback: 'Cloud backup history could not be loaded.',
        ),
        error,
      );
    }
  }

  Future<bool> needsAutomaticBackup(String uid, {DateTime? now}) async {
    final reference = (now ?? DateTime.now()).toLocal();

    // Also migrate users from the previous 7/4/6 retention policy during the
    // normal startup backup check, even if today's backup is not yet due.
    try {
      await pruneRetention(uid);
    } catch (_) {
      // Cleanup is best-effort and will be retried later.
    }

    final backups = await listBackups(uid);

    for (final backup in backups) {
      if (backup.source != CloudBackupSource.automatic) continue;
      final created = backup.createdAt.toLocal();
      return !_sameDay(created, reference);
    }

    return true;
  }

  Future<CloudBackupSnapshot> createBackup({
    required String uid,
    required Iterable<Appliance> appliances,
    required CloudBackupSource source,
  }) async {
    final ownerUid = _requiredUid(uid);
    final applianceList = appliances.toList(growable: false);
    if (applianceList.isEmpty) {
      throw const CloudBackupException(
        'There is no HomeVault data to back up yet.',
      );
    }

    final archive = await _backupService.buildBackup(
      applianceList,
      ownerUid: ownerUid,
    );

    if (archive.missingDocuments > 0) {
      throw CloudBackupException(
        '${archive.missingDocuments} attachment file(s) are not available on '
        'this device yet. HomeVault did not create a partial cloud backup. '
        'Check your connection and try again.',
      );
    }

    if (archive.bytes.length > maxBackupBytes) {
      throw const CloudBackupException(
        'This backup is larger than the 250 MB cloud-backup limit.',
      );
    }

    final createdAt = DateTime.now().toUtc();
    final id = 'backup_${createdAt.microsecondsSinceEpoch}';
    final storagePath = 'users/$ownerUid/backups/$id/homevault-backup.zip';
    final storageRef = _storage.ref(storagePath);

    try {
      await storageRef.putData(
        archive.bytes,
        SettableMetadata(
          contentType: 'application/zip',
          customMetadata: <String, String>{
            'homevaultBackupId': id,
            'source': source.storageValue,
          },
        ),
      );

      final snapshot = CloudBackupSnapshot(
        id: id,
        createdAt: createdAt,
        source: source,
        applianceCount: archive.applianceCount,
        documentCount: archive.documentCount,
        missingDocuments: archive.missingDocuments,
        sizeBytes: archive.bytes.length,
        storagePath: storagePath,
        appVersion: HomeVaultBackupService.appVersion,
      );

      try {
        await _backupCollection(
          ownerUid,
        ).doc(id).set(_snapshotToFirestore(snapshot));
      } catch (_) {
        try {
          await storageRef.delete();
        } catch (_) {
          // A later account cleanup can remove an orphaned object.
        }
        rethrow;
      }

      try {
        // Manual, automatic, and pre-restore safety snapshots all participate
        // in the same two-backup retention policy.
        await pruneRetention(ownerUid);
      } catch (_) {
        // The newly-created snapshot is still valid. Cleanup will be retried on
        // the next startup check or cloud-backup operation.
      }

      return snapshot;
    } catch (error) {
      if (error is CloudBackupException) rethrow;
      throw CloudBackupException(
        friendlyFirebaseError(
          error,
          fallback: 'The cloud backup could not be created. Please try again.',
        ),
        error,
      );
    }
  }

  Future<BackupSelection> downloadBackup({
    required String uid,
    required CloudBackupSnapshot snapshot,
  }) async {
    final ownerUid = _requiredUid(uid);
    _validateStoragePath(ownerUid, snapshot);

    try {
      final data = await _storage
          .ref(snapshot.storagePath)
          .getData(maxBackupBytes);
      if (data == null || data.isEmpty) {
        throw const CloudBackupException(
          'This cloud backup could not be downloaded.',
        );
      }

      return _backupService.inspectBackupBytes(
        Uint8List.fromList(data),
        fileName: _cloudFileName(snapshot),
      );
    } catch (error) {
      if (error is CloudBackupException || error is BackupFormatException) {
        rethrow;
      }
      throw CloudBackupException(
        friendlyFirebaseError(
          error,
          fallback: 'The cloud backup could not be downloaded.',
        ),
        error,
      );
    }
  }

  Future<void> deleteBackup({
    required String uid,
    required CloudBackupSnapshot snapshot,
  }) async {
    final ownerUid = _requiredUid(uid);
    _validateStoragePath(ownerUid, snapshot);

    try {
      try {
        await _storage.ref(snapshot.storagePath).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
      await _backupCollection(ownerUid).doc(snapshot.id).delete();
    } catch (error) {
      throw CloudBackupException(
        friendlyFirebaseError(
          error,
          fallback: 'The cloud backup could not be deleted.',
        ),
        error,
      );
    }
  }

  Future<int> pruneRetention(String uid) async {
    final ownerUid = _requiredUid(uid);
    final backups = await listBackups(ownerUid);
    final keepIds = retainedBackupIds(backups);
    var deleted = 0;

    for (final backup in backups) {
      if (keepIds.contains(backup.id)) continue;
      await deleteBackup(uid: ownerUid, snapshot: backup);
      deleted++;
    }

    return deleted;
  }

  static Set<String> retainedBackupIds(
    Iterable<CloudBackupSnapshot> snapshots,
  ) {
    final sorted = snapshots.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted.take(cloudRetention).map((snapshot) => snapshot.id).toSet();
  }

  CollectionReference<Map<String, dynamic>> _backupCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('backups');
  }

  CloudBackupSnapshot? _snapshotFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : DateTime.tryParse('${createdAtValue ?? ''}');
    if (createdAt == null) return null;

    final storagePath = '${data['storagePath'] ?? ''}'.trim();
    if (storagePath.isEmpty) return null;

    return CloudBackupSnapshot(
      id: document.id,
      createdAt: createdAt,
      source: _sourceFromValue(data['source']),
      applianceCount: _nonNegativeInt(data['applianceCount']),
      documentCount: _nonNegativeInt(data['documentCount']),
      missingDocuments: _nonNegativeInt(data['missingDocuments']),
      sizeBytes: _nonNegativeInt(data['sizeBytes']),
      storagePath: storagePath,
      appVersion: '${data['appVersion'] ?? 'Unknown'}',
    );
  }

  Map<String, dynamic> _snapshotToFirestore(CloudBackupSnapshot snapshot) {
    return <String, dynamic>{
      'createdAt': Timestamp.fromDate(snapshot.createdAt),
      'source': snapshot.source.storageValue,
      'applianceCount': snapshot.applianceCount,
      'documentCount': snapshot.documentCount,
      'missingDocuments': snapshot.missingDocuments,
      'sizeBytes': snapshot.sizeBytes,
      'storagePath': snapshot.storagePath,
      'appVersion': snapshot.appVersion,
      'schemaVersion': HomeVaultBackupService.backupSchemaVersion,
    };
  }

  void _validateStoragePath(String uid, CloudBackupSnapshot snapshot) {
    final expectedPrefix = 'users/$uid/backups/${snapshot.id}/';
    if (!snapshot.storagePath.startsWith(expectedPrefix)) {
      throw const CloudBackupException(
        'This backup does not belong to the signed-in HomeVault account.',
      );
    }
  }

  String _requiredUid(String uid) {
    final normalized = uid.trim();
    if (normalized.isEmpty) {
      throw const CloudBackupException(
        'Sign in before using HomeVault cloud backup.',
      );
    }
    return normalized;
  }

  static CloudBackupSource _sourceFromValue(Object? value) {
    final text = '$value';
    for (final source in CloudBackupSource.values) {
      if (source.storageValue == text) return source;
    }
    return CloudBackupSource.manual;
  }

  static int _nonNegativeInt(Object? value) {
    final parsed = value is int ? value : int.tryParse('$value');
    return parsed == null || parsed < 0 ? 0 : parsed;
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static String _dayBucket(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _cloudFileName(CloudBackupSnapshot snapshot) {
    final created = snapshot.createdAt.toLocal();
    final date = _dayBucket(created);
    final time =
        '${created.hour.toString().padLeft(2, '0')}'
        '${created.minute.toString().padLeft(2, '0')}';
    return 'HomeVault_Cloud_${date}_$time.zip';
  }
}

class CloudBackupException implements Exception {
  const CloudBackupException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
