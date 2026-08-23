import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String normalizeLf(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

void main() {
  group('HomeVault account sign-in PIN race contract', () {
    late String auth;
    late String lock;
    late String app;

    setUpAll(() {
      auth = normalizeLf(
        File('lib/auth/auth_controller.dart').readAsStringSync(),
      );
      lock = normalizeLf(
        File('lib/security/app_lock_controller.dart').readAsStringSync(),
      );
      app = normalizeLf(File('lib/app.dart').readAsStringSync());
    });

    test(
      'email sign-in arms session unlock before Firebase authentication',
      () {
        final method = auth.indexOf('Future<bool> signInWithEmailAndPassword');
        final arm = auth.indexOf('_unlockAfterAccountSignIn = true;', method);
        final serviceCall = auth.indexOf(
          '_service!.signInWithEmailAndPassword(',
          method,
        );

        expect(method, greaterThanOrEqualTo(0));
        expect(arm, greaterThan(method));
        expect(serviceCall, greaterThan(arm));
      },
    );

    test('Google and Apple also arm before provider authentication', () {
      for (final methodAndCall in <String, String>{
        'Future<bool> signInWithGoogle': '_service!.signInWithGoogle()',
        'Future<bool> signInWithApple': '_service!.signInWithApple()',
      }.entries) {
        final method = auth.indexOf(methodAndCall.key);
        final arm = auth.indexOf('_unlockAfterAccountSignIn = true;', method);
        final serviceCall = auth.indexOf(methodAndCall.value, method);

        expect(method, greaterThanOrEqualTo(0));
        expect(arm, greaterThan(method));
        expect(serviceCall, greaterThan(arm));
      }
    });

    test('failed explicit sign-in clears the pre-armed unlock', () {
      expect(
        RegExp(
          r'catch\s*\(_\)\s*\{\s*'
          r'_unlockAfterAccountSignIn\s*=\s*false;\s*'
          r'rethrow;',
          multiLine: true,
        ).allMatches(auth).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('signed-out auth-state also clears any stale unlock', () {
      expect(
        RegExp(
          r'if\s*\(user\s*==\s*null\)\s*\{\s*'
          r'_unlockAfterAccountSignIn\s*=\s*false;',
          multiLine: true,
        ).hasMatch(auth),
        isTrue,
      );
    });

    test('same-UID bind honors a legitimate late account-auth unlock', () {
      expect(
        RegExp(
          r'if\s*\(uid\s*==\s*_boundUid\s*&&\s*!_isInitializing\)\s*\{'
          r'.*?if\s*\(unlockAfterAccountAuthentication\)\s*\{'
          r'.*?await\s+this\.unlockAfterAccountAuthentication\(\);'
          r'.*?\}\s*return;\s*\}',
          multiLine: true,
          dotAll: true,
        ).hasMatch(lock),
        isTrue,
      );
    });

    test('normal/future bind still defaults to PIN locked', () {
      expect(lock, contains('bool unlockAfterAccountAuthentication = false'));
      expect(
        lock,
        contains('_isUnlocked = !_hasPin || unlockAfterAccountAuthentication;'),
      );
      expect(app, contains('return const PinLoginScreen();'));
    });

    test('old post-bind app unlock path remains absent', () {
      expect(
        app,
        isNot(
          contains(
            'await _appLockController.unlockAfterAccountAuthentication();',
          ),
        ),
      );
    });
  });
}
