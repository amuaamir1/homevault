import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appliance.dart';
import 'appliance_repository.dart';

/// Cloud-backed appliance repository used by HomeVault Phase 1 sync.
///
/// Firestore stores the structured appliance, warranty, support, and service
/// data. Device-specific attachment paths remain in the existing local
/// repository so a path from one phone is never treated as a valid path on a
/// different phone.
class FirestoreApplianceRepository
    implements
        ApplianceRepository,
        OwnerScopedApplianceRepository,
        ApplianceRepositoryDiagnostics,
        WatchableApplianceRepository {
  FirestoreApplianceRepository({
    FirebaseFirestore? firestore,
    FileApplianceRepository? localRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localRepository = localRepository ?? FileApplianceRepository();

  static const int _cloudSchemaVersion = 1;
  static const Duration _writeWait = Duration(seconds: 5);

  final FirebaseFirestore _firestore;
  final FileApplianceRepository _localRepository;

  String? _ownerUid;
  String? _lastLoadWarning;
  Map<String, String> _lastCloudFingerprints = {};
  bool _hasCloudBaseline = false;

  @override
  String? get ownerUid => _ownerUid;

  @override
  String? get lastLoadWarning => _lastLoadWarning;

  String get _requiredOwnerUid {
    final uid = _ownerUid;
    if (uid == null || uid.isEmpty) {
      throw const ApplianceStorageException(
        'Sign in before loading HomeVault data.',
      );
    }
    return uid;
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
  Future<void> bindOwner(String? uid) async {
    final normalized = uid?.trim();
    _ownerUid = normalized == null || normalized.isEmpty ? null : normalized;
    _lastLoadWarning = null;
    _lastCloudFingerprints = {};
    _hasCloudBaseline = false;

    await _localRepository.bindOwner(_ownerUid);
  }

  @override
  Future<List<Appliance>> loadAppliances() async {
    try {
      final localAppliances = await _localRepository.loadAppliances();
      final localWarning = _localRepository.lastLoadWarning;

      var cloudSnapshot = await _appliancesCollection.get();
      var cloudAppliances = _decodeSnapshot(cloudSnapshot);

      final migrationSnapshot = await _migrationDocument.get();
      final migrationCompleted = migrationSnapshot.data()?['completed'] == true;

      if (!migrationCompleted) {
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
          'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await batch.commit();

        cloudSnapshot = await _appliancesCollection.get();
        cloudAppliances = _decodeSnapshot(cloudSnapshot);

        if (missingFromCloud.isNotEmpty) {
          _lastLoadWarning =
              '${missingFromCloud.length} existing local appliance'
              '${missingFromCloud.length == 1 ? '' : 's'} '
              'were moved to your HomeVault cloud account.';
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
      throw ApplianceStorageException(_firebaseMessage(error), error);
    } on ApplianceStorageException {
      rethrow;
    } catch (error) {
      throw ApplianceStorageException(
        'HomeVault could not load your cloud appliance data.',
        error,
      );
    }
  }

  @override
  Stream<List<Appliance>> watchAppliances() {
    return _appliancesCollection.snapshots().asyncMap((snapshot) async {
      final localAppliances = await _localRepository.loadAppliances();
      final cloudAppliances = _decodeSnapshot(snapshot);

      final merged = _mergeCloudWithLocal(cloudAppliances, localAppliances);

      await _localRepository.saveAppliances(merged);
      _rememberCloudBaseline(cloudAppliances);
      return merged;
    });
  }

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {
    // Always preserve the complete on-device record first. This includes
    // invoice/warranty/service attachment paths that must stay device-local.
    await _localRepository.saveAppliances(appliances);

    if (!_hasCloudBaseline) {
      final snapshot = await _appliancesCollection.get();
      _rememberCloudBaseline(_decodeSnapshot(snapshot));
    }

    final desiredFingerprints = <String, String>{
      for (final appliance in appliances) appliance.id: _fingerprint(appliance),
    };

    final desiredById = <String, Appliance>{
      for (final appliance in appliances) appliance.id: appliance,
    };

    final changedIds = desiredFingerprints.keys.where(
      (id) => _lastCloudFingerprints[id] != desiredFingerprints[id],
    );

    final deletedIds = _lastCloudFingerprints.keys.where(
      (id) => !desiredFingerprints.containsKey(id),
    );

    final changedList = changedIds.toList(growable: false);
    final deletedList = deletedIds.toList(growable: false);

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

    // Firestore queues writes locally when connectivity is temporarily lost.
    // Wait briefly for the server, but do not freeze HomeVault indefinitely
    // when the phone is offline.
    final commit = batch.commit();
    try {
      await commit.timeout(_writeWait);
      _lastLoadWarning = null;
    } on TimeoutException {
      _lastLoadWarning =
          'Changes are saved on this device and are waiting for cloud sync.';
    }

    _lastCloudFingerprints = desiredFingerprints;
    _hasCloudBaseline = true;
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
    if (local == null) {
      return cloud;
    }

    final mergedJson = Map<String, dynamic>.from(cloud.toJson());

    mergedJson['invoiceDocument'] = local.invoiceDocument?.toJson();
    mergedJson['warrantyDocument'] = local.warrantyDocument?.toJson();
    mergedJson['additionalDocuments'] = local.additionalDocuments
        .map((document) => document.toJson())
        .toList(growable: false);

    final localServiceById = {
      for (final record in local.serviceRecords) record.id: record,
    };

    final serviceRecords =
        (mergedJson['serviceRecords'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) {
              final recordJson = Map<String, dynamic>.from(item);
              final recordId = '${recordJson['id'] ?? ''}';
              final localRecord = localServiceById[recordId];

              if (localRecord != null) {
                recordJson['receiptDocument'] = localRecord.receiptDocument
                    ?.toJson();
                recordJson['reportDocument'] = localRecord.reportDocument
                    ?.toJson();
              }

              return recordJson;
            })
            .toList(growable: false);

    mergedJson['serviceRecords'] = serviceRecords;

    return Appliance.fromJson(mergedJson);
  }

  Map<String, dynamic> _structuredData(Appliance appliance) {
    final data = Map<String, dynamic>.from(appliance.toJson());

    // Attachment binaries and device-local file paths are intentionally not
    // synchronized in Phase 1. References such as invoiceReference and
    // warrantyReference remain synchronized because they are normal fields.
    data['invoiceDocument'] = null;
    data['warrantyDocument'] = null;
    data['additionalDocuments'] = <Object?>[];

    final serviceRecords =
        (data['serviceRecords'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) {
              final record = Map<String, dynamic>.from(item);
              record['receiptDocument'] = null;
              record['reportDocument'] = null;
              return record;
            })
            .toList(growable: false);

    data['serviceRecords'] = serviceRecords;
    return data;
  }

  Map<String, dynamic> _cloudPayload(Appliance appliance) {
    return {
      ..._structuredData(appliance),
      'cloudSchemaVersion': _cloudSchemaVersion,
      'cloudUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  String _fingerprint(Appliance appliance) {
    return jsonEncode(_structuredData(appliance));
  }

  String _firebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'HomeVault does not have permission to access your cloud '
            'appliance data. Publish the latest Firestore rules and try again.';
      case 'unavailable':
        return 'HomeVault cloud sync is temporarily unavailable. '
            'Check your internet connection and try again.';
      default:
        return 'HomeVault could not access your cloud appliance data.';
    }
  }
}
