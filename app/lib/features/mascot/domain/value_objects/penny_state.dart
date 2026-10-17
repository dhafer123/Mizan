import 'package:freezed_annotation/freezed_annotation.dart';

import 'penny_mood.dart';
import 'penny_reason.dart';

part 'penny_state.freezed.dart';

/// How Penny looks and why. Computed, never stored.
@freezed
abstract class PennyState with _$PennyState {
  const factory PennyState({
    required PennyMood mood,
    required PennyReason reason,
  }) = _PennyState;
}
