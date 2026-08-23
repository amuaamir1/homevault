import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 Production Firebase project probe contract', () {
    late String provision;

    setUpAll(() {
      provision = File(
        'scripts/firebase/Provision-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();
    });

    test('uses a project-specific read-only probe first', () {
      expect(provision, contains("'apps:list'"));
      expect(provision, contains("'android'"));
      expect(provision, contains("'--project', \$ProductionProjectId"));
      expect(provision, contains(r'$projectProbe.ExitCode -eq 0'));
    });

    test('does not depend on projects:list JSON output', () {
      expect(provision, isNot(contains("@('projects:list', '--json')")));
      expect(provision, contains("@('projects:list')"));
    });

    test('fails closed when project existence is ambiguous', () {
      expect(
        provision,
        contains(
          'Could not safely determine whether the Production Firebase '
          'project exists. No project was created.',
        ),
      );
      expect(provision, contains('ConfirmCreateProject'));
      expect(provision, contains('homevault-aamir-india-1701'));
    });

    test('prints quiet Firebase output before fatal CLI failures', () {
      expect(provision, contains('Firebase CLI command output:'));
      expect(
        provision,
        contains(r'$Quiet -and -not [string]::IsNullOrWhiteSpace'),
      );
    });
  });
}
