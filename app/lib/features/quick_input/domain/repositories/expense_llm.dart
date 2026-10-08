import '../../../../core/result/result.dart';
import '../value_objects/quick_input_failure.dart';

/// The small on-device language model behind quick input's second tier
/// (ARCHITECTURE.md §8). It is an opt-in download; nothing leaves the
/// phone.
abstract interface class ExpenseLlm {
  Future<bool> isInstalled();

  /// Downloads the model: progress in percent, then done. A failure ends
  /// the stream. Does nothing much if it is already installed.
  Stream<Result<int, QuickInputFailure>> install();

  /// Deletes the model to free the space.
  Future<Result<void, QuickInputFailure>> uninstall();

  /// The model's answer to [prompt], in one piece.
  Future<Result<String, QuickInputFailure>> complete(String prompt);
}
