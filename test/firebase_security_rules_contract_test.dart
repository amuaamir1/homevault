import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String load(String path) => File(path).readAsStringSync();

  test('Firestore rules enforce HomeVault ownership and privileged fields', () {
    final rules = load('firestore.rules');

    expect(rules, contains('request.auth.uid == userId'));
    expect(rules, contains('request.resource.data.uid == userId'));
    expect(rules, contains('request.resource.data.id == applianceId'));
    expect(rules, contains("documentId == 'appliancesV1'"));
    expect(
      rules,
      contains(
        "'users/' + userId + '/backups/' + backupId + '/homevault-backup.zip'",
      ),
    );
    expect(rules, contains('request.resource.data.createdAt == request.time'));
    expect(rules, contains('request.resource.data.updatedAt == request.time'));
    expect(
      rules,
      contains(
        'request.resource.data.diff(resource.data).affectedKeys().hasOnly',
      ),
    );
    expect(
      rules,
      contains('request.resource.data.updatedBy == request.auth.uid'),
    );
    expect(rules, contains('allow create, update, delete: if false;'));
    expect(rules, contains('allow read, write: if false;'));
  });

  test(
    'Storage rules constrain owner paths, backup uploads, and documents',
    () {
      final rules = load('storage.rules');

      expect(rules, contains('request.auth.uid == userId'));
      expect(rules, contains("fileName == 'homevault-backup.zip'"));
      expect(rules, contains(r"backupId.matches('^backup_[0-9]+$')"));
      expect(
        rules,
        contains('request.resource.metadata.homevaultBackupId == backupId'),
      );
      expect(
        rules,
        contains("request.resource.contentType == 'application/zip'"),
      );
      expect(rules, contains('request.resource.size <= 250 * 1024 * 1024'));
      expect(rules, contains('request.resource.size <= 15 * 1024 * 1024'));
      expect(
        rules,
        contains(r"fileName.matches('^[a-f0-9]{24}_[A-Za-z0-9._-]+$')"),
      );
      expect(
        rules,
        contains('request.resource.metadata.applianceId is string'),
      );
      expect(rules, contains('request.resource.metadata.documentId is string'));
      expect(rules, contains('allow read, write: if false;'));
    },
  );
}
