import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/auth/auth_controller.dart';

void main() {
  test('normalizes Indian mobile numbers to E.164 format', () {
    expect(
      AuthController.normalizeIndianMobileNumber('9876543210'),
      '+919876543210',
    );
    expect(
      AuthController.normalizeIndianMobileNumber('+91 98765 43210'),
      '+919876543210',
    );
  });

  test('rejects invalid Indian mobile numbers', () {
    expect(AuthController.normalizeIndianMobileNumber('1234567890'), isNull);
    expect(AuthController.normalizeIndianMobileNumber('98765'), isNull);
  });
}
