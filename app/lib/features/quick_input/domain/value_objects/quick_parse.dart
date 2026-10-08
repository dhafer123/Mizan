import 'package:freezed_annotation/freezed_annotation.dart';

import 'parse_method.dart';
import 'parsed_item.dart';
import 'quick_input_failure.dart';

part 'quick_parse.freezed.dart';

/// What quick input read from a phrase, for the confirmation sheet. Never
/// saved without the user confirming it.
@freezed
abstract class QuickParse with _$QuickParse {
  const factory QuickParse({
    /// The phrase as typed or heard.
    required String text,
    required List<ParsedItem> items,
    required ParseMethod method,

    /// Why the LLM tier didn't help, when the rules were unsure: not
    /// downloaded, failed, or answered nonsense. The rules' items are kept.
    QuickInputFailure? llmFailure,

    /// The day it was spent, when the input says (a receipt's date);
    /// otherwise the sheet uses today.
    DateTime? date,
  }) = _QuickParse;
}
