import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'parsed_item.freezed.dart';

/// One expense read from a typed or spoken phrase, before the user confirms
/// it. Never saved as is.
@freezed
abstract class ParsedItem with _$ParsedItem {
  const factory ParsedItem({
    /// What it was, as said: "café", "taxi". Empty if nothing was said.
    required String label,

    /// Above 0.
    required Money amount,

    /// 0-100: how sure the rules are that [label] and [amount] are right.
    required int confidence,
  }) = _ParsedItem;
}
