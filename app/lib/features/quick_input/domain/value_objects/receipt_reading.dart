import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'receipt_reading.freezed.dart';

/// What was read from a receipt photo, before the user confirms it.
@freezed
abstract class ReceiptReading with _$ReceiptReading {
  const factory ReceiptReading({
    /// The amount paid; null if none was found.
    Money? total,

    /// The receipt's calendar day (UTC midnight); null if none was found.
    DateTime? date,

    /// The shop, from the top of the receipt; may be empty.
    @Default('') String merchant,

    /// 0-100: how sure the rules are about [total].
    @Default(0) int confidence,
  }) = _ReceiptReading;
}
