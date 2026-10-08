import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/repositories/receipt_scanner.dart';
import 'package:mizan/features/quick_input/domain/value_objects/ocr_line.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';

/// A [ReceiptScanner] that "reads" the given rows, one OCR line each, top
/// to bottom.
class FakeReceiptScanner implements ReceiptScanner {
  FakeReceiptScanner([this.rows = const []]);

  List<String> rows;
  QuickInputFailure? failure;

  @override
  Future<Result<List<OcrLine>, QuickInputFailure>> read(
    String imagePath,
  ) async {
    if (failure case final failure?) return Err(failure);
    return Ok(linesOf(rows));
  }

  static List<OcrLine> linesOf(List<String> rows) => [
    for (final (i, row) in rows.indexed)
      OcrLine(
        text: row,
        left: 10,
        top: i * 40,
        right: 400,
        bottom: i * 40 + 30,
      ),
  ];
}
