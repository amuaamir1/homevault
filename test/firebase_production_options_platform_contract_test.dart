import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 Production Firebase options platform contract', () {
    late String generator;

    setUpAll(() {
      generator = File(
        'scripts/firebase/New-HomeVault-ProductionFirebaseOptions.ps1',
      ).readAsStringSync();
    });

    test('Android remains the only supported Production platform', () {
      expect(generator, contains('case TargetPlatform.android:'));
      expect(generator, contains('return android;'));
      expect(
        generator,
        contains(
          'HomeVault Production Firebase is currently configured for '
          'Android only.',
        ),
      );
    });

    test('all non-Android Flutter TargetPlatform cases are handled', () {
      for (final platform in ['iOS', 'macOS', 'windows', 'linux', 'fuchsia']) {
        expect(
          generator,
          contains('case TargetPlatform.$platform:'),
          reason: 'Missing TargetPlatform.$platform in generated switch.',
        );
      }
    });

    test('Production configuration still rejects Development Firebase', () {
      expect(generator, contains('homevault-aamir-india-1701'));
      expect(
        generator,
        contains(
          'Production Firebase options cannot target the HomeVault '
          'Development project.',
        ),
      );
    });
  });
}
