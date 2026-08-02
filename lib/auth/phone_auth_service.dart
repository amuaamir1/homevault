import 'package:firebase_auth/firebase_auth.dart';

import '../models/authenticated_user.dart';
import '../services/firebase_error_message.dart';

typedef OtpCodeSentCallback =
    void Function(String verificationId, int? resendToken);
typedef OtpVerificationCompletedCallback =
    void Function(AuthenticatedUser user);
typedef OtpVerificationFailedCallback = void Function(String message);
typedef OtpAutoRetrievalTimeoutCallback = void Function(String verificationId);

abstract class PhoneAuthService {
  AuthenticatedUser? get currentUser;

  Stream<AuthenticatedUser?> authStateChanges();

  Future<void> sendOtp({
    required String phoneNumber,
    required OtpCodeSentCallback onCodeSent,
    required OtpVerificationCompletedCallback onVerificationCompleted,
    required OtpVerificationFailedCallback onVerificationFailed,
    required OtpAutoRetrievalTimeoutCallback onAutoRetrievalTimeout,
    int? forceResendingToken,
  });

  Future<AuthenticatedUser> verifyOtp({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();
}

class FirebasePhoneAuthService implements PhoneAuthService {
  FirebasePhoneAuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  AuthenticatedUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthenticatedUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required OtpCodeSentCallback onCodeSent,
    required OtpVerificationCompletedCallback onVerificationCompleted,
    required OtpVerificationFailedCallback onVerificationFailed,
    required OtpAutoRetrievalTimeoutCallback onAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          final result = await _firebaseAuth.signInWithCredential(credential);
          final user = _mapUser(result.user);
          if (user == null) {
            onVerificationFailed('The verified account could not be loaded.');
            return;
          }
          onVerificationCompleted(user);
        } on FirebaseAuthException catch (error) {
          onVerificationFailed(friendlyFirebaseError(error));
        } catch (_) {
          onVerificationFailed(
            'Automatic OTP verification failed. Enter the code manually.',
          );
        }
      },
      verificationFailed: (error) {
        onVerificationFailed(friendlyFirebaseError(error));
      },
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onAutoRetrievalTimeout,
    );
  }

  @override
  Future<AuthenticatedUser> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _firebaseAuth.signInWithCredential(credential);
      final user = _mapUser(result.user);
      if (user == null) {
        throw const PhoneAuthServiceException(
          'The verified account could not be loaded.',
        );
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw PhoneAuthServiceException(friendlyFirebaseError(error));
    }
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  static AuthenticatedUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthenticatedUser(
      uid: user.uid,
      phoneNumber: user.phoneNumber ?? '',
    );
  }
}

class PhoneAuthServiceException implements Exception {
  const PhoneAuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
