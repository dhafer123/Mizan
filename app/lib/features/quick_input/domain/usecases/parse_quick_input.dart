import 'dart:async';

import '../../../../core/money/currency.dart';
import '../../../../core/result/result.dart';
import '../repositories/expense_llm.dart';
import '../value_objects/parse_method.dart';
import '../value_objects/quick_input_error.dart';
import '../value_objects/quick_input_failure.dart';
import '../value_objects/quick_parse.dart';
import 'build_llm_prompt.dart';
import 'parse_expense_text.dart';
import 'read_llm_answer.dart';

/// Quick input's two tiers (ARCHITECTURE.md §8): the rule parser first;
/// when it is less sure than `ParseExpenseText.fallbackBelow`, the
/// on-device LLM, whose JSON answer is checked by [ReadLlmAnswer].
///
/// If the LLM isn't downloaded, fails, takes longer than [timeout] or
/// answers nonsense, the rules' reading stands and the reason is kept. The
/// result always goes to the confirmation sheet; nothing is saved here.
class ParseQuickInput {
  const ParseQuickInput(
    this._llm, {
    ParseExpenseText rules = const ParseExpenseText(),
    BuildLlmPrompt prompt = const BuildLlmPrompt(),
    ReadLlmAnswer read = const ReadLlmAnswer(),
    this.timeout = const Duration(seconds: 20),
  }) : _rules = rules,
       _prompt = prompt,
       _read = read;

  final ExpenseLlm _llm;
  final ParseExpenseText _rules;
  final BuildLlmPrompt _prompt;
  final ReadLlmAnswer _read;
  final Duration timeout;

  Future<QuickParse> call(String text, {required Currency currency}) async {
    final phrase = text.trim();
    final rules = _rules(phrase, currency: currency);
    QuickParse byRules([QuickInputFailure? failure]) => QuickParse(
      text: phrase,
      items: rules.items,
      method: ParseMethod.rules,
      llmFailure: failure,
    );

    if (phrase.isEmpty || rules.confidence >= ParseExpenseText.fallbackBelow) {
      return byRules();
    }
    if (!await _llm.isInstalled()) {
      return byRules(
        const QuickInputFailure(QuickInputError.modelNotInstalled),
      );
    }

    final answer = await _llm
        .complete(_prompt(phrase, currency: currency))
        // A fresh future of the declared type, so the timeout's fallback
        // fits whatever future the model returned.
        .then<Result<String, QuickInputFailure>>((answer) => answer)
        .timeout(
          timeout,
          onTimeout: () =>
              const Err(QuickInputFailure(QuickInputError.llmFailed)),
        );
    final read = switch (answer) {
      Ok(:final value) => _read(value, phrase: phrase, currency: currency),
      Err(:final failure) => Err<Never, QuickInputFailure>(failure),
    };
    return switch (read) {
      Ok(:final value) => QuickParse(
        text: phrase,
        items: value,
        method: ParseMethod.llm,
      ),
      Err(:final failure) => byRules(failure),
    };
  }
}
