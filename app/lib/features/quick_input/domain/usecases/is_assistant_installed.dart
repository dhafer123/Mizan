import '../repositories/expense_llm.dart';

/// Whether the on-device assistant model is downloaded.
class IsAssistantInstalled {
  const IsAssistantInstalled(this._llm);

  final ExpenseLlm _llm;

  Future<bool> call() => _llm.isInstalled();
}
