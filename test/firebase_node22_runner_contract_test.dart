import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P16 stable Node 22 Firebase runner contract', () {
    test('cloud-operation scripts use Node 22 Firebase runner', () {
      final provision = File(
        'scripts/firebase/Provision-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();
      final finalizer = File(
        'scripts/firebase/Finalize-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();
      final deploy = File(
        'scripts/firebase/Deploy-HomeVault-Firebase-Rules.ps1',
      ).readAsStringSync();

      for (final script in [provision, finalizer, deploy]) {
        expect(script, contains(r'C:\Tools\Node22\node.exe'));
        expect(
          script,
          contains(r'npm\node_modules\firebase-tools\lib\bin\firebase.js'),
        );
        expect(script, contains('FirebaseNodeExe'));
        expect(script, contains('FirebaseCliJs'));
        expect(script, contains('Node 22'));
        expect(script, isNot(contains('Get-Command firebase.cmd')));
      }

      expect(
        provision,
        contains(r'& $script:FirebaseNodeExe $script:FirebaseCliJs @Arguments'),
      );
      expect(finalizer, contains(r'-FirebaseNodeExe $script:FirebaseNodeExe'));
      expect(finalizer, contains(r'-FirebaseCliJs $script:FirebaseCliJs'));
      expect(
        deploy,
        contains(r'& $script:FirebaseNodeExe $script:FirebaseCliJs deploy'),
      );
    });

    test('production safety confirmations remain in place', () {
      final provision = File(
        'scripts/firebase/Provision-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();
      final finalizer = File(
        'scripts/firebase/Finalize-HomeVault-ProductionFirebase.ps1',
      ).readAsStringSync();
      final deploy = File(
        'scripts/firebase/Deploy-HomeVault-Firebase-Rules.ps1',
      ).readAsStringSync();

      expect(provision, contains('ConfirmCreateProject'));
      expect(provision, contains('ConfirmCreateFirestore'));
      expect(provision, contains('homevault-aamir-india-1701'));
      expect(finalizer, contains('ConfirmProductionRules'));
      expect(deploy, contains('ConfirmProduction'));
      expect(deploy, contains('--project'));
    });
  });
}
