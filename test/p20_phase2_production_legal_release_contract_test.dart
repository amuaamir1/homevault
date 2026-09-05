import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P20.2 production legal release configuration', () {
    test('production build injects the live HomeVault legal configuration', () {
      final script = File(
        'scripts/firebase/Build-HomeVault-Production.ps1',
      ).readAsStringSync();

      expect(
        script,
        contains('https://homevault-prod-in-2026-a1.web.app/privacy'),
      );
      expect(
        script,
        contains('https://homevault-prod-in-2026-a1.web.app/terms'),
      );
      expect(
        script,
        contains('https://homevault-prod-in-2026-a1.web.app/delete-account'),
      );
      expect(script, contains('support.homevault1@gmail.com'));

      for (final key in <String>[
        'HOMEVAULT_PRIVACY_POLICY_URL',
        'HOMEVAULT_TERMS_OF_SERVICE_URL',
        'HOMEVAULT_ACCOUNT_DELETION_URL',
        'HOMEVAULT_SUPPORT_EMAIL',
      ]) {
        expect(script, contains('--dart-define=$key='));
        expect(script, contains(r'$env:' + key));
      }
    });

    test('Android release builds enforce legal configuration', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      for (final key in <String>[
        'HOMEVAULT_PRIVACY_POLICY_URL',
        'HOMEVAULT_TERMS_OF_SERVICE_URL',
        'HOMEVAULT_ACCOUNT_DELETION_URL',
        'HOMEVAULT_SUPPORT_EMAIL',
      ]) {
        expect(gradle, contains('System.getenv("$key")'));
      }

      expect(gradle, contains('isSafePublicHttpsUrl'));
      expect(gradle, contains('looksLikePublicSupportEmail'));
      expect(
        gradle,
        contains('Release Privacy Policy URL is missing or unsafe'),
      );
      expect(
        gradle,
        contains('Release account-deletion URL is missing or unsafe'),
      );
      expect(gradle, contains('Release support email is missing or invalid'));
    });

    test('release configuration has no placeholder or local legal URL', () {
      final script = File(
        'scripts/firebase/Build-HomeVault-Production.ps1',
      ).readAsStringSync();

      expect(script, isNot(contains('HOMEVAULT_SUPPORT_EMAIL_PLACEHOLDER')));
      expect(script, isNot(contains('http://localhost')));
      expect(script, isNot(contains('http://127.0.0.1')));
    });
  });
}
