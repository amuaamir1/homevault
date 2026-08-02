import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/security/pin_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Must be a new mutable map for every test.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('creates and verifies a six-digit PIN', () async {
    final service = PinSecurityService();

    expect(await service.hasPin(), isFalse);

    await service.createPin('123456');

    expect(await service.hasPin(), isTrue);
    expect(await service.verifyPin('123456'), isTrue);
    expect(await service.verifyPin('654321'), isFalse);
  });

  test('rejects a PIN that is not six digits', () async {
    final service = PinSecurityService();

    expect(service.createPin('12345'), throwsA(isA<FormatException>()));
  });
}
