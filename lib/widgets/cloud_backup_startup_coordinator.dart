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
  CloudBackupService? _service;
  String? _attemptKey;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleAutomaticBackupIfNeeded();
  }

  void _scheduleAutomaticBackupIfNeeded() {
    // Widget/unit tests build HomeVault without initializing Firebase.
    // Do not construct Firebase-backed services in that environment.
    // Production initializes Firebase before the app is mounted.
    if (_service == null && Firebase.apps.isEmpty) return;

    final uid = AuthScope.of(context).user?.uid.trim() ?? '';
    final store = AppScope.of(context);
    if (uid.isEmpty ||
        store.ownerUid != uid ||
        !store.isInitialized ||
        store.appliances.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final key = '$uid:${now.year}-${now.month}-${now.day}';
    if (_attemptKey == key) return;
    _attemptKey = key;

    unawaited(_runAutomaticBackup(uid));
  }

  Future<void> _runAutomaticBackup(String uid) async {
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
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Creating the scheduled HomeVault cloud backup',
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
