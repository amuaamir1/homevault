import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known technical setup guidance is not user-facing', () {
    final guardedFiles = <String>[
      'lib/services/firestore_appliance_repository.dart',
      'lib/screens/feedback/feedback_dashboard_screen.dart',
      'lib/screens/backup/cloud_backup_screen.dart',
      'lib/screens/auth/firebase_setup_required_screen.dart',
    ];

    final combined = guardedFiles
        .map((path) => File(path).readAsStringSync())
        .join('\n')
        .toLowerCase();

    expect(combined, isNot(contains('publish the latest firestore rules')));
    expect(combined, isNot(contains('check the firestore rules')));
    expect(combined, isNot(contains('firebase user id')));
    expect(combined, isNot(contains('flutterfire configure')));
    expect(combined, isNot(contains('technical details')));
  });
}
