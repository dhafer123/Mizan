import '../../../../core/result/result.dart';
import '../value_objects/quick_input_failure.dart';

/// Gets a receipt photo from the camera or the phone's photos.
abstract interface class ReceiptCamera {
  /// The photo's file path; Ok(null) if the user backed out.
  Future<Result<String?, QuickInputFailure>> take({required bool fromGallery});
}
