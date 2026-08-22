import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_controller.dart';
import 'firebase_options.dart';
import 'profile/profile_controller.dart';
import 'services/appliance_repository.dart';
import 'services/cloud_document_storage_service.dart';
import 'services/cloud_document_sync_journal.dart';
import 'services/crash_reporting_service.dart';
import 'services/firestore_appliance_repository.dart';
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

  final applianceStore = firebaseInitializationError == null
      ? ApplianceStore(
          repository: FirestoreApplianceRepository(
            localRepository: FileApplianceRepository(),
          ),
          reminderScheduler: notificationService,
          cloudDocumentStorage: FirebaseCloudDocumentStorage(),
          cloudDocumentSyncJournal: FileCloudDocumentSyncJournal(),
        )
      : ApplianceStore(reminderScheduler: notificationService);

  runApp(
    HomeVaultApp(
      applianceStore: applianceStore,
      authController: authController,
      profileController: profileController,
      firebaseInitializationError: firebaseInitializationError,
    ),
  );
}
