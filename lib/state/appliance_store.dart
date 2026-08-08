import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/appliance.dart';
import '../models/cloud_sync_status.dart';
import '../models/service_record.dart';
import '../models/stored_document.dart';
import '../services/appliance_repository.dart';
import '../services/crash_reporting_service.dart';
import '../services/warranty_notification_service.dart';

class ApplianceStore extends ChangeNotifier {
  ApplianceStore({
    ApplianceRepository? repository,
    WarrantyReminderScheduler? reminderScheduler,
  }) : _repository = repository ?? FileApplianceRepository(),
       _reminderScheduler =
           reminderScheduler ?? const NoOpWarrantyReminderScheduler();

  final ApplianceRepository _repository;
  final WarrantyReminderScheduler _reminderScheduler;
  List<Appliance> _appliances = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _loadError;
  String? _loadWarning;
  String? _ownerUid;
  Future<void>? _initialization;
  StreamSubscription<List<Appliance>>? _repositorySubscription;
  StreamSubscription<CloudSyncStatus>? _syncStatusSubscription;
  CloudSyncStatus _cloudSyncStatus = const CloudSyncStatus.unavailable();

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
    return _appliances.expand((appliance) => appliance.serviceRecords).where((
      record,
    ) {
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

  Future<void> bindOwner(String? uid) async {
    final normalized = uid?.trim();
    final nextOwner = normalized == null || normalized.isEmpty
        ? null
        : normalized;

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
      await _syncRemindersSafely();
      await _startRepositoryWatch();
    } catch (error, stack) {
      _loadError = error.toString();
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

  Future<void> add(Appliance appliance) async {
    final updated = [..._appliances, appliance];
    await _repository.saveAppliances(updated);
    _appliances = updated;
    notifyListeners();
    await _scheduleReminderSafely(appliance);
  }

  Future<void> update(Appliance appliance) async {
    final index = _appliances.indexWhere((item) => item.id == appliance.id);
    if (index == -1) {
      throw StateError('The appliance could not be found.');
    }

    final updated = [..._appliances];
    updated[index] = appliance;
    await _repository.saveAppliances(updated);
    _appliances = updated;
    notifyListeners();
    await _scheduleReminderSafely(appliance);
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
      final replacement = List<Appliance>.from(appliances);
      await _repository.saveAppliances(replacement);
      _appliances = replacement;
      notifyListeners();
      await _syncRemindersSafely();
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
      await _repository.saveAppliances(updated);
      _appliances = updated;
      notifyListeners();
      await _syncRemindersSafely();
      return imported.length;
    });
  }

  Future<T> _runWithRepositoryWatchPaused<T>(
    Future<T> Function() operation,
  ) async {
    final shouldRestart =
        _repository is WatchableApplianceRepository && _ownerUid != null;

    if (shouldRestart) {
      await _repositorySubscription?.cancel();
      _repositorySubscription = null;
    }

    try {
      return await operation();
    } finally {
      if (shouldRestart && _ownerUid != null) {
        await _startRepositoryWatch();
      }
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
    final updated = _appliances
        .where((item) => item.id != applianceId)
        .toList(growable: false);

    if (updated.length == _appliances.length) {
      return;
    }

    await _repository.saveAppliances(updated);
    _appliances = updated;
    notifyListeners();
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
      await _reminderScheduler.syncAll(_appliances);
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
      await _reminderScheduler.scheduleFor(appliance);
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
      await _reminderScheduler.cancelFor(applianceId);
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Canceling an appliance reminder',
      );
    }
  }
}
