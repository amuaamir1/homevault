import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_controller.dart';
import 'firebase_options.dart';
import 'profile/profile_controller.dart';
import 'services/crash_reporting_service.dart';
import 'services/warranty_notification_service.dart';
import 'state/appliance_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseInitializationError;
  AuthController? authController;
  ProfileController? profileController;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await CrashReportingService.initialize();
    CrashReportingService.installGlobalHandlers();

    authController = AuthController();
    profileController = ProfileController();
  } catch (error, stack) {
    firebaseInitializationError = error;
    await CrashReportingService.recordNonFatal(
      error,
      stack,
      reason: 'Initializing Firebase',
    );
  }

  final notificationService = WarrantyNotificationService.instance;

  try {
    await notificationService.initialize();
  } catch (error, stack) {
    await CrashReportingService.recordNonFatal(
      error,
      stack,
      reason: 'Initializing local notifications',
    );
  }

  runApp(
    HomeVaultApp(
      applianceStore: ApplianceStore(reminderScheduler: notificationService),
      authController: authController,
      profileController: profileController,
      firebaseInitializationError: firebaseInitializationError,
    ),
  );
}
