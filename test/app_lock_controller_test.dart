import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/security/app_lock_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });
  test('sign out preparation locks without deleting PIN state', () {
    final controller = AppLockController.unlockedForTesting(
      uid: 'firebase-user-a',
    );
    addTearDown(controller.dispose);

    controller.prepareForSignOut();

    expect(controller.boundUid, 'firebase-user-a');
    expect(controller.hasPin, isTrue);
    expect(controller.pinSetupCompleted, isTrue);
    expect(controller.isUnlocked, isFalse);
  });

  test(
    'email password authentication unlocks the bound PIN session once',
    () async {
      final controller = AppLockController.unlockedForTesting(
        uid: 'firebase-user-b',
      );
      addTearDown(controller.dispose);

      controller.prepareForSignOut();
      expect(controller.isUnlocked, isFalse);

      await controller.unlockAfterAccountAuthentication();
      expect(controller.isUnlocked, isTrue);
    },
  );
}
