import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_controller.dart';
import 'firebase_options.dart';
import 'profile/profile_controller.dart';
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

    authController = AuthController();
    profileController = ProfileController();
  } catch (error) {
    firebaseInitializationError = error;
  }

  final notificationService = WarrantyNotificationService.instance;

  try {
    await notificationService.initialize();
  } catch (_) {
    // HomeVault can still open if local notification initialization
    // is unavailable on a particular device.
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
