import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/authenticated_user.dart';
import '../services/crash_reporting_service.dart';
import '../services/firebase_error_message.dart';
import 'email_auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({EmailAuthService? service})
    : _service = service ?? FirebaseEmailAuthService();

  AuthController.authenticatedForTesting({
    String uid = 'test-user',
    String email = 'test@example.com',
    bool isEmailVerified = true,
    String phoneNumber = '+919876543210',
  }) : _service = null,
       _isInitializing = false,
       _user = AuthenticatedUser(
         uid: uid,
         email: email,
         isEmailVerified: isEmailVerified,
         phoneNumber: phoneNumber,
       ),
       _isTestController = true;

  final EmailAuthService? _service;
  StreamSubscription<AuthenticatedUser?>? _authSubscription;
  Future<bool>? _sessionValidationFuture;

  bool _isInitializing = true;
  bool _isBusy = false;
  bool _isValidatingSession = false;
  bool _unlockAfterAccountSignIn = false;
  bool _isTestController = false;
  AuthenticatedUser? _user;
  String? _errorMessage;
  String? _statusMessage;

  bool get isInitializing => _isInitializing;
  bool get isBusy => _isBusy;
  bool get isValidatingSession => _isValidatingSession;
  bool get isAuthenticated => _user != null;
  bool get isEmailVerified => _user?.isEmailVerified == true;
  bool get needsLegacyEmailUpgrade =>
      isAuthenticated && (_user?.email.trim().isEmpty ?? true);
  AuthenticatedUser? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;

  Set<String> get providerIds {
    final service = _service;
    if (service == null || service is! SensitiveAuthOperations) {
      return const <String>{};
    }

    final sensitiveService = service as SensitiveAuthOperations;
    return Set<String>.unmodifiable(sensitiveService.currentProviderIds);
  }

  bool get hasPasswordProvider => providerIds.contains('password');
  bool get hasGoogleProvider => providerIds.contains('google.com');
  bool get hasAppleProvider => providerIds.contains('apple.com');

  Future<void> initialize() async {
    if (_isTestController) return;

    final service = _service!;
    _user = service.currentUser;
    _authSubscription = service.authStateChanges().listen((user) {
      _user = user;
      if (user == null) _unlockAfterAccountSignIn = false;
      notifyListeners();
    });

    if (_user != null) {
      await validateCurrentSession();
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<bool> validateCurrentSession() {
    if (_isTestController || _user == null) {
      return Future<bool>.value(_user != null);
    }

    final existing = _sessionValidationFuture;
    if (existing != null) return existing;

    final future = _validateCurrentSessionInternal();
    _sessionValidationFuture = future;

    return future.whenComplete(() {
      if (identical(_sessionValidationFuture, future)) {
        _sessionValidationFuture = null;
      }
    });
  }

  Future<bool> _validateCurrentSessionInternal() async {
    final service = _service;
    if (service == null || service is! SessionValidationOperations) {
      return true;
    }

    _isValidatingSession = true;
    notifyListeners();

    try {
      final result = await (service as SessionValidationOperations)
          .validateCurrentSession();

      if (result == SessionValidationResult.revoked) {
        _unlockAfterAccountSignIn = false;
        _errorMessage =
            'Your account session has expired. Sign in again to continue.';

        try {
          await service.signOut();
        } catch (error, stack) {
          await CrashReportingService.recordNonFatal(
            error,
            stack,
            reason: 'Signing out after Firebase session revocation',
          );
        }

        _user = null;
        notifyListeners();
        return false;
      }

      // A temporary network failure must not make offline HomeVault data
      // inaccessible. The session will be checked again on the next resume,
      // PIN/biometric unlock, or periodic validation.
      return true;
    } catch (error, stack) {
      await CrashReportingService.recordNonFatal(
        error,
        stack,
        reason: 'Validating the current Firebase Authentication session',
      );
      return true;
    } finally {
      _isValidatingSession = false;
      notifyListeners();
    }
  }

  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail == null) {
      _setError('Enter a valid email address.');
      return false;
    }

    final passwordValidation = validatePassword(password);
    if (passwordValidation != null) {
      _setError(passwordValidation);
      return false;
    }

    return _run(
      reason: 'Registering with email and password',
      fallback: 'The account could not be created. Please try again.',
      operation: () async {
        _user = await _service!.registerWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );

        try {
          await _service.resendVerificationEmail();
          _statusMessage =
              'Account created. A verification email was sent to ${_user!.email}. '
              'You can continue and verify it from your profile.';
        } catch (error, stack) {
          _statusMessage =
              'Account created. Email verification is pending. '
              'You can continue and resend the verification email from your profile.';
          await CrashReportingService.recordNonFatal(
            error,
            stack,
            reason: 'Sending the initial email verification after registration',
          );
        }
      },
    );
  }

  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail == null) {
      _setError('Enter a valid email address.');
      return false;
    }
    if (password.isEmpty) {
      _setError('Enter your password.');
      return false;
    }

    return _run(
      reason: 'Signing in with email and password',
      fallback: 'Sign-in failed. Check your email and password.',
      operation: () async {
        _user = await _service!.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        _unlockAfterAccountSignIn = true;
      },
    );
  }

  Future<bool> signInWithGoogle() async {
    return _run(
      reason: 'Signing in with Google',
      fallback: 'Google sign-in failed. Please try again.',
      operation: () async {
        _user = await _service!.signInWithGoogle();
        _unlockAfterAccountSignIn = true;
      },
    );
  }

  Future<bool> signInWithApple() async {
    return _run(
      reason: 'Signing in with Apple',
      fallback: 'Apple sign-in failed. Please try again.',
      operation: () async {
        _user = await _service!.signInWithApple();
        _unlockAfterAccountSignIn = true;
      },
    );
  }

  Future<bool> refreshEmailVerification() async {
    return _run(
      reason: 'Checking email verification',
      fallback: 'Email verification could not be checked.',
      operation: () async {
        _user = await _service!.reloadCurrentUser();
        if (_user!.isEmailVerified) {
          _statusMessage = 'Email verified successfully.';
        } else {
          _errorMessage =
              'Email verification is still pending. Open the verification link '
              'from your inbox, then check again.';
        }
      },
      successWhen: () => _user?.isEmailVerified == true,
    );
  }

  Future<bool> resendVerificationEmail() async {
    return _run(
      reason: 'Resending email verification',
      fallback: 'The verification email could not be sent.',
      operation: () async {
        await _service!.resendVerificationEmail();
        _statusMessage = 'A new verification email was sent.';
      },
    );
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail == null) {
      _setError('Enter a valid email address.');
      return false;
    }

    return _run(
      reason: 'Sending a password reset email',
      fallback: 'The password reset email could not be sent.',
      operation: () async {
        await _service!.sendPasswordResetEmail(normalizedEmail);
        _statusMessage =
            'If an account exists for that email, a password reset link has been sent.';
      },
    );
  }

  Future<bool> reauthenticateWithPassword(String password) async {
    final email = _user?.email.trim() ?? '';
    if (email.isEmpty) {
      _setError('This account must be upgraded to email sign-in first.');
      return false;
    }
    if (password.isEmpty) {
      _setError('Enter your account password.');
      return false;
    }

    return _run(
      reason: 'Reauthenticating for PIN recovery',
      fallback:
          'The password is incorrect or the session could not be verified.',
      operation: () => _service!.reauthenticateWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  Future<bool> reauthenticateWithGoogle() async {
    final service = _service;
    if (service is! SensitiveAuthOperations) {
      _setError('Google verification is not available in this build.');
      return false;
    }

    final sensitiveService = service as SensitiveAuthOperations;
    return _run(
      reason: 'Reauthenticating with Google for a sensitive action',
      fallback: 'Google verification failed. Please try again.',
      operation: sensitiveService.reauthenticateWithGoogle,
    );
  }

  Future<bool> reauthenticateWithApple() async {
    final service = _service;
    if (service is! SensitiveAuthOperations) {
      _setError('Apple verification is not available in this build.');
      return false;
    }

    final sensitiveService = service as SensitiveAuthOperations;
    return _run(
      reason: 'Reauthenticating with Apple for a sensitive action',
      fallback: 'Apple verification failed. Please try again.',
      operation: sensitiveService.reauthenticateWithApple,
    );
  }

  Future<bool> deleteCurrentAccount() async {
    final service = _service;
    if (service is! SensitiveAuthOperations) {
      _setError('Account deletion is not available in this build.');
      return false;
    }

    final sensitiveService = service as SensitiveAuthOperations;
    return _run(
      reason: 'Deleting the Firebase Authentication account',
      fallback:
          'Your sign-in account could not be deleted. Please verify your account again and retry.',
      operation: () async {
        await sensitiveService.deleteCurrentUser();
        _user = null;
        _unlockAfterAccountSignIn = false;
      },
    );
  }

  Future<bool> upgradeLegacyPhoneAccount({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail == null) {
      _setError('Enter a valid email address.');
      return false;
    }

    final passwordValidation = validatePassword(password);
    if (passwordValidation != null) {
      _setError(passwordValidation);
      return false;
    }

    return _run(
      reason: 'Upgrading a phone account to email sign-in',
      fallback: 'The existing account could not be upgraded.',
      operation: () async {
        _user = await _service!.linkEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        _statusMessage = 'Verification email sent to ${_user!.email}.';
      },
    );
  }

  Future<void> signOut() async {
    _errorMessage = null;
    _statusMessage = null;
    await _service?.signOut();
    _user = null;
    _unlockAfterAccountSignIn = false;
    notifyListeners();
  }

  bool consumeAccountSignInUnlock() {
    final shouldUnlock = _unlockAfterAccountSignIn;
    _unlockAfterAccountSignIn = false;
    return shouldUnlock;
  }

  void clearMessages() {
    if (_errorMessage == null && _statusMessage == null) return;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
  }

  Future<bool> _run({
    required String reason,
    required String fallback,
    required Future<void> Function() operation,
    bool Function()? successWhen,
  }) async {
    if (_isBusy) return false;
    _isBusy = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await operation();
      return successWhen?.call() ?? true;
    } catch (error, stack) {
      _errorMessage = friendlyFirebaseError(error, fallback: fallback);
      await CrashReportingService.recordNonFatal(error, stack, reason: reason);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _statusMessage = null;
    notifyListeners();
  }

  static String? normalizeEmail(String value) {
    final email = value.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return null;
    }
    return email;
  }

  static String? normalizeIndianMobileNumber(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(digits)) return null;
    return '+91$digits';
  }

  static String? validatePassword(String value) {
    if (value.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Include at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Include at least one number.';
    }
    return null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
