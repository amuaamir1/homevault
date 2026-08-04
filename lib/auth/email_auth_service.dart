import 'package:firebase_auth/firebase_auth.dart';

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

class FirebaseEmailAuthService implements EmailAuthService {
  FirebaseEmailAuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

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

    await user.sendEmailVerification();
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
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return the signed-in user.');
    }
    return _mapRequiredUser(user);
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
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No Firebase user is signed in.');
    await user.sendEmailVerification();
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
  Future<void> signOut() => _firebaseAuth.signOut();

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
