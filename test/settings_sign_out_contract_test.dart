import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings sign out is bottom-level and preserves lock lifecycle', () {
    final source = File(
      'lib/screens/settings/settings_screen.dart',
    ).readAsStringSync();

    final serviceIndex = source.indexOf("title: const Text('Service center')");
    final signOutIndex = source.indexOf("ValueKey('settingsSignOutTile')");

    expect(serviceIndex, greaterThanOrEqualTo(0));
    expect(signOutIndex, greaterThan(serviceIndex));
    expect(source, contains("title: const Text('Sign out')"));
    expect(source, contains('lockController.prepareForSignOut();'));
    expect(source, contains('await authController.signOut();'));

    final prepareIndex = source.indexOf('lockController.prepareForSignOut();');
    final authIndex = source.indexOf('await authController.signOut();');
    expect(prepareIndex, greaterThanOrEqualTo(0));
    expect(authIndex, greaterThan(prepareIndex));
  });
}
