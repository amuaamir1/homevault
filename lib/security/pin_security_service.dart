import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'security_scope_key.dart';

class PinSecurityService {
  PinSecurityService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _legacyPinSaltKey = 'homevault.pin.salt.v1';
  static const _legacyPinHashKey = 'homevault.pin.hash.v1';
  static const _legacyPinSetupCompleteKey = 'homevault.pin.setup.complete.v1';

  final FlutterSecureStorage _storage;
  String? _scope;

  String get _pinSaltKey => _scopedKey('salt');
  String get _pinHashKey => _scopedKey('hash');
  String get _pinSetupCompleteKey => _scopedKey('setup.complete');

  String _scopedKey(String suffix) {
    final scope = _scope;
    if (scope == null) {
      return switch (suffix) {
        'salt' => _legacyPinSaltKey,
        'hash' => _legacyPinHashKey,
        _ => _legacyPinSetupCompleteKey,
      };
    }
    return 'homevault.pin.$scope.$suffix.v2';
  }

  Future<void> bindUser(String uid) async {
    _scope = securityScopeKey(uid);
    await _migrateLegacyValues();
  }

  Future<void> _migrateLegacyValues() async {
    if (_scope == null || await hasPin()) return;

    final values = await Future.wait([
      _storage.read(key: _legacyPinSaltKey),
      _storage.read(key: _legacyPinHashKey),
      _storage.read(key: _legacyPinSetupCompleteKey),
    ]);

    final legacySalt = values[0];
    final legacyHash = values[1];
    final legacySetup = values[2];

    if (legacySalt?.isNotEmpty == true && legacyHash?.isNotEmpty == true) {
      await Future.wait([
        _storage.write(key: _pinSaltKey, value: legacySalt),
        _storage.write(key: _pinHashKey, value: legacyHash),
        _storage.write(key: _pinSetupCompleteKey, value: legacySetup ?? 'true'),
      ]);

      await Future.wait([
        _storage.delete(key: _legacyPinSaltKey),
        _storage.delete(key: _legacyPinHashKey),
        _storage.delete(key: _legacyPinSetupCompleteKey),
      ]);
    }
  }

  Future<bool> hasPin() async {
    final values = await Future.wait([
      _storage.read(key: _pinSaltKey),
      _storage.read(key: _pinHashKey),
    ]);

    return values[0]?.isNotEmpty == true && values[1]?.isNotEmpty == true;
  }

  Future<bool> hasCompletedPinSetup() async {
    if (await hasPin()) return true;
    return await _storage.read(key: _pinSetupCompleteKey) == 'true';
  }

  Future<void> createPin(String pin) async {
    _validatePin(pin);

    final saltBytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    final salt = base64UrlEncode(saltBytes);
    final hash = await _deriveHash(pin: pin, salt: salt);

    await Future.wait([
      _storage.write(key: _pinSaltKey, value: salt),
      _storage.write(key: _pinHashKey, value: hash),
      _storage.write(key: _pinSetupCompleteKey, value: 'true'),
    ]);
  }

  Future<void> markPinSetupSkipped() async {
    await _storage.write(key: _pinSetupCompleteKey, value: 'true');
  }

  Future<bool> verifyPin(String pin) async {
    if (!_isValidPin(pin)) return false;

    final salt = await _storage.read(key: _pinSaltKey);
    final expectedHash = await _storage.read(key: _pinHashKey);
    if (salt == null || expectedHash == null) return false;

    final actualHash = await _deriveHash(pin: pin, salt: salt);
    return _constantTimeEquals(actualHash, expectedHash);
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!await verifyPin(currentPin)) return false;
    await createPin(newPin);
    return true;
  }

  Future<void> clearPin({bool markSetupComplete = true}) async {
    final operations = <Future<void>>[
      _storage.delete(key: _pinSaltKey),
      _storage.delete(key: _pinHashKey),
    ];

    if (markSetupComplete) {
      operations.add(_storage.write(key: _pinSetupCompleteKey, value: 'true'));
    } else {
      operations.add(_storage.delete(key: _pinSetupCompleteKey));
    }

    await Future.wait(operations);
  }

  static bool isValidPin(String pin) => _isValidPin(pin);

  static bool _isValidPin(String pin) {
    return RegExp(r'^\d{4,8}$').hasMatch(pin);
  }

  static void _validatePin(String pin) {
    if (!_isValidPin(pin)) {
      throw const FormatException('PIN must contain 4 to 8 digits.');
    }
  }

  static Future<String> _deriveHash({
    required String pin,
    required String salt,
  }) {
    return Isolate.run(() => _derivePinHash((pin: pin, salt: salt)));
  }

  static bool _constantTimeEquals(String first, String second) {
    if (first.length != second.length) return false;

    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first.codeUnitAt(index) ^ second.codeUnitAt(index);
    }
    return difference == 0;
  }
}

String _derivePinHash(({String pin, String salt}) input) {
  final saltBytes = utf8.encode(input.salt);
  List<int> digestBytes = utf8.encode('${input.salt}:${input.pin}');

  for (var round = 0; round < 25000; round++) {
    digestBytes = sha256.convert([...digestBytes, ...saltBytes]).bytes;
  }

  return base64UrlEncode(digestBytes);
}
