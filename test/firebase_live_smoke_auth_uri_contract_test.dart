import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 Production Firebase live smoke Auth URI contract', () {
    late String smoke;

    setUpAll(() {
      smoke = File(
        'scripts/firebase/Test-HomeVault-ProductionFirebase-Live.ps1',
      ).readAsStringSync();
    });

    test('terminates Action interpolation before Firebase API key query', () {
      expect(
        smoke,
        contains(
          r'"https://identitytoolkit.googleapis.com/v1/accounts:$Action" + '
          r'"?key=$apiKey"',
        ),
      );

      expect(
        smoke,
        isNot(
          contains(
            r'"https://identitytoolkit.googleapis.com/v1/accounts:'
            r'$Action?key=$apiKey"',
          ),
        ),
      );
    });

    test(
      'retains sign-up, deletion, and Firestore isolation smoke coverage',
      () {
        expect(smoke, contains("-Action 'signUp'"));
        expect(smoke, contains("-Action 'delete'"));
        expect(smoke, contains('Production Firestore owner write is allowed'));
        expect(smoke, contains('Production Firestore owner read is allowed'));
        expect(
          smoke,
          contains('Production Firestore cross-user read is denied'),
        );
        expect(
          smoke,
          contains('Temporary Production Firebase Auth smoke user deleted'),
        );
      },
    );

    test('still refuses Development Firebase', () {
      expect(smoke, contains("homevault-aamir-india-1701"));
      expect(
        smoke,
        contains(
          'Production live smoke cannot target the Development Firebase project.',
        ),
      );
    });
  });
}
