import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'homevault_error_telemetry.dart';

class CrashReportingService {
  const CrashReportingService._();

  static bool _isReady = false;

  static Future<void> initialize() async {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);

    if (!kReleaseMode) {
      await crashlytics.deleteUnsentReports();
      _isReady = false;
      return;
    }

    _isReady = true;
  }

  static void installGlobalHandlers() {
    final previousFlutterHandler = FlutterError.onError;

    FlutterError.onError = (details) {
      if (_isReady) {
        final telemetry = HomeVaultErrorTelemetry.fromError(
          details.exception,
          operation: 'uncaught flutter error',
        );
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            _SanitizedCrashException(telemetry.crashReason),
            details.stack ?? StackTrace.current,
            fatal: true,
            reason: telemetry.crashReason,
          ),
        );
      }
      previousFlutterHandler?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (!_isReady) {
        return false;
      }

      final telemetry = HomeVaultErrorTelemetry.fromError(
        error,
        operation: 'uncaught platform error',
      );
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          _SanitizedCrashException(telemetry.crashReason),
          stack,
          fatal: true,
          reason: telemetry.crashReason,
        ),
      );
      return true;
    };
  }

  static Future<void> setAuthenticatedUser(String? uid) async {
    if (!_isReady) return;

    if (uid == null || uid.trim().isEmpty) {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      return;
    }

    final anonymized = sha256
        .convert(uid.codeUnits)
        .toString()
        .substring(0, 16);
    await FirebaseCrashlytics.instance.setUserIdentifier(anonymized);
  }

  static Future<void> recordNonFatal(
    Object error,
    StackTrace stack, {
    String? operation,
    String? reason,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    if (!_isReady) return;

    final telemetry = HomeVaultErrorTelemetry.fromError(
      error,
      operation: operation ?? reason ?? 'Unspecified HomeVault operation',
      context: context,
    );

    await FirebaseCrashlytics.instance.log(telemetry.logLine);
    await FirebaseCrashlytics.instance.recordError(
      _SanitizedCrashException(telemetry.crashReason),
      stack,
      fatal: false,
      reason: telemetry.crashReason,
    );
  }
}

class _SanitizedCrashException implements Exception {
  const _SanitizedCrashException(this.code);

  final String code;

  @override
  String toString() => 'HomeVaultError($code)';
}
