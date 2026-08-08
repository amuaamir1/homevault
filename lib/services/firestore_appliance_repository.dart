import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appliance.dart';
import '../models/cloud_sync_status.dart';
import '../models/stored_document.dart';
import 'appliance_repository.dart';
import 'cloud_sync_identity_service.dart';

/// Cloud-backed appliance repository used by HomeVault structured-data sync.
///
/// Firestore stores appliance, warranty, support, service, and notes data.
/// Device-specific attachment paths remain in the local repository so a path
/// from one phone is never treated as a valid path on another phone.
class FirestoreApplianceRepository
    implements
        ApplianceRepository,
        OwnerScopedApplianceRepository,
        ApplianceRepositoryDiagnostics,
        WatchableApplianceRepository,
        CloudSyncAwareApplianceRepository {
  FirestoreApplianceRepository({
    FirebaseFirestore? firestore,
    FileApplianceRepository? localRepository,
    CloudSyncIdentityService? identityService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localRepository = localRepository ?? FileApplianceRepository(),
       _identityService = identityService ?? CloudSyncIdentityService();

  static const int _cloudSchemaVersion = 3;
  static const Duration _writeWait = Duration(seconds: 5);
  static const Duration _retryWait = Duration(seconds: 8);

  final FirebaseFirestore _firestore;
  final FileApplianceRepository _localRepository;
  final CloudSyncIdentityService _identityService;
  final StreamController<CloudSyncStatus> _syncStatusController =
      StreamController<CloudSyncStatus>.broadcast();

  String? _ownerUid;
  String? _lastLoadWarning;
  Map<String, String> _lastCloudFingerprints = {};
  bool _hasCloudBaseline = false;
  DateTime? _lastSyncedAt;
  String? _installationId;
  CloudSyncStatus _syncStatus = const CloudSyncStatus.unavailable();

  @override
  String? get ownerUid => _ownerUid;

  @override
  String? get lastLoadWarning => _lastLoadWarning;

  @override
  CloudSyncStatus get syncStatus => _syncStatus;

  String get _requiredOwnerUid {
    final uid = _ownerUid;
    if (uid == null || uid.isEmpty) {
      throw const ApplianceStorageException(
        'Sign in before loading HomeVault data.',
      );
    }
    return uid;
  }

  String get _requiredInstallationId {
    final installationId = _installationId;
    if (installationId == null || installationId.isEmpty) {
      throw const ApplianceStorageException(
        'HomeVault could not identify this app installation.',
      );
    }
    return installationId;
  }

  CollectionReference<Map<String, dynamic>> get _appliancesCollection =>
      _firestore
          .collection('users')
          .doc(_requiredOwnerUid)
          .collection('appliances');

  DocumentReference<Map<String, dynamic>> get _migrationDocument => _firestore
      .collection('users')
      .doc(_requiredOwnerUid)
      .collection('syncMeta')
      .doc('appliancesV1');

  @override
  Stream<CloudSyncStatus> watchSyncStatus() => _syncStatusController.stream;

  @override
  Future<void> bindOwner(String? uid) async {
    final normalized = uid?.trim();
    _ownerUid = normalized == null || normalized.isEmpty ? null : normalized;
    _lastLoadWarning = null;
    _lastCloudFingerprints = {};
    _hasCloudBaseline = false;
    _lastSyncedAt = null;
    _installationId = null;

    await _localRepository.bindOwner(_ownerUid);
    await _identityService.bindOwner(_ownerUid);

    if (_ownerUid == null) {
      _emitSyncStatus(const CloudSyncStatus.unavailable());
    } else {
      _installationId = await _identityService.installationId();
      _emitSyncStatus(const CloudSyncStatus(state: CloudSyncState.connecting));
    }
  }

  @override
  Future<List<Appliance>> loadAppliances() async {
    final ownerAtStart = _requiredOwnerUid;
    final localAppliances = await _localRepository.loadAppliances();
    final localWarning = _localRepository.lastLoadWarning;

    _emitForOwner(
      ownerAtStart,
      CloudSyncStatus(
        state: CloudSyncState.connecting,
        lastSyncedAt: _lastSyncedAt,
      ),
    );

    try {
      var cloudSnapshot = await _appliancesCollection.get();
      _updateStatusFromSnapshot(ownerAtStart, cloudSnapshot);
      var cloudAppliances = _decodeSnapshot(cloudSnapshot);

      final migrationSnapshot = await _migrationDocument.get();
      final migrationData = migrationSnapshot.data();
      final cloudMigrationCompleted = migrationData?['completed'] == true;
      final localMigrationCompleted = await _identityService
          .hasCompletedStructuredMigration();
      final cloudSchemaVersion =
          (migrationData?['schemaVersion'] as num?)?.toInt() ?? 0;

      if (!localMigrationCompleted) {
        final cloudIds = cloudAppliances.map((item) => item.id).toSet();
        final missingFromCloud = localAppliances
            .where((item) => !cloudIds.contains(item.id))
            .toList(growable: false);

        final batch = _firestore.batch();

        for (final appliance in missingFromCloud) {
          batch.set(
            _appliancesCollection.doc(appliance.id),
            _cloudPayload(appliance),
          );
        }

        batch.set(_migrationDocument, {
          'completed': true,
          'schemaVersion': _cloudSchemaVersion,
          'completedAt': cloudMigrationCompleted
              ? migrationData!['completedAt']
              : FieldValue.serverTimestamp(),
          'lastConfirmedAt': FieldValue.serverTimestamp(),
          'lastConfirmedByDevice': _requiredInstallationId,
        }, SetOptions(merge: true));

        if (missingFromCloud.isNotEmpty) {
          _emitForOwner(
            ownerAtStart,
            CloudSyncStatus(
              state: CloudSyncState.syncing,
              lastSyncedAt: _lastSyncedAt,
              hasPendingWrites: true,
            ),
          );
        }

        final commit = batch.commit();
        try {
          await commit.timeout(_writeWait);
          await _identityService.markStructuredMigrationCompleted();

          cloudSnapshot = await _appliancesCollection.get();
          _updateStatusFromSnapshot(ownerAtStart, cloudSnapshot);
          cloudAppliances = _decodeSnapshot(cloudSnapshot);

          if (missingFromCloud.isNotEmpty) {
            _lastLoadWarning =
                '${missingFromCloud.length} existing local appliance'
                '${missingFromCloud.length == 1 ? '' : 's'} '
                'were moved to your HomeVault cloud account.';
          }
        } on TimeoutException {
          // Firestore keeps the batch queued locally. Mark this device as
          // migrated so stale local data cannot be re-imported on a later
          // launch while that queued write is awaiting the server.
          await _identityService.markStructuredMigrationCompleted();

          _emitForOwner(
            ownerAtStart,
            CloudSyncStatus(
              state: CloudSyncState.offline,
              lastSyncedAt: _lastSyncedAt,
              hasPendingWrites: true,
              message: 'Changes are waiting for cloud sync.',
            ),
          );

          cloudAppliances = _mergeUniqueAppliances(
            cloudAppliances,
            missingFromCloud,
          );
        }
      } else {
        // This installation has already completed the one-time local import.
        // Never re-import stale local records merely because the cloud marker
        // is missing or an older schema marker is present.
        if (!cloudMigrationCompleted ||
            cloudSchemaVersion < _cloudSchemaVersion) {
          try {
            await _migrationDocument
                .set({
                  'completed': true,
                  'schemaVersion': _cloudSchemaVersion,
                  'lastConfirmedAt': FieldValue.serverTimestamp(),
                  'lastConfirmedByDevice': _requiredInstallationId,
                }, SetOptions(merge: true))
                .timeout(_writeWait);
          } on TimeoutException {
            // The marker update is queued by Firestore. No appliance data is
            // re-imported, which is the important safety behavior here.
          }
        }
      }

      final merged = _mergeCloudWithLocal(cloudAppliances, localAppliances);

      await _localRepository.saveAppliances(merged);
      _rememberCloudBaseline(cloudAppliances);

      if (_lastLoadWarning == null && localWarning != null) {
        _lastLoadWarning = localWarning;
      }

      return merged;
    } on FirebaseException catch (error) {
      if (_isOfflineError(error)) {
        _rememberCloudBaseline(localAppliances);
        _emitForOwner(
          ownerAtStart,
          CloudSyncStatus(
            state: CloudSyncState.offline,
            lastSyncedAt: _lastSyncedAt,
            message: 'Using the last data saved on this device.',
          ),
        );
        return localAppliances;
      }

      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.error,
          lastSyncedAt: _lastSyncedAt,
          message: _firebaseMessage(error),
        ),
      );
      throw ApplianceStorageException(_firebaseMessage(error), error);
    } on ApplianceStorageException {
      rethrow;
    } catch (error) {
      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.error,
          lastSyncedAt: _lastSyncedAt,
          message: 'HomeVault could not load cloud appliance data.',
        ),
      );
      throw ApplianceStorageException(
        'HomeVault could not load your cloud appliance data.',
        error,
      );
    }
  }

  @override
  Stream<List<Appliance>> watchAppliances() async* {
    final ownerAtStart = _requiredOwnerUid;
    final collection = _appliancesCollection;

    try {
      await for (final snapshot in collection.snapshots(
        includeMetadataChanges: true,
      )) {
        if (_ownerUid != ownerAtStart) {
          return;
        }

        _updateStatusFromSnapshot(ownerAtStart, snapshot);

        final localAppliances = await _localRepository.loadAppliances();
        final cloudAppliances = _decodeSnapshot(snapshot);

        final merged = _mergeCloudWithLocal(cloudAppliances, localAppliances);

        await _localRepository.saveAppliances(merged);
        _rememberCloudBaseline(cloudAppliances);
        yield merged;
      }
    } on FirebaseException catch (error) {
      if (_ownerUid == ownerAtStart) {
        _emitSyncStatus(
          CloudSyncStatus(
            state: _isOfflineError(error)
                ? CloudSyncState.offline
                : CloudSyncState.error,
            lastSyncedAt: _lastSyncedAt,
            message: _firebaseMessage(error),
          ),
        );
      }
      rethrow;
    } catch (error) {
      if (_ownerUid == ownerAtStart) {
        _emitSyncStatus(
          CloudSyncStatus(
            state: CloudSyncState.error,
            lastSyncedAt: _lastSyncedAt,
            message: 'Cloud sync listener stopped unexpectedly.',
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {
    final ownerAtStart = _requiredOwnerUid;

    // Always preserve the complete on-device record first. This includes
    // invoice/warranty/service attachment paths that must stay device-local.
    await _localRepository.saveAppliances(appliances);

    if (!_hasCloudBaseline) {
      try {
        final snapshot = await _appliancesCollection.get();
        _updateStatusFromSnapshot(ownerAtStart, snapshot);
        _rememberCloudBaseline(_decodeSnapshot(snapshot));
      } on FirebaseException catch (error) {
        if (!_isOfflineError(error)) {
          _emitForOwner(
            ownerAtStart,
            CloudSyncStatus(
              state: CloudSyncState.error,
              lastSyncedAt: _lastSyncedAt,
              message: _firebaseMessage(error),
            ),
          );
          rethrow;
        }

        // The local file is our best-known baseline when starting offline.
        _rememberCloudBaseline(appliances);
        _emitForOwner(
          ownerAtStart,
          CloudSyncStatus(
            state: CloudSyncState.offline,
            lastSyncedAt: _lastSyncedAt,
            message: 'Changes will sync when a connection is available.',
          ),
        );
      }
    }

    final desiredFingerprints = <String, String>{
      for (final appliance in appliances) appliance.id: _fingerprint(appliance),
    };

    final desiredById = <String, Appliance>{
      for (final appliance in appliances) appliance.id: appliance,
    };

    final changedList = desiredFingerprints.keys
        .where((id) => _lastCloudFingerprints[id] != desiredFingerprints[id])
        .toList(growable: false);

    final deletedList = _lastCloudFingerprints.keys
        .where((id) => !desiredFingerprints.containsKey(id))
        .toList(growable: false);

    if (changedList.isEmpty && deletedList.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final id in changedList) {
      batch.set(_appliancesCollection.doc(id), _cloudPayload(desiredById[id]!));
    }

    for (final id in deletedList) {
      batch.delete(_appliancesCollection.doc(id));
    }

    _emitForOwner(
      ownerAtStart,
      CloudSyncStatus(
        state: CloudSyncState.syncing,
        lastSyncedAt: _lastSyncedAt,
        hasPendingWrites: true,
      ),
    );

    final commit = batch.commit();
    try {
      await commit.timeout(_writeWait);
      _lastLoadWarning = null;
      _lastCloudFingerprints = desiredFingerprints;
      _hasCloudBaseline = true;
      _markSynced(ownerAtStart);
    } on TimeoutException {
      // The Firestore SDK retains this write locally. A metadata snapshot will
      // switch the status back to Synced once the server acknowledges it.
      _lastCloudFingerprints = desiredFingerprints;
      _hasCloudBaseline = true;
      _lastLoadWarning =
          'Changes are saved on this device and are waiting for cloud sync.';
      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.offline,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: true,
          message: 'Changes are waiting for cloud sync.',
        ),
      );
    } on FirebaseException catch (error) {
      if (_isOfflineError(error)) {
        // Do not advance the cloud baseline: retrySync() will re-send the
        // local difference when connectivity returns.
        _lastLoadWarning =
            'Changes are saved locally and still need cloud sync.';
        _emitForOwner(
          ownerAtStart,
          CloudSyncStatus(
            state: CloudSyncState.offline,
            lastSyncedAt: _lastSyncedAt,
            hasPendingWrites: true,
            message: 'Changes are waiting for cloud sync.',
          ),
        );
        return;
      }

      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.error,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: true,
          message: _firebaseMessage(error),
        ),
      );
      rethrow;
    } catch (error) {
      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.error,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: true,
          message: 'HomeVault could not save cloud appliance data.',
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> retrySync() async {
    final ownerAtStart = _requiredOwnerUid;

    _emitForOwner(
      ownerAtStart,
      CloudSyncStatus(
        state: CloudSyncState.connecting,
        lastSyncedAt: _lastSyncedAt,
        hasPendingWrites: _syncStatus.hasPendingWrites,
      ),
    );

    try {
      // Re-send any local structured-data difference that was not known to be
      // queued in Firestore, then require a server read as proof of connectivity.
      final localAppliances = await _localRepository.loadAppliances();
      await saveAppliances(localAppliances);

      final snapshot = await _appliancesCollection
          .get(const GetOptions(source: Source.server))
          .timeout(_retryWait);

      _updateStatusFromSnapshot(ownerAtStart, snapshot);
    } on TimeoutException {
      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.offline,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: _syncStatus.hasPendingWrites,
          message: 'Cloud connection could not be confirmed.',
        ),
      );
      rethrow;
    } on FirebaseException catch (error) {
      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: _isOfflineError(error)
              ? CloudSyncState.offline
              : CloudSyncState.error,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: _syncStatus.hasPendingWrites,
          message: _firebaseMessage(error),
        ),
      );
      rethrow;
    }
  }

  void _updateStatusFromSnapshot(
    String ownerAtStart,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (_ownerUid != ownerAtStart) return;

    if (snapshot.metadata.hasPendingWrites) {
      _emitSyncStatus(
        CloudSyncStatus(
          state: CloudSyncState.syncing,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: true,
        ),
      );
      return;
    }

    if (snapshot.metadata.isFromCache) {
      _emitSyncStatus(
        CloudSyncStatus(
          state: CloudSyncState.offline,
          lastSyncedAt: _lastSyncedAt,
          message: 'Showing cached HomeVault data.',
        ),
      );
      return;
    }

    _markSynced(ownerAtStart);
  }

  void _markSynced(String ownerAtStart) {
    if (_ownerUid != ownerAtStart) return;

    _lastSyncedAt = DateTime.now();
    _emitSyncStatus(
      CloudSyncStatus(
        state: CloudSyncState.synced,
        lastSyncedAt: _lastSyncedAt,
      ),
    );
  }

  void _emitForOwner(String ownerAtStart, CloudSyncStatus status) {
    if (_ownerUid != ownerAtStart) return;
    _emitSyncStatus(status);
  }

  void _emitSyncStatus(CloudSyncStatus status) {
    _syncStatus = status;
    if (!_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  void _rememberCloudBaseline(List<Appliance> appliances) {
    _lastCloudFingerprints = {
      for (final appliance in appliances) appliance.id: _fingerprint(appliance),
    };
    _hasCloudBaseline = true;
  }

  List<Appliance> _decodeSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final appliances = <Appliance>[];
    var skipped = 0;

    for (final document in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(document.data());
        data.remove('cloudSchemaVersion');
        data.remove('cloudUpdatedAt');
        data.remove('cloudUpdatedByDevice');
        data.remove('cloudRevision');

        final appliance = Appliance.fromJson(data);
        if (appliance.id.isEmpty || appliance.id != document.id) {
          skipped++;
          continue;
        }

        appliances.add(appliance);
      } catch (_) {
        skipped++;
      }
    }

    appliances.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (skipped > 0) {
      _lastLoadWarning =
          '$skipped cloud appliance record${skipped == 1 ? '' : 's'} '
          'could not be read.';
    }

    return appliances;
  }

  List<Appliance> _mergeUniqueAppliances(
    List<Appliance> first,
    List<Appliance> second,
  ) {
    final byId = <String, Appliance>{
      for (final appliance in first) appliance.id: appliance,
    };

    for (final appliance in second) {
      byId.putIfAbsent(appliance.id, () => appliance);
    }

    final result = byId.values.toList(growable: false);
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  List<Appliance> _mergeCloudWithLocal(
    List<Appliance> cloudAppliances,
    List<Appliance> localAppliances,
  ) {
    final localById = <String, Appliance>{
      for (final appliance in localAppliances) appliance.id: appliance,
    };

    return cloudAppliances
        .map((cloud) => _mergeLocalAttachments(cloud, localById[cloud.id]))
        .toList(growable: false);
  }

  Appliance _mergeLocalAttachments(Appliance cloud, Appliance? local) {
    final mergedJson = Map<String, dynamic>.from(cloud.toJson());

    mergedJson['invoiceDocument'] = cloud.invoiceDocument
        ?.withLocalAvailabilityFrom(local?.invoiceDocument)
        .toJson();
    mergedJson['warrantyDocument'] = cloud.warrantyDocument
        ?.withLocalAvailabilityFrom(local?.warrantyDocument)
        .toJson();

    final localAdditionalById = <String, StoredDocument>{
      for (final document in local?.additionalDocuments ?? const [])
        document.id: document,
    };
    mergedJson['additionalDocuments'] = cloud.additionalDocuments
        .map(
          (document) => document
              .withLocalAvailabilityFrom(localAdditionalById[document.id])
              .toJson(),
        )
        .toList(growable: false);

    final localServiceById = {
      for (final record in local?.serviceRecords ?? const []) record.id: record,
    };

    mergedJson['serviceRecords'] = cloud.serviceRecords
        .map((cloudRecord) {
          final localRecord = localServiceById[cloudRecord.id];
          final recordJson = Map<String, dynamic>.from(cloudRecord.toJson());

          recordJson['receiptDocument'] = cloudRecord.receiptDocument
              ?.withLocalAvailabilityFrom(localRecord?.receiptDocument)
              .toJson();
          recordJson['reportDocument'] = cloudRecord.reportDocument
              ?.withLocalAvailabilityFrom(localRecord?.reportDocument)
              .toJson();

          return recordJson;
        })
        .toList(growable: false);

    return Appliance.fromJson(mergedJson);
  }

  Map<String, dynamic> _structuredData(Appliance appliance) {
    final data = Map<String, dynamic>.from(appliance.toJson());

    // Phase 1C synchronizes metadata for every attachment while keeping the
    // physical file and its localPath on the device that owns that copy.
    data['invoiceDocument'] = appliance.invoiceDocument?.toCloudMetadataJson();
    data['warrantyDocument'] = appliance.warrantyDocument
        ?.toCloudMetadataJson();
    data['additionalDocuments'] = appliance.additionalDocuments
        .map((document) => document.toCloudMetadataJson())
        .toList(growable: false);

    data['serviceRecords'] = appliance.serviceRecords
        .map((record) {
          final recordData = Map<String, dynamic>.from(record.toJson());
          recordData['receiptDocument'] = record.receiptDocument
              ?.toCloudMetadataJson();
          recordData['reportDocument'] = record.reportDocument
              ?.toCloudMetadataJson();
          return recordData;
        })
        .toList(growable: false);

    return data;
  }

  Map<String, dynamic> _cloudPayload(Appliance appliance) {
    return {
      ..._structuredData(appliance),
      'cloudSchemaVersion': _cloudSchemaVersion,
      'cloudUpdatedAt': FieldValue.serverTimestamp(),
      'cloudUpdatedByDevice': _requiredInstallationId,
      'cloudRevision': FieldValue.increment(1),
    };
  }

  String _fingerprint(Appliance appliance) {
    return jsonEncode(_structuredData(appliance));
  }

  bool _isOfflineError(FirebaseException error) {
    return error.code == 'unavailable' ||
        error.code == 'network-request-failed' ||
        error.code == 'deadline-exceeded';
  }

  String _firebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'HomeVault does not have permission to access your cloud '
            'appliance data. Publish the latest Firestore rules and try again.';
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return 'HomeVault cloud sync is temporarily unavailable. '
            'Check your internet connection and try again.';
      default:
        return 'HomeVault could not access your cloud appliance data.';
    }
  }
}
