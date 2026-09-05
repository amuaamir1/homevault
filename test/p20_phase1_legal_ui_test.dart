import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/core/homevault_legal_links.dart';
import 'package:homevault/screens/settings/about_legal_screen.dart';
import 'package:homevault/screens/settings/account_data_deletion_info_screen.dart';

void main() {
  group('P20.1 Play Store legal UI', () {
    testWidgets('About & Legal exposes required release-readiness entries', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: AboutLegalScreen()));

      expect(find.text('About & Legal'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Account & Data Deletion'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('Open-source licenses'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('aboutLegalVersionText')),
        findsOneWidget,
      );
    });

    testWidgets('account deletion information exposes app and web paths', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: AccountDataDeletionInfoScreen()),
      );

      expect(find.text('Account & Data Deletion'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('deleteAccountInAppButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('openWebDeletionPageButton')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Settings → Account & Data → Delete account'),
        findsOneWidget,
      );
    });

    test('legal links reject empty and unsafe default configuration', () {
      expect(HomeVaultLegalLinks.privacyPolicyUri, isNull);
      expect(HomeVaultLegalLinks.termsOfServiceUri, isNull);
      expect(HomeVaultLegalLinks.accountDeletionUri, isNull);
      expect(HomeVaultLegalLinks.supportEmailUri, isNull);
      expect(HomeVaultLegalLinks.hasProductionLegalLinks, isFalse);
    });

    test(
      'Settings contains the About & Legal route and no Beta version label',
      () {
        final settings = File(
          'lib/screens/settings/settings_screen.dart',
        ).readAsStringSync();

        expect(settings, contains("ValueKey('settingsAboutLegalTile')"));
        expect(settings, contains('AboutLegalScreen'));
        expect(settings, isNot(contains("const Text('Beta ")));
      },
    );
  });
}
