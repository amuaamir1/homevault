import 'package:flutter/material.dart';

import 'app.dart';
import 'services/warranty_notification_service.dart';
import 'state/appliance_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = WarrantyNotificationService.instance;
  try {
    await notificationService.initialize();
  } catch (_) {
    // HomeVault remains usable even when notification setup is unavailable.
  }

  runApp(
    HomeVaultApp(
      applianceStore: ApplianceStore(reminderScheduler: notificationService),
    ),
  );
}
