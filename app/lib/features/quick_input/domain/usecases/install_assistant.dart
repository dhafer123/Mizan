import '../../../../core/result/result.dart';
import '../repositories/expense_llm.dart';
import '../value_objects/quick_input_failure.dart';

/// Downloads the on-device assistant model: progress in percent.
class InstallAssistant {
  const InstallAssistant(this._llm);

  final ExpenseLlm _llm;

  Stream<Result<int, QuickInputFailure>> call() => _llm.install();
}
