import 'package:mizan/core/result/result.dart';
import 'package:mizan/features/quick_input/domain/repositories/receipt_camera.dart';
import 'package:mizan/features/quick_input/domain/value_objects/quick_input_failure.dart';

/// A [ReceiptCamera] that hands back [result] and records each call.
class FakeReceiptCamera implements ReceiptCamera {
  FakeReceiptCamera([this.result = const Ok('/photos/receipt.jpg')]);

  Result<String?, QuickInputFailure> result;

  /// `fromGallery` of each call, in order.
  final calls = <bool>[];

  @override
  Future<Result<String?, QuickInputFailure>> take({
    required bool fromGallery,
  }) async {
    calls.add(fromGallery);
    return result;
  }
}
