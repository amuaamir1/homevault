import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/services/local_document_cache_policy.dart';

void main() {
  test('memory cache policy keeps evictions isolated by account', () async {
    final policy = MemoryLocalDocumentCachePolicy();

    await policy.bindOwner('owner-a');
    await policy.markEvicted(['users/owner-a/documents/one.pdf']);
    expect(
      await policy.evictedCloudPaths(),
      contains('users/owner-a/documents/one.pdf'),
    );

    await policy.bindOwner('owner-b');
    expect(await policy.evictedCloudPaths(), isEmpty);
    await policy.markEvicted(['users/owner-b/documents/two.pdf']);

    await policy.bindOwner('owner-a');
    expect(
      await policy.evictedCloudPaths(),
      equals({'users/owner-a/documents/one.pdf'}),
    );

    await policy.markAvailable(['users/owner-a/documents/one.pdf']);
    expect(await policy.evictedCloudPaths(), isEmpty);
  });

  test('file cache policy persists release choices per account', () async {
    final root = await Directory.systemTemp.createTemp(
      'homevault-p18-cache-policy-',
    );
    addTearDown(() => root.delete(recursive: true));

    FileLocalDocumentCachePolicy createPolicy() =>
        FileLocalDocumentCachePolicy(documentsDirectoryProvider: () async => root);

    final first = createPolicy();
    await first.bindOwner('owner-a');
    await first.markEvicted([
      'users/owner-a/documents/manual.pdf',
      'users/owner-a/documents/invoice.pdf',
    ]);

    final reloaded = createPolicy();
    await reloaded.bindOwner('owner-a');
    expect(
      await reloaded.evictedCloudPaths(),
      equals({
        'users/owner-a/documents/manual.pdf',
        'users/owner-a/documents/invoice.pdf',
      }),
    );

    await reloaded.bindOwner('owner-b');
    expect(await reloaded.evictedCloudPaths(), isEmpty);

    await reloaded.bindOwner('owner-a');
    await reloaded.markAvailable(['users/owner-a/documents/manual.pdf']);
    expect(
      await reloaded.evictedCloudPaths(),
      equals({'users/owner-a/documents/invoice.pdf'}),
    );
  });
}
