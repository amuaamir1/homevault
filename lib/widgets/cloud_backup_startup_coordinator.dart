import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../models/backup_models.dart';
import '../services/cloud_backup_service.dart';
import '../services/crash_reporting_service.dart';
import '../state/app_scope.dart';

class CloudBackupStartupCoordinator extends StatefulWidget {
  const CloudBackupStartupCoordinator({
    super.key,
    required this.child,
    this.service,
  });

  final Widget child;
  final CloudBackupService? service;

  @override
  State<CloudBackupStartupCoordinator> createState() =>
      _CloudBackupStartupCoordinatorState();
}

class _CloudBackupStartupCoordinatorState
    extends State<CloudBackupStartupCoordinator> {
  static const Duration _dataChangeDebounce = Duration(seconds: 5);

  CloudBackupService? _service;
  String? _attemptKey;
  String? _activeUid;

  int _observedDataRevision = 0;
  int _lastBackedUpDataRevision = 0;
  int _pendingDataRevision = 0;

  Timer? _dataChangeTimer;
  bool _dataBackupInProgress = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Widget/unit tests build HomeVault without initializing Firebase.
    if (_service == null && Firebase.apps.isEmpty) return;

    final uid = AuthScope.of(context).user?.uid.trim() ?? '';
    final store = AppScope.of(context);

    if (uid.isEmpty || store.ownerUid != uid || !store.isInitialized) {
      _resetObservedAccount();
      return;
    }

    if (_activeUid != uid) {
      _activeUid = uid;
      _observedDataRevision = store.dataChangeRevision;
      _lastBackedUpDataRevision = store.dataChangeRevision;
      _pendingDataRevision = 0;
      _dataChangeTimer?.cancel();
      _dataChangeTimer = null;
    } else if (store.dataChangeRevision > _observedDataRevision) {
      _observedDataRevision = store.dataChangeRevision;
      _pendingDataRevision = store.dataChangeRevision;

      if (store.appliances.isNotEmpty) {
        _queueDataChangeBackup();
      }
    }

    if (store.appliances.isNotEmpty) {
      _scheduleDailyAutomaticBackupIfNeeded(uid);
    }
  }

  void _resetObservedAccount() {
    _activeUid = null;
    _observedDataRevision = 0;
    _lastBackedUpDataRevision = 0;
    _pendingDataRevision = 0;
    _attemptKey = null;
    _dataChangeTimer?.cancel();
    _dataChangeTimer = null;
  }

  void _scheduleDailyAutomaticBackupIfNeeded(String uid) {
    final now = DateTime.now();
    final key = '$uid:${now.year}-${now.month}-${now.day}';
    if (_attemptKey == key) return;
    _attemptKey = key;

    unawaited(_runDailyAutomaticBackup(uid));
  }

  void _queueDataChangeBackup() {
    _dataChangeTimer?.cancel();
    _dataChangeTimer = Timer(_dataChangeDebounce, () {
      _dataChangeTimer = null;
      unawaited(_runDataChangeBackup());
    });
  }

  Future<void> _runDailyAutomaticBackup(String uid) async {
    try {
      final store = AppScope.read(context);
      await store.retryCloudDocumentSync().timeout(const Duration(minutes: 2));
      if (!mounted || AuthScope.read(context).user?.uid != uid) return;

      final service = _service ??= CloudBackupService();
      final needed = await service.needsAutomaticBackup(uid);
      if (!needed || !mounted) return;

      final latestStore = AppScope.read(context);
      if (latestStore.ownerUid != uid || latestStore.appliances.isEmpty) return;

      await service.createBackup(
        uid: uid,
        appliances: latestStore.appliances,
        source: CloudBackupSource.automatic,
      );

      _lastBackedUpDataRevision = latestStore.dataChangeRevision;
      if (_pendingDataRevision <= _lastBackedUpDataRevision) {
        _pendingDataRevision = 0;
      }
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Creating the scheduled HomeVault cloud backup',
      );
    }
  }

  Future<void> _runDataChangeBackup() async {
    if (_dataBackupInProgress || !mounted) return;

    final uid = _activeUid;
    if (uid == null || uid.isEmpty) return;

    final requestedRevision = _pendingDataRevision;
    if (requestedRevision <= _lastBackedUpDataRevision) return;

    _dataBackupInProgress = true;

    try {
      final store = AppScope.read(context);
      if (store.ownerUid != uid || store.appliances.isEmpty) return;

      // Let pending invoice/photo/warranty/service attachments reach cloud
      // storage before building the full backup ZIP.
      await store.retryCloudDocumentSync().timeout(const Duration(minutes: 2));

      if (!mounted || AuthScope.read(context).user?.uid != uid) return;

      final latestStore = AppScope.read(context);
      if (latestStore.ownerUid != uid || latestStore.appliances.isEmpty) return;

      final revisionBeingBackedUp = latestStore.dataChangeRevision;
      if (revisionBeingBackedUp <= _lastBackedUpDataRevision) return;

      final service = _service ??= CloudBackupService();
      await service.createBackup(
        uid: uid,
        appliances: latestStore.appliances,
        source: CloudBackupSource.automatic,
      );

      _lastBackedUpDataRevision = revisionBeingBackedUp;
      if (_pendingDataRevision <= revisionBeingBackedUp) {
        _pendingDataRevision = 0;
      }
    } catch (error, stack) {
      // Do not show normal users a backup error for an automatic background
      // attempt. A new data change or the daily fallback will try again.
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Creating a HomeVault cloud backup after saved data changed',
      );

      // Avoid an immediate retry loop when the same revision cannot be backed
      // up (for example because an attachment is temporarily unavailable).
      if (_pendingDataRevision <= requestedRevision) {
        _pendingDataRevision = 0;
      }
    } finally {
      _dataBackupInProgress = false;

      // If another saved change arrived while this backup was running, queue a
      // fresh backup. Successful backup may already include it, in which case
      // the revision comparison prevents a duplicate snapshot.
      if (mounted &&
          _pendingDataRevision > _lastBackedUpDataRevision &&
          _activeUid == uid) {
        _queueDataChangeBackup();
      }
    }
  }

  @override
  void dispose() {
    _dataChangeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
