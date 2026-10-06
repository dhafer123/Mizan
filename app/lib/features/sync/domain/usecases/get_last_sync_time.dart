import '../repositories/sync_repository.dart';

/// When this phone last finished a sync, or null.
class GetLastSyncTime {
  const GetLastSyncTime(this._repository);

  final SyncRepository _repository;

  Future<DateTime?> call() => _repository.lastSyncAt();
}
