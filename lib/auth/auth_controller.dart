import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/authenticated_user.dart';
import '../services/crash_reporting_service.dart';
import '../services/firebase_error_message.dart';
import 'phone_auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({PhoneAuthService? service})
    : _service = service ?? FirebasePhoneAuthService();

  AuthController.authenticatedForTesting({
    String uid = 'test-user',
    String phoneNumber = '+919876543210',
  }) : _service = null,
       _isInitializing = false,
       _user = AuthenticatedUser(uid: uid, phoneNumber: phoneNumber),
       _isTestController = true;

  final PhoneAuthService? _service;
  StreamSubscription<AuthenticatedUser?>? _authSubscription;

  bool _isInitializing = true;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isTestController = false;
  AuthenticatedUser? _user;
  String? _verificationId;
  String? _pendingPhoneNumber;
  int? _resendToken;
  String? _errorMessage;

  bool get isInitializing => _isInitializing;
  bool get isSendingOtp => _isSendingOtp;
  bool get isVerifyingOtp => _isVerifyingOtp;
  bool get isAuthenticated => _user != null;
  bool get isAwaitingOtp =>
      !isAuthenticated && _verificationId?.isNotEmpty == true;
  AuthenticatedUser? get user => _user;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_isTestController) return;

    final service = _service!;
    _user = service.currentUser;
    _authSubscription = service.authStateChanges().listen((user) {
      _user = user;
      if (user != null) {
        _clearOtpState();
      }
      notifyListeners();
    });
    _isInitializing = false;
    notifyListeners();
  }

  Future<bool> sendOtp(String mobileNumber, {bool resend = false}) async {
    if (_isSendingOtp) return false;

    final phoneNumber = normalizeIndianMobileNumber(mobileNumber);
    if (phoneNumber == null) {
      _errorMessage = 'Enter a valid 10-digit Indian mobile number.';
      notifyListeners();
      return false;
    }

    _isSendingOtp = true;
    _errorMessage = null;
    _pendingPhoneNumber = phoneNumber;
    if (!resend) {
      _verificationId = null;
    }
    notifyListeners();

    try {
      await _service!.sendOtp(
        phoneNumber: phoneNumber,
        forceResendingToken: resend ? _resendToken : null,
        onCodeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isSendingOtp = false;
          _errorMessage = null;
          notifyListeners();
        },
        onVerificationCompleted: (user) {
          _user = user;
          _isSendingOtp = false;
          _isVerifyingOtp = false;
          _clearOtpState();
          notifyListeners();
        },
        onVerificationFailed: (message) {
          _isSendingOtp = false;
          _isVerifyingOtp = false;
          _errorMessage = message;
          notifyListeners();
        },
        onAutoRetrievalTimeout: (verificationId) {
          _verificationId ??= verificationId;
          _isSendingOtp = false;
          notifyListeners();
        },
      );
      return true;
    } catch (error, stack) {
      _isSendingOtp = false;
      _errorMessage = _friendlyError(error);
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Sending phone OTP',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      _errorMessage = 'Request a new OTP before continuing.';
      notifyListeners();
      return false;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp.trim())) {
      _errorMessage = 'Enter the 6-digit OTP from the SMS.';
      notifyListeners();
      return false;
    }

    _isVerifyingOtp = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _service!.verifyOtp(
        verificationId: verificationId,
        smsCode: otp.trim(),
      );
      _isVerifyingOtp = false;
      _clearOtpState();
      notifyListeners();
      return true;
    } catch (error, stack) {
      _isVerifyingOtp = false;
      _errorMessage = _friendlyError(error);
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Verifying phone OTP',
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _errorMessage = null;
    await _service?.signOut();
    _user = null;
    _clearOtpState();
    notifyListeners();
  }

  void editPhoneNumber() {
    _verificationId = null;
    _pendingPhoneNumber = null;
    _errorMessage = null;
    _isSendingOtp = false;
    _isVerifyingOtp = false;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearOtpState() {
    _verificationId = null;
    _pendingPhoneNumber = null;
    _resendToken = null;
  }

  String _friendlyError(Object error) {
    if (error is PhoneAuthServiceException) return error.message;
    return friendlyFirebaseError(
      error,
      fallback: 'Phone verification failed. Please try again.',
    );
  }

  static String? normalizeIndianMobileNumber(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(digits)) {
      return null;
    }
    return '+91$digits';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
