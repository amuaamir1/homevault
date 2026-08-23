import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'security_scope_key.dart';

class PinSecurityService {
  PinSecurityService({FlutterSecureStorage? storage, DateTime Function()? now})
    : _storage = storage ?? const FlutterSecureStorage(),
      _now = now ?? DateTime.now;

  static const _legacyPinSaltKey = 'homevault.pin.salt.v1';
  static const _legacyPinHashKey = 'homevault.pin.hash.v1';
  static const _legacyPinSetupCompleteKey = 'homevault.pin.setup.complete.v1';
  static const _legacyPinHistoryKey = 'homevault.pin.history.v1';
  static const _pinHistoryLimit = 4;
  static const _attemptsPerLockoutTier = 5;

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  String? _scope;

  String get _pinSaltKey => _scopedKey('salt');
  String get _pinHashKey => _scopedKey('hash');
  String get _pinSetupCompleteKey => _scopedKey('setup.complete');
  String get _pinHistoryKey {
    final scope = _scope;
    if (scope == null) return _legacyPinHistoryKey;
    return 'homevault.pin.$scope.history.v2';
  }

  String get _failedAttemptsKey {
    final scope = _scope;
    return scope == null
        ? 'homevault.pin.failed.attempts.v1'
        : 'homevault.pin.$scope.failed.attempts.v1';
  }

  String get _lockedUntilKey {
    final scope = _scope;
    return scope == null
        ? 'homevault.pin.locked.until.v1'
        : 'homevault.pin.$scope.locked.until.v1';
  }

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
    await _rememberCurrentPin();
  }

  Future<void> _migrateLegacyValues() async {
    if (_scope == null || await hasPin()) return;

    final values = await Future.wait([
      _storage.read(key: _legacyPinSaltKey),
      _storage.read(key: _legacyPinHashKey),
      _storage.read(key: _legacyPinSetupCompleteKey),
      _storage.read(key: _legacyPinHistoryKey),
    ]);

    final legacySalt = values[0];
    final legacyHash = values[1];
    final legacySetup = values[2];
    final legacyHistory = values[3];

    final writes = <Future<void>>[];
    if (legacySalt?.isNotEmpty == true && legacyHash?.isNotEmpty == true) {
      writes.addAll([
        _storage.write(key: _pinSaltKey, value: legacySalt),
        _storage.write(key: _pinHashKey, value: legacyHash),
        _storage.write(key: _pinSetupCompleteKey, value: legacySetup ?? 'true'),
      ]);
    }
    if (legacyHistory?.isNotEmpty == true) {
      writes.add(_storage.write(key: _pinHistoryKey, value: legacyHistory));
    }

    if (writes.isNotEmpty) {
      await Future.wait(writes);
      await Future.wait([
        _storage.delete(key: _legacyPinSaltKey),
        _storage.delete(key: _legacyPinHashKey),
        _storage.delete(key: _legacyPinSetupCompleteKey),
        _storage.delete(key: _legacyPinHistoryKey),
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

    // Defensive guard for callers that attempt to create a PIN while a current
    // PIN still exists. Normal UI flows use changePin instead.
    await _rememberCurrentPin();
    if (await isPinInRecentHistory(pin)) {
      throw const PinReuseException();
    }

    await _savePin(pin);
    await clearFailedAttempts();
  }

  Future<void> _savePin(String pin) async {
    final saltBytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    final salt = base64UrlEncode(saltBytes);
    final hash = await _deriveHash(pin: pin, salt: salt);
    final history = await _historyWithEntryAdded(
      _PinHistoryEntry(salt: salt, hash: hash),
    );

    await Future.wait([
      _storage.write(key: _pinSaltKey, value: salt),
      _storage.write(key: _pinHashKey, value: hash),
      _storage.write(key: _pinSetupCompleteKey, value: 'true'),
      _writeHistory(history),
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

  /// Verifies a PIN while enforcing durable, account-scoped brute-force
  /// protection. Failed-attempt state lives in secure storage, so rebuilding
  /// the unlock screen or restarting HomeVault cannot bypass a lockout.
  Future<PinUnlockResult> verifyPinWithProtection(String pin) async {
    final currentStatus = await getAttemptStatus();
    if (currentStatus.isLockedAt(_now())) {
      return PinUnlockResult.locked(currentStatus);
    }

    final isValid = await verifyPin(pin);
    if (isValid) {
      await clearFailedAttempts();
      return const PinUnlockResult.success();
    }

    final failedAttempts = currentStatus.failedAttempts + 1;
    final lockoutDuration = _lockoutDurationForAttempt(failedAttempts);
    final lockedUntil = lockoutDuration == null
        ? null
        : _now().add(lockoutDuration);

    await Future.wait([
      _storage.write(key: _failedAttemptsKey, value: failedAttempts.toString()),
      if (lockedUntil != null)
        _storage.write(
          key: _lockedUntilKey,
          value: lockedUntil.millisecondsSinceEpoch.toString(),
        )
      else
        _storage.delete(key: _lockedUntilKey),
    ]);

    return PinUnlockResult.failure(
      PinAttemptStatus(
        failedAttempts: failedAttempts,
        lockedUntil: lockedUntil,
      ),
    );
  }

  Future<PinAttemptStatus> getAttemptStatus() async {
    final values = await Future.wait([
      _storage.read(key: _failedAttemptsKey),
      _storage.read(key: _lockedUntilKey),
    ]);

    final attempts = int.tryParse(values[0] ?? '') ?? 0;
    final lockedUntilMillis = int.tryParse(values[1] ?? '');
    final lockedUntil = lockedUntilMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockedUntilMillis);

    if (lockedUntil != null && !_now().isBefore(lockedUntil)) {
      await _storage.delete(key: _lockedUntilKey);
      return PinAttemptStatus(failedAttempts: attempts);
    }

    return PinAttemptStatus(failedAttempts: attempts, lockedUntil: lockedUntil);
  }

  Future<void> clearFailedAttempts() async {
    await Future.wait([
      _storage.delete(key: _failedAttemptsKey),
      _storage.delete(key: _lockedUntilKey),
    ]);
  }

  static Duration? _lockoutDurationForAttempt(int failedAttempts) {
    if (failedAttempts <= 0 || failedAttempts % _attemptsPerLockoutTier != 0) {
      return null;
    }

    if (failedAttempts >= 15) return const Duration(minutes: 10);
    if (failedAttempts >= 10) return const Duration(minutes: 2);
    return const Duration(seconds: 30);
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!await verifyPin(currentPin)) return false;

    // Existing users may already have a PIN from before PIN history was
    // introduced. Preserve its current salt/hash before checking the new PIN
    // so the current PIN immediately becomes part of the last-four policy.
    await _rememberCurrentPin();

    if (await isPinInRecentHistory(newPin)) {
      throw const PinReuseException();
    }

    await _savePin(newPin);
    await clearFailedAttempts();
    return true;
  }

  Future<bool> isPinInRecentHistory(String pin) async {
    _validatePin(pin);

    final history = await _readHistory();
    for (final entry in history) {
      final actualHash = await _deriveHash(pin: pin, salt: entry.salt);
      if (_constantTimeEquals(actualHash, entry.hash)) {
        return true;
      }
    }
    return false;
  }

  Future<void> clearPin({
    bool markSetupComplete = true,
    bool clearHistory = false,
  }) async {
    if (!clearHistory) {
      // Account recovery clears the active PIN but intentionally keeps the
      // recent-PIN history, including a PIN created before this feature.
      await _rememberCurrentPin();
    }

    final operations = <Future<void>>[
      _storage.delete(key: _pinSaltKey),
      _storage.delete(key: _pinHashKey),
      _storage.delete(key: _failedAttemptsKey),
      _storage.delete(key: _lockedUntilKey),
    ];

    if (markSetupComplete) {
      operations.add(_storage.write(key: _pinSetupCompleteKey, value: 'true'));
    } else {
      operations.add(_storage.delete(key: _pinSetupCompleteKey));
    }

    if (clearHistory) {
      operations.add(_storage.delete(key: _pinHistoryKey));
    }

    await Future.wait(operations);
  }

  Future<void> _rememberCurrentPin() async {
    final values = await Future.wait([
      _storage.read(key: _pinSaltKey),
      _storage.read(key: _pinHashKey),
    ]);
    final salt = values[0];
    final hash = values[1];
    if (salt?.isNotEmpty != true || hash?.isNotEmpty != true) return;

    final history = await _historyWithEntryAdded(
      _PinHistoryEntry(salt: salt!, hash: hash!),
    );
    await _writeHistory(history);
  }

  Future<List<_PinHistoryEntry>> _historyWithEntryAdded(
    _PinHistoryEntry entry,
  ) async {
    final history = await _readHistory();
    history.removeWhere(
      (existing) => existing.salt == entry.salt && existing.hash == entry.hash,
    );
    history.insert(0, entry);
    if (history.length > _pinHistoryLimit) {
      history.removeRange(_pinHistoryLimit, history.length);
    }
    return history;
  }

  Future<List<_PinHistoryEntry>> _readHistory() async {
    final encoded = await _storage.read(key: _pinHistoryKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return <_PinHistoryEntry>[];
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <_PinHistoryEntry>[];

      final history = <_PinHistoryEntry>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final salt = '${value['salt'] ?? ''}'.trim();
        final hash = '${value['hash'] ?? ''}'.trim();
        if (salt.isEmpty || hash.isEmpty) continue;
        history.add(_PinHistoryEntry(salt: salt, hash: hash));
        if (history.length == _pinHistoryLimit) break;
      }
      return history;
    } catch (_) {
      // A damaged history entry must not prevent access to the current PIN.
      return <_PinHistoryEntry>[];
    }
  }

  Future<void> _writeHistory(List<_PinHistoryEntry> history) {
    return _storage.write(
      key: _pinHistoryKey,
      value: jsonEncode(history.map((entry) => entry.toJson()).toList()),
    );
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

class PinAttemptStatus {
  const PinAttemptStatus({this.failedAttempts = 0, this.lockedUntil});

  final int failedAttempts;
  final DateTime? lockedUntil;

  bool isLockedAt(DateTime now) {
    final until = lockedUntil;
    return until != null && now.isBefore(until);
  }

  int secondsRemainingAt(DateTime now) {
    final until = lockedUntil;
    if (until == null || !now.isBefore(until)) return 0;
    final milliseconds = until.difference(now).inMilliseconds;
    return (milliseconds + 999) ~/ 1000;
  }
}

class PinUnlockResult {
  const PinUnlockResult._({
    required this.isValid,
    required this.status,
    required this.wasLockedBeforeAttempt,
  });

  const PinUnlockResult.success()
    : this._(
        isValid: true,
        status: const PinAttemptStatus(),
        wasLockedBeforeAttempt: false,
      );

  PinUnlockResult.failure(PinAttemptStatus status)
    : this._(isValid: false, status: status, wasLockedBeforeAttempt: false);

  PinUnlockResult.locked(PinAttemptStatus status)
    : this._(isValid: false, status: status, wasLockedBeforeAttempt: true);

  final bool isValid;
  final PinAttemptStatus status;
  final bool wasLockedBeforeAttempt;
}

class PinReuseException implements Exception {
  const PinReuseException([
    this.message = 'You cannot reuse one of your last 4 PINs.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class _PinHistoryEntry {
  const _PinHistoryEntry({required this.salt, required this.hash});

  final String salt;
  final String hash;

  Map<String, String> toJson() => {'salt': salt, 'hash': hash};
}

String _derivePinHash(({String pin, String salt}) input) {
  final saltBytes = utf8.encode(input.salt);
  List<int> digestBytes = utf8.encode('${input.salt}:${input.pin}');

  for (var round = 0; round < 25000; round++) {
    digestBytes = sha256.convert([...digestBytes, ...saltBytes]).bytes;
  }

  return base64UrlEncode(digestBytes);
}
