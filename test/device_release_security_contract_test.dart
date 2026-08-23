import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P13 Phase 4 device and release security contract', () {
    test('Android backup and transport rules exclude private app data', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final legacyRules = File(
        'android/app/src/main/res/xml/backup_rules.xml',
      ).readAsStringSync();
      final extractionRules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(manifest, contains('android:usesCleartextTraffic="false"'));

      for (final domain in <String>[
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
      ]) {
        expect(legacyRules, contains('<exclude domain="$domain" path="."'));
        expect(extractionRules, contains('<exclude domain="$domain" path="."'));
      }

      expect(extractionRules, contains('<cloud-backup'));
      expect(extractionRules, contains('<device-transfer>'));
    });

    test('Crashlytics is natively disabled until release-mode opt-in', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final crashService = File(
        'lib/services/crash_reporting_service.dart',
      ).readAsStringSync();

      expect(
        manifest,
        contains('android:name="firebase_crashlytics_collection_enabled"'),
      );
      expect(manifest, contains('android:value="false"'));
      expect(
        crashService,
        contains('setCrashlyticsCollectionEnabled(kReleaseMode)'),
      );
      expect(crashService, contains('deleteUnsentReports()'));
      expect(crashService, contains('_SanitizedCrashException'));
      expect(crashService, isNot(contains('recordFlutterFatalError(details)')));
    });

    test('release signing never falls back to the debug key', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('releaseBuildRequested'));
      expect(gradle, contains('throw GradleException('));
      expect(gradle, contains('Release signing is not configured.'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    });

    test('authentication diagnostics exclude email, messages, and stacks', () {
      final authService = File(
        'lib/auth/email_auth_service.dart',
      ).readAsStringSync();

      expect(authService, contains('void _debugAuthEvent(String message)'));
      expect(authService, contains('if (kDebugMode)'));
      expect(authService, isNot(contains('email=${user.email}')));
      expect(authService, isNot(contains('message=${error.message}')));
      expect(authService, isNot(contains('debugPrintStack(')));
    });

    test('credential file patterns are excluded from source control', () {
      final gitignore = File('.gitignore').readAsStringSync();
      final scanScript = File(
        'scripts/Test-HomeVault-Release-Security.ps1',
      ).readAsStringSync();

      for (final pattern in <String>[
        'android/key.properties',
        '*.jks',
        '*.keystore',
        '*.p12',
        '*.pfx',
        '*.pem',
        '*.key',
        '.env',
        '**/*service-account*.json',
        '**/*adminsdk*.json',
      ]) {
        expect(gitignore, contains(pattern));
      }

      expect(scanScript, contains('git ls-files'));
      expect(scanScript, contains('BEGIN PRIVATE KEY'));
      expect(scanScript, contains('aws_secret_access_key'));
    });
  });
}
