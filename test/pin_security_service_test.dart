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
}
