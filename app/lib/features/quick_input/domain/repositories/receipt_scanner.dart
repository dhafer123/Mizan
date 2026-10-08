import '../../../../core/result/result.dart';
import '../value_objects/ocr_line.dart';
import '../value_objects/quick_input_failure.dart';

/// Reads the text on a receipt photo, on the phone (ARCHITECTURE.md §8).
abstract interface class ReceiptScanner {
  /// The lines of text on the image at [imagePath], in no set order.
  Future<Result<List<OcrLine>, QuickInputFailure>> read(String imagePath);
}
