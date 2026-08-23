import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/auth/auth_controller.dart';
import 'package:homevault/auth/auth_scope.dart';
import 'package:homevault/screens/auth/sensitive_action_verification_dialog.dart';

void main() {
  String load(String path) => File(path).readAsStringSync();

  test('recent authentication is enforced for sensitive operations', () {
    final auth = load('lib/auth/auth_controller.dart');
    final localRestore = load('lib/screens/backup/backup_restore_screen.dart');
    final cloudRestore = load('lib/screens/backup/cloud_backup_screen.dart');
    final accountDeletion = load(
      'lib/screens/settings/account_deletion_screen.dart',
    );
    final security = load('lib/screens/settings/security_settings_screen.dart');

    expect(auth, contains('const Duration(minutes: 5)'));
    expect(auth, contains('bool get hasRecentSensitiveAuthentication'));
    expect(auth, contains("Verify your account again before deleting it."));
    expect(auth, contains('_clearSensitiveAuthentication();'));

    expect(localRestore, contains("title: 'Verify before replacing data'"));
    expect(localRestore, contains('verifySensitiveAction('));

    expect(cloudRestore, contains("title: 'Verify before replacing data'"));
    expect(cloudRestore, contains("title: 'Verify before deleting backup'"));

    expect(accountDeletion, contains('auth.hasRecentSensitiveAuthentication'));
    expect(
      accountDeletion,
      contains('Verify your account again to finish deleting it.'),
    );

    final remoteDelete = accountDeletion.indexOf('deleteRemoteAccountData');
    final authDelete = accountDeletion.indexOf('deleteCurrentAccount');
    final localDelete = accountDeletion.indexOf('deleteLocalAccountData');
    expect(remoteDelete, greaterThanOrEqualTo(0));
    expect(authDelete, greaterThan(remoteDelete));
    expect(localDelete, greaterThan(authDelete));

    expect(security, contains("title: 'Verify before creating a PIN'"));
    expect(security, contains("title: 'Verify before changing your PIN'"));
    expect(security, contains("title: 'Verify before enabling biometrics'"));
    expect(security, contains("title: 'Verify before extending auto-lock'"));
  });

  test('sensitive verification dialog supports account providers', () {
    final dialog = load(
      'lib/screens/auth/sensitive_action_verification_dialog.dart',
    );

    expect(dialog, contains('auth.hasRecentSensitiveAuthentication'));
    expect(dialog, contains('reauthenticateWithPassword'));
    expect(dialog, contains('reauthenticateWithGoogle'));
    expect(dialog, contains('reauthenticateWithApple'));
    expect(dialog, contains("ValueKey('sensitiveActionVerificationDialog')"));
  });

  testWidgets('recent account authentication bypasses a repeat prompt', (
    tester,
  ) async {
    final controller = AuthController.authenticatedForTesting(
      recentlyAuthenticated: true,
    );
    addTearDown(controller.dispose);
    bool? result;

    await tester.pumpWidget(
      AuthScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await verifySensitiveAction(
                    context,
                    title: 'Verify action',
                    message: 'Sensitive operation',
                  );
                },
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(result, isTrue);
    expect(
      find.byKey(const ValueKey('sensitiveActionVerificationDialog')),
      findsNothing,
    );
  });

  testWidgets('stale account authentication opens the verification dialog', (
    tester,
  ) async {
    final controller = AuthController.authenticatedForTesting();
    addTearDown(controller.dispose);
    bool? result;

    await tester.pumpWidget(
      AuthScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await verifySensitiveAction(
                    context,
                    title: 'Verify action',
                    message: 'Sensitive operation',
                  );
                },
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sensitiveActionVerificationDialog')),
      findsOneWidget,
    );
    expect(result, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('fresh-verification mode ignores an existing recent window', (
    tester,
  ) async {
    final controller = AuthController.authenticatedForTesting(
      recentlyAuthenticated: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AuthScope(
        controller: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await verifySensitiveAction(
                    context,
                    title: 'Verify action',
                    message: 'Sensitive operation',
                    requireFreshVerification: true,
                  );
                },
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sensitiveActionVerificationDialog')),
      findsOneWidget,
    );
  });
}
