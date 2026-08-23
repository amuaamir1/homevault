import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeVault explicit sign-in / future PIN contract', () {
    late String app;
    late String lock;

    setUpAll(() {
      app = File('lib/app.dart').readAsStringSync();
      lock = File('lib/security/app_lock_controller.dart').readAsStringSync();
    });

    test(
      'explicit account authentication is consumed before signed-in bind',
      () {
        final consumeMatch = RegExp(
          r'final\s+unlockAfterAccountAuthentication\s*=\s*'
          r'auth\.consumeAccountSignInUnlock\(\);',
          multiLine: true,
        ).firstMatch(app);

        final signedInBindMatch = RegExp(
          r'_appLockController\.bindUser\(\s*'
          r'user\.uid,\s*'
          r'unlockAfterAccountAuthentication:\s*'
          r'unlockAfterAccountAuthentication,\s*'
          r'\)',
          multiLine: true,
        ).firstMatch(app);

        expect(consumeMatch, isNotNull);
        expect(signedInBindMatch, isNotNull);
        expect(signedInBindMatch!.start, greaterThan(consumeMatch!.start));
      },
    );

    test(
      'one-shot account-auth state is passed into signed-in lock binding',
      () {
        expect(
          RegExp(
            r'_appLockController\.bindUser\(\s*'
            r'user\.uid,\s*'
            r'unlockAfterAccountAuthentication:\s*'
            r'unlockAfterAccountAuthentication,\s*'
            r'\)',
            multiLine: true,
          ).hasMatch(app),
          isTrue,
        );
      },
    );

    test('old post-bind PIN flash call is removed', () {
      expect(
        app,
        isNot(
          contains(
            'await _appLockController.unlockAfterAccountAuthentication();',
          ),
        ),
      );
    });

    test('future cached-session launches remain PIN locked by default', () {
      expect(lock, contains('bool unlockAfterAccountAuthentication = false'));
      expect(app, contains('return const PinLoginScreen();'));
    });

    test('explicit account authentication clears PIN attack state in bind', () {
      expect(
        lock,
        contains('if (unlockAfterAccountAuthentication && _hasPin) {'),
      );
      expect(lock, contains('await _securityService.clearFailedAttempts();'));
      expect(lock, contains('_pinAttemptStatus = const PinAttemptStatus();'));
    });

    test('final lock state is published atomically', () {
      expect(
        lock,
        contains('_isUnlocked = !_hasPin || unlockAfterAccountAuthentication;'),
      );
    });

    test('existing compatibility API remains available', () {
      expect(
        lock,
        contains('Future<void> unlockAfterAccountAuthentication() async'),
      );
      expect(
        lock,
        contains('Future app launches still require the PIN or biometrics.'),
      );
    });
  });
}
