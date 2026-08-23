import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 Phase 2 Production Firebase onboarding contract', () {
    test('provisioning is explicit and cannot target Development', () {
      final provision = File(
        'scripts/firebase/Provision-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();

      expect(provision, contains('ConfirmCreateProject'));
      expect(provision, contains('ConfirmCreateFirestore'));
      expect(provision, contains('homevault-aamir-india-1701'));
      expect(provision, contains('Production Firebase cannot use'));
      expect(provision, contains('apps:create'));
      expect(provision, contains('apps:sdkconfig'));
      expect(provision, contains('firestore:databases:create'));
      expect(provision, contains("'--delete-protection', 'ENABLED'"));
      expect(provision, contains("'asia-south1'"));
      expect(provision, isNot(contains('firebase deploy')));
    });

    test('production config remains external and environment matched', () {
      final generator = File(
        'scripts/firebase/New-HomeVault-ProductionFirebaseOptions.ps1',
      ).readAsStringSync();
      final finalizer = File(
        'scripts/firebase/Finalize-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();

      expect(generator, contains('HomeVault-Firebase-Config\\production'));
      expect(generator, contains('com.amuaamir.homevault'));
      expect(generator, contains('ExpectedProjectId'));
      expect(generator, contains('storageBucket'));
      expect(finalizer, contains('Test-HomeVault-Firebase-Environment.ps1'));
      expect(finalizer, contains('ProductionProjectId'));
    });

    test('production rules deployment remains separately confirmed', () {
      final finalizer = File(
        'scripts/firebase/Finalize-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();
      final deploy = File(
        'scripts/firebase/Deploy-HomeVault-Firebase-Rules.ps1',
      ).readAsStringSync();

      expect(finalizer, contains('ConfirmProductionRules'));
      expect(finalizer, contains('Deploy-HomeVault-Firebase-Rules.ps1'));
      expect(finalizer, contains('-ConfirmProduction'));
      expect(deploy, contains('ConfirmProduction'));
      expect(deploy, contains('firestore:rules,storage'));
      expect(deploy, contains('--project'));
    });

    test('live smoke uses a temporary user and cleans it up', () {
      final smoke = File(
        'scripts/firebase/Test-HomeVault-ProductionFirebase-Live.ps1',
      ).readAsStringSync();

      expect(smoke, contains("-Action 'signUp'"));
      expect(smoke, contains("-Action 'delete'"));
      expect(smoke, contains(r'accounts:$Action'));
      expect(smoke, contains('Production Firestore owner write is allowed'));
      expect(smoke, contains('cross-user read is denied'));
      expect(smoke, contains('homevault-p16-smoke-'));
      expect(smoke, isNot(contains(r'Write-Host $password')));
    });

    test('release SHA helper avoids direct keystore-password handling', () {
      final sha = File(
        'scripts/firebase/Get-HomeVault-ReleaseSha1.ps1',
      ).readAsStringSync();

      expect(sha, contains('signingReport'));
      expect(sha, contains('SHA1:'));
      expect(sha, isNot(contains('storePassword')));
      expect(sha, isNot(contains('keyPassword')));
    });
  });
}
