import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/cloud_backup_service.dart';
import 'package:homevault/services/homevault_error_message.dart';

void main() {
  group('friendlyHomeVaultError', () {
    test('preserves trusted HomeVault exception messages', () {
      expect(
        friendlyHomeVaultError(
          const ApplianceConflictException(
            applianceId: 'ac-1',
            message:
                'This appliance was updated on another device. Reopen it and try again.',
          ),
        ),
        'This appliance was updated on another device. Reopen it and try again.',
      );

      expect(
        friendlyHomeVaultError(
          const CloudBackupException(
            'Cloud backup is temporarily unavailable.',
          ),
        ),
        'Cloud backup is temporarily unavailable.',
      );
    });

    test('maps Firebase technical codes to user-facing messages', () {
      final message = friendlyHomeVaultError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.',
        ),
      );

      expect(message, contains('permission'));
      expect(message, isNot(contains('Firebase')));
      expect(message, isNot(contains('security rules')));
    });

    test('maps timeout and network errors without exposing internals', () {
      expect(
        friendlyHomeVaultError(TimeoutException('internal timeout details')),
        contains('taking longer than expected'),
      );

      final socketMessage = friendlyHomeVaultError(
        SocketException('Failed host lookup: secret.internal.example'),
      );
      expect(socketMessage, contains('internet connection'));
      expect(socketMessage, isNot(contains('secret.internal.example')));
    });

    test('maps filesystem and malformed-data errors', () {
      expect(
        friendlyHomeVaultError(
          FileSystemException('Permission denied', '/private/path'),
        ),
        contains('required file'),
      );

      expect(
        friendlyHomeVaultError(const FormatException('raw parser details')),
        contains('saved data'),
      );
    });

    test('maps platform permission errors', () {
      final message = friendlyHomeVaultError(
        PlatformException(
          code: 'permission_denied',
          message: 'android.permission.READ_MEDIA_IMAGES',
        ),
      );

      expect(message, contains('required device permission'));
      expect(message, isNot(contains('READ_MEDIA_IMAGES')));
    });

    test('uses caller fallback for unknown exceptions', () {
      expect(
        friendlyHomeVaultError(
          StateError('database implementation details'),
          fallback: 'HomeVault could not finish this action.',
        ),
        'HomeVault could not finish this action.',
      );
    });
  });
}
