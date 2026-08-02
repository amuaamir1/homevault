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

  test('records when PIN setup is skipped', () async {
    final service = PinSecurityService();

    await service.markPinSetupSkipped();

    expect(await service.hasPin(), isFalse);
    expect(await service.hasCompletedPinSetup(), isTrue);
  });
}
