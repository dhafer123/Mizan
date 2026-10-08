import 'package:freezed_annotation/freezed_annotation.dart';

import 'parsed_item.dart';

part 'parsed_input.freezed.dart';

/// What the rule parser read from a phrase.
@freezed
abstract class ParsedInput with _$ParsedInput {
  const factory ParsedInput({
    required List<ParsedItem> items,

    /// Words that look like an amount but weren't read ("trois", "nos"), or
    /// words left with no amount: the rules missed something.
    @Default(false) bool missedSomething,
  }) = _ParsedInput;

  const ParsedInput._();

  /// 0-100: the least sure item; 0 with no items or when something was
  /// missed.
  int get confidence => items.isEmpty || missedSomething
      ? 0
      : items.map((i) => i.confidence).reduce((a, b) => a < b ? a : b);
}
