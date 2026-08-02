import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/security/auto_lock_preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('auto-lock defaults to two minutes for a user', () async {
    final service = AutoLockPreferenceService();
    service.bindUser('user-a');

    expect(await service.load(), AutoLockOption.twoMinutes);
  });

  test('auto-lock preference is separated by user', () async {
    final service = AutoLockPreferenceService();

    service.bindUser('user-a');
    await service.save(AutoLockOption.fiveMinutes);

    service.bindUser('user-b');
    expect(await service.load(), AutoLockOption.twoMinutes);

    service.bindUser('user-a');
    expect(await service.load(), AutoLockOption.fiveMinutes);
  });
}
