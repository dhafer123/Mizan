import '../repositories/sync_repository.dart';
import '../value_objects/outbox_counts.dart';

/// Unsynced and refused local changes, live.
class WatchOutboxCounts {
  const WatchOutboxCounts(this._repository);

  final SyncRepository _repository;

  Stream<OutboxCounts> call() => _repository.watchOutbox();
}
