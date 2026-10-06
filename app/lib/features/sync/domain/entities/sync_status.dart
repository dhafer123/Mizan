import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/outbox_counts.dart';
import '../value_objects/sync_failure.dart';
import '../value_objects/sync_phase.dart';

part 'sync_status.freezed.dart';

/// What the sync indicator shows.
@freezed
abstract class SyncStatus with _$SyncStatus {
  const factory SyncStatus({
    @Default(SyncPhase.signedOut) SyncPhase phase,
    @Default(OutboxCounts()) OutboxCounts outbox,

    /// When the last sync finished; null if never.
    DateTime? lastSyncAt,

    /// Why the last sync failed, while [phase] is error or offline.
    SyncFailure? failure,
  }) = _SyncStatus;
}
