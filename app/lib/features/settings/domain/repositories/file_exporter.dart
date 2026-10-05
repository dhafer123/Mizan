import '../../../../core/result/result.dart';
import '../value_objects/settings_failure.dart';

/// Saves a file where the user chooses (on Android, the system "save as"
/// picker).
abstract interface class FileExporter {
  /// Ok(true) when saved, Ok(false) when the user cancelled.
  Future<Result<bool, SettingsFailure>> save({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  });
}
