import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';

/// The server account this phone is signed in to. Without one the app runs
/// in local-only mode: everything works, nothing syncs.
@freezed
abstract class Account with _$Account {
  const factory Account({
    /// The server's id for the user. Opaque.
    required String id,

    /// Lowercased.
    required String email,

    /// Shown to group members; null when not set.
    String? displayName,
  }) = _Account;
}
