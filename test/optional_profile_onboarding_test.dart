import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/app.dart';
import 'package:homevault/auth/auth_controller.dart';
import 'package:homevault/auth/auth_scope.dart';
import 'package:homevault/models/user_profile.dart';
import 'package:homevault/profile/profile_controller.dart';
import 'package:homevault/profile/profile_scope.dart';
import 'package:homevault/screens/profile/profile_screen.dart';
import 'package:homevault/security/app_lock_controller.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/state/appliance_store.dart';

void main() {
  test('mobile number is not required for profile completeness', () {
    const profile = UserProfile(
      uid: 'test-user',
      fullName: 'Aamir Test',
      phoneNumber: '',
      addressLine1: '12 Test Street',
      state: 'Delhi',
      city: 'New Delhi',
      pinCode: '110001',
    );

    expect(profile.isComplete, isTrue);
  });

  testWidgets('incomplete profile does not block HomeVault home', (
    tester,
  ) async {
    const uid = 'test-user';

    final store = ApplianceStore(repository: MemoryApplianceRepository());
    await store.initialize();
    await store.bindOwner(uid);

    final lockController = AppLockController.unlockedForTesting(uid: uid);
    final authController = AuthController.authenticatedForTesting(
      uid: uid,
      email: 'test@example.com',
      phoneNumber: '',
    );
    final profileController = ProfileController.loadedForTesting(
      const UserProfile(
        uid: uid,
        fullName: '',
        phoneNumber: '',
        addressLine1: '',
        state: '',
        city: '',
        pinCode: '',
      ),
    );

    addTearDown(store.dispose);
    addTearDown(lockController.dispose);
    addTearDown(authController.dispose);
    addTearDown(profileController.dispose);

    await tester.pumpWidget(
      HomeVaultApp(
        applianceStore: store,
        appLockController: lockController,
        authController: authController,
        profileController: profileController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HomeVault'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Create your profile'), findsNothing);
  });

  testWidgets('blank mobile number can be saved from Profile', (tester) async {
    const uid = 'test-user';

    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authController = AuthController.authenticatedForTesting(
      uid: uid,
      email: 'test@example.com',
      phoneNumber: '',
    );
    final profileController = ProfileController.loadedForTesting(
      const UserProfile(
        uid: uid,
        fullName: 'Aamir Test',
        phoneNumber: '',
        addressLine1: '12 Test Street',
        state: 'Delhi',
        city: 'New Delhi',
        pinCode: '110001',
      ),
    );

    addTearDown(authController.dispose);
    addTearDown(profileController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScope(
          controller: authController,
          child: ProfileScope(
            controller: profileController,
            child: const ProfileScreen(isInitialSetup: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mobileField = find.byKey(const Key('profileMobileNumberField'));
    expect(mobileField, findsOneWidget);

    final mobileFormField = tester.widget<TextFormField>(mobileField);
    expect(mobileFormField.validator?.call(''), isNull);

    final mobileTextField = find.descendant(
      of: mobileField,
      matching: find.byType(TextField),
    );
    expect(mobileTextField, findsOneWidget);
    expect(
      tester.widget<TextField>(mobileTextField).decoration?.labelText,
      'Mobile number',
    );

    final saveButton = find.byKey(const Key('saveProfileButton'));
    expect(saveButton, findsOneWidget);

    expect(profileController.profile?.updatedAt, isNull);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid 10-digit Indian mobile number.'),
      findsNothing,
    );
    expect(profileController.profile?.phoneNumber, isEmpty);
    expect(profileController.profile?.updatedAt, isNotNull);
    expect(profileController.profile?.isComplete, isTrue);
  });
}
