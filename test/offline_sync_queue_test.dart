import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/appliance.dart';
import 'package:homevault/services/appliance_repository.dart';
import 'package:homevault/services/cloud_sync_identity_service.dart';
import 'package:homevault/services/firestore_appliance_repository.dart';

class _FakeCloudSyncIdentityService extends CloudSyncIdentityService {
  @override
  Future<void> bindOwner(String? uid) async {}

  @override
  Future<String> installationId() async => 'test-installation';

  @override
  Future<bool> hasCompletedStructuredMigration() async => true;

  @override
  Future<void> markStructuredMigrationCompleted() async {}
}

void main() {
  group('durable offline sync queue', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'homevault-offline-sync-test-',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'pending state survives repository recreation and is UID scoped',
      () async {
        Future<Directory> documentsDirectoryProvider() async => tempDirectory;

        final first = FileApplianceRepository(
          documentsDirectoryProvider: documentsDirectoryProvider,
        );
        await first.bindOwner('user-a');
        await first.savePendingSyncState(
          const PendingApplianceSyncState(
            pendingUpsertIds: {'ac-1'},
            pendingDeleteIds: {'tv-1'},
            authoritativeDeleteIds: {'tv-1'},
          ),
        );

        final recreated = FileApplianceRepository(
          documentsDirectoryProvider: documentsDirectoryProvider,
        );
        await recreated.bindOwner('user-a');
        final restored = await recreated.loadPendingSyncState();

        expect(restored.pendingUpsertIds, {'ac-1'});
        expect(restored.pendingDeleteIds, {'tv-1'});
        expect(restored.authoritativeDeleteIds, {'tv-1'});

        await recreated.bindOwner('user-b');
        final otherUser = await recreated.loadPendingSyncState();
        expect(otherUser.hasPendingChanges, isFalse);
      },
    );

    test('newer local operation wins for the same pending appliance ID', () {
      final queuedDelete = const PendingApplianceSyncState(
        pendingUpsertIds: {'ac-1'},
      ).queue(deleteIds: {'ac-1'}, authoritativeDeletes: {'ac-1'});

      expect(queuedDelete.pendingUpsertIds, isEmpty);
      expect(queuedDelete.pendingDeleteIds, {'ac-1'});
      expect(queuedDelete.authoritativeDeleteIds, {'ac-1'});

      final readded = queuedDelete.queue(upsertIds: {'ac-1'});
      expect(readded.pendingUpsertIds, {'ac-1'});
      expect(readded.pendingDeleteIds, isEmpty);
      expect(readded.authoritativeDeleteIds, isEmpty);
    });

    test(
      'pending offline edit survives reconnect snapshot and auto uploads',
      () async {
        Future<Directory> documentsDirectoryProvider() async => tempDirectory;
        final firestore = FakeFirebaseFirestore();
        final local = FileApplianceRepository(
          documentsDirectoryProvider: documentsDirectoryProvider,
        );

        final cloud = _appliance(
          id: 'ac-1',
          name: 'Living room AC',
          cloudRevision: 3,
        );
        final offlineEdit = _appliance(
          id: 'ac-1',
          name: 'Bedroom AC',
          cloudRevision: 3,
        );

        await local.bindOwner('user-a');
        await local.saveAppliances([offlineEdit]);
        await local.savePendingSyncState(
          const PendingApplianceSyncState(pendingUpsertIds: {'ac-1'}),
        );

        await firestore
            .collection('users')
            .doc('user-a')
            .collection('appliances')
            .doc('ac-1')
            .set(_cloudJson(cloud));
        await firestore
            .collection('users')
            .doc('user-a')
            .collection('syncMeta')
            .doc('appliancesV1')
            .set({'completed': true, 'schemaVersion': 5});

        final repository = FirestoreApplianceRepository(
          firestore: firestore,
          localRepository: local,
          identityService: _FakeCloudSyncIdentityService(),
        );
        await repository.bindOwner('user-a');

        final loaded = await repository.loadAppliances();
        expect(loaded.single.name, 'Bedroom AC');

        await Future<void>.delayed(const Duration(milliseconds: 700));

        final cloudAfterRetry = await firestore
            .collection('users')
            .doc('user-a')
            .collection('appliances')
            .doc('ac-1')
            .get();

        expect(cloudAfterRetry.data()?['name'], 'Bedroom AC');
        expect(cloudAfterRetry.data()?['cloudRevision'], 4);
        expect((await local.loadPendingSyncState()).hasPendingChanges, isFalse);
      },
    );

    test('pending authoritative delete stays deleted and auto syncs', () async {
      Future<Directory> documentsDirectoryProvider() async => tempDirectory;
      final firestore = FakeFirebaseFirestore();
      final local = FileApplianceRepository(
        documentsDirectoryProvider: documentsDirectoryProvider,
      );

      final cloud = _appliance(
        id: 'tv-1',
        name: 'Living room TV',
        cloudRevision: 5,
      );

      await local.bindOwner('user-a');
      await local.saveAppliances(const []);
      await local.savePendingSyncState(
        const PendingApplianceSyncState(
          pendingDeleteIds: {'tv-1'},
          authoritativeDeleteIds: {'tv-1'},
        ),
      );

      await firestore
          .collection('users')
          .doc('user-a')
          .collection('appliances')
          .doc('tv-1')
          .set(_cloudJson(cloud));
      await firestore
          .collection('users')
          .doc('user-a')
          .collection('syncMeta')
          .doc('appliancesV1')
          .set({'completed': true, 'schemaVersion': 5});

      final repository = FirestoreApplianceRepository(
        firestore: firestore,
        localRepository: local,
        identityService: _FakeCloudSyncIdentityService(),
      );
      await repository.bindOwner('user-a');

      final loaded = await repository.loadAppliances();
      expect(loaded, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 700));

      final cloudAfterRetry = await firestore
          .collection('users')
          .doc('user-a')
          .collection('appliances')
          .doc('tv-1')
          .get();

      expect(cloudAfterRetry.exists, isFalse);
      expect((await local.loadPendingSyncState()).hasPendingChanges, isFalse);
    });
  });
}

Appliance _appliance({
  required String id,
  required String name,
  required int cloudRevision,
}) {
  return Appliance(
    id: id,
    name: name,
    category: 'Other',
    brand: 'Test',
    cloudRevision: cloudRevision,
    cloudUpdatedByDevice: 'device-a',
    createdAt: DateTime(2026, 8, 22),
  );
}

Map<String, dynamic> _cloudJson(Appliance appliance) {
  return {
    ...appliance.toJson(),
    'cloudSchemaVersion': 5,
    'cloudRevision': appliance.cloudRevision,
    'cloudUpdatedByDevice': appliance.cloudUpdatedByDevice,
    'cloudUpdatedAt': DateTime(2026, 8, 22),
  };
}
