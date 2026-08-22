import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/backup_models.dart';
import 'package:homevault/services/cloud_backup_service.dart';

void main() {
  test('cloud backup retention keeps only the latest two snapshots', () {
    final reference = DateTime(2026, 8, 22, 12);
    final snapshots = <CloudBackupSnapshot>[
      _snapshot(
        id: 'old-manual',
        createdAt: reference.subtract(const Duration(days: 5)),
        source: CloudBackupSource.manual,
      ),
      _snapshot(
        id: 'old-auto',
        createdAt: reference.subtract(const Duration(days: 3)),
        source: CloudBackupSource.automatic,
      ),
      _snapshot(
        id: 'latest-auto',
        createdAt: reference.subtract(const Duration(hours: 2)),
        source: CloudBackupSource.automatic,
      ),
      _snapshot(
        id: 'latest-safety',
        createdAt: reference.subtract(const Duration(minutes: 15)),
        source: CloudBackupSource.preRestoreSafety,
      ),
    ];

    final kept = CloudBackupService.retainedBackupIds(snapshots);

    expect(kept.length, CloudBackupService.cloudRetention);
    expect(kept, containsAll(<String>['latest-safety', 'latest-auto']));
    expect(kept, isNot(contains('old-auto')));
    expect(kept, isNot(contains('old-manual')));
  });

  test(
    'cloud backup retention keeps a single snapshot when only one exists',
    () {
      final snapshots = <CloudBackupSnapshot>[
        _snapshot(
          id: 'only-backup',
          createdAt: DateTime(2026, 8, 22, 12),
          source: CloudBackupSource.manual,
        ),
      ];

      final kept = CloudBackupService.retainedBackupIds(snapshots);

      expect(kept, {'only-backup'});
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
