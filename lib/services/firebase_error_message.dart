import 'package:firebase_auth/firebase_auth.dart';

String friendlyFirebaseError(
  Object error, {
  String fallback = 'The operation could not be completed. Please try again.',
}) {
  if (error is FirebaseAuthException) {
    return _authMessage(error.code, error.message);
  }

  if (error is FirebaseException) {
    return _firebaseMessage(error.code, error.message, fallback);
  }

  final value = error.toString().toLowerCase();
  if (value.contains('billing_not_enabled') ||
      value.contains('billing-not-enabled')) {
    return 'Real SMS OTP delivery is not enabled for this Firebase project. '
        'Use a configured test number or enable billing.';
  }
  if (value.contains('configuration_not_found') ||
      value.contains('configuration-not-found')) {
    return 'Phone authentication is not fully configured for this Firebase app.';
  }
  if (value.contains('network')) {
    return 'A network error occurred. Check your internet connection.';
  }

  return fallback;
}

String _authMessage(String code, String? details) {
  return switch (code) {
    'invalid-phone-number' => 'Enter a valid Indian mobile number.',
    'invalid-verification-code' =>
      'The OTP is incorrect. Check the SMS and try again.',
    'session-expired' => 'The OTP has expired. Request a new code.',
    'too-many-requests' =>
      'Too many OTP requests were made. Wait before trying again.',
    'quota-exceeded' =>
      'The SMS quota is currently unavailable. Please try again later.',
    'network-request-failed' =>
      'A network error occurred. Check your internet connection.',
    'operation-not-allowed' || 'app-not-authorized' =>
      'Phone authentication is not enabled for this Firebase app.',
    'invalid-app-credential' ||
    'missing-client-identifier' ||
    'missing-app-credential' =>
      'Android app verification failed. Check the Firebase SHA fingerprints.',
    'billing-not-enabled' =>
      'Real SMS OTP delivery requires billing. Use a configured Firebase test number during development.',
    'configuration-not-found' =>
      'Phone authentication is not fully configured for this Firebase project.',
    'user-disabled' => 'This HomeVault account has been disabled.',
    _ => _messageFallback(
      details,
      'Phone verification failed. Please try again.',
    ),
  };
}

String _firebaseMessage(String code, String? details, String fallback) {
  return switch (code) {
    'permission-denied' =>
      'Permission was denied. Sign in again and check the Firebase security rules.',
    'failed-precondition' =>
      'Firebase is not fully configured for this operation.',
    'unavailable' =>
      'The Firebase service is temporarily unavailable. Try again shortly.',
    'deadline-exceeded' =>
      'The request timed out. Check your connection and try again.',
    'resource-exhausted' =>
      'The Firebase service limit was reached. Try again later.',
    'unauthenticated' => 'Your session has expired. Sign in again.',
    'network-request-failed' =>
      'A network error occurred. Check your internet connection.',
    _ => _messageFallback(details, fallback),
  };
}

String _messageFallback(String? details, String fallback) {
  final message = details?.trim();
  if (message == null || message.isEmpty) return fallback;

  final upper = message.toUpperCase();
  if (upper.contains('BILLING_NOT_ENABLED')) {
    return 'Real SMS OTP delivery requires billing. Use a configured Firebase test number during development.';
  }
  if (upper.contains('CONFIGURATION_NOT_FOUND')) {
    return 'Phone authentication is not fully configured for this Firebase project.';
  }
  return fallback;
}
