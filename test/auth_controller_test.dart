import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/auth/auth_controller.dart';
import 'package:homevault/auth/email_auth_service.dart';
import 'package:homevault/models/authenticated_user.dart';

void main() {
  test('normalizes email and Indian profile mobile numbers', () {
    expect(
      AuthController.normalizeEmail(' User@Example.COM '),
      'user@example.com',
    );
    expect(AuthController.normalizeEmail('not-an-email'), isNull);

    expect(
      AuthController.normalizeIndianMobileNumber('9876543210'),
      '+919876543210',
    );
    expect(
      AuthController.normalizeIndianMobileNumber('+91 98765 43210'),
      '+919876543210',
    );
    expect(AuthController.normalizeIndianMobileNumber('1234567890'), isNull);
  });

  test('validates a production account password', () {
    expect(AuthController.validatePassword('Short1'), isNotNull);
    expect(AuthController.validatePassword('alllowercase1'), isNotNull);
    expect(AuthController.validatePassword('ALLUPPERCASE1'), isNotNull);
    expect(AuthController.validatePassword('NoNumbersHere'), isNotNull);
    expect(AuthController.validatePassword('SecurePass1'), isNull);
  });

  test('reuses an existing Firebase email session', () async {
    final service = _FakeEmailAuthService(
      currentUser: const AuthenticatedUser(
        uid: 'existing-user',
        email: 'user@example.com',
        isEmailVerified: true,
      ),
    );
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.isAuthenticated, isTrue);
    expect(controller.isEmailVerified, isTrue);
    expect(controller.user?.uid, 'existing-user');
    expect(service.signInCalls, 0);
  });

  test(
    'registers with email and password without blocking on verification',
    () async {
      final service = _FakeEmailAuthService();
      final controller = AuthController(service: service);
      addTearDown(controller.dispose);
      await controller.initialize();

      final registered = await controller.registerWithEmailAndPassword(
        email: 'new@example.com',
        password: 'SecurePass1',
      );

      expect(registered, isTrue);
      expect(service.registerCalls, 1);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.isEmailVerified, isFalse);
      expect(controller.statusMessage, contains('Account created'));
      expect(controller.statusMessage, contains('verify it from your profile'));
    },
  );

  test(
    'registration succeeds when the initial verification email cannot be sent',
    () async {
      final service = _FakeEmailAuthService(failVerificationEmail: true);
      final controller = AuthController(service: service);
      addTearDown(controller.dispose);
      await controller.initialize();

      final registered = await controller.registerWithEmailAndPassword(
        email: 'new@example.com',
        password: 'SecurePass1',
      );

      expect(registered, isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.isEmailVerified, isFalse);
      expect(controller.statusMessage, contains('verification is pending'));
      expect(controller.statusMessage, contains('continue'));
    },
  );

  test('email password sign-in unlocks the local session once', () async {
    final service = _FakeEmailAuthService();
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);
    await controller.initialize();

    final signedIn = await controller.signInWithEmailAndPassword(
      email: 'user@example.com',
      password: 'SecurePass1',
    );

    expect(signedIn, isTrue);
    expect(controller.consumeAccountSignInUnlock(), isTrue);
    expect(controller.consumeAccountSignInUnlock(), isFalse);
  });

  test('revoked Firebase session is signed out during startup', () async {
    final service = _FakeSessionValidationAuthService(
      currentUser: const AuthenticatedUser(
        uid: 'existing-user',
        email: 'user@example.com',
        isEmailVerified: true,
      ),
      validationResult: SessionValidationResult.revoked,
    );
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(service.validationCalls, 1);
    expect(service.signOutCalls, 1);
    expect(controller.isAuthenticated, isFalse);
    expect(
      controller.errorMessage,
      'Your account session has expired. Sign in again to continue.',
    );
  });

  test(
    'temporary validation outage keeps the cached Firebase session',
    () async {
      final service = _FakeSessionValidationAuthService(
        currentUser: const AuthenticatedUser(
          uid: 'existing-user',
          email: 'user@example.com',
          isEmailVerified: true,
        ),
        validationResult: SessionValidationResult.unavailable,
      );
      final controller = AuthController(service: service);
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(service.validationCalls, 1);
      expect(service.signOutCalls, 0);
      expect(controller.isAuthenticated, isTrue);
    },
  );

  test('Google sign-in authenticates and unlocks the local session', () async {
    final service = _FakeEmailAuthService();
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);
    await controller.initialize();

    final signedIn = await controller.signInWithGoogle();

    expect(signedIn, isTrue);
    expect(service.googleSignInCalls, 1);
    expect(controller.user?.email, 'google@example.com');
    expect(controller.isEmailVerified, isTrue);
    expect(controller.consumeAccountSignInUnlock(), isTrue);
  });

  test('Apple sign-in authenticates and unlocks the local session', () async {
    final service = _FakeEmailAuthService();
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);
    await controller.initialize();

    final signedIn = await controller.signInWithApple();

    expect(signedIn, isTrue);
    expect(service.appleSignInCalls, 1);
    expect(controller.user?.email, 'apple@example.com');
    expect(controller.isEmailVerified, isTrue);
    expect(controller.consumeAccountSignInUnlock(), isTrue);
  });
}

class _FakeEmailAuthService implements EmailAuthService {
  _FakeEmailAuthService({
    AuthenticatedUser? currentUser,
    bool failVerificationEmail = false,
  }) : this._(currentUser, failVerificationEmail: failVerificationEmail);

  _FakeEmailAuthService._(
    this._currentUser, {
    this.failVerificationEmail = false,
  });

  AuthenticatedUser? _currentUser;
  final bool failVerificationEmail;
  int registerCalls = 0;
  int signInCalls = 0;
  int googleSignInCalls = 0;
  int appleSignInCalls = 0;

  @override
  AuthenticatedUser? get currentUser => _currentUser;

  @override
  Stream<AuthenticatedUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthenticatedUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    registerCalls++;
    return _currentUser = AuthenticatedUser(
      uid: 'registered-user',
      email: email,
    );
  }

  @override
  Future<AuthenticatedUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return _currentUser = AuthenticatedUser(
      uid: 'signed-in-user',
      email: email,
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthenticatedUser> signInWithGoogle() async {
    googleSignInCalls++;
    return _currentUser = const AuthenticatedUser(
      uid: 'google-user',
      email: 'google@example.com',
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthenticatedUser> signInWithApple() async {
    appleSignInCalls++;
    return _currentUser = const AuthenticatedUser(
      uid: 'apple-user',
      email: 'apple@example.com',
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthenticatedUser> reloadCurrentUser() async {
    final user = _currentUser!;
    return _currentUser = AuthenticatedUser(
      uid: user.uid,
      email: user.email,
      isEmailVerified: true,
      phoneNumber: user.phoneNumber,
    );
  }

  @override
  Future<void> resendVerificationEmail() async {
    if (failVerificationEmail) {
      throw StateError('Verification email service unavailable.');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> reauthenticateWithEmailAndPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<AuthenticatedUser> linkEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = _currentUser!;
    return _currentUser = AuthenticatedUser(
      uid: user.uid,
      email: email,
      isEmailVerified: false,
      phoneNumber: user.phoneNumber,
    );
  }

  @override
  Future<void> signOut() async => _currentUser = null;
}

class _FakeSessionValidationAuthService extends _FakeEmailAuthService
    implements SessionValidationOperations {
  _FakeSessionValidationAuthService({
    required AuthenticatedUser currentUser,
    required this.validationResult,
  }) : super(currentUser: currentUser);

  final SessionValidationResult validationResult;
  int validationCalls = 0;
  int signOutCalls = 0;

  @override
  Future<SessionValidationResult> validateCurrentSession() async {
    validationCalls++;
    return validationResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await super.signOut();
  }
}
