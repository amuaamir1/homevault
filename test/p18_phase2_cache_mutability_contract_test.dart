import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApplianceStore owns a mutable cache-policy snapshot', () {
    final source = File('lib/state/appliance_store.dart').readAsStringSync();

    final assignmentIndex = source.indexOf(
      '_evictedCloudDocumentPaths = nextOwner == null',
    );
    final mutableCopyIndex = source.indexOf(
      'Set<String>.from(',
      assignmentIndex,
    );
    final policyReadIndex = source.indexOf(
      'await _localDocumentCachePolicy.evictedCloudPaths()',
      mutableCopyIndex,
    );

    expect(assignmentIndex, greaterThanOrEqualTo(0));
    expect(mutableCopyIndex, greaterThan(assignmentIndex));
    expect(policyReadIndex, greaterThan(mutableCopyIndex));

    // Guard against the original bug: the policy's immutable snapshot must
    // never be assigned directly into ApplianceStore's mutable working state.
    expect(
      source,
      isNot(contains(': await _localDocumentCachePolicy.evictedCloudPaths();')),
    );
  });

  test(
    'cache availability is updated in memory only after policy persistence',
    () {
      final source = File('lib/state/appliance_store.dart').readAsStringSync();

      final persistIndex = source.indexOf(
        'await _localDocumentCachePolicy.markAvailable([normalized]);',
      );
      final memoryIndex = source.indexOf(
        '_evictedCloudDocumentPaths.remove(normalized);',
        persistIndex,
      );

      expect(persistIndex, greaterThanOrEqualTo(0));
      expect(memoryIndex, greaterThan(persistIndex));
    },
  );
}
