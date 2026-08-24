import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/auth/auth_controller.dart';
import 'package:homevault/auth/auth_scope.dart';
import 'package:homevault/screens/settings/account_data_screen.dart';
import 'package:homevault/security/app_lock_controller.dart';
import 'package:homevault/security/app_lock_scope.dart';
import 'package:homevault/state/app_scope.dart';
import 'package:homevault/state/appliance_store.dart';

void main() {
  testWidgets('Account & Data groups data security and lifecycle actions', (
    tester,
  ) async {
    final auth = AuthController.authenticatedForTesting(
      uid: 'account-data-user',
      email: 'owner@example.com',
    );
    final lock = AppLockController.unlockedForTesting(uid: 'account-data-user');
    final store = ApplianceStore();

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: AppLockScope(
          controller: lock,
          child: AppScope(
            applianceStore: store,
            child: const MaterialApp(home: AccountDataScreen()),
          ),
        ),
      ),
    );

    expect(find.text('Account & Data'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Your HomeVault data'), findsOneWidget);
    expect(find.text('Appliances'), findsOneWidget);
    expect(find.text('Documents & photos'), findsOneWidget);

    // Profile remains only in the parent Settings screen.
    expect(find.text('Profile & service address'), findsNothing);

    // Authentication/security status details remain intentionally omitted.
    expect(find.text('Sign-in methods'), findsNothing);
    expect(find.textContaining('PIN protection'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('accountDataBackupTile')),
      250,
    );
    expect(find.text('Backup, restore & export'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('accountDataDeviceStorageTile')),
      250,
    );
    expect(find.text('Device storage & cleanup'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('accountDataSecurityTile')),
      250,
    );
    expect(find.text('Security'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('accountDataDeleteAccountTile')),
      250,
    );
    expect(
      find.byKey(const ValueKey('accountDataSignOutTile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('accountDataDeleteAccountTile')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    lock.dispose();
    store.dispose();
  });
}
