import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReportingService {
  const CrashReportingService._();

  static bool _isReady = false;

  static Future<void> initialize() async {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    _isReady = true;
  }

  static void installGlobalHandlers() {
    final previousFlutterHandler = FlutterError.onError;

    FlutterError.onError = (details) {
      if (_isReady) {
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      }
      previousFlutterHandler?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_isReady) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
        );
      }
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
    String? reason,
  }) async {
    if (!_isReady) return;

    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: false,
      reason: reason,
    );
  }

  static Future<void> log(String message) async {
    if (!_isReady) return;
    await FirebaseCrashlytics.instance.log(message);
  }
}
