import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/appliance.dart';
import '../models/cloud_sync_status.dart';

abstract class ApplianceRepository {
  Future<List<Appliance>> loadAppliances();

  Future<void> saveAppliances(List<Appliance> appliances);
}

abstract class OwnerScopedApplianceRepository {
  String? get ownerUid;

  Future<void> bindOwner(String? uid);
}

abstract class ApplianceRepositoryDiagnostics {
  String? get lastLoadWarning;
}

abstract class WatchableApplianceRepository {
  Stream<List<Appliance>> watchAppliances();
}

abstract class CloudSyncAwareApplianceRepository {
  CloudSyncStatus get syncStatus;

  Stream<CloudSyncStatus> watchSyncStatus();

  Future<void> retrySync();
}

abstract class ConflictProtectedApplianceRepository {
  Future<List<Appliance>> saveAppliancesProtected(
    List<Appliance> appliances, {
    bool forceOverwrite = false,
    Set<String> authoritativeDeleteIds = const <String>{},
  });
}

class PendingApplianceSyncState {
  const PendingApplianceSyncState({
    this.pendingUpsertIds = const <String>{},
    this.pendingDeleteIds = const <String>{},
    this.authoritativeDeleteIds = const <String>{},
  });

  factory PendingApplianceSyncState.fromJson(Map<String, dynamic> json) {
    final pendingUpserts = _stringSet(json['pendingUpsertIds']);
    final pendingDeletes = _stringSet(json['pendingDeleteIds']);
    final authoritativeDeletes = _stringSet(
      json['authoritativeDeleteIds'],
    ).intersection(pendingDeletes);

    return PendingApplianceSyncState(
      pendingUpsertIds: pendingUpserts.difference(pendingDeletes),
      pendingDeleteIds: pendingDeletes,
      authoritativeDeleteIds: authoritativeDeletes,
    );
  }

  final Set<String> pendingUpsertIds;
  final Set<String> pendingDeleteIds;
  final Set<String> authoritativeDeleteIds;

  bool get hasPendingChanges =>
      pendingUpsertIds.isNotEmpty || pendingDeleteIds.isNotEmpty;

  bool isPendingUpsert(String applianceId) =>
      pendingUpsertIds.contains(applianceId);

  bool isPendingDelete(String applianceId) =>
      pendingDeleteIds.contains(applianceId);

  PendingApplianceSyncState queue({
    Iterable<String> upsertIds = const <String>[],
    Iterable<String> deleteIds = const <String>[],
    Iterable<String> authoritativeDeletes = const <String>[],
  }) {
    final nextUpserts = <String>{...pendingUpsertIds, ...upsertIds};
    final nextDeletes = <String>{...pendingDeleteIds, ...deleteIds};

    // A newer operation for the same ID wins locally. Re-adding an appliance
    // cancels its pending delete; deleting it cancels its pending upsert.
    nextUpserts.removeAll(deleteIds);
    nextDeletes.removeAll(upsertIds);

    final nextAuthoritativeDeletes = <String>{
      ...authoritativeDeleteIds,
      ...authoritativeDeletes,
    }..retainAll(nextDeletes);

    return PendingApplianceSyncState(
      pendingUpsertIds: Set<String>.unmodifiable(nextUpserts),
      pendingDeleteIds: Set<String>.unmodifiable(nextDeletes),
      authoritativeDeleteIds: Set<String>.unmodifiable(
        nextAuthoritativeDeletes,
      ),
    );
  }

  PendingApplianceSyncState clear({
    Iterable<String> upsertIds = const <String>[],
    Iterable<String> deleteIds = const <String>[],
  }) {
    final nextUpserts = <String>{...pendingUpsertIds}..removeAll(upsertIds);
    final nextDeletes = <String>{...pendingDeleteIds}..removeAll(deleteIds);
    final nextAuthoritativeDeletes = <String>{...authoritativeDeleteIds}
      ..retainAll(nextDeletes);

    return PendingApplianceSyncState(
      pendingUpsertIds: Set<String>.unmodifiable(nextUpserts),
      pendingDeleteIds: Set<String>.unmodifiable(nextDeletes),
      authoritativeDeleteIds: Set<String>.unmodifiable(
        nextAuthoritativeDeletes,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final upserts = pendingUpsertIds.toList(growable: false)..sort();
    final deletes = pendingDeleteIds.toList(growable: false)..sort();
    final authoritativeDeletes = authoritativeDeleteIds.toList(growable: false)
      ..sort();

    return {
      'schemaVersion': 1,
      'pendingUpsertIds': upserts,
      'pendingDeleteIds': deletes,
      'authoritativeDeleteIds': authoritativeDeletes,
    };
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! List) return const <String>{};

    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }
}

class FileApplianceRepository
    implements
        ApplianceRepository,
        OwnerScopedApplianceRepository,
        ApplianceRepositoryDiagnostics {
  FileApplianceRepository({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const int _schemaVersion = 5;

  final Future<Directory> Function() _documentsDirectoryProvider;
  String? _ownerUid;
  String? _lastLoadWarning;

  @override
  String? get ownerUid => _ownerUid;

  @override
  String? get lastLoadWarning => _lastLoadWarning;

  String get _ownerFingerprint {
    final owner = _ownerUid;
    if (owner == null || owner.trim().isEmpty) {
      throw const ApplianceStorageException(
        'Sign in before loading HomeVault data.',
      );
    }
    return sha256.convert(utf8.encode(owner)).toString().substring(0, 20);
  }

  @override
  Future<void> bindOwner(String? uid) async {
    _ownerUid = uid?.trim().isEmpty == true ? null : uid?.trim();
    _lastLoadWarning = null;

    if (_ownerUid != null) {
      await _migrateLegacyFileIfNeeded();
    }
  }

  Future<Directory> _dataDirectory() async {
    final documentsDirectory = await _documentsDirectoryProvider();
    final directory = Directory(
      path.join(
        documentsDirectory.path,
        'homevault',
        'data',
        'users',
        _ownerFingerprint,
      ),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _dataFile() async {
    final directory = await _dataDirectory();
    return File(path.join(directory.path, 'appliances.json'));
  }

  Future<File> _pendingSyncFile() async {
    final directory = await _dataDirectory();
    return File(path.join(directory.path, 'pending_structured_sync.json'));
  }

  Future<File> _legacyDataFile() async {
    final documentsDirectory = await _documentsDirectoryProvider();
    return File(
      path.join(
        documentsDirectory.path,
        'homevault',
        'data',
        'appliances.json',
      ),
    );
  }

  Future<void> _migrateLegacyFileIfNeeded() async {
    final destination = await _dataFile();
    if (await destination.exists()) return;

    final legacy = await _legacyDataFile();
    if (!await legacy.exists()) return;

    await destination.parent.create(recursive: true);
    await legacy.copy(destination.path);
    await legacy.delete();
    _lastLoadWarning =
        'Existing local data was securely assigned to this HomeVault account.';
  }

  @override
  Future<List<Appliance>> loadAppliances() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(contents);
      if (decoded is! Map) {
        throw const FormatException('The saved data has an invalid format.');
      }

      final data = Map<String, dynamic>.from(decoded);
      final storedOwner = '${data['ownerFingerprint'] ?? ''}'.trim();
      if (storedOwner.isNotEmpty && storedOwner != _ownerFingerprint) {
        throw const ApplianceStorageException(
          'This local data belongs to a different HomeVault account.',
        );
      }

      final applianceData = data['appliances'];
      if (applianceData is! List) {
        return [];
      }

      final appliances = <Appliance>[];
      var skipped = 0;

      for (final item in applianceData) {
        if (item is! Map) {
          skipped++;
          continue;
        }

        try {
          final appliance = Appliance.fromJson(Map<String, dynamic>.from(item));
          if (appliance.id.isEmpty) {
            skipped++;
          } else {
            appliances.add(appliance);
          }
        } catch (_) {
          skipped++;
        }
      }

      if (skipped > 0) {
        _lastLoadWarning =
            '$skipped damaged local record(s) were skipped during startup.';
      }

      return appliances;
    } on ApplianceStorageException {
      rethrow;
    } catch (error) {
      throw ApplianceStorageException(
        'HomeVault could not read the saved appliance data.',
        error,
      );
    }
  }

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {
    try {
      final file = await _dataFile();
      final temporaryFile = File('${file.path}.tmp');
      final payload = jsonEncode({
        'schemaVersion': _schemaVersion,
        'ownerFingerprint': _ownerFingerprint,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'appliances': appliances.map((item) => item.toJson()).toList(),
      });

      await temporaryFile.writeAsString(payload, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } catch (error) {
      if (error is ApplianceStorageException) rethrow;
      throw ApplianceStorageException(
        'HomeVault could not save the appliance data.',
        error,
      );
    }
  }

  Future<PendingApplianceSyncState> loadPendingSyncState() async {
    try {
      final file = await _pendingSyncFile();
      if (!await file.exists()) {
        return const PendingApplianceSyncState();
      }

      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        return const PendingApplianceSyncState();
      }

      final decoded = jsonDecode(contents);
      if (decoded is! Map) {
        throw const FormatException(
          'The pending cloud-sync state has an invalid format.',
        );
      }

      final data = Map<String, dynamic>.from(decoded);
      final storedOwner = '${data['ownerFingerprint'] ?? ''}'.trim();
      if (storedOwner.isNotEmpty && storedOwner != _ownerFingerprint) {
        throw const ApplianceStorageException(
          'This pending cloud-sync state belongs to a different HomeVault account.',
        );
      }

      return PendingApplianceSyncState.fromJson(data);
    } on ApplianceStorageException {
      rethrow;
    } catch (_) {
      _lastLoadWarning =
          'HomeVault recovered from damaged local cloud-sync metadata.';
      return const PendingApplianceSyncState();
    }
  }

  Future<void> savePendingSyncState(PendingApplianceSyncState state) async {
    try {
      final file = await _pendingSyncFile();
      final temporaryFile = File('${file.path}.tmp');

      if (!state.hasPendingChanges) {
        if (await temporaryFile.exists()) {
          await temporaryFile.delete();
        }
        if (await file.exists()) {
          await file.delete();
        }
        return;
      }

      final payload = jsonEncode({
        ...state.toJson(),
        'ownerFingerprint': _ownerFingerprint,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
      });

      await temporaryFile.writeAsString(payload, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } catch (error) {
      if (error is ApplianceStorageException) rethrow;
      throw ApplianceStorageException(
        'HomeVault could not save pending cloud-sync changes.',
        error,
      );
    }
  }
}

class MemoryApplianceRepository implements ApplianceRepository {
  MemoryApplianceRepository({List<Appliance> initialAppliances = const []})
    : _appliances = List<Appliance>.from(initialAppliances);

  List<Appliance> _appliances;

  @override
  Future<List<Appliance>> loadAppliances() async {
    return List<Appliance>.from(_appliances);
  }

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {
    _appliances = List<Appliance>.from(appliances);
  }
}

class ApplianceConflictException implements Exception {
  const ApplianceConflictException({
    required this.applianceId,
    required this.message,
  });

  final String applianceId;
  final String message;

  @override
  String toString() => message;
}

class ApplianceStorageException implements Exception {
  const ApplianceStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
