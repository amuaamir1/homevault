import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/auth/auth_controller.dart';
import 'package:homevault/auth/auth_scope.dart';
import 'package:homevault/models/user_profile.dart';
import 'package:homevault/profile/profile_controller.dart';
import 'package:homevault/profile/profile_scope.dart';
import 'package:homevault/screens/profile/profile_screen.dart';

void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    required bool isEmailVerified,
  }) async {
    const uid = 'profile-user';

    final auth = AuthController.authenticatedForTesting(
      uid: uid,
      email: 'profile@example.com',
      isEmailVerified: isEmailVerified,
      phoneNumber: '+919876543210',
    );
    final profile = ProfileController.loadedForTesting(
      const UserProfile(
        uid: uid,
        fullName: 'Profile User',
        phoneNumber: '+919876543210',
        email: 'profile@example.com',
        addressLine1: '12 Test Street',
        state: 'Delhi',
        city: 'New Delhi',
        pinCode: '110001',
      ),
    );

    addTearDown(auth.dispose);
    addTearDown(profile.dispose);

    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: ProfileScope(
          controller: profile,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('profile highlights pending email verification', (tester) async {
    await pumpProfile(tester, isEmailVerified: false);

    expect(
      find.byKey(const ValueKey('profileEmailVerificationStatus')),
      findsOneWidget,
    );
    expect(find.text('Verification pending'), findsOneWidget);
    expect(find.text("I've verified"), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
  });

  testWidgets('profile shows verified email status without pending actions', (
    tester,
  ) async {
    await pumpProfile(tester, isEmailVerified: true);

    expect(find.text('Email verified'), findsOneWidget);
    expect(find.text('Verification pending'), findsNothing);
    expect(find.text("I've verified"), findsNothing);
    expect(find.text('Resend verification email'), findsNothing);
  });
}
