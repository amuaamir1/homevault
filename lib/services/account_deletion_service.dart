import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../security/security_scope_key.dart';
import 'firebase_error_message.dart';

class AccountDeletionService {
  AccountDeletionService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FlutterSecureStorage? secureStorage,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FlutterSecureStorage _secureStorage;
  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<void> deleteRemoteAccountData(String uid) async {
    final ownerUid = _requiredUid(uid);

    try {
      final userDocument = _firestore.collection('users').doc(ownerUid);

      await _deleteCollection(userDocument.collection('appliances'));
      await _deleteCollection(userDocument.collection('syncMeta'));
      await _deleteCollection(userDocument.collection('backups'));
      await _deleteCollection(userDocument.collection('feedback'));
      await _deleteTopLevelFeedback(ownerUid);
      await _deleteStorageTree(_storage.ref().child('users/$ownerUid'));
      await userDocument.delete();
    } catch (error) {
      throw AccountDeletionException(
        friendlyFirebaseError(
          error,
          fallback:
              'HomeVault could not remove all cloud account data. Nothing '
              'else was deleted. Please try again while online.',
        ),
        error,
      );
    }
  }

  Future<void> deleteLocalAccountData(String uid) async {
    final ownerUid = _requiredUid(uid);
    final scope = securityScopeKey(ownerUid);
    final documentsDirectory = await _documentsDirectoryProvider();
    final homeVaultRoot = Directory(
      path.join(documentsDirectory.path, 'homevault'),
    );

    final accountPaths = <String>[
      path.join(homeVaultRoot.path, 'accounts', scope),
      path.join(homeVaultRoot.path, 'data', 'users', scope),
      path.join(homeVaultRoot.path, 'safety_backups', scope),
    ];

    for (final accountPath in accountPaths) {
      await _deleteDirectoryIfPresent(Directory(accountPath));
    }

    await _deleteOwnedLegacyDocuments(homeVaultRoot, scope);
    await _secureStorage.delete(
      key: 'homevault.cloud.$scope.appliances.migrated.v1',
    );
  }

  Future<void> _deleteTopLevelFeedback(String uid) async {
    while (true) {
      final snapshot = await _firestore
          .collection('feedback')
          .where('uid', isEqualTo: uid)
          .limit(400)
          .get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteStorageTree(Reference reference) async {
    try {
      final listing = await reference.listAll();
      for (final prefix in listing.prefixes) {
        await _deleteStorageTree(prefix);
      }
      for (final item in listing.items) {
        try {
          await item.delete();
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
      }
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  Future<void> _deleteOwnedLegacyDocuments(
    Directory homeVaultRoot,
    String scope,
  ) async {
    final legacyRoot = Directory(path.join(homeVaultRoot.path, 'appliances'));
    if (!await legacyRoot.exists()) return;

    final marker = File(path.join(legacyRoot.path, '.homevault_owner'));
    if (!await marker.exists()) return;

    final storedOwner = (await marker.readAsString()).trim();
    if (storedOwner == scope) {
      await legacyRoot.delete(recursive: true);
    }
  }

  Future<void> _deleteDirectoryIfPresent(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  String _requiredUid(String uid) {
    final normalized = uid.trim();
    if (normalized.isEmpty) {
      throw const AccountDeletionException(
        'Sign in before deleting your HomeVault account.',
      );
    }
    return normalized;
  }
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
