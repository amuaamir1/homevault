enum CloudSyncState { unavailable, connecting, syncing, synced, offline, error }

class CloudSyncStatus {
  const CloudSyncStatus({
    required this.state,
    this.lastSyncedAt,
    this.hasPendingWrites = false,
    this.message,
  });

  const CloudSyncStatus.unavailable()
    : state = CloudSyncState.unavailable,
      lastSyncedAt = null,
      hasPendingWrites = false,
      message = null;

  final CloudSyncState state;
  final DateTime? lastSyncedAt;
  final bool hasPendingWrites;
  final String? message;
}
