import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage_sharing.freezed.dart';

/// The user opted in to sharing anonymous usage counts. Device-only: never
/// synced. Opting out forgets it all, so opting in again starts a new
/// install id that can't be linked to the old one.
@freezed
abstract class UsageSharing with _$UsageSharing {
  const factory UsageSharing({
    /// A random id for this install, not the account or the device id.
    required String installId,

    /// The calendar day the user opted in. Nothing before it is sent.
    required DateTime since,

    /// The calendar day of the last report the server accepted.
    DateTime? lastSentDay,
  }) = _UsageSharing;
}
