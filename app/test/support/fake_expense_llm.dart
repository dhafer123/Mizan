import 'dart:async';

import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/repositories/expense_llm.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';

/// An [ExpenseLlm] that answers from a script.
class FakeExpenseLlm implements ExpenseLlm {
  FakeExpenseLlm({this.installed = true, this.answer});

  bool installed;

  /// What [complete] returns; null answers nothing ever (a hang).
  Result<String, QuickInputFailure>? answer;

  /// Every prompt passed to [complete].
  final prompts = <String>[];

  /// What [install] emits.
  List<Result<int, QuickInputFailure>> installUpdates = const [Ok(40), Ok(100)];

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Stream<Result<int, QuickInputFailure>> install() async* {
    for (final update in installUpdates) {
      yield update;
    }
    if (installUpdates.lastOrNull case Ok(value: 100)) installed = true;
  }

  @override
  Future<Result<void, QuickInputFailure>> uninstall() async {
    installed = false;
    return const Ok(null);
  }

  @override
  Future<Result<String, QuickInputFailure>> complete(String prompt) {
    prompts.add(prompt);
    final answer = this.answer;
    return answer == null ? Completer<Never>().future : Future.value(answer);
  }
}
