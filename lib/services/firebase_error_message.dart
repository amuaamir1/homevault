import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

String friendlyFirebaseError(
  Object error, {
  String fallback = 'The operation could not be completed. Please try again.',
}) {
  if (error is GoogleSignInException) {
    return _googleSignInMessage(error.code, fallback);
  }

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

String _googleSignInMessage(GoogleSignInExceptionCode code, String fallback) {
  return switch (code) {
    GoogleSignInExceptionCode.canceled => 'Google sign-in was cancelled.',
    GoogleSignInExceptionCode.interrupted =>
      'Google sign-in was interrupted. Please try again.',
    GoogleSignInExceptionCode.clientConfigurationError ||
    GoogleSignInExceptionCode.providerConfigurationError =>
      'Google sign-in is not fully configured for this app.',
    GoogleSignInExceptionCode.uiUnavailable =>
      'Google sign-in could not open on this device.',
    _ => fallback,
  };
}

String _authMessage(String code, String? details, String fallback) {
  return switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'email-already-in-use' =>
      'An account already exists for this email. Try signing in instead.',
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
      'This sign-in method is not enabled in Firebase Authentication.',
    'requires-recent-login' =>
      'For security, sign in again before completing this action.',
    'provider-already-linked' =>
      'This sign-in method is already connected to the account.',
    'credential-already-in-use' =>
      'This sign-in credential is already connected to another account.',
    'account-exists-with-different-credential' =>
      'An account already exists for this email. Sign in using the original method first.',
    'missing-google-id-token' =>
      'Google sign-in did not return a valid authentication token.',
    'popup-closed-by-user' ||
    'web-context-cancelled' ||
    'canceled' => 'Sign-in was cancelled.',
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
