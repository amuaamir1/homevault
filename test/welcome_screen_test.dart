import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/auth/auth_controller.dart';
import 'package:homevault/auth/auth_scope.dart';
import 'package:homevault/auth/email_auth_service.dart';
import 'package:homevault/models/authenticated_user.dart';
import 'package:homevault/screens/auth/welcome_screen.dart';

void main() {
  testWidgets('welcome screen uses the requested sign-in architecture', (
    tester,
  ) async {
    final controller = AuthController(service: _FakeEmailAuthService());
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      AuthScope(
        controller: controller,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HomeVault'), findsOneWidget);
    expect(find.text('Sign in to HomeVault'), findsOneWidget);
    expect(find.text('Use your email and password.'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('OR CONTINUE WITH'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text("Don't have an account yet?"), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Create your HomeVault account'), findsNothing);
  });

  testWidgets('forgot password cancel closes safely', (tester) async {
    final service = _FakeEmailAuthService();
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      AuthScope(
        controller: controller,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);

    await tester.tap(find.byKey(const Key('resetPasswordCancelButton')));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsNothing);
    expect(find.text('Sign in to HomeVault'), findsOneWidget);
  });

  testWidgets('forgot password sends reset before closing the dialog', (
    tester,
  ) async {
    final service = _FakeEmailAuthService();
    final controller = AuthController(service: service);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      AuthScope(
        controller: controller,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('resetPasswordEmailField')),
      'aamir.ahmad5144@gmail.com',
    );
    await tester.tap(find.byKey(const Key('resetPasswordSubmitButton')));
    await tester.pumpAndSettle();

    expect(service.lastPasswordResetEmail, 'aamir.ahmad5144@gmail.com');
    expect(find.text('Reset password'), findsNothing);
    expect(
      find.text('Password reset instructions were sent by email.'),
      findsOneWidget,
    );
  });

  testWidgets('register link opens the email registration form', (
    tester,
  ) async {
    final controller = AuthController(service: _FakeEmailAuthService());
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      AuthScope(
        controller: controller,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final switchAuthModeButton = find.byKey(const Key('switchAuthModeButton'));

    await tester.ensureVisible(switchAuthModeButton);
    await tester.pumpAndSettle();
    await tester.tap(switchAuthModeButton);
    await tester.pumpAndSettle();

    expect(find.text('Create your HomeVault account'), findsOneWidget);
    expect(find.byKey(const Key('registerEmailField')), findsOneWidget);
    expect(find.byKey(const Key('registerPasswordField')), findsOneWidget);
    expect(
      find.byKey(const Key('confirmRegistrationPasswordField')),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Already have an account?'), findsOneWidget);
  });
}

class _FakeEmailAuthService implements EmailAuthService {
  AuthenticatedUser? _currentUser;
  String? lastPasswordResetEmail;

  @override
  AuthenticatedUser? get currentUser => _currentUser;

  @override
  Stream<AuthenticatedUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthenticatedUser> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
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
    return _currentUser = AuthenticatedUser(
      uid: 'signed-in-user',
      email: email,
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthenticatedUser> signInWithGoogle() async {
    return _currentUser = const AuthenticatedUser(
      uid: 'google-user',
      email: 'google@example.com',
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthenticatedUser> signInWithApple() async {
    return _currentUser = const AuthenticatedUser(
      uid: 'apple-user',
      email: 'apple@example.com',
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthenticatedUser> reloadCurrentUser() async => _currentUser!;

  @override
  Future<void> resendVerificationEmail() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastPasswordResetEmail = email;
  }

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
    return _currentUser = AuthenticatedUser(
      uid: _currentUser?.uid ?? 'linked-user',
      email: email,
    );
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}
