import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/services/cloud_document_sync_journal.dart';

void main() {
  test('reconcile queues only cloud paths no longer referenced', () {
    const state = CloudDocumentSyncState(
      knownCloudPaths: {
        'users/u1/appliances/a1/documents/d1/old.pdf',
        'users/u1/appliances/a1/documents/d2/current.pdf',
      },
    );

    final reconciled = state.reconcile({
      'users/u1/appliances/a1/documents/d2/current.pdf',
      'users/u1/appliances/a1/documents/d3/new.pdf',
    });

    expect(reconciled.pendingDeletePaths, {
      'users/u1/appliances/a1/documents/d1/old.pdf',
    });
    expect(
      reconciled.knownCloudPaths,
      containsAll({
        'users/u1/appliances/a1/documents/d1/old.pdf',
        'users/u1/appliances/a1/documents/d2/current.pdf',
        'users/u1/appliances/a1/documents/d3/new.pdf',
      }),
    );
  });

  test('active path cancels a queued delete before cleanup', () {
    const cloudPath = 'users/u1/appliances/a1/documents/d1/file.pdf';
    final queued = const CloudDocumentSyncState(
      knownCloudPaths: {cloudPath},
      pendingDeletePaths: {cloudPath},
    ).reconcile({cloudPath});

    expect(queued.pendingDeletePaths, isEmpty);
    expect(queued.knownCloudPaths, contains(cloudPath));
  });

  test('file journal survives restart and remains isolated per user', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'homevault-cloud-document-journal-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    const cloudPath = 'users/user-1/appliances/a1/documents/d1/file.pdf';

    final first = FileCloudDocumentSyncJournal(
      documentsDirectoryProvider: () async => tempDirectory,
    );
    await first.bindOwner('user-1');
    await first.rememberCloudPaths({cloudPath});
    await first.reconcileActiveCloudPaths(const <String>{});

    expect(await first.pendingDeletePaths(), {cloudPath});

    final restarted = FileCloudDocumentSyncJournal(
      documentsDirectoryProvider: () async => tempDirectory,
    );
    await restarted.bindOwner('user-1');

    expect(await restarted.pendingDeletePaths(), {cloudPath});

    await restarted.bindOwner('user-2');
    expect(await restarted.pendingDeletePaths(), isEmpty);
  });

  test(
    'completed delete is removed from durable known-path manifest',
    () async {
      final journal = MemoryCloudDocumentSyncJournal();
      const cloudPath = 'users/user-1/appliances/a1/documents/d1/file.pdf';

      await journal.bindOwner('user-1');
      await journal.rememberCloudPaths({cloudPath});
      await journal.reconcileActiveCloudPaths(const <String>{});

      expect(await journal.pendingDeletePaths(), {cloudPath});

      await journal.completeDelete(cloudPath);

      expect(await journal.pendingDeletePaths(), isEmpty);
      expect(await journal.hasPendingDeletes(), isFalse);
    },
  );
}
