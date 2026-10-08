import '../../../../core/money/currency.dart';
import '../../../../core/result/result.dart';
import '../repositories/receipt_scanner.dart';
import '../value_objects/quick_input_failure.dart';
import '../value_objects/quick_parse.dart';
import 'read_receipt.dart';

/// Reads the receipt photo at a path: text recognition on the phone, then
/// [ReadReceipt]. Nothing is saved; the result goes to the confirmation
/// sheet.
class ScanReceipt {
  const ScanReceipt(this._scanner, this._read);

  final ReceiptScanner _scanner;
  final ReadReceipt _read;

  Future<Result<QuickParse, QuickInputFailure>> call(
    String imagePath, {
    required Currency currency,
    required DateTime today,
  }) async {
    switch (await _scanner.read(imagePath)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return Ok(await _read(value, currency: currency, today: today));
    }
  }
}
