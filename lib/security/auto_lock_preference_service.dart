import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'security_scope_key.dart';

enum AutoLockOption {
  immediately,
  oneMinute,
  twoMinutes,
  fiveMinutes,
  fifteenMinutes,
}

extension AutoLockOptionDetails on AutoLockOption {
  String get label => switch (this) {
    AutoLockOption.immediately => 'Immediately',
    AutoLockOption.oneMinute => 'After 1 minute',
    AutoLockOption.twoMinutes => 'After 2 minutes',
    AutoLockOption.fiveMinutes => 'After 5 minutes',
    AutoLockOption.fifteenMinutes => 'After 15 minutes',
  };

  Duration get duration => switch (this) {
    AutoLockOption.immediately => Duration.zero,
    AutoLockOption.oneMinute => const Duration(minutes: 1),
    AutoLockOption.twoMinutes => const Duration(minutes: 2),
    AutoLockOption.fiveMinutes => const Duration(minutes: 5),
    AutoLockOption.fifteenMinutes => const Duration(minutes: 15),
  };
}

class AutoLockPreferenceService {
  AutoLockPreferenceService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  String? _scope;

  void bindUser(String uid) {
    _scope = securityScopeKey(uid);
  }

  String get _key {
    final scope = _scope;
    if (scope == null) {
      throw StateError('Auto-lock storage is not bound to a user.');
    }
    return 'homevault.auto_lock.$scope.v1';
  }

  Future<AutoLockOption> load() async {
    final stored = await _storage.read(key: _key);
    return AutoLockOption.values.firstWhere(
      (value) => value.name == stored,
      orElse: () => AutoLockOption.twoMinutes,
    );
  }

  Future<void> save(AutoLockOption option) {
    return _storage.write(key: _key, value: option.name);
  }
}
