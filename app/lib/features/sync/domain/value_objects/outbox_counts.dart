import 'package:freezed_annotation/freezed_annotation.dart';

part 'outbox_counts.freezed.dart';

/// Local changes the server hasn't accepted yet.
@freezed
abstract class OutboxCounts with _$OutboxCounts {
  const factory OutboxCounts({
    /// Waiting to be pushed.
    @Default(0) int pending,

    /// Refused by the server for good (shown, never retried).
    @Default(0) int rejected,
  }) = _OutboxCounts;
}
