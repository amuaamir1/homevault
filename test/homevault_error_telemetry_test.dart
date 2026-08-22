import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/homevault_error_telemetry.dart';

void main() {
  test('classifies common technical failures into stable categories', () {
    expect(
      classifyHomeVaultError(
        FirebaseException(plugin: 'test', code: 'permission-denied'),
      ),
      HomeVaultErrorCategory.authorization,
    );
    expect(
      classifyHomeVaultError(
        FirebaseException(plugin: 'test', code: 'unavailable'),
      ),
      HomeVaultErrorCategory.connectivity,
    );
    expect(
      classifyHomeVaultError(TimeoutException('slow')),
      HomeVaultErrorCategory.timeout,
    );
    expect(
      classifyHomeVaultError(const SocketException('offline')),
      HomeVaultErrorCategory.connectivity,
    );
    expect(
      classifyHomeVaultError(
        ApplianceConflictException(
          applianceId: 'test-appliance',
          message: 'conflict',
        ),
      ),
      HomeVaultErrorCategory.conflict,
    );
    expect(
      classifyHomeVaultError(PlatformException(code: 'permission_denied')),
      HomeVaultErrorCategory.devicePermission,
    );
  });

  test('normalizes operation labels into stable telemetry keys', () {
    expect(
      normalizeHomeVaultOperationKey(' Saving the user profile '),
      'saving.the.user.profile',
    );
    expect(normalizeHomeVaultOperationKey(''), 'unspecified');
  });

  test('telemetry context excludes identifiers, paths and secrets', () {
    final context = safeHomeVaultTelemetryContext(<String, Object?>{
      'source': 'automatic_backup',
      'phase': 'restore',
      'attempt': 2,
      'isRetry': true,
      'uid': 'real-user-id',
      'email': 'person@example.com',
      'filePath': '/private/user/file.pdf',
      'token': 'secret-token',
      'name': 'Private Name',
      'freeText': 'should not be collected',
    });

    expect(context['source'], 'automatic.backup');
    expect(context['phase'], 'restore');
    expect(context['attempt'], '2');
    expect(context['isretry'], 'true');
    expect(context, isNot(contains('uid')));
    expect(context, isNot(contains('email')));
    expect(context, isNot(contains('filepath')));
    expect(context, isNot(contains('token')));
    expect(context, isNot(contains('name')));
    expect(context, isNot(contains('freetext')));
  });

  test(
    'Crashlytics reason contains category and normalized operation only',
    () {
      final telemetry = HomeVaultErrorTelemetry.fromError(
        FirebaseException(plugin: 'test', code: 'unavailable'),
        operation: 'Creating scheduled backup',
        context: const <String, Object?>{'source': 'automatic'},
      );

      expect(telemetry.crashReason, 'connectivity:creating.scheduled.backup');
      expect(telemetry.logLine, contains('category=connectivity'));
      expect(
        telemetry.logLine,
        contains('operation=creating.scheduled.backup'),
      );
      expect(telemetry.logLine, contains('source=automatic'));
    },
  );
}
