import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 Firebase SDK config resilience contract', () {
    test('provision downloads to a candidate file before replacing config', () {
      final source = File(
        'scripts/firebase/Provision-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();

      expect(source, contains('google-services.candidate.json'));
      expect(source, contains('Read-ValidatedGoogleServices'));
      expect(
        source,
        contains('Continuing with the previously validated Production config'),
      );
      expect(
        source,
        contains(
          'Production google-services.json failed project/package/App-ID '
          'validation.',
        ),
      );
      expect(source, contains('Firebase Console -> Project settings ->'));
    });

    test('finalization never blindly replaces the known-good config', () {
      final source = File(
        'scripts/firebase/Finalize-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();

      expect(source, contains('google-services.candidate.json'));
      expect(source, contains('-AllowFailure'));
      expect(
        source,
        contains('Finalization will validate the existing external config'),
      );
      expect(
        source,
        contains(
          'does not match the expected Android package and Firebase App ID',
        ),
      );
    });

    test('final Production gates still require Storage and web OAuth', () {
      final source = File(
        'scripts/firebase/Finalize-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'Production Cloud Storage default bucket is not present in '
          'google-services.json',
        ),
      );
      expect(
        source,
        contains('Production google-services.json has no web OAuth client'),
      );
      expect(source, contains('ConfirmBlazeAndStorage'));
      expect(source, contains('ConfirmAuthConfigured'));
      expect(source, contains('ConfirmProductionRules'));
    });
  });
}
