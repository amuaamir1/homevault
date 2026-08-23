import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../security/security_scope_key.dart';

abstract class LocalDocumentCachePolicy {
  Future<void> bindOwner(String? uid);

  Future<Set<String>> evictedCloudPaths();

  Future<void> markEvicted(Iterable<String> cloudPaths);

  Future<void> markAvailable(Iterable<String> cloudPaths);
}

class FileLocalDocumentCachePolicy implements LocalDocumentCachePolicy {
  FileLocalDocumentCachePolicy({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  String? _ownerScope;
  Set<String> _evictedCloudPaths = <String>{};
  Future<void> _operationQueue = Future<void>.value();

  @override
  Future<void> bindOwner(String? uid) {
    final normalized = uid?.trim();
    final nextScope = normalized == null || normalized.isEmpty
        ? null
        : securityScopeKey(normalized);

    return _enqueue(() async {
      _ownerScope = nextScope;
      _evictedCloudPaths = nextScope == null
          ? <String>{}
          : await _readEvictedPaths();
    });
  }

  @override
  Future<Set<String>> evictedCloudPaths() async {
    await _operationQueue;
    return Set<String>.unmodifiable(_evictedCloudPaths);
  }

  @override
  Future<void> markEvicted(Iterable<String> cloudPaths) {
    final normalized = _normalize(cloudPaths);
    if (normalized.isEmpty) return Future<void>.value();

    return _enqueue(() async {
      final next = <String>{..._evictedCloudPaths, ...normalized};
      await _writeIfChanged(next);
    });
  }

  @override
  Future<void> markAvailable(Iterable<String> cloudPaths) {
    final normalized = _normalize(cloudPaths);
    if (normalized.isEmpty) return Future<void>.value();

    return _enqueue(() async {
      final next = <String>{..._evictedCloudPaths}..removeAll(normalized);
      await _writeIfChanged(next);
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationQueue.then((_) => operation());
    _operationQueue = next.catchError((Object _, StackTrace _) {});
    return next;
  }

  Future<File> _stateFile() async {
    final scope = _ownerScope;
    if (scope == null) {
      throw const LocalDocumentCachePolicyException(
        'Sign in before managing HomeVault offline document copies.',
      );
    }

    final documentsDirectory = await _documentsDirectoryProvider();
    final directory = Directory(
      path.join(documentsDirectory.path, 'homevault', 'data', 'users', scope),
    );
    await directory.create(recursive: true);
    return File(path.join(directory.path, 'local_document_cache_policy.json'));
  }

  Future<Set<String>> _readEvictedPaths() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return <String>{};

      final contents = await file.readAsString();
      if (contents.trim().isEmpty) return <String>{};

      final decoded = jsonDecode(contents);
      if (decoded is! Map) return <String>{};

      final data = Map<String, dynamic>.from(decoded);
      final storedOwner = '${data['ownerScope'] ?? ''}'.trim();
      if (storedOwner.isNotEmpty && storedOwner != _ownerScope) {
        return <String>{};
      }

      final values = data['evictedCloudPaths'];
      if (values is! List) return <String>{};
      return _normalize(values.whereType<String>());
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _writeIfChanged(Set<String> next) async {
    if (_sameSet(_evictedCloudPaths, next)) return;

    _evictedCloudPaths = next;
    final file = await _stateFile();
    final temporaryFile = File('${file.path}.tmp');

    if (next.isEmpty) {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      if (await file.exists()) await file.delete();
      return;
    }

    final values = next.toList(growable: false)..sort();
    final payload = jsonEncode({
      'schemaVersion': 1,
      'ownerScope': _ownerScope,
      'evictedCloudPaths': values,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });

    await temporaryFile.writeAsString(payload, flush: true);
    if (await file.exists()) await file.delete();
    await temporaryFile.rename(file.path);
  }

  static Set<String> _normalize(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static bool _sameSet(Set<String> first, Set<String> second) {
    return first.length == second.length && first.containsAll(second);
  }
}

class MemoryLocalDocumentCachePolicy implements LocalDocumentCachePolicy {
  final Map<String, Set<String>> _evictedByOwner = <String, Set<String>>{};
  String? _ownerScope;

  @override
  Future<void> bindOwner(String? uid) async {
    final normalized = uid?.trim();
    _ownerScope = normalized == null || normalized.isEmpty
        ? null
        : securityScopeKey(normalized);
  }

  @override
  Future<Set<String>> evictedCloudPaths() async {
    final scope = _ownerScope;
    if (scope == null) return const <String>{};
    return Set<String>.unmodifiable(_evictedByOwner[scope] ?? const <String>{});
  }

  @override
  Future<void> markEvicted(Iterable<String> cloudPaths) async {
    final scope = _ownerScope;
    if (scope == null) return;
    final paths = _evictedByOwner.putIfAbsent(scope, () => <String>{});
    paths.addAll(
      cloudPaths.map((value) => value.trim()).where((value) => value.isNotEmpty),
    );
  }

  @override
  Future<void> markAvailable(Iterable<String> cloudPaths) async {
    final scope = _ownerScope;
    if (scope == null) return;
    final paths = _evictedByOwner[scope];
    if (paths == null) return;
    paths.removeAll(
      cloudPaths.map((value) => value.trim()).where((value) => value.isNotEmpty),
    );
    if (paths.isEmpty) _evictedByOwner.remove(scope);
  }
}

class LocalDocumentCachePolicyException implements Exception {
  const LocalDocumentCachePolicyException(this.message);

  final String message;

  @override
  String toString() => message;
}
