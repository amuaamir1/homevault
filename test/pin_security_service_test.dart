import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/security/pin_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('creates and verifies a PIN containing 4 to 8 digits', () async {
    final service = PinSecurityService();

    expect(await service.hasPin(), isFalse);
    expect(await service.hasCompletedPinSetup(), isFalse);

    await service.createPin('1234');

    expect(await service.hasPin(), isTrue);
    expect(await service.hasCompletedPinSetup(), isTrue);
    expect(await service.verifyPin('1234'), isTrue);
    expect(await service.verifyPin('4321'), isFalse);
  });

  test('accepts an eight-digit PIN', () async {
    final service = PinSecurityService();

    await service.createPin('12345678');

    expect(await service.verifyPin('12345678'), isTrue);
  });

  test('rejects PINs shorter than four or longer than eight digits', () async {
    final service = PinSecurityService();

    expect(service.createPin('123'), throwsA(isA<FormatException>()));
    expect(service.createPin('123456789'), throwsA(isA<FormatException>()));
  });

  test('stores a different PIN for each Firebase user', () async {
    final service = PinSecurityService();

    await service.bindUser('firebase-user-a');
    await service.createPin('1234');

    await service.bindUser('firebase-user-b');
    expect(await service.hasPin(), isFalse);
    await service.createPin('5678');
    expect(await service.verifyPin('5678'), isTrue);
    expect(await service.verifyPin('1234'), isFalse);

    await service.bindUser('firebase-user-a');
    expect(await service.verifyPin('1234'), isTrue);
    expect(await service.verifyPin('5678'), isFalse);
  });

  test('keeps the PIN for the same user after sign out and relogin', () async {
    final firstSession = PinSecurityService();

    await firstSession.bindUser('firebase-user-a');
    await firstSession.createPin('2468');

    final reloginSession = PinSecurityService();
    await reloginSession.bindUser('firebase-user-a');

    expect(await reloginSession.hasPin(), isTrue);
    expect(await reloginSession.verifyPin('2468'), isTrue);
  });

  test('records when PIN setup is skipped', () async {
    final service = PinSecurityService();

    await service.markPinSetupSkipped();

    expect(await service.hasPin(), isFalse);
    expect(await service.hasCompletedPinSetup(), isTrue);
  });
  test(
    'PIN data can be cleared completely when an account is deleted',
    () async {
      final service = PinSecurityService();
      await service.bindUser('firebase-user-a');
      await service.createPin('2468');

      await service.clearPin(markSetupComplete: false, clearHistory: true);

      expect(await service.hasPin(), isFalse);
      expect(await service.hasCompletedPinSetup(), isFalse);
    },
  );

  test('rejects reuse of any of the last four PINs', () async {
    final service = PinSecurityService();
    await service.bindUser('firebase-user-history');

    await service.createPin('1111');
    expect(await service.changePin(currentPin: '1111', newPin: '2222'), isTrue);
    expect(await service.changePin(currentPin: '2222', newPin: '3333'), isTrue);
    expect(await service.changePin(currentPin: '3333', newPin: '4444'), isTrue);

    expect(
      service.changePin(currentPin: '4444', newPin: '1111'),
      throwsA(isA<PinReuseException>()),
    );
    expect(
      service.changePin(currentPin: '4444', newPin: '2222'),
      throwsA(isA<PinReuseException>()),
    );
    expect(
      service.changePin(currentPin: '4444', newPin: '4444'),
      throwsA(isA<PinReuseException>()),
    );
  });

  test('allows a PIN again after it falls outside the last four', () async {
    final service = PinSecurityService();
    await service.bindUser('firebase-user-rotation');

    await service.createPin('1111');
    await service.changePin(currentPin: '1111', newPin: '2222');
    await service.changePin(currentPin: '2222', newPin: '3333');
    await service.changePin(currentPin: '3333', newPin: '4444');
    await service.changePin(currentPin: '4444', newPin: '5555');

    expect(await service.changePin(currentPin: '5555', newPin: '1111'), isTrue);
    expect(await service.verifyPin('1111'), isTrue);
  });

  test('forgot PIN reset preserves PIN history', () async {
    final service = PinSecurityService();
    await service.bindUser('firebase-user-recovery');
    await service.createPin('2468');

    await service.clearPin(markSetupComplete: false);

    expect(await service.hasPin(), isFalse);
    expect(service.createPin('2468'), throwsA(isA<PinReuseException>()));
    await service.createPin('1357');
    expect(await service.verifyPin('1357'), isTrue);
  });

  test('account deletion removes PIN history', () async {
    final service = PinSecurityService();
    await service.bindUser('firebase-user-delete-history');
    await service.createPin('2468');

    await service.clearPin(markSetupComplete: false, clearHistory: true);

    await service.createPin('2468');
    expect(await service.verifyPin('2468'), isTrue);
  });

  test('PIN history remains scoped to the Firebase user', () async {
    final service = PinSecurityService();

    await service.bindUser('firebase-user-history-a');
    await service.createPin('1122');
    await service.clearPin(markSetupComplete: false);

    await service.bindUser('firebase-user-history-b');
    await service.createPin('1122');
    expect(await service.verifyPin('1122'), isTrue);

    await service.bindUser('firebase-user-history-a');
    expect(service.createPin('1122'), throwsA(isA<PinReuseException>()));
  });

  test('locks PIN entry after five failed attempts', () async {
    var now = DateTime(2026, 8, 23, 12);
    final service = PinSecurityService(now: () => now);
    await service.bindUser('firebase-user-lockout');
    await service.createPin('2468');

    for (var attempt = 1; attempt <= 4; attempt++) {
      final result = await service.verifyPinWithProtection('1357');
      expect(result.isValid, isFalse);
      expect(result.status.failedAttempts, attempt);
      expect(result.status.lockedUntil, isNull);
    }

    final fifth = await service.verifyPinWithProtection('1357');
    expect(fifth.isValid, isFalse);
    expect(fifth.status.failedAttempts, 5);
    expect(fifth.status.isLockedAt(now), isTrue);
    expect(fifth.status.secondsRemainingAt(now), 30);

    final blockedCorrectPin = await service.verifyPinWithProtection('2468');
    expect(blockedCorrectPin.isValid, isFalse);
    expect(blockedCorrectPin.wasLockedBeforeAttempt, isTrue);
    expect(blockedCorrectPin.status.failedAttempts, 5);
  });

  test('PIN lockout survives service recreation and expires safely', () async {
    var now = DateTime(2026, 8, 23, 12);
    final firstSession = PinSecurityService(now: () => now);
    await firstSession.bindUser('firebase-user-persistent-lock');
    await firstSession.createPin('2468');

    for (var attempt = 0; attempt < 5; attempt++) {
      await firstSession.verifyPinWithProtection('1357');
    }

    final restartedSession = PinSecurityService(now: () => now);
    await restartedSession.bindUser('firebase-user-persistent-lock');

    var status = await restartedSession.getAttemptStatus();
    expect(status.failedAttempts, 5);
    expect(status.isLockedAt(now), isTrue);

    now = now.add(const Duration(seconds: 31));
    status = await restartedSession.getAttemptStatus();
    expect(status.failedAttempts, 5);
    expect(status.lockedUntil, isNull);

    final success = await restartedSession.verifyPinWithProtection('2468');
    expect(success.isValid, isTrue);
    expect((await restartedSession.getAttemptStatus()).failedAttempts, 0);
  });

  test('successful PIN clears failed-attempt state', () async {
    final service = PinSecurityService();
    await service.bindUser('firebase-user-attempt-reset');
    await service.createPin('2468');

    await service.verifyPinWithProtection('1357');
    await service.verifyPinWithProtection('1357');
    expect((await service.getAttemptStatus()).failedAttempts, 2);

    final success = await service.verifyPinWithProtection('2468');
    expect(success.isValid, isTrue);
    expect((await service.getAttemptStatus()).failedAttempts, 0);
  });

  test('failed PIN attempts remain scoped to each Firebase user', () async {
    final service = PinSecurityService();

    await service.bindUser('firebase-user-attempt-a');
    await service.createPin('2468');
    await service.verifyPinWithProtection('1357');
    await service.verifyPinWithProtection('1357');
    expect((await service.getAttemptStatus()).failedAttempts, 2);

    await service.bindUser('firebase-user-attempt-b');
    await service.createPin('8642');
    expect((await service.getAttemptStatus()).failedAttempts, 0);

    await service.bindUser('firebase-user-attempt-a');
    expect((await service.getAttemptStatus()).failedAttempts, 2);
  });

  test('repeated attack waves increase the PIN lockout duration', () async {
    var now = DateTime(2026, 8, 23, 12);
    final service = PinSecurityService(now: () => now);
    await service.bindUser('firebase-user-progressive-lock');
    await service.createPin('2468');

    for (var attempt = 0; attempt < 5; attempt++) {
      await service.verifyPinWithProtection('1357');
    }
    var status = await service.getAttemptStatus();
    expect(status.lockedUntil, now.add(const Duration(seconds: 30)));

    now = now.add(const Duration(seconds: 31));
    for (var attempt = 0; attempt < 5; attempt++) {
      await service.verifyPinWithProtection('1357');
    }
    status = await service.getAttemptStatus();
    expect(status.failedAttempts, 10);
    expect(status.lockedUntil, now.add(const Duration(minutes: 2)));
  });

  test(
    'account recovery clears PIN attack state but keeps PIN history',
    () async {
      final service = PinSecurityService();
      await service.bindUser('firebase-user-lock-recovery');
      await service.createPin('2468');

      for (var attempt = 0; attempt < 5; attempt++) {
        await service.verifyPinWithProtection('1357');
      }
      expect((await service.getAttemptStatus()).lockedUntil, isNotNull);

      await service.clearPin(markSetupComplete: false);

      expect((await service.getAttemptStatus()).failedAttempts, 0);
      expect(service.createPin('2468'), throwsA(isA<PinReuseException>()));
    },
  );
}
