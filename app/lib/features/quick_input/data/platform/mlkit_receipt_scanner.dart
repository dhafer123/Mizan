import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/receipt_scanner.dart';
import '../../domain/value_objects/ocr_line.dart';
import '../../domain/value_objects/quick_input_error.dart';
import '../../domain/value_objects/quick_input_failure.dart';

/// [ReceiptScanner] on ML Kit text recognition (google_mlkit_text_recognition
/// 0.16.0), Latin script, bundled model: on the phone, offline.
class MlKitReceiptScanner implements ReceiptScanner {
  MlKitReceiptScanner();

  TextRecognizer? _recognizer;

  @override
  Future<Result<List<OcrLine>, QuickInputFailure>> read(
    String imagePath,
  ) async {
    try {
      final recognizer = _recognizer ??= TextRecognizer();
      final text = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return Ok([
        for (final block in text.blocks)
          for (final line in block.lines)
            OcrLine(
              text: line.text,
              left: line.boundingBox.left.round(),
              top: line.boundingBox.top.round(),
              right: line.boundingBox.right.round(),
              bottom: line.boundingBox.bottom.round(),
            ),
      ]);
    } on Object {
      return const Err(QuickInputFailure(QuickInputError.ocrFailed));
    }
  }
}
