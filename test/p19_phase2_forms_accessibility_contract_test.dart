import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P19 Phase 2 core forms use the shared accessible form wrapper', () {
    for (final path in [
      'lib/screens/appliances/add_appliance_screen.dart',
      'lib/screens/documents/add_document_screen.dart',
      'lib/screens/service/add_service_record_screen.dart',
      'lib/screens/service/add_service_request_screen.dart',
      'lib/screens/profile/profile_screen.dart',
      'lib/screens/auth/pin_setup_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('HomeVaultAccessibleForm('), reason: path);
      expect(source, contains('HomeVaultFormValidationSummary('), reason: path);
      expect(source, contains('_showValidationSummary'), reason: path);
    }
  });

  test(
    'required core fields use spoken required labels instead of asterisks',
    () {
      final appliance = File(
        'lib/screens/appliances/add_appliance_screen.dart',
      ).readAsStringSync();
      final document = File(
        'lib/screens/documents/add_document_screen.dart',
      ).readAsStringSync();
      final serviceRequest = File(
        'lib/screens/service/add_service_request_screen.dart',
      ).readAsStringSync();
      final serviceRecord = File(
        'lib/screens/service/add_service_record_screen.dart',
      ).readAsStringSync();
      final profile = File(
        'lib/screens/profile/profile_screen.dart',
      ).readAsStringSync();

      expect(appliance, contains('Appliance name (required)'));
      expect(document, contains('Document title (required)'));
      expect(serviceRequest, contains('Service address (required)'));
      expect(serviceRecord, contains('Problem or complaint (required)'));
      expect(profile, contains('PIN code (required)'));

      expect(appliance, isNot(contains("labelText: 'Appliance name *'")));
      expect(document, isNot(contains("labelText: 'Document title *'")));
      expect(serviceRequest, isNot(contains("labelText: 'Service address *'")));
      expect(
        serviceRecord,
        isNot(contains("labelText: 'Problem or complaint *'")),
      );
      expect(profile, isNot(contains("labelText: 'PIN code *'")));
    },
  );

  test(
    'validation failures expose a live summary before save can continue',
    () {
      for (final path in [
        'lib/screens/appliances/add_appliance_screen.dart',
        'lib/screens/documents/add_document_screen.dart',
        'lib/screens/service/add_service_record_screen.dart',
        'lib/screens/service/add_service_request_screen.dart',
        'lib/screens/profile/profile_screen.dart',
        'lib/screens/auth/pin_setup_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains('setState(() => _showValidationSummary = true);'),
          reason: path,
        );
      }
    },
  );

  test('P19 Phase 1 accessibility foundation remains intact', () {
    final theme = File('lib/theme/app_theme.dart').readAsStringSync();
    final dashboard = File(
      'lib/screens/dashboard/dashboard_screen.dart',
    ).readAsStringSync();

    expect(
      theme,
      contains('materialTapTargetSize: MaterialTapTargetSize.padded'),
    );
    expect(dashboard, contains('HomeVaultAccessibility.responsiveColumnCount'));
    expect(dashboard, contains('Reminder center, no items need attention'));
  });
}
