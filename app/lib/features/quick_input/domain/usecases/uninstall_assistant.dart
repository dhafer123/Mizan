import '../../../../core/result/result.dart';
import '../repositories/expense_llm.dart';
import '../value_objects/quick_input_failure.dart';

/// Deletes the on-device assistant model.
class UninstallAssistant {
  const UninstallAssistant(this._llm);

  final ExpenseLlm _llm;

  Future<Result<void, QuickInputFailure>> call() => _llm.uninstall();
}
