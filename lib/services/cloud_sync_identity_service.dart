import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../security/security_scope_key.dart';

class CloudSyncIdentityService {
  CloudSyncIdentityService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _installationIdKey = 'homevault.cloud.installation.id.v1';

  final FlutterSecureStorage _storage;
  String? _scope;

  Future<void> bindOwner(String? uid) async {
    final normalized = uid?.trim();
    _scope = normalized == null || normalized.isEmpty
        ? null
        : securityScopeKey(normalized);
  }

  Future<String> installationId() async {
    final existing = await _storage.read(key: _installationIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final created = base64UrlEncode(bytes).replaceAll('=', '');

    await _storage.write(key: _installationIdKey, value: created);

    return created;
  }

  Future<bool> hasCompletedStructuredMigration() async {
    final key = _migrationKey;
    if (key == null) return false;

    return await _storage.read(key: key) == 'true';
  }

  Future<void> markStructuredMigrationCompleted() async {
    final key = _migrationKey;
    if (key == null) return;

    await _storage.write(key: key, value: 'true');
  }

  String? get _migrationKey {
    final scope = _scope;
    if (scope == null) return null;

    return 'homevault.cloud.$scope.appliances.migrated.v1';
  }
}
