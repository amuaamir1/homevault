import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/authenticated_user.dart';

abstract class EmailAuthService {
  AuthenticatedUser? get currentUser;

  Stream<AuthenticatedUser?> authStateChanges();

  Future<AuthenticatedUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AuthenticatedUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AuthenticatedUser> signInWithGoogle();

  Future<AuthenticatedUser> signInWithApple();

  Future<AuthenticatedUser> reloadCurrentUser();

  Future<void> resendVerificationEmail();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> reauthenticateWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AuthenticatedUser> linkEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

abstract interface class SensitiveAuthOperations {
  Set<String> get currentProviderIds;

  Future<void> reauthenticateWithGoogle();

  Future<void> reauthenticateWithApple();

  Future<void> deleteCurrentUser();
}

enum SessionValidationResult { valid, revoked, unavailable }

abstract interface class SessionValidationOperations {
  Future<SessionValidationResult> validateCurrentSession();
}

class FirebaseEmailAuthService
    implements
        EmailAuthService,
        SensitiveAuthOperations,
        SessionValidationOperations {
  FirebaseEmailAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  @override
  Set<String> get currentProviderIds =>
      _firebaseAuth.currentUser?.providerData
          .map((provider) => provider.providerId)
          .where((providerId) => providerId.trim().isNotEmpty)
          .toSet() ??
      <String>{};

  @override
  AuthenticatedUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthenticatedUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  @override
  Future<AuthenticatedUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return the newly created user.');
    }

    return _mapRequiredUser(user);
  }

  @override
  Future<AuthenticatedUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _mapCredentialUser(
      credential,
      missingUserMessage: 'Firebase did not return the signed-in user.',
    );
  }

  @override
  Future<AuthenticatedUser> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final googleAccount = await _googleSignIn.authenticate();
    final googleAuthentication = googleAccount.authentication;
    final idToken = googleAuthentication.idToken;

    if (idToken == null || idToken.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _firebaseAuth.signInWithCredential(credential);

    return _mapCredentialUser(
      result,
      missingUserMessage: 'Firebase did not return the Google user.',
    );
  }

  @override
  Future<AuthenticatedUser> signInWithApple() async {
    final provider = AppleAuthProvider();
    final result = await _firebaseAuth.signInWithProvider(provider);

    return _mapCredentialUser(
      result,
      missingUserMessage: 'Firebase did not return the Apple user.',
    );
  }

  @override
  Future<AuthenticatedUser> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No Firebase user is signed in.');

    await user.reload();
    final refreshed = _firebaseAuth.currentUser;
    if (refreshed == null) throw StateError('The Firebase session expired.');
    return _mapRequiredUser(refreshed);
  }

  @override
  Future<void> resendVerificationEmail() async {
    final existingUser = _firebaseAuth.currentUser;

    if (existingUser == null) {
      throw StateError('No Firebase user is signed in.');
    }

    await existingUser.reload();

    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('The Firebase user could not be refreshed.');
    }

    _debugAuthEvent(
      'Verification state refreshed. '
      'emailVerified=${user.emailVerified}, '
      'providers=${user.providerData.map((provider) => provider.providerId).join(',')}',
    );

    if (user.emailVerified) {
      _debugAuthEvent('The email address is already verified.');
      return;
    }

    try {
      await user.sendEmailVerification();

      _debugAuthEvent('Verification email resend request completed.');
    } on FirebaseAuthException catch (error) {
      _debugAuthEvent('Verification email resend failed. code=${error.code}');
      rethrow;
    } catch (error) {
      _debugAuthEvent(
        'Unexpected verification email error. type=${error.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> reauthenticateWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No Firebase user is signed in.');

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<AuthenticatedUser> linkEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No Firebase user is signed in.');

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final result = await user.linkWithCredential(credential);
    final linkedUser = result.user;
    if (linkedUser == null) {
      throw StateError('Firebase did not return the upgraded user.');
    }

    await linkedUser.sendEmailVerification();
    return _mapRequiredUser(linkedUser);
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No Firebase user is signed in.');

    await _ensureGoogleInitialized();
    final googleAccount = await _googleSignIn.authenticate();
    final googleAuthentication = googleAccount.authentication;
    final idToken = googleAuthentication.idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> reauthenticateWithApple() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No Firebase user is signed in.');
    await user.reauthenticateWithProvider(AppleAuthProvider());
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No Firebase user is signed in.');
    await user.delete();
  }

  @override
  Future<SessionValidationResult> validateCurrentSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return SessionValidationResult.revoked;

    try {
      final token = await user.getIdToken(true);
      if (token == null || token.trim().isEmpty) {
        return SessionValidationResult.revoked;
      }
      return SessionValidationResult.valid;
    } on FirebaseAuthException catch (error) {
      final code = error.code.trim().toLowerCase();

      if (code == 'user-token-expired' ||
          code == 'invalid-user-token' ||
          code == 'user-disabled' ||
          code == 'user-not-found') {
        _debugAuthEvent('Firebase session is no longer valid. code=$code');
        return SessionValidationResult.revoked;
      }

      // Do not force-sign-out merely because the device is temporarily
      // offline or Firebase cannot be reached. HomeVault supports local
      // PIN access while offline.
      _debugAuthEvent('Firebase session validation unavailable. code=$code');
      return SessionValidationResult.unavailable;
    } catch (error) {
      _debugAuthEvent(
        'Firebase session validation unavailable. type=${error.runtimeType}',
      );
      return SessionValidationResult.unavailable;
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();

    final initialization = _googleInitialization;
    if (initialization == null) return;

    try {
      await initialization;
      await _googleSignIn.signOut();
    } catch (error) {
      _debugAuthEvent(
        'Google sign-out cleanup failed. type=${error.runtimeType}',
      );
    }
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _googleSignIn.initialize();
  }

  AuthenticatedUser _mapCredentialUser(
    UserCredential credential, {
    required String missingUserMessage,
  }) {
    final user = credential.user;
    if (user == null) throw StateError(missingUserMessage);
    return _mapRequiredUser(user);
  }

  AuthenticatedUser _mapRequiredUser(User user) => _mapUser(user)!;

  AuthenticatedUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthenticatedUser(
      uid: user.uid,
      email: user.email ?? '',
      isEmailVerified: user.emailVerified,
      phoneNumber: user.phoneNumber ?? '',
    );
  }
}

void _debugAuthEvent(String message) {
  if (kDebugMode) {
    debugPrint('HOMEVAULT_AUTH: $message');
  }
}
