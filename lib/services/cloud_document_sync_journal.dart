import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../security/security_scope_key.dart';

class CloudDocumentSyncState {
  const CloudDocumentSyncState({
    this.knownCloudPaths = const <String>{},
    this.pendingDeletePaths = const <String>{},
  });

  factory CloudDocumentSyncState.fromJson(Map<String, dynamic> json) {
    final known = _stringSet(json['knownCloudPaths']);
    final pending = _stringSet(json['pendingDeletePaths']);

    return CloudDocumentSyncState(
      knownCloudPaths: Set<String>.unmodifiable(known),
      pendingDeletePaths: Set<String>.unmodifiable(pending.intersection(known)),
    );
  }

  final Set<String> knownCloudPaths;
  final Set<String> pendingDeletePaths;

  bool get hasPendingDeletes => pendingDeletePaths.isNotEmpty;

  CloudDocumentSyncState remember(Iterable<String> paths) {
    final normalized = _normalizedPaths(paths);
    if (normalized.isEmpty) return this;

    final known = <String>{...knownCloudPaths, ...normalized};
    final pending = <String>{...pendingDeletePaths}..removeAll(normalized);

    return CloudDocumentSyncState(
      knownCloudPaths: Set<String>.unmodifiable(known),
      pendingDeletePaths: Set<String>.unmodifiable(pending),
    );
  }

  CloudDocumentSyncState reconcile(Iterable<String> activePaths) {
    final active = _normalizedPaths(activePaths);
    final known = <String>{...knownCloudPaths, ...active};
    final pending = <String>{...pendingDeletePaths, ...known.difference(active)}
      ..removeAll(active);

    return CloudDocumentSyncState(
      knownCloudPaths: Set<String>.unmodifiable(known),
      pendingDeletePaths: Set<String>.unmodifiable(pending),
    );
  }

  CloudDocumentSyncState completeDelete(String cloudPath) {
    final normalized = cloudPath.trim();
    if (normalized.isEmpty) return this;

    final known = <String>{...knownCloudPaths}..remove(normalized);
    final pending = <String>{...pendingDeletePaths}..remove(normalized);

    return CloudDocumentSyncState(
      knownCloudPaths: Set<String>.unmodifiable(known),
      pendingDeletePaths: Set<String>.unmodifiable(pending),
    );
  }

  Map<String, dynamic> toJson() {
    final known = knownCloudPaths.toList(growable: false)..sort();
    final pending = pendingDeletePaths.toList(growable: false)..sort();

    return {
      'schemaVersion': 1,
      'knownCloudPaths': known,
      'pendingDeletePaths': pending,
    };
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! List) return <String>{};
    return _normalizedPaths(value.whereType<String>());
  }

  static Set<String> _normalizedPaths(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }
}

abstract class CloudDocumentSyncJournal {
  Future<void> bindOwner(String? uid);

  Future<void> rememberCloudPaths(Iterable<String> paths);

  Future<void> reconcileActiveCloudPaths(Iterable<String> activePaths);

  Future<Set<String>> pendingDeletePaths();

  Future<bool> hasPendingDeletes();

  Future<void> completeDelete(String cloudPath);
}

class FileCloudDocumentSyncJournal implements CloudDocumentSyncJournal {
  FileCloudDocumentSyncJournal({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  String? _ownerScope;
  CloudDocumentSyncState _state = const CloudDocumentSyncState();
  Future<void> _operationQueue = Future<void>.value();

  @override
  Future<void> bindOwner(String? uid) {
    final normalized = uid?.trim();
    final nextScope = normalized == null || normalized.isEmpty
        ? null
        : securityScopeKey(normalized);

    return _enqueue(() async {
      _ownerScope = nextScope;
      _state = nextScope == null
          ? const CloudDocumentSyncState()
          : await _readState();
    });
  }

  @override
  Future<void> rememberCloudPaths(Iterable<String> paths) {
    final snapshot = paths.toList(growable: false);
    return _enqueue(() async {
      final next = _state.remember(snapshot);
      await _saveIfChanged(next);
    });
  }

  @override
  Future<void> reconcileActiveCloudPaths(Iterable<String> activePaths) {
    final snapshot = activePaths.toList(growable: false);
    return _enqueue(() async {
      final next = _state.reconcile(snapshot);
      await _saveIfChanged(next);
    });
  }

  @override
  Future<Set<String>> pendingDeletePaths() async {
    await _operationQueue;
    return Set<String>.unmodifiable(_state.pendingDeletePaths);
  }

  @override
  Future<bool> hasPendingDeletes() async {
    await _operationQueue;
    return _state.hasPendingDeletes;
  }

  @override
  Future<void> completeDelete(String cloudPath) {
    return _enqueue(() async {
      final next = _state.completeDelete(cloudPath);
      await _saveIfChanged(next);
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operationQueue.then((_) => operation());
    _operationQueue = next.catchError((Object _, StackTrace _) {});
    return next;
  }

  Future<void> _saveIfChanged(CloudDocumentSyncState next) async {
    if (_sameState(_state, next)) return;
    _state = next;
    await _writeState(next);
  }

  Future<File> _stateFile() async {
    final scope = _ownerScope;
    if (scope == null) {
      throw const CloudDocumentSyncJournalException(
        'Sign in before synchronizing HomeVault cloud documents.',
      );
    }

    final documentsDirectory = await _documentsDirectoryProvider();
    final directory = Directory(
      path.join(documentsDirectory.path, 'homevault', 'data', 'users', scope),
    );
    await directory.create(recursive: true);
    return File(path.join(directory.path, 'pending_document_sync.json'));
  }

  Future<CloudDocumentSyncState> _readState() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) {
        return const CloudDocumentSyncState();
      }

      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        return const CloudDocumentSyncState();
      }

      final decoded = jsonDecode(contents);
      if (decoded is! Map) {
        throw const FormatException(
          'The cloud document sync journal has an invalid format.',
        );
      }

      final data = Map<String, dynamic>.from(decoded);
      final storedOwner = '${data['ownerScope'] ?? ''}'.trim();
      if (storedOwner.isNotEmpty && storedOwner != _ownerScope) {
        throw const CloudDocumentSyncJournalException(
          'This cloud document sync journal belongs to a different HomeVault account.',
        );
      }

      return CloudDocumentSyncState.fromJson(data);
    } on CloudDocumentSyncJournalException {
      rethrow;
    } catch (_) {
      // A damaged maintenance journal must never prevent HomeVault from
      // loading. Active attachment metadata will rebuild the safe baseline.
      return const CloudDocumentSyncState();
    }
  }

  Future<void> _writeState(CloudDocumentSyncState state) async {
    final file = await _stateFile();
    final temporaryFile = File('${file.path}.tmp');

    if (state.knownCloudPaths.isEmpty && !state.hasPendingDeletes) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    final payload = jsonEncode({
      ...state.toJson(),
      'ownerScope': _ownerScope,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    });

    await temporaryFile.writeAsString(payload, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temporaryFile.rename(file.path);
  }

  bool _sameState(CloudDocumentSyncState first, CloudDocumentSyncState second) {
    return _sameSet(first.knownCloudPaths, second.knownCloudPaths) &&
        _sameSet(first.pendingDeletePaths, second.pendingDeletePaths);
  }

  bool _sameSet(Set<String> first, Set<String> second) {
    return first.length == second.length && first.containsAll(second);
  }
}

class MemoryCloudDocumentSyncJournal implements CloudDocumentSyncJournal {
  String? _ownerUid;
  final Map<String, CloudDocumentSyncState> _states = {};

  @override
  Future<void> bindOwner(String? uid) async {
    final normalized = uid?.trim();
    _ownerUid = normalized == null || normalized.isEmpty ? null : normalized;
  }

  String get _requiredOwner {
    final owner = _ownerUid;
    if (owner == null) {
      throw const CloudDocumentSyncJournalException(
        'Sign in before synchronizing HomeVault cloud documents.',
      );
    }
    return owner;
  }

  CloudDocumentSyncState get _state =>
      _states[_requiredOwner] ?? const CloudDocumentSyncState();

  set _state(CloudDocumentSyncState value) {
    _states[_requiredOwner] = value;
  }

  @override
  Future<void> rememberCloudPaths(Iterable<String> paths) async {
    _state = _state.remember(paths);
  }

  @override
  Future<void> reconcileActiveCloudPaths(Iterable<String> activePaths) async {
    _state = _state.reconcile(activePaths);
  }

  @override
  Future<Set<String>> pendingDeletePaths() async {
    return Set<String>.unmodifiable(_state.pendingDeletePaths);
  }

  @override
  Future<bool> hasPendingDeletes() async => _state.hasPendingDeletes;

  @override
  Future<void> completeDelete(String cloudPath) async {
    _state = _state.completeDelete(cloudPath);
  }
}

class CloudDocumentSyncJournalException implements Exception {
  const CloudDocumentSyncJournalException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
