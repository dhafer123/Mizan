import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/account.dart';
import 'token_pair.dart';

part 'stored_session.freezed.dart';

/// A signed-in session as kept on the phone: who, and their tokens.
@freezed
abstract class StoredSession with _$StoredSession {
  const factory StoredSession({
    required Account account,
    required TokenPair tokens,
  }) = _StoredSession;
}
