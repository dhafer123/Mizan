import '../../../../core/result/result.dart';
import '../repositories/receipt_camera.dart';
import '../value_objects/quick_input_failure.dart';

/// Takes a receipt photo, or picks one from the phone's photos. Ok(null) if
/// the user backed out.
class TakeReceiptPhoto {
  const TakeReceiptPhoto(this._camera);

  final ReceiptCamera _camera;

  Future<Result<String?, QuickInputFailure>> call({
    required bool fromGallery,
  }) => _camera.take(fromGallery: fromGallery);
}
