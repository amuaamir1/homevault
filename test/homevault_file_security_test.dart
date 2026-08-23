import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/security/homevault_file_security.dart';

void main() {
  group('HomeVault file signature validation', () {
    test('accepts PDF, JPEG, and PNG signatures that match the extension', () {
      expect(
        HomeVaultFileSecurity.validateBytes(
          Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 0x2d, 0x31]),
          fileName: 'invoice.pdf',
          maximumBytes: 1024,
          allowedExtensions: const {'pdf', 'jpg', 'jpeg', 'png'},
        ),
        'application/pdf',
      );

      expect(
        HomeVaultFileSecurity.validateBytes(
          Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xe0]),
          fileName: 'photo.jpeg',
          maximumBytes: 1024,
          allowedExtensions: const {'jpg', 'jpeg', 'png'},
        ),
        'image/jpeg',
      );

      expect(
        HomeVaultFileSecurity.validateBytes(
          Uint8List.fromList(<int>[
            0x89,
            0x50,
            0x4e,
            0x47,
            0x0d,
            0x0a,
            0x1a,
            0x0a,
            0x00,
          ]),
          fileName: 'photo.png',
          maximumBytes: 1024,
          allowedExtensions: const {'jpg', 'jpeg', 'png'},
        ),
        'image/png',
      );
    });

    test('rejects content whose signature does not match its extension', () {
      expect(
        () => HomeVaultFileSecurity.validateBytes(
          Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xe0]),
          fileName: 'renamed.pdf',
          maximumBytes: 1024,
          allowedExtensions: const {'pdf', 'jpg', 'jpeg', 'png'},
        ),
        throwsA(isA<HomeVaultFileSecurityException>()),
      );
    });

    test('rejects unsupported extensions and oversized input', () {
      expect(
        () => HomeVaultFileSecurity.validateBytes(
          Uint8List.fromList(<int>[0x47, 0x49, 0x46, 0x38]),
          fileName: 'image.gif',
          maximumBytes: 1024,
          allowedExtensions: const {'jpg', 'jpeg', 'png'},
        ),
        throwsA(isA<HomeVaultFileSecurityException>()),
      );

      expect(
        () => HomeVaultFileSecurity.validateBytes(
          Uint8List.fromList(List<int>.filled(20, 0)),
          fileName: 'invoice.pdf',
          maximumBytes: 10,
          allowedExtensions: const {'pdf'},
        ),
        throwsA(isA<HomeVaultFileSecurityException>()),
      );
    });
  });
}
