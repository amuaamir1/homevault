import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/cloud_sync_status.dart';

void main() {
  test('cloud sync status tracks pending writes and last sync time', () {
    final timestamp = DateTime(2026, 8, 8, 0, 20);
    final status = CloudSyncStatus(
      state: CloudSyncState.syncing,
      lastSyncedAt: timestamp,
      hasPendingWrites: true,
    );

    expect(status.state, CloudSyncState.syncing);
    expect(status.lastSyncedAt, timestamp);
    expect(status.hasPendingWrites, isTrue);
  });

  test('unavailable status has no pending writes', () {
    const status = CloudSyncStatus.unavailable();

    expect(status.state, CloudSyncState.unavailable);
    expect(status.hasPendingWrites, isFalse);
    expect(status.lastSyncedAt, isNull);
  });
}
