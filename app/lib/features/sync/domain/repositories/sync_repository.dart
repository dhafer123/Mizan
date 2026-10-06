import '../../../../core/result/result.dart';
import '../value_objects/outbox_counts.dart';
import '../value_objects/sync_failure.dart';

/// The local outbox and sync state, and the server's push/pull.
abstract interface class SyncRepository {
  /// Pushes queued ops, oldest first, until none are pending. Returns how
  /// many the server accepted and how many it refused for good.
  Future<Result<({int accepted, int rejected}), SyncFailure>> push();

  /// Pulls every change since the stored cursor and applies it, re-applying
  /// local changes that are still queued (rebase). Each page is applied in
  /// one transaction with its cursor, and only while the local data still
  /// belongs to [accountId]. Returns how many changes were applied.
  Future<Result<int, SyncFailure>> pull({required String accountId});

  /// Makes the local synced data [accountId]'s: kept if it already is (or
  /// has never been synced), wiped if it belongs to another account.
  /// Returns whether it wiped.
  Future<Result<bool, SyncFailure>> claimFor(String accountId);

  /// Pending and rejected outbox ops, re-emitted on every change.
  Stream<OutboxCounts> watchOutbox();

  /// When the last pull finished, or null.
  Future<DateTime?> lastSyncAt();
}
