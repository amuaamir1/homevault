import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 Phase 3 production readiness contract', () {
    late String readiness;
    late String recorder;
    late String checklist;

    setUpAll(() {
      readiness = File(
        'scripts/firebase/Test-HomeVault-Production-Readiness.ps1',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      recorder = File(
        'scripts/firebase/Record-HomeVault-P16-Phase3-Device-Smoke.ps1',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      checklist = File(
        'docs/P16_PHASE3_DEVICE_SMOKE.md',
      ).readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('keeps Production and Development Firebase projects explicit', () {
      expect(readiness, contains('homevault-prod-in-2026-a1'));
      expect(readiness, contains('homevault-aamir-india-1701'));
      expect(
        readiness,
        contains('Production and Development project IDs must be different'),
      );
    });

    test('locks the exact hardened Firebase rules hashes', () {
      expect(
        readiness,
        contains(
          '6c1719fbc83104953d1ef9cd62660e8d55dcbf2485712b6af08d523238deb0a7',
        ),
      );
      expect(
        readiness,
        contains(
          '1606d4fbde8ffb7fd5dd6427794d1f6490ef2d283de18780b67df89fbf4dae21',
        ),
      );
    });

    test('validates the Production Android identity and release certificate', () {
      expect(readiness, contains('com.amuaamir.homevault'));
      expect(
        readiness,
        contains('1:676132710044:android:04d03b44c9b8e182afef59'),
      );
      expect(
        readiness,
        contains('55:BD:58:B0:89:20:AD:F7:55:F1:05:F1:21:7E:D2:DE:90:9C:A9:EE'),
      );
      expect(
        readiness,
        contains(
          '21:B1:30:D8:3C:0B:84:D5:96:31:F3:EC:89:1E:E2:9A:96:81:C2:07:5F:F8:D0:67:ED:88:43:07:2B:9D:D2:4E',
        ),
      );
      expect(readiness, contains('apksigner.bat'));
    });

    test(
      'checks build-time restoration and prevents Production default alias',
      () {
        expect(
          readiness,
          contains('.firebaserc does not default to Production'),
        );
        expect(
          readiness,
          contains('Local google-services.json restored to Development'),
        );
        expect(
          readiness,
          contains('Local firebase_options.dart restored to Development'),
        );
        expect(readiness, contains('finally'));
      },
    );

    test('keeps the readiness validator read-only toward Firebase', () {
      expect(readiness, isNot(contains('firebase deploy')));
      expect(readiness, isNot(contains('apps:android:sha:create')));
      expect(readiness, isNot(contains('projects:create')));
    });

    test('tracks every Production device acceptance area', () {
      for (final marker in <String>[
        'EmailPasswordPinFlow',
        'GoogleSignIn',
        'DocumentVault',
        'CloudBackup',
        'BetaFeedback',
        'Persistence',
        'ProductionIsolation',
      ]) {
        expect(recorder, contains(marker));
      }
      expect(recorder, contains("'INCOMPLETE'"));
      expect(recorder, contains("'PASS'"));
      expect(recorder, contains("'FAIL'"));
    });

    test('documents the real-device smoke acceptance flows', () {
      expect(checklist, contains('Email/password + PIN'));
      expect(checklist, contains('Google Sign-In'));
      expect(checklist, contains('Document Vault'));
      expect(checklist, contains('Cloud backup'));
      expect(checklist, contains('Beta feedback'));
      expect(checklist, contains('Persistence'));
      expect(checklist, contains('Production isolation'));
    });
  });
}
