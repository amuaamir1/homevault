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
/// Firestore stores appliance, warranty, support, service, notes, and
/// attachment metadata. Device-specific local paths remain in the local
/// repository, while private Firebase Storage object paths synchronize between
/// devices so another authenticated device can download the physical file.
class FirestoreApplianceRepository
    implements
        ApplianceRepository,
        OwnerScopedApplianceRepository,
        ApplianceRepositoryDiagnostics,
        WatchableApplianceRepository,
        CloudSyncAwareApplianceRepository,
        ConflictProtectedApplianceRepository {
  FirestoreApplianceRepository({
    FirebaseFirestore? firestore,
    FileApplianceRepository? localRepository,
    CloudSyncIdentityService? identityService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localRepository = localRepository ?? FileApplianceRepository(),
       _identityService = identityService ?? CloudSyncIdentityService();

  static const int _cloudSchemaVersion = 5;
  static const Duration _writeWait = Duration(seconds: 5);
  static const Duration _startupReadWait = Duration(seconds: 2);
  static const Duration _retryWait = Duration(seconds: 8);
  static const Duration _automaticReconnectRetryDelay = Duration(
    milliseconds: 300,
  );

  final FirebaseFirestore _firestore;
  final FileApplianceRepository _localRepository;
  final CloudSyncIdentityService _identityService;
  final StreamController<CloudSyncStatus> _syncStatusController =
      StreamController<CloudSyncStatus>.broadcast();

  String? _ownerUid;
  String? _lastLoadWarning;
  Map<String, String> _lastCloudFingerprints = {};
  Map<String, int> _lastCloudRevisions = {};
  bool _hasCloudBaseline = false;
  DateTime? _lastSyncedAt;
  String? _installationId;
  PendingApplianceSyncState _pendingSync = const PendingApplianceSyncState();
  Future<void>? _automaticReconnectRetry;
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
    _lastCloudRevisions = {};
    _hasCloudBaseline = false;
    _lastSyncedAt = null;
    _installationId = null;
    _pendingSync = const PendingApplianceSyncState();
    _automaticReconnectRetry = null;

    await _localRepository.bindOwner(_ownerUid);
    await _identityService.bindOwner(_ownerUid);

    if (_ownerUid == null) {
      _emitSyncStatus(const CloudSyncStatus.unavailable());
    } else {
      _installationId = await _identityService.installationId();
      _pendingSync = await _localRepository.loadPendingSyncState();
      _emitSyncStatus(
        CloudSyncStatus(
          state: CloudSyncState.connecting,
          hasPendingWrites: _pendingSync.hasPendingChanges,
        ),
      );
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
        hasPendingWrites: _pendingSync.hasPendingChanges,
      ),
    );

    try {
      var cloudSnapshot = await _appliancesCollection.get().timeout(
        _startupReadWait,
      );
      _updateStatusFromSnapshot(ownerAtStart, cloudSnapshot);
      var cloudAppliances = _decodeSnapshot(cloudSnapshot);

      final migrationSnapshot = await _migrationDocument.get().timeout(
        _startupReadWait,
      );
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

          cloudSnapshot = await _appliancesCollection.get().timeout(
            _startupReadWait,
          );
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

      if (!cloudSnapshot.metadata.isFromCache &&
          !cloudSnapshot.metadata.hasPendingWrites) {
        await _reconcilePendingWithCloud(cloudAppliances, localAppliances);
      }
      final merged = _mergeCloudWithLocal(cloudAppliances, localAppliances);

      await _localRepository.saveAppliances(merged);
      _rememberCloudBaseline(cloudAppliances);
      _updateStatusFromSnapshot(ownerAtStart, cloudSnapshot);

      if (_lastLoadWarning == null && localWarning != null) {
        _lastLoadWarning = localWarning;
      }

      if (_pendingSync.hasPendingChanges) {
        _scheduleAutomaticReconnectRetry(ownerAtStart);
      }

      return merged;
    } on TimeoutException {
      _lastLoadWarning =
          'Cloud sync is taking longer than expected. '
          'Showing the latest data saved on this device while HomeVault reconnects.';
      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.connecting,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: _pendingSync.hasPendingChanges,
          message: 'Showing device data while cloud sync reconnects.',
        ),
      );
      return localAppliances;
    } on FirebaseException catch (error) {
      if (_isOfflineError(error)) {
        _emitForOwner(
          ownerAtStart,
          CloudSyncStatus(
            state: CloudSyncState.offline,
            lastSyncedAt: _lastSyncedAt,
            hasPendingWrites: _pendingSync.hasPendingChanges,
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

        if (!snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites) {
          await _reconcilePendingWithCloud(cloudAppliances, localAppliances);
        }
        final merged = _mergeCloudWithLocal(cloudAppliances, localAppliances);

        await _localRepository.saveAppliances(merged);
        _rememberCloudBaseline(cloudAppliances);
        _updateStatusFromSnapshot(ownerAtStart, snapshot);
        yield merged;

        if (!snapshot.metadata.isFromCache && _pendingSync.hasPendingChanges) {
          _scheduleAutomaticReconnectRetry(ownerAtStart);
        }
      }
    } on FirebaseException catch (error) {
      if (_ownerUid == ownerAtStart) {
        _emitSyncStatus(
          CloudSyncStatus(
            state: _isOfflineError(error)
                ? CloudSyncState.offline
                : CloudSyncState.error,
            lastSyncedAt: _lastSyncedAt,
            hasPendingWrites: _pendingSync.hasPendingChanges,
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
            hasPendingWrites: _pendingSync.hasPendingChanges,
            message: 'Cloud sync listener stopped unexpectedly.',
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {
    await saveAppliancesProtected(appliances);
  }

  @override
  Future<List<Appliance>> saveAppliancesProtected(
    List<Appliance> appliances, {
    bool forceOverwrite = false,
    Set<String> authoritativeDeleteIds = const <String>{},
  }) async {
    final ownerAtStart = _requiredOwnerUid;
    final localBeforeSave = await _localRepository.loadAppliances();

    if (!_hasCloudBaseline) {
      try {
        final snapshot = await _appliancesCollection
            .get(const GetOptions(source: Source.server))
            .timeout(_retryWait);
        _updateStatusFromSnapshot(ownerAtStart, snapshot);
        _rememberCloudBaseline(_decodeSnapshot(snapshot));
      } on TimeoutException {
        await _localRepository.saveAppliances(appliances);
        await _queuePendingDifference(
          ownerAtStart,
          previous: localBeforeSave,
          desired: appliances,
          authoritativeDeleteIds: authoritativeDeleteIds,
        );
        _emitForOwner(
          ownerAtStart,
          CloudSyncStatus(
            state: CloudSyncState.offline,
            lastSyncedAt: _lastSyncedAt,
            hasPendingWrites: _pendingSync.hasPendingChanges,
            message:
                'Changes are saved on this device and will sync automatically.',
          ),
        );
        return appliances;
      } on FirebaseException catch (error) {
        if (_isOfflineError(error)) {
          await _localRepository.saveAppliances(appliances);
          await _queuePendingDifference(
            ownerAtStart,
            previous: localBeforeSave,
            desired: appliances,
            authoritativeDeleteIds: authoritativeDeleteIds,
          );
          _emitForOwner(
            ownerAtStart,
            CloudSyncStatus(
              state: CloudSyncState.offline,
              lastSyncedAt: _lastSyncedAt,
              hasPendingWrites: _pendingSync.hasPendingChanges,
              message:
                  'Changes are saved on this device and will sync automatically.',
            ),
          );
          return appliances;
        }
        rethrow;
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
      await _localRepository.saveAppliances(appliances);
      await _reconcilePendingAgainstRememberedBaseline(
        ownerAtStart,
        appliances,
      );
      if (!_pendingSync.hasPendingChanges) {
        _markSynced(ownerAtStart);
      }
      return appliances;
    }

    _emitForOwner(
      ownerAtStart,
      CloudSyncStatus(
        state: CloudSyncState.syncing,
        lastSyncedAt: _lastSyncedAt,
        hasPendingWrites: true,
      ),
    );

    try {
      final resolved = await _firestore
          .runTransaction<List<Appliance>>((transaction) async {
            final currentSnapshots =
                <String, DocumentSnapshot<Map<String, dynamic>>>{};

            for (final id in {...changedList, ...deletedList}) {
              currentSnapshots[id] = await transaction.get(
                _appliancesCollection.doc(id),
              );
            }

            final resolvedById = <String, Appliance>{
              for (final appliance in appliances) appliance.id: appliance,
            };

            for (final id in changedList) {
              final desired = desiredById[id]!;
              final current = currentSnapshots[id]!;
              final currentData = current.data();
              final currentRevision =
                  (currentData?['cloudRevision'] as num?)?.toInt() ?? 0;
              final expectedRevision = desired.cloudRevision;

              if (!forceOverwrite) {
                if (!current.exists && expectedRevision != 0) {
                  throw ApplianceConflictException(
                    applianceId: id,
                    message:
                        'This appliance was deleted on another device. Reopen HomeVault before making more changes.',
                  );
                }

                if (current.exists && currentRevision != expectedRevision) {
                  throw ApplianceConflictException(
                    applianceId: id,
                    message:
                        'This appliance was updated on another device. Your older copy was not uploaded.',
                  );
                }
              }

              final nextRevision = currentRevision + 1;
              transaction.set(
                _appliancesCollection.doc(id),
                _cloudPayload(desired, cloudRevision: nextRevision),
              );

              resolvedById[id] = desired.withCloudSyncMetadata(
                cloudRevision: nextRevision,
                cloudUpdatedByDevice: _requiredInstallationId,
              );
            }

            for (final id in deletedList) {
              final current = currentSnapshots[id]!;
              if (!current.exists) {
                continue;
              }

              final currentRevision =
                  (current.data()?['cloudRevision'] as num?)?.toInt() ?? 0;
              final expectedRevision = _lastCloudRevisions[id] ?? 0;

              final authoritativeDelete = authoritativeDeleteIds.contains(id);

              if (!forceOverwrite &&
                  !authoritativeDelete &&
                  currentRevision != expectedRevision) {
                throw ApplianceConflictException(
                  applianceId: id,
                  message:
                      'This appliance was updated on another device and was not deleted. Reopen it and try again.',
                );
              }

              // Explicit deletion wins over a newer revision of the same
              // appliance. This is intentionally scoped to the confirmed ID;
              // stale edits and unrelated appliance writes remain protected.
              transaction.delete(_appliancesCollection.doc(id));
            }

            return appliances
                .map((item) => resolvedById[item.id] ?? item)
                .toList(growable: false);
          })
          .timeout(_retryWait);

      await _localRepository.saveAppliances(resolved);
      _rememberCloudBaseline(resolved);
      await _clearPendingSync(
        ownerAtStart,
        upsertIds: changedList,
        deleteIds: deletedList,
      );
      _lastLoadWarning = null;
      _markSynced(ownerAtStart);
      return resolved;
    } on ApplianceConflictException {
      final snapshot = await _appliancesCollection
          .get(const GetOptions(source: Source.server))
          .timeout(_retryWait);
      final cloudAppliances = _decodeSnapshot(snapshot);
      final localAppliances = await _localRepository.loadAppliances();

      if (!snapshot.metadata.isFromCache &&
          !snapshot.metadata.hasPendingWrites) {
        await _reconcilePendingWithCloud(cloudAppliances, localAppliances);
      }
      final refreshed = _mergeCloudWithLocal(cloudAppliances, localAppliances);
      await _localRepository.saveAppliances(refreshed);
      _rememberCloudBaseline(cloudAppliances);

      if (_pendingSync.hasPendingChanges) {
        _emitForOwner(
          ownerAtStart,
          CloudSyncStatus(
            state: CloudSyncState.error,
            lastSyncedAt: _lastSyncedAt,
            hasPendingWrites: true,
            message:
                'A saved offline change conflicts with a newer cloud update.',
          ),
        );
      } else {
        _markSynced(ownerAtStart);
      }

      rethrow;
    } on TimeoutException {
      await _localRepository.saveAppliances(appliances);
      await _queuePendingSync(
        ownerAtStart,
        upsertIds: changedList,
        deleteIds: deletedList,
        authoritativeDeleteIds: authoritativeDeleteIds,
      );
      _lastLoadWarning =
          'Changes are saved locally and will sync automatically.';
      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.offline,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: _pendingSync.hasPendingChanges,
          message: 'Changes are saved locally and will sync automatically.',
        ),
      );
      return appliances;
    } on FirebaseException catch (error) {
      if (_isOfflineError(error)) {
        await _localRepository.saveAppliances(appliances);
        await _queuePendingSync(
          ownerAtStart,
          upsertIds: changedList,
          deleteIds: deletedList,
          authoritativeDeleteIds: authoritativeDeleteIds,
        );
        _lastLoadWarning =
            'Changes are saved locally and will sync automatically.';
        _emitForOwner(
          ownerAtStart,
          CloudSyncStatus(
            state: CloudSyncState.offline,
            lastSyncedAt: _lastSyncedAt,
            hasPendingWrites: _pendingSync.hasPendingChanges,
            message: 'Changes are saved locally and will sync automatically.',
          ),
        );
        return appliances;
      }

      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.error,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: _pendingSync.hasPendingChanges,
          message: _firebaseMessage(error),
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
        hasPendingWrites: _pendingSync.hasPendingChanges,
      ),
    );

    try {
      final localAppliances = await _localRepository.loadAppliances();
      final pendingAtStart = _pendingSync;

      if (pendingAtStart.hasPendingChanges) {
        await saveAppliancesProtected(
          localAppliances,
          authoritativeDeleteIds: pendingAtStart.authoritativeDeleteIds,
        );
      } else {
        // Preserve the previous retry behavior for upgrades from builds that
        // predate the durable pending-sync journal.
        await saveAppliances(localAppliances);
      }

      final snapshot = await _appliancesCollection
          .get(const GetOptions(source: Source.server))
          .timeout(_retryWait);

      final cloudAppliances = _decodeSnapshot(snapshot);
      final latestLocal = await _localRepository.loadAppliances();
      if (!snapshot.metadata.isFromCache &&
          !snapshot.metadata.hasPendingWrites) {
        await _reconcilePendingWithCloud(cloudAppliances, latestLocal);
      }

      final merged = _mergeCloudWithLocal(cloudAppliances, latestLocal);
      await _localRepository.saveAppliances(merged);
      _rememberCloudBaseline(cloudAppliances);
      _updateStatusFromSnapshot(ownerAtStart, snapshot);
    } on TimeoutException {
      _emitForOwner(
        ownerAtStart,
        CloudSyncStatus(
          state: CloudSyncState.offline,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: _pendingSync.hasPendingChanges,
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
          hasPendingWrites: _pendingSync.hasPendingChanges,
          message: _firebaseMessage(error),
        ),
      );
      rethrow;
    }
  }

  Future<void> _queuePendingDifference(
    String ownerAtStart, {
    required List<Appliance> previous,
    required List<Appliance> desired,
    Set<String> authoritativeDeleteIds = const <String>{},
  }) async {
    final previousFingerprints = <String, String>{
      for (final appliance in previous) appliance.id: _fingerprint(appliance),
    };
    final desiredFingerprints = <String, String>{
      for (final appliance in desired) appliance.id: _fingerprint(appliance),
    };

    final upsertIds = desiredFingerprints.keys
        .where((id) => previousFingerprints[id] != desiredFingerprints[id])
        .toSet();
    final deleteIds = previousFingerprints.keys
        .where((id) => !desiredFingerprints.containsKey(id))
        .toSet();

    await _queuePendingSync(
      ownerAtStart,
      upsertIds: upsertIds,
      deleteIds: deleteIds,
      authoritativeDeleteIds: authoritativeDeleteIds,
    );
  }

  Future<void> _queuePendingSync(
    String ownerAtStart, {
    Iterable<String> upsertIds = const <String>[],
    Iterable<String> deleteIds = const <String>[],
    Iterable<String> authoritativeDeleteIds = const <String>[],
  }) async {
    if (_ownerUid != ownerAtStart ||
        _localRepository.ownerUid != ownerAtStart) {
      return;
    }

    final next = _pendingSync.queue(
      upsertIds: upsertIds,
      deleteIds: deleteIds,
      authoritativeDeletes: authoritativeDeleteIds,
    );

    if (identical(next, _pendingSync) ||
        _samePendingSyncState(next, _pendingSync)) {
      return;
    }

    await _localRepository.savePendingSyncState(next);
    if (_ownerUid == ownerAtStart) {
      _pendingSync = next;
    }
  }

  Future<void> _clearPendingSync(
    String ownerAtStart, {
    Iterable<String> upsertIds = const <String>[],
    Iterable<String> deleteIds = const <String>[],
  }) async {
    if (_ownerUid != ownerAtStart ||
        _localRepository.ownerUid != ownerAtStart) {
      return;
    }

    final next = _pendingSync.clear(upsertIds: upsertIds, deleteIds: deleteIds);

    if (_samePendingSyncState(next, _pendingSync)) {
      return;
    }

    await _localRepository.savePendingSyncState(next);
    if (_ownerUid == ownerAtStart) {
      _pendingSync = next;
    }
  }

  Future<void> _reconcilePendingWithCloud(
    List<Appliance> cloudAppliances,
    List<Appliance> localAppliances,
  ) async {
    final ownerAtStart = _requiredOwnerUid;
    if (!_pendingSync.hasPendingChanges) return;

    final cloudById = <String, Appliance>{
      for (final appliance in cloudAppliances) appliance.id: appliance,
    };
    final localById = <String, Appliance>{
      for (final appliance in localAppliances) appliance.id: appliance,
    };

    final satisfiedUpserts = <String>{};
    for (final id in _pendingSync.pendingUpsertIds) {
      final cloud = cloudById[id];
      final local = localById[id];
      if (cloud != null &&
          local != null &&
          _fingerprint(cloud) == _fingerprint(local)) {
        satisfiedUpserts.add(id);
      }
    }

    final satisfiedDeletes = _pendingSync.pendingDeleteIds
        .where((id) => !cloudById.containsKey(id))
        .toSet();

    if (satisfiedUpserts.isEmpty && satisfiedDeletes.isEmpty) {
      return;
    }

    await _clearPendingSync(
      ownerAtStart,
      upsertIds: satisfiedUpserts,
      deleteIds: satisfiedDeletes,
    );
  }

  Future<void> _reconcilePendingAgainstRememberedBaseline(
    String ownerAtStart,
    List<Appliance> desired,
  ) async {
    if (!_pendingSync.hasPendingChanges || !_hasCloudBaseline) return;

    final desiredById = <String, Appliance>{
      for (final appliance in desired) appliance.id: appliance,
    };

    final satisfiedUpserts = <String>{};
    for (final id in _pendingSync.pendingUpsertIds) {
      final appliance = desiredById[id];
      final cloudFingerprint = _lastCloudFingerprints[id];
      if (appliance != null &&
          cloudFingerprint != null &&
          _fingerprint(appliance) == cloudFingerprint) {
        satisfiedUpserts.add(id);
      }
    }

    final satisfiedDeletes = _pendingSync.pendingDeleteIds
        .where((id) => !_lastCloudFingerprints.containsKey(id))
        .toSet();

    await _clearPendingSync(
      ownerAtStart,
      upsertIds: satisfiedUpserts,
      deleteIds: satisfiedDeletes,
    );
  }

  bool _samePendingSyncState(
    PendingApplianceSyncState first,
    PendingApplianceSyncState second,
  ) {
    return _sameStringSet(first.pendingUpsertIds, second.pendingUpsertIds) &&
        _sameStringSet(first.pendingDeleteIds, second.pendingDeleteIds) &&
        _sameStringSet(
          first.authoritativeDeleteIds,
          second.authoritativeDeleteIds,
        );
  }

  bool _sameStringSet(Set<String> first, Set<String> second) {
    return first.length == second.length && first.containsAll(second);
  }

  void _scheduleAutomaticReconnectRetry(String ownerAtStart) {
    if (_ownerUid != ownerAtStart ||
        !_pendingSync.hasPendingChanges ||
        _automaticReconnectRetry != null) {
      return;
    }

    late final Future<void> operation;
    operation = Future<void>.delayed(_automaticReconnectRetryDelay, () async {
      if (_ownerUid != ownerAtStart || !_pendingSync.hasPendingChanges) {
        return;
      }

      try {
        await retrySync();
      } catch (_) {
        // A conflict remains queued for explicit user review, while an offline
        // failure will be retried on the next server snapshot/app resume.
      }
    });

    _automaticReconnectRetry = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_automaticReconnectRetry, operation)) {
          _automaticReconnectRetry = null;
        }
      }),
    );
  }

  void _updateStatusFromSnapshot(
    String ownerAtStart,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (_ownerUid != ownerAtStart) return;

    final hasPendingWrites =
        snapshot.metadata.hasPendingWrites || _pendingSync.hasPendingChanges;

    if (hasPendingWrites) {
      _emitSyncStatus(
        CloudSyncStatus(
          state: snapshot.metadata.isFromCache
              ? CloudSyncState.offline
              : CloudSyncState.syncing,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: true,
          message: snapshot.metadata.isFromCache
              ? 'Changes are saved on this device and will sync automatically.'
              : null,
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

    if (_pendingSync.hasPendingChanges) {
      _emitSyncStatus(
        CloudSyncStatus(
          state: CloudSyncState.syncing,
          lastSyncedAt: _lastSyncedAt,
          hasPendingWrites: true,
        ),
      );
      return;
    }

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
    _lastCloudRevisions = {
      for (final appliance in appliances) appliance.id: appliance.cloudRevision,
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
    final cloudIds = cloudAppliances.map((appliance) => appliance.id).toSet();
    final merged = <Appliance>[];

    for (final cloud in cloudAppliances) {
      if (_pendingSync.isPendingDelete(cloud.id)) {
        // A user-confirmed local delete must remain deleted on this device
        // while the cloud transaction is waiting for connectivity.
        continue;
      }

      final local = localById[cloud.id];
      if (_pendingSync.isPendingUpsert(cloud.id) && local != null) {
        // Preserve the user's locally saved edit until conflict-protected retry
        // either uploads it or determines that the cloud changed meanwhile.
        merged.add(local);
        continue;
      }

      merged.add(_mergeLocalAttachments(cloud, local));
    }

    for (final id in _pendingSync.pendingUpsertIds) {
      if (cloudIds.contains(id)) continue;
      final local = localById[id];
      if (local != null) {
        // Offline-created appliances are not allowed to disappear merely
        // because a reconnect snapshot arrives before the queued upload runs.
        merged.add(local);
      }
    }

    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<Appliance>.unmodifiable(merged);
  }

  Appliance _mergeLocalAttachments(Appliance cloud, Appliance? local) {
    final mergedJson = Map<String, dynamic>.from(cloud.toJson());

    mergedJson['appliancePhotoDocument'] = cloud.appliancePhotoDocument
        ?.withLocalAvailabilityFrom(local?.appliancePhotoDocument)
        .toJson();
    mergedJson['invoiceDocument'] = cloud.invoiceDocument
        ?.withLocalAvailabilityFrom(local?.invoiceDocument)
        .toJson();
    mergedJson['warrantyDocument'] = cloud.warrantyDocument
        ?.withLocalAvailabilityFrom(local?.warrantyDocument)
        .toJson();
    mergedJson['extendedWarrantyDocument'] = cloud.extendedWarrantyDocument
        ?.withLocalAvailabilityFrom(local?.extendedWarrantyDocument)
        .toJson();
    mergedJson['amcDocument'] = cloud.amcDocument
        ?.withLocalAvailabilityFrom(local?.amcDocument)
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
    data.remove('cloudRevision');
    data.remove('cloudUpdatedByDevice');

    // Attachment metadata includes the private Firebase Storage object path,
    // but localPath always remains device-specific.
    data['appliancePhotoDocument'] = appliance.appliancePhotoDocument
        ?.toCloudMetadataJson();
    data['invoiceDocument'] = appliance.invoiceDocument?.toCloudMetadataJson();
    data['warrantyDocument'] = appliance.warrantyDocument
        ?.toCloudMetadataJson();
    data['extendedWarrantyDocument'] = appliance.extendedWarrantyDocument
        ?.toCloudMetadataJson();
    data['amcDocument'] = appliance.amcDocument?.toCloudMetadataJson();
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

  Map<String, dynamic> _cloudPayload(
    Appliance appliance, {
    int? cloudRevision,
  }) {
    return {
      ..._structuredData(appliance),
      'cloudSchemaVersion': _cloudSchemaVersion,
      'cloudUpdatedAt': FieldValue.serverTimestamp(),
      'cloudUpdatedByDevice': _requiredInstallationId,
      'cloudRevision': cloudRevision ?? (appliance.cloudRevision + 1),
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
            'appliance data. Sign in again and try once more.';
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
