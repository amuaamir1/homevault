import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/backup_models.dart';
import 'package:homevault/services/cloud_backup_service.dart';

void main() {
  test('cloud backup retention keeps 7 daily, 4 weekly, and 6 monthly', () {
    final reference = DateTime(2026, 8, 11, 9);
    final automatic = List<CloudBackupSnapshot>.generate(180, (index) {
      return _snapshot(
        id: 'auto-$index',
        createdAt: reference.subtract(Duration(days: index)),
        source: CloudBackupSource.automatic,
      );
    });

    final kept = CloudBackupService.retainedBackupIds(automatic);
    final keptAutomatic = automatic.where((item) => kept.contains(item.id));

    expect(
      keptAutomatic.length,
      CloudBackupService.dailyRetention +
          CloudBackupService.weeklyRetention +
          CloudBackupService.monthlyRetention,
    );

    for (var index = 0; index < CloudBackupService.dailyRetention; index++) {
      expect(kept, contains('auto-$index'));
    }
  });

  test(
    'manual backups are preserved and safety backups keep the latest three',
    () {
      final now = DateTime(2026, 8, 11, 12);
      final snapshots = <CloudBackupSnapshot>[
        _snapshot(
          id: 'manual-old',
          createdAt: now.subtract(const Duration(days: 500)),
          source: CloudBackupSource.manual,
        ),
        ...List<CloudBackupSnapshot>.generate(
          5,
          (index) => _snapshot(
            id: 'safety-$index',
            createdAt: now.subtract(Duration(hours: index)),
            source: CloudBackupSource.preRestoreSafety,
          ),
        ),
      ];

      final kept = CloudBackupService.retainedBackupIds(snapshots);

      expect(kept, contains('manual-old'));
      expect(kept, containsAll(<String>['safety-0', 'safety-1', 'safety-2']));
      expect(kept, isNot(contains('safety-3')));
      expect(kept, isNot(contains('safety-4')));
    },
  );
}

CloudBackupSnapshot _snapshot({
  required String id,
  required DateTime createdAt,
  required CloudBackupSource source,
}) {
  return CloudBackupSnapshot(
    id: id,
    createdAt: createdAt,
    source: source,
    applianceCount: 1,
    documentCount: 1,
    missingDocuments: 0,
    sizeBytes: 1024,
    storagePath: 'users/test/backups/$id/homevault-backup.zip',
    appVersion: 'test',
  );
}
