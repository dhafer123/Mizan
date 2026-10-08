import 'package:freezed_annotation/freezed_annotation.dart';

import 'alert_type.dart';

part 'sent_alert.freezed.dart';

/// That an alert was sent on this phone. Local only: notifications are per
/// device, so this never syncs.
@freezed
abstract class SentAlert with _$SentAlert {
  const factory SentAlert({
    required AlertType type,

    /// `BudgetAlert.situation`.
    required String situation,

    /// The calendar day it was sent (UTC midnight).
    required DateTime sentOn,

    /// For a run-out alert, the date it warned about: it is sent again for
    /// the same payday only if the date moves earlier.
    DateTime? runOut,
  }) = _SentAlert;
}
