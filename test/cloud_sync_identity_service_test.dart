import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/services/cloud_sync_identity_service.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test(
    'keeps one anonymous installation ID on the same installation',
    () async {
      final service = CloudSyncIdentityService();

      final first = await service.installationId();
      final second = await service.installationId();

      expect(first, isNotEmpty);
      expect(second, first);
      expect(first.length, greaterThanOrEqualTo(20));
    },
  );

  test('migration completion is scoped to the Firebase user', () async {
    final service = CloudSyncIdentityService();

    await service.bindOwner('user-a');
    expect(await service.hasCompletedStructuredMigration(), isFalse);

    await service.markStructuredMigrationCompleted();
    expect(await service.hasCompletedStructuredMigration(), isTrue);

    await service.bindOwner('user-b');
    expect(await service.hasCompletedStructuredMigration(), isFalse);

    await service.bindOwner('user-a');
    expect(await service.hasCompletedStructuredMigration(), isTrue);
  });

  test('signed-out state cannot mark a user migration complete', () async {
    final service = CloudSyncIdentityService();

    await service.bindOwner(null);
    await service.markStructuredMigrationCompleted();

    expect(await service.hasCompletedStructuredMigration(), isFalse);
  });
}
