import 'package:firebase_auth/firebase_auth.dart';

String friendlyFirebaseError(
  Object error, {
  String fallback = 'The operation could not be completed. Please try again.',
}) {
  if (error is FirebaseAuthException) {
    return _authMessage(error.code, error.message, fallback);
  }

  if (error is FirebaseException) {
    return _firebaseMessage(error.code, error.message, fallback);
  }

  final value = error.toString().toLowerCase();
  if (value.contains('network')) {
    return 'A network error occurred. Check your internet connection.';
  }

  return fallback;
}

String _authMessage(String code, String? details, String fallback) {
  return switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'email-already-in-use' =>
      'An account already exists for this email. Try logging in instead.',
    'weak-password' => 'Choose a stronger password with at least 8 characters.',
    'wrong-password' ||
    'invalid-credential' => 'The email or password is incorrect.',
    'user-not-found' => 'No HomeVault account was found for this email.',
    'user-disabled' => 'This HomeVault account has been disabled.',
    'too-many-requests' =>
      'Too many attempts were made. Wait a little before trying again.',
    'network-request-failed' =>
      'A network error occurred. Check your internet connection.',
    'operation-not-allowed' =>
      'Email/password authentication is not enabled for this Firebase app.',
    'requires-recent-login' =>
      'For security, sign in again before completing this action.',
    'provider-already-linked' =>
      'This account is already connected to email sign-in.',
    'credential-already-in-use' =>
      'That email is already connected to another Firebase account.',
    _ => _messageFallback(details, fallback),
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
  return fallback;
}
