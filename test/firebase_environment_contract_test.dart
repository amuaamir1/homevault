import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 Firebase environment architecture contract', () {
    test('repository Firebase config is environment-neutral and dev-safe', () {
      final firebaseJson = File('firebase.json').readAsStringSync();
      final firebaserc = File('.firebaserc').readAsStringSync();

      expect(firebaseJson, contains('"firestore"'));
      expect(firebaseJson, contains('"storage"'));
      expect(firebaseJson, isNot(contains('"projectId"')));
      expect(firebaserc, contains('"development"'));
      expect(firebaserc, contains('homevault-aamir-india-1701'));
      expect(firebaserc, isNot(contains('"production"')));
    });

    test('release build has a Firebase project mismatch guard', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('HOMEVAULT_FIREBASE_PROJECT_ID'));
      expect(gradle, contains('HOMEVAULT_ALLOW_NON_PROD_RELEASE'));
      expect(gradle, contains('readGoogleServicesProjectId'));
      expect(gradle, contains('developmentFirebaseProjectId'));
      expect(gradle, contains('com.amuaamir.homevault'));
    });

    test('production scripts always require explicit project selection', () {
      final build = File(
        'scripts/firebase/Build-HomeVault-Production.ps1',
      ).readAsStringSync();
      final deploy = File(
        'scripts/firebase/Deploy-HomeVault-Firebase-Rules.ps1',
      ).readAsStringSync();

      expect(build, contains('HOMEVAULT_ENV=production'));
      expect(build, contains('HOMEVAULT_FIREBASE_PROJECT_ID'));
      expect(build, contains('HomeVault-Firebase-Config\\production'));
      expect(deploy, contains('--project'));
      expect(deploy, contains('ConfirmProduction'));
      expect(deploy, contains('firestore:rules,storage'));
    });

    test('Firebase client config variants remain outside source control', () {
      final gitignore = File('.gitignore').readAsStringSync();
      final safeZip = File(
        'scripts/Create-HomeVault-Safe-Zip.ps1',
      ).readAsStringSync();

      expect(gitignore, contains('lib/firebase_options*.dart'));
      expect(gitignore, contains('android/app/**/google-services.json'));
      expect(safeZip, contains('firebase_options*.dart'));
      expect(safeZip, contains('google-services*.json'));
    });
  });
}
