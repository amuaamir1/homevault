import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/auth/auth_controller.dart';
import 'package:homevault/auth/phone_auth_service.dart';
import 'package:homevault/models/authenticated_user.dart';

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

  test('reuses an existing Firebase session without requesting OTP', () async {
    final service = _SessionPhoneAuthService(
      const AuthenticatedUser(
        uid: 'existing-user',
        phoneNumber: '+919876543210',
      ),
    );
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.isAuthenticated, isTrue);
    expect(controller.user?.uid, 'existing-user');
    expect(controller.isAwaitingOtp, isFalse);
    expect(service.sendOtpCalls, 0);
  });

  test('rejects invalid Indian mobile numbers', () {
    expect(AuthController.normalizeIndianMobileNumber('1234567890'), isNull);
    expect(AuthController.normalizeIndianMobileNumber('98765'), isNull);
  });
}

class _SessionPhoneAuthService implements PhoneAuthService {
  _SessionPhoneAuthService(this._currentUser);

  final AuthenticatedUser _currentUser;
  int sendOtpCalls = 0;

  @override
  AuthenticatedUser? get currentUser => _currentUser;

  @override
  Stream<AuthenticatedUser?> authStateChanges() => const Stream.empty();

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required OtpCodeSentCallback onCodeSent,
    required OtpVerificationCompletedCallback onVerificationCompleted,
    required OtpVerificationFailedCallback onVerificationFailed,
    required OtpAutoRetrievalTimeoutCallback onAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    sendOtpCalls++;
  }

  @override
  Future<AuthenticatedUser> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}
