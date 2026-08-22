import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/appliance.dart';
import '../models/cloud_sync_status.dart';
import '../models/service_record.dart';
import '../models/stored_document.dart';
import '../services/appliance_repository.dart';
import '../services/cloud_document_storage_service.dart';
import '../services/cloud_document_sync_journal.dart';
import '../services/crash_reporting_service.dart';
import '../services/document_storage_service.dart';
import '../services/homevault_error_message.dart';
import '../services/warranty_notification_service.dart';

class ApplianceStore extends ChangeNotifier {
  ApplianceStore({
    ApplianceRepository? repository,
    WarrantyReminderScheduler? reminderScheduler,
    CloudDocumentStorage? cloudDocumentStorage,
    CloudDocumentSyncJournal? cloudDocumentSyncJournal,
    DocumentStorageService? documentStorageService,
  }) : _repository = repository ?? FileApplianceRepository(),
       _reminderScheduler =
           reminderScheduler ?? const NoOpWarrantyReminderScheduler(),
       _cloudDocumentStorage =
           cloudDocumentStorage ?? const NoOpCloudDocumentStorage(),
       _cloudDocumentSyncJournal =
           cloudDocumentSyncJournal ?? MemoryCloudDocumentSyncJournal(),
       _documentStorageService =
           documentStorageService ?? DocumentStorageService();

  final ApplianceRepository _repository;
  final WarrantyReminderScheduler _reminderScheduler;
  final CloudDocumentStorage _cloudDocumentStorage;
  final CloudDocumentSyncJournal _cloudDocumentSyncJournal;
  final DocumentStorageService _documentStorageService;
  List<Appliance> _appliances = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _loadError;
  String? _loadWarning;
  String? _ownerUid;
  Future<void>? _initialization;
  Future<void>? _refreshInProgress;
  Future<void>? _ownerBinding;
  String? _ownerBindingTarget;
  StreamSubscription<List<Appliance>>? _repositorySubscription;
  StreamSubscription<CloudSyncStatus>? _syncStatusSubscription;
  CloudSyncStatus _cloudSyncStatus = const CloudSyncStatus.unavailable();
  Future<void>? _documentSyncInProgress;
  final Map<String, Future<StoredDocument>> _documentDownloads = {};
  bool _hasPendingCloudDocumentDeletes = false;

  // Advances only after a successful local structured-data mutation.
  // Cloud-sync status changes, remote-watch refreshes, and local document-cache
  // downloads intentionally do not advance this value.
  int _dataChangeRevision = 0;

  UnmodifiableListView<Appliance> get appliances =>
      UnmodifiableListView(_appliances);

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get loadError => _loadError;
  String? get loadWarning => _loadWarning;
  String? get ownerUid => _ownerUid;
  CloudSyncStatus get cloudSyncStatus => _cloudSyncStatus;
  bool get cloudSyncAvailable =>
      _repository is CloudSyncAwareApplianceRepository;
  bool get cloudDocumentStorageAvailable => _cloudDocumentStorage.isAvailable;

  bool get hasPendingCloudDocumentWork {
    if (_hasPendingCloudDocumentDeletes) return true;

    for (final appliance in _appliances) {
      for (final document in appliance.allAttachments) {
        if (document.needsCloudUpload ||
            (!document.isAvailableOnDevice && document.isAvailableInCloud)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Monotonic revision used by automatic backup coordination.
  ///
  /// It changes only when HomeVault successfully persists a local appliance
  /// data mutation. It is deliberately separate from Firestore cloudRevision.
  int get dataChangeRevision => _dataChangeRevision;

  int get totalCount => _appliances.length;

  int get totalServiceRecordCount => _appliances.fold<int>(
    0,
    (total, appliance) => total + appliance.serviceRecordCount,
  );

  double get totalServiceCost => _appliances.fold<double>(
    0,
    (total, appliance) => total + appliance.totalServiceCost,
  );

  int upcomingServiceCount({int days = 30, DateTime? now}) {
    final referenceDate = now ?? DateTime.now();
    return _appliances.where((appliance) {
      final record = appliance.maintenanceScheduleRecord;
      if (record == null) return false;
      final remaining = record.daysUntilNextService(referenceDate);
      return remaining != null && remaining >= 0 && remaining <= days;
    }).length;
  }

  Appliance? applianceById(String applianceId) {
    for (final appliance in _appliances) {
      if (appliance.id == applianceId) {
        return appliance;
      }
    }
    return null;
  }

  Future<void> bindOwner(String? uid) {
    final normalized = uid?.trim();
    final nextOwner = normalized == null || normalized.isEmpty
        ? null
        : normalized;

    final activeBinding = _ownerBinding;
    if (activeBinding != null && _ownerBindingTarget == nextOwner) {
      return activeBinding;
    }

    Future<void> runBinding() async {
      if (activeBinding != null) {
        try {
          await activeBinding;
        } catch (_) {
          // A newer authentication state must still be allowed to bind even
          // when the previous owner transition failed.
        }
      }
      await _bindOwnerResolved(nextOwner);
    }

    final operation = runBinding();
    _ownerBinding = operation;
    _ownerBindingTarget = nextOwner;

    void clearActiveBinding() {
      if (identical(_ownerBinding, operation)) {
        _ownerBinding = null;
        _ownerBindingTarget = null;
      }
    }

    unawaited(
      operation.then<void>(
        (_) => clearActiveBinding(),
        onError: (Object _, StackTrace _) => clearActiveBinding(),
      ),
    );

    return operation;
  }

  Future<void> _bindOwnerResolved(String? nextOwner) async {
    await Future.wait([
      _cloudDocumentStorage.bindOwner(nextOwner),
      _cloudDocumentSyncJournal.bindOwner(nextOwner),
    ]);
    _hasPendingCloudDocumentDeletes =
        nextOwner != null &&
        await _cloudDocumentSyncJournal.hasPendingDeletes();

    if (_repository is! OwnerScopedApplianceRepository) {
      final ownerChanged = _ownerUid != nextOwner;

      _ownerUid = nextOwner;

      if (!_isInitialized) {
        await initialize();
      } else if (ownerChanged) {
        notifyListeners();
      }

      return;
    }

    if (_ownerUid == nextOwner && _isInitialized) return;

    await _repositorySubscription?.cancel();
    _repositorySubscription = null;
    await _syncStatusSubscription?.cancel();
    _syncStatusSubscription = null;
    _cloudSyncStatus = const CloudSyncStatus.unavailable();

    _ownerUid = nextOwner;
    _refreshInProgress = null;
    _appliances = [];
    _loadError = null;
    _loadWarning = null;
    _isInitialized = false;
    _initialization = null;

    final ownedRepository = _repository as OwnerScopedApplianceRepository;
    await ownedRepository.bindOwner(nextOwner);
    await _startSyncStatusWatch();

    if (nextOwner == null) {
      _isLoading = false;
      notifyListeners();
      await _syncRemindersSafely();
      return;
    }

    await initialize(force: true);
  }

  Future<void> initialize({bool force = false}) {
    if (_repository is OwnerScopedApplianceRepository && _ownerUid == null) {
      _isLoading = false;
      _isInitialized = false;
      notifyListeners();
      return Future.value();
    }

    if (_initialization != null) {
      return _initialization!;
    }
    if (_isInitialized && !force) {
      return Future.value();
    }

    _initialization = _load();
    return _initialization!;
  }

  /// Refreshes already loaded appliance data without putting the whole app
  /// back through the startup loading gate.
  ///
  /// Repeated pull-to-refresh gestures share the same in-flight operation so
  /// they cannot stack multiple cloud reads on top of each other.
  Future<void> refresh() {
    if (!_isInitialized) {
      return initialize(force: true);
    }

    final activeRefresh = _refreshInProgress;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final operation = _refreshLoadedData();
    _refreshInProgress = operation;

    return operation.whenComplete(() {
      if (identical(_refreshInProgress, operation)) {
        _refreshInProgress = null;
      }
    });
  }

  Future<void> _refreshLoadedData() async {
    final ownerAtStart = _ownerUid;

    try {
      final refreshed = await _repository.loadAppliances().timeout(
        const Duration(seconds: 12),
      );

      if (_ownerUid != ownerAtStart) {
        return;
      }

      _appliances = refreshed;
      _loadError = null;
      _isInitialized = true;

      if (_repository is ApplianceRepositoryDiagnostics) {
        _loadWarning =
            (_repository as ApplianceRepositoryDiagnostics).lastLoadWarning;
      }

      notifyListeners();

      // These follow-up tasks should never hold the pull-to-refresh spinner
      // open or send the app back to its startup loading screen.
      unawaited(_syncRemindersSafely());
      if (_repositorySubscription == null) {
        unawaited(_startRepositoryWatch());
      }
      unawaited(retryCloudDocumentSync());
    } on TimeoutException catch (error, stack) {
      if (_ownerUid != ownerAtStart) {
        return;
      }

      _loadError = null;
      _isInitialized = true;
      _loadWarning =
          'Refresh is taking longer than expected. '
          'Your last loaded HomeVault data is still available.';
      notifyListeners();

      unawaited(
        CrashReportingService.recordNonFatal(
          error,
          stack,
          reason: 'Refreshing appliance data timed out',
        ),
      );
    } catch (error, stack) {
      if (_ownerUid != ownerAtStart) {
        return;
      }

      _loadError = null;
      _isInitialized = true;
      _loadWarning =
          'HomeVault could not refresh right now. '
          'Your last loaded data is still available.';
      notifyListeners();

      unawaited(
        CrashReportingService.recordNonFatal(
          error,
          stack,
          reason: 'Refreshing appliance data',
        ),
      );
    }
  }

  Future<void> _load() async {
    _isLoading = true;
    _loadError = null;
    _loadWarning = null;
    notifyListeners();

    try {
      _appliances = await _repository.loadAppliances();
      if (_repository is ApplianceRepositoryDiagnostics) {
        _loadWarning =
            (_repository as ApplianceRepositoryDiagnostics).lastLoadWarning;
      }
      _isInitialized = true;
      unawaited(_syncRemindersSafely());
      await _startRepositoryWatch();
      unawaited(retryCloudDocumentSync());
    } catch (error, stack) {
      _loadError = friendlyHomeVaultError(
        error,
        fallback: 'HomeVault could not load your saved appliances. Try again.',
      );
      _isInitialized = false;
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Loading appliance data',
      );
    } finally {
      _isLoading = false;
      _initialization = null;
      notifyListeners();
    }
  }

  Future<void> _startSyncStatusWatch() async {
    if (_repository is! CloudSyncAwareApplianceRepository) {
      _cloudSyncStatus = const CloudSyncStatus.unavailable();
      return;
    }

    await _syncStatusSubscription?.cancel();

    final syncRepository = _repository as CloudSyncAwareApplianceRepository;
    _cloudSyncStatus = syncRepository.syncStatus;
    _syncStatusSubscription = syncRepository.watchSyncStatus().listen(
      (status) {
        _cloudSyncStatus = status;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        _cloudSyncStatus = CloudSyncStatus(
          state: CloudSyncState.error,
          lastSyncedAt: _cloudSyncStatus.lastSyncedAt,
          hasPendingWrites: _cloudSyncStatus.hasPendingWrites,
          message: 'Cloud sync status could not be updated.',
        );
        notifyListeners();

        unawaited(
          CrashReportingService.recordNonFatal(
            error,
            stack,
            reason: 'Listening for cloud sync status',
          ),
        );
      },
    );

    notifyListeners();
  }

  Future<bool> retryCloudSync() async {
    if (_repository is! CloudSyncAwareApplianceRepository ||
        _ownerUid == null) {
      return false;
    }

    final syncRepository = _repository as CloudSyncAwareApplianceRepository;

    try {
      await syncRepository.retrySync();
      await _startRepositoryWatch();
      await retryCloudDocumentSync();
      return syncRepository.syncStatus.state == CloudSyncState.synced ||
          syncRepository.syncStatus.state == CloudSyncState.syncing;
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Retrying cloud appliance sync',
      );
      return false;
    }
  }

  Future<void> _startRepositoryWatch() async {
    if (_repository is! WatchableApplianceRepository || _ownerUid == null) {
      return;
    }

    await _repositorySubscription?.cancel();

    final watchableRepository = _repository as WatchableApplianceRepository;
    _repositorySubscription = watchableRepository.watchAppliances().listen(
      (appliances) {
        _appliances = appliances;
        _isInitialized = true;
        _loadError = null;

        if (_repository is ApplianceRepositoryDiagnostics) {
          _loadWarning =
              (_repository as ApplianceRepositoryDiagnostics).lastLoadWarning;
        }

        notifyListeners();
        unawaited(_syncRemindersSafely());
        unawaited(retryCloudDocumentSync());
      },
      onError: (Object error, StackTrace stack) {
        _loadWarning =
            'Cloud sync is temporarily unavailable. '
            'Your last loaded data remains available.';
        notifyListeners();

        unawaited(
          CrashReportingService.recordNonFatal(
            error,
            stack,
            reason: 'Listening for cloud appliance changes',
          ),
        );
      },
    );
  }

  void clearLoadWarning() {
    if (_loadWarning == null) return;
    _loadWarning = null;
    notifyListeners();
  }

  int warrantyCount(WarrantyStatus status, {DateTime? now}) {
    final referenceDate = now ?? DateTime.now();
    return _appliances
        .where(
          (appliance) => appliance.warrantyStatusAt(referenceDate) == status,
        )
        .length;
  }

  List<Appliance> get recentAppliances {
    final sorted = [..._appliances]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(3).toList(growable: false);
  }

  Future<List<Appliance>> _persistAppliances(
    List<Appliance> appliances, {
    bool forceOverwrite = false,
    Set<String> authoritativeDeleteIds = const <String>{},
  }) async {
    if (_repository is ConflictProtectedApplianceRepository) {
      return (_repository as ConflictProtectedApplianceRepository)
          .saveAppliancesProtected(
            appliances,
            forceOverwrite: forceOverwrite,
            authoritativeDeleteIds: authoritativeDeleteIds,
          );
    }

    await _repository.saveAppliances(appliances);
    return appliances;
  }

  Future<void> retryCloudDocumentSync() {
    if (!_cloudDocumentStorage.isAvailable || _ownerUid == null) {
      return Future.value();
    }

    final existing = _documentSyncInProgress;
    if (existing != null) {
      return existing;
    }

    final operation = _synchronizeCloudDocuments();
    _documentSyncInProgress = operation;
    return operation.whenComplete(() {
      if (identical(_documentSyncInProgress, operation)) {
        _documentSyncInProgress = null;
      }
    });
  }

  Future<void> ensureCloudDocumentSyncComplete() async {
    await retryCloudDocumentSync();

    if (hasPendingCloudDocumentWork) {
      throw const CloudDocumentStorageException(
        'Some HomeVault attachments are still waiting for cloud synchronization. '
        'Keep the app online and try again shortly.',
      );
    }
  }

  Future<StoredDocument> uploadDocument(
    String applianceId,
    String documentId,
  ) async {
    if (!_cloudDocumentStorage.isAvailable) {
      throw const CloudDocumentStorageException(
        'Cloud document storage is not available in this build.',
      );
    }

    final appliance = applianceById(applianceId);
    if (appliance == null) {
      throw StateError('The appliance could not be found.');
    }

    final document = _documentById(appliance, documentId);
    if (document == null) {
      throw StateError('The document could not be found.');
    }

    if (document.isAvailableInCloud) {
      return document;
    }

    if (!document.isAvailableOnDevice) {
      throw const CloudDocumentStorageException(
        'The document file is not available on this device.',
      );
    }

    final ownerAtStart = _ownerUid;
    final uploaded = await _cloudDocumentStorage.upload(
      applianceId: applianceId,
      document: document,
    );

    if (_ownerUid != ownerAtStart) {
      throw const CloudDocumentStorageException(
        'The document upload stopped because the signed-in account changed.',
      );
    }

    // Register the new Storage object before publishing its metadata. If the
    // process stops between these two operations, the durable journal will see
    // that the path is no longer referenced after restart and safely delete it.
    try {
      await _cloudDocumentSyncJournal.rememberCloudPaths([
        uploaded.cloudStoragePath,
      ]);
    } catch (_) {
      try {
        await _cloudDocumentStorage.delete(uploaded);
      } catch (_) {
        // Preserve the journal error; an account cleanup can remove the object.
      }
      rethrow;
    }

    try {
      await update(appliance.replaceDocument(documentId, uploaded));
    } catch (_) {
      await _reconcileCloudDocumentJournalSafely(_appliances);
      unawaited(retryCloudDocumentSync());
      rethrow;
    }

    final refreshedAppliance = applianceById(applianceId);
    return refreshedAppliance == null
        ? uploaded
        : _documentById(refreshedAppliance, documentId) ?? uploaded;
  }

  Future<StoredDocument> downloadDocument(
    String applianceId,
    String documentId,
  ) {
    final ownerKey = _ownerUid ?? 'signed-out';
    final transferKey = '$ownerKey::$applianceId::$documentId';
    final activeDownload = _documentDownloads[transferKey];
    if (activeDownload != null) {
      return activeDownload;
    }

    final operation = _downloadDocumentResolved(applianceId, documentId);
    _documentDownloads[transferKey] = operation;

    return operation.whenComplete(() {
      if (identical(_documentDownloads[transferKey], operation)) {
        _documentDownloads.remove(transferKey);
      }
    });
  }

  Future<StoredDocument> _downloadDocumentResolved(
    String applianceId,
    String documentId,
  ) async {
    if (!_cloudDocumentStorage.isAvailable) {
      throw const CloudDocumentStorageException(
        'Cloud document storage is not available in this build.',
      );
    }

    final appliance = applianceById(applianceId);
    if (appliance == null) {
      throw StateError('The appliance could not be found.');
    }

    final document = _documentById(appliance, documentId);
    if (document == null) {
      throw StateError('The document could not be found.');
    }

    if (document.isAvailableOnDevice) {
      return document;
    }

    if (!document.isAvailableInCloud) {
      throw const CloudDocumentStorageException(
        'This document is not available for automatic download yet.',
      );
    }

    final ownerAtStart = _ownerUid;
    final destinationPath = await _documentStorageService
        .prepareDownloadDestination(
          applianceId: applianceId,
          document: document,
        );

    final downloaded = await _cloudDocumentStorage.download(
      document: document,
      destinationPath: destinationPath,
    );

    if (_ownerUid != ownerAtStart) {
      try {
        await _documentStorageService.deleteStoredDocument(downloaded);
      } catch (_) {
        // Account switching must not expose a downloaded file to another user.
      }
      throw const CloudDocumentStorageException(
        'The document download stopped because the signed-in account changed.',
      );
    }

    final latestAppliance = applianceById(applianceId);
    final latestDocument = latestAppliance == null
        ? null
        : _documentById(latestAppliance, documentId);

    if (latestAppliance == null ||
        latestDocument == null ||
        latestDocument.cloudStoragePath.trim() !=
            document.cloudStoragePath.trim()) {
      try {
        await _documentStorageService.deleteStoredDocument(downloaded);
      } catch (_) {
        // A newer document version remains authoritative even if cleanup fails.
      }
      throw const CloudDocumentStorageException(
        'This document changed while it was being prepared. Open it again.',
      );
    }

    final cachedDocument = latestDocument.copyWith(
      localPath: downloaded.localPath,
      sizeBytes: downloaded.sizeBytes,
    );

    // localPath is excluded from the Firestore fingerprint. Persisting this
    // cache updates only this device when the structured document metadata has
    // not changed, so automatic downloads do not create cloud revisions.
    try {
      await _persistDocumentCache(latestAppliance, documentId, cachedDocument);
    } catch (_) {
      try {
        await _documentStorageService.deleteStoredDocument(downloaded);
      } catch (_) {
        // Preserve the persistence error if temporary-cache cleanup fails.
      }
      rethrow;
    }

    final refreshedAppliance = applianceById(applianceId);
    return refreshedAppliance == null
        ? cachedDocument
        : _documentById(refreshedAppliance, documentId) ?? cachedDocument;
  }

  Future<void> _persistDocumentCache(
    Appliance appliance,
    String documentId,
    StoredDocument document,
  ) async {
    final index = _appliances.indexWhere((item) => item.id == appliance.id);
    if (index == -1) {
      throw StateError('The appliance could not be found.');
    }

    final updated = [..._appliances];
    updated[index] = appliance.replaceDocument(documentId, document);
    _appliances = await _persistAppliances(updated);
    notifyListeners();
  }

  /// Keeps attachment synchronization invisible during normal use. Local-only
  /// files are uploaded in the background and cloud-only files are cached on
  /// this device automatically after sign-in, refresh, or a remote update.
  Future<void> _synchronizeCloudDocuments() async {
    final ownerAtStart = _ownerUid;
    if (ownerAtStart == null) return;

    await _reconcileCloudDocumentJournalSafely(_appliances);
    if (_ownerUid != ownerAtStart) return;

    await _drainPendingCloudDeletes();
    if (_ownerUid != ownerAtStart) return;

    final applianceIds = _appliances
        .map((appliance) => appliance.id)
        .toList(growable: false);

    // Upload local-only files first. The local file plus its appliance metadata
    // is the durable upload queue: it survives an app restart until a cloud
    // Storage path has been written back to the appliance.
    for (final applianceId in applianceIds) {
      if (_ownerUid != ownerAtStart) return;
      final current = applianceById(applianceId);
      if (current == null) continue;

      final pendingUploadIds = current.allAttachments
          .where((document) => document.needsCloudUpload)
          .map((document) => document.id)
          .toList(growable: false);

      for (final documentId in pendingUploadIds) {
        final latest = applianceById(applianceId);
        final latestDocument = latest == null
            ? null
            : _documentById(latest, documentId);

        if (latestDocument == null || !latestDocument.needsCloudUpload) {
          continue;
        }

        try {
          await uploadDocument(applianceId, documentId);
        } catch (error, stack) {
          await CrashReportingService.recordNonFatal(
            error,
            stack,
            reason: 'Uploading a pending HomeVault cloud document',
          );
        }
      }
    }

    // Cache files that came from another signed-in device. This runs in the
    // background, so users normally open documents without seeing transfer
    // states or needing to press a download button.
    for (final applianceId in applianceIds) {
      if (_ownerUid != ownerAtStart) return;
      final current = applianceById(applianceId);
      if (current == null) continue;

      final pendingDownloadIds = current.allAttachments
          .where(
            (document) =>
                !document.isAvailableOnDevice && document.isAvailableInCloud,
          )
          .map((document) => document.id)
          .toList(growable: false);

      for (final documentId in pendingDownloadIds) {
        final latest = applianceById(applianceId);
        final latestDocument = latest == null
            ? null
            : _documentById(latest, documentId);

        if (latestDocument == null ||
            latestDocument.isAvailableOnDevice ||
            !latestDocument.isAvailableInCloud) {
          continue;
        }

        try {
          await downloadDocument(applianceId, documentId);
        } catch (error, stack) {
          await CrashReportingService.recordNonFatal(
            error,
            stack,
            reason: 'Caching a HomeVault cloud document on this device',
          );
        }
      }
    }

    // Uploads can create new cloud paths, and metadata changes during the pass
    // can make older objects stale. Reconcile once more before finishing.
    if (_ownerUid != ownerAtStart) return;
    await _reconcileCloudDocumentJournalSafely(_appliances);
    if (_ownerUid != ownerAtStart) return;
    await _drainPendingCloudDeletes();
  }

  StoredDocument? _documentById(Appliance appliance, String documentId) {
    for (final document in appliance.allAttachments) {
      if (document.id == documentId) {
        return document;
      }
    }
    return null;
  }

  Set<String> _cloudPathsFrom(Iterable<Appliance> appliances) {
    return appliances
        .expand((appliance) => appliance.allAttachments)
        .map((document) => document.cloudStoragePath.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Future<void> _rememberCloudDocumentPathsSafely(
    Iterable<Appliance> appliances,
  ) async {
    if (!_cloudDocumentStorage.isAvailable || _ownerUid == null) return;

    try {
      await _cloudDocumentSyncJournal.rememberCloudPaths(
        _cloudPathsFrom(appliances),
      );
      await _refreshPendingCloudDeleteFlag();
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Remembering HomeVault cloud document paths',
      );
    }
  }

  Future<void> _reconcileCloudDocumentJournalSafely(
    Iterable<Appliance> appliances,
  ) async {
    if (!_cloudDocumentStorage.isAvailable || _ownerUid == null) return;

    try {
      await _cloudDocumentSyncJournal.reconcileActiveCloudPaths(
        _cloudPathsFrom(appliances),
      );
      await _refreshPendingCloudDeleteFlag();
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Reconciling HomeVault cloud document cleanup state',
      );
    }
  }

  Future<void> _refreshPendingCloudDeleteFlag() async {
    final next = await _cloudDocumentSyncJournal.hasPendingDeletes();
    if (_hasPendingCloudDocumentDeletes == next) return;
    _hasPendingCloudDocumentDeletes = next;
    notifyListeners();
  }

  Future<void> _drainPendingCloudDeletes() async {
    if (!_cloudDocumentStorage.isAvailable || _ownerUid == null) return;

    final ownerAtStart = _ownerUid;
    final pendingPaths = await _cloudDocumentSyncJournal.pendingDeletePaths();
    if (_ownerUid != ownerAtStart) return;
    if (pendingPaths.isEmpty) {
      if (_hasPendingCloudDocumentDeletes) {
        _hasPendingCloudDocumentDeletes = false;
        notifyListeners();
      }
      return;
    }

    if (!_hasPendingCloudDocumentDeletes) {
      _hasPendingCloudDocumentDeletes = true;
      notifyListeners();
    }

    for (final cloudPath in pendingPaths) {
      if (_ownerUid != ownerAtStart) return;

      // A late metadata update can make a path active again. Re-check before
      // deleting so a queued cleanup can never remove a currently referenced
      // Storage object.
      if (_cloudPathsFrom(_appliances).contains(cloudPath)) {
        await _cloudDocumentSyncJournal.reconcileActiveCloudPaths(
          _cloudPathsFrom(_appliances),
        );
        continue;
      }

      try {
        await _cloudDocumentStorage
            .deletePath(cloudPath)
            .timeout(const Duration(seconds: 8));
        if (_ownerUid != ownerAtStart) return;
        await _cloudDocumentSyncJournal.completeDelete(cloudPath);
      } catch (error, stack) {
        await CrashReportingService.recordNonFatal(
          error,
          stack,
          reason: 'Retrying a queued HomeVault cloud document deletion',
        );
      }
    }

    if (_ownerUid == ownerAtStart) {
      await _refreshPendingCloudDeleteFlag();
    }
  }

  Future<void> _cleanupRemovedCloudCopiesSafely(
    Iterable<Appliance> previous,
    Iterable<Appliance> current,
  ) async {
    if (!_cloudDocumentStorage.isAvailable || _ownerUid == null) return;

    // `previous` is remembered even if this is the first run after upgrading
    // from the old direct-delete implementation. Reconciliation then turns any
    // no-longer-referenced paths into a durable pending delete.
    await _rememberCloudDocumentPathsSafely(previous);
    await _reconcileCloudDocumentJournalSafely(current);
    await _drainPendingCloudDeletes();
  }

  void _markDataChanged() {
    _dataChangeRevision++;
  }

  Future<void> add(Appliance appliance) async {
    final updated = [..._appliances, appliance];
    final persisted = await _persistAppliances(updated);
    _appliances = persisted;
    _markDataChanged();
    notifyListeners();
    await _scheduleReminderSafely(appliance);
    unawaited(retryCloudDocumentSync());
  }

  Future<void> update(Appliance appliance) async {
    final index = _appliances.indexWhere((item) => item.id == appliance.id);
    if (index == -1) {
      throw StateError('The appliance could not be found.');
    }

    final previousAppliances = [..._appliances];
    final updated = [..._appliances];
    updated[index] = appliance;

    // Persist a durable record of currently referenced cloud objects before
    // changing structured metadata. If the app stops immediately after the
    // save, Phase 2 can still identify objects that became unreferenced.
    await _rememberCloudDocumentPathsSafely(previousAppliances);

    final persisted = await _persistAppliances(updated);
    _appliances = persisted;
    _markDataChanged();
    notifyListeners();

    await _cleanupRemovedCloudCopiesSafely(previousAppliances, persisted);

    final persistedAppliance = applianceById(appliance.id) ?? appliance;
    await _scheduleReminderSafely(persistedAppliance);
    unawaited(retryCloudDocumentSync());
  }

  Future<void> rescheduleWarrantyReminders() async {
    await _syncRemindersSafely();
  }

  Future<void> addServiceRecord(
    String applianceId,
    ServiceRecord record,
  ) async {
    final appliance = applianceById(applianceId);
    if (appliance == null) {
      throw StateError('The appliance could not be found.');
    }
    await update(appliance.withServiceRecord(record));
  }

  Future<void> updateServiceRecord(
    String applianceId,
    ServiceRecord record,
  ) async {
    final appliance = applianceById(applianceId);
    if (appliance == null) {
      throw StateError('The appliance could not be found.');
    }
    await update(appliance.replaceServiceRecord(record));
  }

  Future<void> removeServiceRecord(String applianceId, String recordId) async {
    final appliance = applianceById(applianceId);
    if (appliance == null) {
      throw StateError('The appliance could not be found.');
    }
    await update(appliance.withoutServiceRecord(recordId));
  }

  Future<void> addDocument(String applianceId, StoredDocument document) async {
    final appliance = applianceById(applianceId);
    if (appliance == null) {
      throw StateError('The appliance could not be found.');
    }

    await update(appliance.withAdditionalDocument(document));
  }

  Future<void> replaceDocument(
    String applianceId,
    String documentId,
    StoredDocument replacement,
  ) async {
    final appliance = applianceById(applianceId);
    if (appliance == null) {
      throw StateError('The appliance could not be found.');
    }

    await update(appliance.replaceDocument(documentId, replacement));
  }

  Future<void> removeDocument(String applianceId, String documentId) async {
    final appliance = applianceById(applianceId);
    if (appliance == null) {
      throw StateError('The appliance could not be found.');
    }

    await update(appliance.withoutDocument(documentId));
  }

  Future<void> replaceAll(Iterable<Appliance> appliances) async {
    await _runWithRepositoryWatchPaused<void>(() async {
      final previousAppliances = [..._appliances];
      final replacement = List<Appliance>.from(appliances);

      await _rememberCloudDocumentPathsSafely(previousAppliances);

      final persisted = await _persistAppliances(
        replacement,
        forceOverwrite: true,
      );
      _appliances = persisted;
      _markDataChanged();
      notifyListeners();
      // The restored structured data is already safely persisted at this
      // point. Cloud-file cleanup and local reminder rebuilding are
      // maintenance tasks and must not keep the restore dialog spinning.
      unawaited(
        _cleanupRemovedCloudCopiesSafely(previousAppliances, persisted),
      );
      unawaited(_syncRemindersSafely());
      unawaited(retryCloudDocumentSync());
    });
  }

  Future<int> mergeAppliances(Iterable<Appliance> appliances) async {
    return _runWithRepositoryWatchPaused<int>(() async {
      final existingIds = _appliances.map((item) => item.id).toSet();
      final existingSerials = _appliances
          .map(_serialKey)
          .whereType<String>()
          .toSet();
      final imported = <Appliance>[];

      for (final appliance in appliances) {
        final serialKey = _serialKey(appliance);
        if (existingIds.contains(appliance.id) ||
            (serialKey != null && existingSerials.contains(serialKey))) {
          continue;
        }
        imported.add(appliance);
        existingIds.add(appliance.id);
        if (serialKey != null) {
          existingSerials.add(serialKey);
        }
      }

      if (imported.isEmpty) {
        return 0;
      }

      final updated = [..._appliances, ...imported];
      final persisted = await _persistAppliances(updated);
      _appliances = persisted;
      _markDataChanged();
      notifyListeners();
      // Reminder rebuilding is best-effort post-restore work. Do not block
      // merge completion if the platform notification plugin is slow.
      unawaited(_syncRemindersSafely());
      unawaited(retryCloudDocumentSync());
      return imported.length;
    });
  }

  Future<T> _runWithRepositoryWatchPaused<T>(
    Future<T> Function() operation,
  ) async {
    final shouldRestart =
        _repository is WatchableApplianceRepository && _ownerUid != null;

    if (shouldRestart) {
      final subscription = _repositorySubscription;
      _repositorySubscription = null;

      if (subscription != null) {
        try {
          await subscription.cancel().timeout(const Duration(seconds: 5));
        } catch (error, stack) {
          // A Firebase stream can occasionally take too long to tear down.
          // Restore/save operations must not remain blocked indefinitely just
          // because the live repository watcher is slow to cancel.
          unawaited(
            CrashReportingService.recordNonFatal(
              error,
              stack,
              reason: 'Pausing cloud repository watch for a data restore',
            ),
          );
        }
      }
    }

    try {
      return await operation();
    } finally {
      if (shouldRestart && _ownerUid != null) {
        // Restarting the live watcher is post-save maintenance. The restored
        // data has already been persisted, so do not keep a restore dialog
        // spinning while a Firestore listener is being re-established.
        unawaited(_restartRepositoryWatchAfterRestore());
      }
    }
  }

  Future<void> _restartRepositoryWatchAfterRestore() async {
    try {
      await _startRepositoryWatch().timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Restarting cloud repository watch after a data restore',
      );
    }
  }

  String? _serialKey(Appliance appliance) {
    final serial = appliance.serialNumber.trim().toLowerCase();
    if (serial.isEmpty) {
      return null;
    }
    return '${appliance.brand.trim().toLowerCase()}|$serial';
  }

  Future<void> delete(String applianceId) async {
    final previousAppliances = [..._appliances];
    final updated = _appliances
        .where((item) => item.id != applianceId)
        .toList(growable: false);

    if (updated.length == _appliances.length) {
      return;
    }

    await _rememberCloudDocumentPathsSafely(previousAppliances);

    // A user-confirmed delete is authoritative for this appliance only.
    // This allows Device B to delete the latest cloud revision even if Device A
    // advanced the revision through normal background synchronization after
    // Device B originally displayed the record. Other appliances retain normal
    // conflict protection.
    final persisted = await _persistAppliances(
      updated,
      authoritativeDeleteIds: {applianceId},
    );
    _appliances = persisted;
    _markDataChanged();
    notifyListeners();
    await _cleanupRemovedCloudCopiesSafely(previousAppliances, persisted);
    await _cancelReminderSafely(applianceId);
  }

  @override
  void dispose() {
    unawaited(_repositorySubscription?.cancel());
    unawaited(_syncStatusSubscription?.cancel());
    super.dispose();
  }

  Future<void> _syncRemindersSafely() async {
    try {
      await _reminderScheduler
          .syncAll(_appliances)
          .timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Synchronizing local reminders',
      );
    }
  }

  Future<void> _scheduleReminderSafely(Appliance appliance) async {
    try {
      await _reminderScheduler
          .scheduleFor(appliance)
          .timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Scheduling an appliance reminder',
      );
    }
  }

  Future<void> _cancelReminderSafely(String applianceId) async {
    try {
      await _reminderScheduler
          .cancelFor(applianceId)
          .timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Canceling an appliance reminder',
      );
    }
  }
}
