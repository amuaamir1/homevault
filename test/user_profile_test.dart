import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/user_profile.dart';

void main() {
  test('extracts first name for the dashboard welcome message', () {
    const profile = UserProfile(
      uid: 'user-1',
      fullName: 'Aamir Khan',
      phoneNumber: '+919876543210',
      addressLine1: '12 Main Road',
      state: 'Maharashtra',
      city: 'Mumbai',
      pinCode: '400001',
    );

    expect(profile.firstName, 'Aamir');
    expect(profile.isComplete, isTrue);
  });

  test('requires a valid six-digit Indian PIN code', () {
    expect(UserProfile.isValidIndianPinCode('110001'), isTrue);
    expect(UserProfile.isValidIndianPinCode('012345'), isFalse);
    expect(UserProfile.isValidIndianPinCode('12345'), isFalse);
  });
}
